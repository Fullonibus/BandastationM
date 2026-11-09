"""Pinned dmm-tools sprite previews and explicitly schematic area diagrams."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import tomllib
import uuid

from PIL import Image, ImageDraw, UnidentifiedImageError

from .document import MapDocument, atom_path, normalize_region
from .renderer_compat import render_environment

RENDERER_SHA256 = 'e3967f7d954567497b297e4671d36baef50755126fea5db8608ba6d94042fb82'
MAX_IMAGES = 8
MAX_NATIVE_PIXELS = 67108864
MAX_PREVIEW_SIZE = 2048
RENDER_TIMEOUT = 120
TILE_SIZE = 32
VIEWS = ('appearance', 'power', 'atmos', 'areas')


def _limits():
    return {'images': MAX_IMAGES, 'native_pixels': MAX_NATIVE_PIXELS, 'preview_max_size': MAX_PREVIEW_SIZE,
            'default_max_size': 2048, 'timeout_seconds': RENDER_TIMEOUT, 'context_max': 8,
            'tile_size': TILE_SIZE, 'scales': [1, 2, 4]}


def renderer_capabilities(root: Path) -> dict:
    base = os.environ.get('LOCALAPPDATA')
    path = Path(base) / 'BandaStation/agent-tools/maps/dmm-tools.exe' if base else None
    result = {'available': False, 'path': str(path) if path else None, 'release': 'suite-1.12',
              'expected_sha256': RENDERER_SHA256, 'passes': [], 'diagnostics': [], 'limits': _limits()}
    if path is None or not path.is_file():
        result['diagnostics'].append('Pinned Windows dmm-tools.exe is not installed.')
        return result
    result['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    if result['sha256'] != RENDERER_SHA256:
        result['diagnostics'].append('Renderer SHA256 does not match the pinned suite-1.12 asset.')
        return result
    try:
        version = subprocess.run([str(path), '--version'], cwd=root, capture_output=True, text=True,
                                 encoding='utf-8', errors='replace', timeout=10, check=True)
        passes = subprocess.run([str(path), 'list-passes', '--json'], cwd=root, capture_output=True,
                                text=True, encoding='utf-8', errors='replace', timeout=10, check=True)
        result['version'] = version.stdout.strip()
        result['passes'] = json.loads(passes.stdout)
        names = {item['name'] for item in result['passes']}
        required = {'icon-smoothing-2025', 'only-powernet', 'only-pipenet'}
        if not required <= names:
            raise ValueError(f'Missing required renderer passes: {sorted(required - names)}')
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        result['diagnostics'].append(str(exc))
        return result
    result['available'] = True
    return result


def _inside(root, path):
    path = Path(path).resolve()
    try:
        parts = path.relative_to(root).parts
    except ValueError as exc:
        raise ValueError('Renderer paths must stay inside the checkout.') from exc
    if any(part.lower() == '.git' for part in parts):
        raise ValueError('Renderer paths cannot enter .git.')
    return path


def _integer(value, name, minimum, maximum):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f'{name} must be an integer from {minimum} to {maximum}.')
    return value


def _passes(root, capabilities, view):
    config_file = root / 'SpacemanDMM.toml'
    config = tomllib.loads(config_file.read_text(encoding='utf-8')) if config_file.exists() else {}
    overrides = config.get('map_renderer', {}).get('render_passes', {})
    names = [p['name'] for p in capabilities['passes'] if overrides.get(p['name'], p['default'])]
    excluded = {'random', 'icon-smoothing', 'icon-smoothing-2016',
                'only-powernet', 'only-pipenet', 'only-wires-and-pipes'}
    names = [name for name in names if name not in excluded]
    if 'icon-smoothing-2025' not in names:
        names.append('icon-smoothing-2025')
    if view == 'power':
        names.append('only-powernet')
    elif view == 'atmos':
        names.append('only-pipenet')
    return names


def _area_image(document, job, target):
    lo, hi = job['bounds']['min'], job['bounds']['max']
    image = Image.new('RGB', tuple(job['native_size']))
    draw = ImageDraw.Draw(image)
    legend = {}
    for at in document.coordinates(job['bounds']):
        area = next((atom for atom in document.tile(at) if atom_path(atom).split('/', 2)[1] == 'area'), None)
        if area is None:
            raise ValueError(f'Cannot draw area diagram: tile {at} has no area.')
        color = tuple(64 + byte % 160 for byte in hashlib.sha256(area.encode()).digest()[:3])
        legend[area] = {'typepath': atom_path(area), 'raw': area, 'color': list(color)}
        x, y = (at[0] - lo[0]) * TILE_SIZE, (hi[1] - at[1]) * TILE_SIZE
        draw.rectangle((x, y, x + TILE_SIZE - 1, y + TILE_SIZE - 1), fill=color)
    image.save(target)
    image.close()
    return [legend[key] for key in sorted(legend)]


def _preview(native, target, job):
    try:
        with Image.open(native) as image:
            if image.format != 'PNG' or list(image.size) != job['native_size']:
                raise ValueError('Native renderer returned an unexpected PNG size or format.')
            image.load()
            if image.mode == 'RGBA' and image.getextrema()[3] == (0, 0):
                job['diagnostics'].append('The rendered image is fully transparent; this may be an empty network view.')
            width, height = image.size
            ratio = min(job['scale'], job['max_size'] / max(width, height))
            size = (max(1, round(width * ratio)), max(1, round(height * ratio)))
            resample = Image.Resampling.NEAREST if ratio >= 1 else Image.Resampling.LANCZOS
            preview = image.resize(size, resample=resample)
            preview.save(target)
            preview.close()
    except (OSError, UnidentifiedImageError, Image.DecompressionBombError) as exc:
        raise ValueError(f'Native renderer did not produce a readable PNG: {exc}') from exc
    return list(size)


def render_requests(root: Path, requests: list[dict], output_dir: Path) -> dict:
    """Validate the whole batch before output; use one render-many per sprite preset."""
    root = Path(root).resolve()
    output_dir = _inside(root, output_dir)
    if not isinstance(requests, list) or not 1 <= len(requests) <= MAX_IMAGES:
        raise ValueError(f'Render requests must contain 1 to {MAX_IMAGES} items.')
    jobs, documents = [], {}
    pixels = 0
    for index, request in enumerate(requests):
        if not isinstance(request, dict) or set(request) - {'path', 'region', 'view', 'context', 'scale', 'max_size'}:
            raise ValueError('Unknown render request fields.')
        if not isinstance(request.get('path'), str) or not Path(request['path']).is_absolute():
            raise ValueError('Renderer input must be an absolute DMM snapshot path.')
        path = _inside(root, request['path'])
        if path.suffix.lower() != '.dmm':
            raise ValueError('Renderer input must be a DMM snapshot.')
        if path not in documents:
            documents[path] = MapDocument.from_bytes(path.read_bytes())
        document = documents[path]
        lo, hi = normalize_region(request.get('region'), document.size)
        context = _integer(request.get('context', 1), 'context', 0, 8)
        scale = _integer(request.get('scale', 1), 'scale', 1, 4)
        if scale not in (1, 2, 4):
            raise ValueError('scale must be 1, 2 or 4.')
        max_size = _integer(request.get('max_size', 2048), 'max_size', 64, MAX_PREVIEW_SIZE)
        view = request.get('view', 'appearance')
        if view not in VIEWS:
            raise ValueError(f'view must be one of {VIEWS}.')
        xmin, ymin = max(1, lo[0] - context), max(1, lo[1] - context)
        xmax, ymax = min(document.size[0], hi[0] + context), min(document.size[1], hi[1] + context)
        for z in range(lo[2], hi[2] + 1):
            size = [(xmax - xmin + 1) * TILE_SIZE, (ymax - ymin + 1) * TILE_SIZE]
            pixels += size[0] * size[1]
            jobs.append({'request_index': index, 'source': path, 'view': view, 'scale': scale, 'max_size': max_size,
                         'context': context, 'bounds': {'min': [xmin, ymin, z], 'max': [xmax, ymax, z]},
                         'requested_bounds': {'min': [lo[0], lo[1], z], 'max': [hi[0], hi[1], z]},
                         'native_size': size, 'diagnostics': []})
            if len(jobs) > MAX_IMAGES or pixels > MAX_NATIVE_PIXELS:
                raise ValueError('Render batch exceeds image/native pixel limits; select fewer Z levels or smaller regions.')

    sprite_jobs = [job for job in jobs if job['view'] != 'areas']
    capabilities = renderer_capabilities(root) if sprite_jobs else {'available': True, 'backend': 'area-schematic', 'limits': _limits()}
    if sprite_jobs and not capabilities['available']:
        raise ValueError('Sprite renderer unavailable: ' + '; '.join(capabilities['diagnostics']))
    if sprite_jobs and 'icon-smoothing-2025' not in {p['name'] for p in capabilities['passes']}:
        raise ValueError('Sprite renderer lacks required icon-smoothing-2025 pass.')
    directory = output_dir / ('render-' + uuid.uuid4().hex)
    directory.mkdir(parents=True)
    # Copy exact snapshot bytes to unique stems: RenderMany names output by input stem.
    snapshots = {}
    for index, (path, document) in enumerate(documents.items()):
        target = directory / f'source-{index}.dmm'
        target.write_bytes(document.raw)
        snapshots[path] = target

    diagnostics = []
    if sprite_jobs:
        with render_environment(root, directory) as (environment, compatibility):
            _render_native(root, jobs, capabilities, directory, snapshots, diagnostics, environment)
        capabilities = {**capabilities, 'compatibility': compatibility}

    images = []
    for index, job in enumerate(jobs):
        document = documents[job['source']]
        if job['view'] == 'areas':
            native = directory / f'areas-{index}.png'
            job['legend'] = _area_image(document, job, native)
            job['native_path'] = str(native)
            job['passes'] = []
        preview = directory / f'preview-{index}.png'
        preview_size = _preview(job['native_path'], preview, job)
        images.append({key: value for key, value in job.items() if key not in ('source', 'max_size')} | {
            'path': str(preview), 'source_sha256': document.sha256, 'preview_size': preview_size,
            'pixels_per_tile': preview_size[0] / (job['bounds']['max'][0] - job['bounds']['min'][0] + 1),
            'preview_scale_xy': [preview_size[axis] / job['native_size'][axis] for axis in (0, 1)],
            'pixel_origin': 'northwest', 'y_axis': 'north', 'schematic': job['view'] == 'areas',
            'runtime_checked': False})
    return {'images': images, 'diagnostics': diagnostics, 'renderer': capabilities}


def _render_native(root, jobs, capabilities, directory, snapshots, diagnostics, environment):
    deadline = time.monotonic() + RENDER_TIMEOUT
    for view in ('appearance', 'power', 'atmos'):
        selected = [job for job in jobs if job['view'] == view]
        if not selected:
            continue
        native_dir = directory / view
        grouped = {}
        for job in selected:
            lo, hi = job['bounds']['min'], job['bounds']['max']
            chunk = {'z': lo[2], 'min_x': lo[0], 'min_y': lo[1], 'max_x': hi[0], 'max_y': hi[1]}
            grouped.setdefault(job['source'], []).append((job, chunk))
        passes = _passes(root, capabilities, view)
        payload = {'output_directory': str(native_dir), 'enable': passes, 'disable': ['all'],
                   'files': [{'path': str(snapshots[path]), 'chunks': [chunk for _, chunk in entries]} for path, entries in grouped.items()]}
        try:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise ValueError('Render batch exceeded its total subprocess time limit.')
            completed = subprocess.run([capabilities['path'], '--env', str(environment), 'render-many'],
                                       input=json.dumps(payload), cwd=root, capture_output=True, text=True,
                                       encoding='utf-8', errors='replace', timeout=remaining, check=False)
            if completed.stderr:
                diagnostics.append({'view': view, 'message': completed.stderr[-32768:]})
            if completed.returncode:
                raise ValueError(f'dmm-tools exited with {completed.returncode}: {completed.stderr[-4000:]}')
            response = json.loads(completed.stdout)
            files = response['files']
            if len(files) != len(grouped):
                raise ValueError('Native renderer returned an unexpected file count.')
            for entries, result in zip(grouped.values(), files):
                if len(result['chunks']) != len(entries):
                    raise ValueError('Native renderer returned an unexpected chunk count.')
                for (job, _), chunk in zip(entries, result['chunks']):
                    filename = chunk['filename']
                    if not isinstance(filename, str) or Path(filename).name != filename:
                        raise ValueError('Native renderer returned an unsafe filename.')
                    native = _inside(native_dir.resolve(), native_dir / filename)
                    job['native_path'] = str(native)
                    job['passes'] = passes
        except (OSError, KeyError, TypeError, json.JSONDecodeError, subprocess.SubprocessError) as exc:
            raise ValueError(f'Native renderer failed: {exc}') from exc

