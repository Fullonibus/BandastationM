"""Bounded map operations and persistent, previewable one-file transactions."""
from __future__ import annotations

import base64
from collections import Counter
import hashlib
import itertools
import json
from pathlib import Path
import re
import sys

from .document import MapDocument, atom_path, normalize_region
from .patch import build_changes
from .paths import MapPaths, atomic_replace


def fields(value, allowed, required=()):
    if not isinstance(value, dict):
        raise ValueError('Arguments must be an object')
    unknown = set(value) - set(allowed)
    missing = set(required) - set(value)
    if unknown or missing:
        raise ValueError('Invalid fields: ' + ', '.join(sorted(unknown)) +
                         ('; missing: ' + ', '.join(sorted(missing)) if missing else ''))


def integer(value, minimum, maximum, label):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f'{label} must be an integer from {minimum} to {maximum}')
    return value


def canonical(value) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


class MapService:
    def __init__(self, root: Path):
        self.paths = MapPaths(root)
        self.root = self.paths.root

    def call(self, tool: str, arguments: dict) -> dict:
        handlers = {
            'dmm_capabilities': self.capabilities, 'dmm_info': self.info, 'dmm_read': self.read,
            'dmm_find': self.find, 'dmm_render': self.render, 'dmm_prepare_patch': self.prepare,
            'dmm_apply_patch': self.apply, 'dmm_diff': self.diff, 'dmm_validate': self.validate,
        }
        if tool not in handlers:
            raise ValueError('Unknown map tool: ' + str(tool))
        if not isinstance(arguments, dict):
            raise ValueError('Tool arguments must be an object')
        return handlers[tool](arguments)

    def document(self, path: Path) -> MapDocument:
        raw = path.read_bytes()
        if len(raw) > 64 * 1024 * 1024:
            raise ValueError('Map exceeds the 64 MiB document limit')
        model = MapDocument.from_bytes(raw)
        if len(model.grid) > 1000000:
            raise ValueError('Map exceeds the one million cell document limit')
        return model

    def plan(self, plan_id: str) -> tuple[dict, Path]:
        directory = self.paths.plan(plan_id)
        metadata_path = self.paths.artifact(directory / 'plan.json')
        try:
            wrapper = json.loads(metadata_path.read_text(encoding='utf-8'))
            metadata = wrapper['metadata']
            if wrapper['sha256'] != digest(canonical(metadata)):
                raise ValueError('Plan metadata integrity check failed')
            if metadata['format'] != 1 or metadata['root'] != str(self.root) or metadata['plan_id'] != plan_id:
                raise ValueError('Plan belongs to another checkout or format')
            for side in ('before', 'after'):
                path = self.paths.artifact(directory / (side + '.dmm'))
                if digest(path.read_bytes()) != metadata[side + '_sha256']:
                    raise ValueError('Plan candidate/snapshot hash integrity check failed')
        except (KeyError, TypeError, json.JSONDecodeError, OSError) as error:
            raise ValueError('Invalid or incomplete map plan: ' + str(error)) from error
        return metadata, directory

    def source(self, source: dict) -> tuple[MapDocument, str]:
        if isinstance(source, dict) and 'path' in source:
            fields(source, ('path',), ('path',))
            path = self.paths.map(source['path'])
            return self.document(path), self.paths.relative(path)
        fields(source, ('plan_id', 'side'), ('plan_id', 'side'))
        if source['side'] not in ('before', 'after'):
            raise ValueError('Plan side must be before or after')
        metadata, directory = self.plan(source['plan_id'])
        return self.document(directory / (source['side'] + '.dmm')), metadata['path']

    def capabilities(self, args):
        fields(args, ())
        from .renderer import renderer_capabilities
        from .validation import validation_capabilities
        return {'format': 'TGM', 'coordinates': 'BYOND XYZ, 1-based; Y north; inclusive bounds',
                'python': {'version': sys.version.split()[0], 'executable': sys.executable},
                'maplint': validation_capabilities(self.root),
                'renderer': renderer_capabilities(self.root), 'runtime_checked': False,
                'limits': {'page': 1000, 'operations': 10000, 'map_bytes': 64 * 1024 * 1024}}

    def info(self, args):
        fields(args, ('path',), ('path',))
        path = self.paths.map(args['path'])
        model = self.document(path)
        occurrences = Counter(model.grid.values())
        types = Counter()
        areas = Counter()
        for key, count in occurrences.items():
            for atom in model.tiles[key]:
                typepath = atom_path(atom)
                types[typepath] += count
                if typepath == '/area' or typepath.startswith('/area/'):
                    areas[typepath] += count
        return {'path': self.paths.relative(path), 'sha256': model.sha256, 'format': 'TGM',
                'size': list(model.size), 'cells': len(model.grid), 'definitions': len(model.tiles),
                'type_count': len(types), 'areas': dict(sorted(areas.items())),
                'types': dict(types.most_common(100)), 'types_truncated': len(types) > 100}

    def page(self, args, records, snapshot):
        limit = integer(args.get('limit', 100), 1, 1000, 'limit')
        query = {key: value for key, value in args.items() if key not in ('limit', 'cursor')}
        query_hash = digest(canonical(query))
        offset = 0
        if 'cursor' in args:
            cursor = args['cursor']
            if not isinstance(cursor, str) or len(cursor) > 2048:
                raise ValueError('Invalid cursor')
            try:
                data = json.loads(base64.urlsafe_b64decode(cursor.encode('ascii')))
                if data['snapshot'] != snapshot or data['query'] != query_hash:
                    raise ValueError('Cursor query or source snapshot changed')
                offset = integer(data['offset'], 0, 100000000, 'cursor offset')
            except (KeyError, TypeError, UnicodeError, json.JSONDecodeError) as error:
                raise ValueError('Invalid cursor') from error
        batch = list(itertools.islice(records, offset, offset + limit + 1))
        truncated = len(batch) > limit
        next_cursor = None
        if truncated:
            next_cursor = base64.urlsafe_b64encode(canonical({
                'snapshot': snapshot, 'query': query_hash, 'offset': offset + limit})).decode('ascii')
        return batch[:limit], truncated, next_cursor

    def read(self, args):
        fields(args, ('source', 'region', 'coordinates', 'limit', 'cursor'), ('source',))
        model, logical = self.source(args['source'])
        if 'coordinates' in args:
            if 'region' in args:
                raise ValueError('Use coordinates or region, not both')
            coords = args['coordinates']
            if not isinstance(coords, list) or not 1 <= len(coords) <= 10000:
                raise ValueError('coordinates must contain 1 to 10000 XYZ positions')
            validated = []
            for at in coords:
                low, _ = normalize_region({'min': at, 'max': at}, model.size)
                validated.append(low)
            coordinates = iter(validated)
        else:
            coordinates = model.coordinates(args.get('region'))
        def records():
            for at in coordinates:
                yield {'at': list(at), 'atoms': [
                    {'index': index, 'typepath': atom_path(atom), 'raw': atom}
                    for index, atom in enumerate(model.tile(at))]}
        items, truncated, cursor = self.page(args, records(), model.sha256)
        return {'path': logical, 'sha256': model.sha256, 'items': items,
                'truncated': truncated, 'next_cursor': cursor}

    def find(self, args):
        fields(args, ('source', 'typepath', 'subtypes', 'region', 'limit', 'cursor'), ('source', 'typepath'))
        needle = args['typepath']
        if not isinstance(needle, str) or not re.fullmatch(r'/[A-Za-z_][A-Za-z_0-9]*(?:/[A-Za-z_][A-Za-z_0-9]*)*', needle):
            raise ValueError('typepath must be an absolute DM type path')
        if type(args.get('subtypes', False)) is not bool:
            raise ValueError('subtypes must be boolean')
        model, logical = self.source(args['source'])
        matching = {}
        for key, atoms in model.tiles.items():
            matches = []
            for index, atom in enumerate(atoms):
                path = atom_path(atom)
                if path == needle or (args.get('subtypes', False) and path.startswith(needle + '/')):
                    matches.append((index, path, atom))
            if matches:
                matching[key] = matches
        def records():
            for at in model.coordinates(args.get('region')):
                for index, path, atom in matching.get(model.grid[at], ()):
                    yield {'at': list(at), 'atom_index': index, 'typepath': path, 'raw': atom}
        items, truncated, cursor = self.page(args, records(), model.sha256)
        return {'path': logical, 'sha256': model.sha256, 'items': items,
                'truncated': truncated, 'next_cursor': cursor, 'matching': 'lexical typepath'}

    @staticmethod
    def differences(before, after):
        for at in sorted(before.grid.keys() | after.grid.keys(), key=lambda at: (at[2], at[1], at[0])):
            old = before.tile(at) if at in before.grid else ()
            new = after.tile(at) if at in after.grid else ()
            if old != new:
                yield {'at': list(at), 'before': list(old), 'after': list(new)}

    def diff(self, args):
        fields(args, ('left', 'right', 'limit', 'cursor'), ('left', 'right'))
        before, _ = self.source(args['left'])
        after, _ = self.source(args['right'])
        changed_cells = sum(1 for _ in self.differences(before, after))
        items, truncated, cursor = self.page(args, self.differences(before, after), before.sha256 + ':' + after.sha256)
        return {'before_sha256': before.sha256, 'after_sha256': after.sha256,
                'changed_cells': changed_cells, 'changes': items, 'truncated': truncated, 'next_cursor': cursor,
                'comparison': 'ordered raw atoms by coordinate; dictionary keys ignored'}

    def validate(self, args):
        fields(args, ('source',), ('source',))
        from .validation import validate_document
        model, logical = self.source(args['source'])
        result = validate_document(model, logical, self.root)
        return {**result, 'errors': result['errors'][:1000], 'error_count': len(result['errors']),
                'truncated': len(result['errors']) > 1000, 'path': logical, 'sha256': model.sha256}

    def checked_validation(self, before, after, logical):
        from .validation import validate_document
        baseline = validate_document(before, logical, self.root)
        candidate = validate_document(after, logical, self.root)
        if before.raw != after.raw:
            for issue in candidate['errors']:
                if (issue['rule'] in ('configuration', 'parse') or
                        issue['message'].startswith('Lint could not run:')):
                    raise ValueError('Maplint validation is unavailable: ' + issue['message'][:1000])
        signatures = {item['signature'] for item in baseline['errors']}
        introduced = [item for item in candidate['errors'] if item['signature'] not in signatures]
        if introduced:
            raise ValueError('Map validation rejected new errors: ' + introduced[0]['message'][:1000])
        return baseline, candidate, introduced

    def prepare(self, args):
        fields(args, ('path', 'expected_sha256', 'operations'), ('path', 'expected_sha256', 'operations'))
        expected = args['expected_sha256']
        if not isinstance(expected, str) or not re.fullmatch('[0-9a-f]{64}', expected):
            raise ValueError('expected_sha256 must come from a current map read')
        if not isinstance(args['operations'], list) or len(args['operations']) > 10000:
            raise ValueError('operations must be a list of at most 10000 operations')
        path = self.paths.map(args['path'])
        before = self.document(path)
        if before.sha256 != expected:
            raise ValueError('Source hash changed; read the current map before preparing edits')
        changes = build_changes(before, args['operations'])
        after = MapDocument.from_bytes(before.rewrite(changes))
        logical = self.paths.relative(path)
        old_validation, new_validation, introduced = self.checked_validation(before, after, logical)
        directory = self.paths.create('')
        plan_id = directory.name
        metadata = {'format': 1, 'root': str(self.root), 'plan_id': plan_id, 'path': logical,
                    'before_sha256': before.sha256, 'after_sha256': after.sha256,
                    'operations': args['operations']}
        (directory / 'before.dmm').write_bytes(before.raw)
        (directory / 'after.dmm').write_bytes(after.raw)
        (directory / 'plan.json').write_text(json.dumps({
            'metadata': metadata, 'sha256': digest(canonical(metadata))}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        diff = list(itertools.islice(self.differences(before, after), 101))
        changed_cells = sum(1 for _ in self.differences(before, after))
        return {'plan_id': plan_id, 'before_sha256': before.sha256, 'after_sha256': after.sha256,
                'no_op': before.raw == after.raw,
                'diff': {'changed_cells': changed_cells, 'changes': diff[:100], 'truncated': changed_cells > 100},
                'validation': {'baseline_errors': old_validation['errors'][:1000], 'candidate_errors': new_validation['errors'][:1000],
                               'baseline_error_count': len(old_validation['errors']), 'candidate_error_count': len(new_validation['errors']),
                               'errors_truncated': len(old_validation['errors']) > 1000 or len(new_validation['errors']) > 1000,
                               'introduced_errors': introduced},
                'sources': {side: {'plan_id': plan_id, 'side': side} for side in ('before', 'after')}}

    def apply(self, args):
        fields(args, ('plan_id',), ('plan_id',))
        metadata, directory = self.plan(args['plan_id'])
        path = self.paths.map(metadata['path'])
        current = self.document(path)
        if current.sha256 == metadata['after_sha256']:
            status = 'no_op' if metadata['before_sha256'] == current.sha256 else 'already_applied'
        else:
            if current.sha256 != metadata['before_sha256']:
                raise ValueError('Source changed after preview; prepare a new plan')
            after = self.document(directory / 'after.dmm')
            expected_bytes = current.rewrite(build_changes(current, metadata['operations']))
            if expected_bytes != after.raw:
                raise ValueError('Candidate integrity differs from the planned operations')
            self.checked_validation(current, after, metadata['path'])
            atomic_replace(path, after.raw, current.sha256)
            status = 'applied'
        return {'status': status, 'plan_id': args['plan_id'], 'path': metadata['path'],
                'sha256': metadata['after_sha256'], 'runtime_checked': False}

    def render(self, args):
        fields(args, ('requests',), ('requests',))
        requests = args['requests']
        if not isinstance(requests, list) or not 1 <= len(requests) <= 8:
            raise ValueError('requests must contain 1 to 8 image requests')
        snapshots = []
        for request in requests:
            fields(request, ('source', 'region', 'view', 'context', 'scale', 'max_size'), ('source',))
            model, logical = self.source(request['source'])
            snapshots.append((model, logical, request))
        directory = self.paths.create('render-')
        prepared = []
        for index, (model, logical, request) in enumerate(snapshots):
            snapshot = directory / f'{index}-{Path(logical).name}'
            snapshot.write_bytes(model.raw)
            prepared.append({key: value for key, value in request.items() if key != 'source'} | {'path': str(snapshot)})
        from .renderer import render_requests
        return render_requests(self.root, prepared, directory)
