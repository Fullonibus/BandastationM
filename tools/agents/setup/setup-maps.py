"""Install only the pinned maps MCP runtime and its checkout-local config section."""
from __future__ import annotations

import argparse
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tomllib
import urllib.request
from uuid import uuid4

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'lib'))
from toolkit import ROOT, digest, ordinary, run

spec = importlib.util.spec_from_file_location('setup_tools', Path(__file__).with_name('setup-tools.py'))
setup_tools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup_tools)

RENDERER_SHA256 = 'e3967f7d954567497b297e4671d36baef50755126fea5db8608ba6d94042fb82'
RENDERER_URL = 'https://github.com/SpaceManiac/SpacemanDMM/releases/download/suite-1.12/dmm-tools.exe'
SECTION = 'mcp_servers.bandastation-maps'


def maps_section(node: str) -> str:
    template = (ROOT/'.AGENTS/templates/codex.toml').read_text(encoding='utf-8-sig')
    start = template.index('['+SECTION+']')
    section = re.split(r'(?m)^\[', template[start+1:], maxsplit=1)[0]
    section = '['+section
    token = lambda value: str(value).replace('\\', '/').replace('"', '\\"')
    return section.replace('{{NODE}}', token(node)).replace('{{WORKSPACE}}', token(ROOT)).rstrip()+'\n'


def merge_config(text: str, section: str) -> str:
    """Replace our table while retaining every byte of unrelated custom tables."""
    parsed = tomllib.loads(text)
    headers = []
    for candidate in re.finditer(r'(?m)^[ \t]*\[.*\][ \t]*(?:#[^\r\n]*)?\r?$', text):
        try:
            # A prefix ending inside a multiline string/array is not a table boundary.
            tomllib.loads(text[:candidate.start()])
            table = tomllib.loads(candidate.group()+'\n')
        except tomllib.TOMLDecodeError:
            continue
        headers.append((candidate, 'bandastation-maps' in table.get('mcp_servers', {})))
    ranges = []
    for index, (header, owned) in enumerate(headers):
        if owned:
            ranges.append((header.start(), headers[index+1][0].start() if index+1 < len(headers) else len(text)))
    if 'bandastation-maps' in parsed.get('mcp_servers', {}) and not ranges:
        raise ValueError('Existing maps configuration uses an inline/quoted table; preserve it and merge the maps section explicitly')
    if ranges:
        first = ranges[0][0]
        for start, end in reversed(ranges):
            text = text[:start]+text[end:]
        result = text[:first]+section+('\n' if text[first:] else '')+text[first:]
    else:
        result = text+('' if not text or text.endswith('\n\n') else '\n' if text.endswith('\n') else '\n\n')+section
    tomllib.loads(result)
    return result


def install_renderer(cache: Path) -> None:
    executable = cache/'dmm-tools.exe'
    ordinary(executable)
    if not executable.is_file() or digest(executable) != RENDERER_SHA256:
        temporary = cache/('dmm-tools-'+uuid4().hex+'.download')
        try:
            request = urllib.request.Request(RENDERER_URL, headers={'User-Agent': 'BandaStation-maps-setup/1.0'})
            with urllib.request.urlopen(request, timeout=60) as response, temporary.open('xb') as target:
                size = 0
                while chunk := response.read(1024*1024):
                    size += len(chunk)
                    if size > 100*1024*1024:
                        raise ValueError('Pinned renderer download exceeds 100 MiB')
                    target.write(chunk)
            if digest(temporary) != RENDERER_SHA256:
                raise ValueError('Pinned suite-1.12 renderer SHA256 mismatch')
            temporary.replace(executable)
        finally:
            temporary.unlink(missing_ok=True)
    version = run([str(executable), '--version'], cwd=ROOT).strip()
    passes = run([str(executable), 'list-passes'], cwd=ROOT)
    if 'icon-smoothing-2025' not in passes:
        raise ValueError('Pinned renderer lacks icon-smoothing-2025')
    print('PASS: pinned suite-1.12 renderer SHA256; '+version+'; icon-smoothing-2025')


def install_maps(seed: Path | None, repair: bool) -> None:
    setup_tools.install_runtime('maps', ROOT/'tools/agents/mcp/maps', seed, repair)
    cache = Path(os.environ['LOCALAPPDATA'])/'BandaStation/agent-tools/maps'
    install_renderer(cache)
    node = shutil.which('node.exe')
    if not node:
        raise ValueError('Node.js >=20 is required')
    print(run([node, str(ROOT/'tools/agents/mcp/maps-mcp.cjs'), '--check'], cwd=ROOT).strip())
    setup_tools.record_runtime('maps', ROOT/'tools/agents/mcp/maps')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repair', action='store_true')
    parser.add_argument('--config-only', action='store_true')
    parser.add_argument('--maps-seed', type=Path)
    args = parser.parse_args()
    if os.name != 'nt' or not os.environ.get('LOCALAPPDATA'):
        raise ValueError('This setup requires Windows and LOCALAPPDATA')
    node = shutil.which('node.exe')
    if not node:
        raise ValueError('Node.js >=20 is required')
    config = ROOT/'.codex/config.toml'
    ordinary(config)
    encoding = 'utf-8-sig' if config.exists() and config.read_bytes().startswith(b'\xef\xbb\xbf') else 'utf-8'
    if config.exists():
        with config.open(encoding=encoding, newline='') as stream:
            original = stream.read()
    else:
        original = ''
    rendered = merge_config(original, maps_section(node))
    if not args.config_only:
        install_maps(args.maps_seed, args.repair)
    config.parent.mkdir(parents=True, exist_ok=True)
    if rendered != original:
        with config.open('w', encoding=encoding, newline='') as stream:
            stream.write(rendered)
    print('PASS: maps-only checkout config; other tables, global config, Git hooks and excludes preserved.')
    if args.config_only:
        print('SKIP: dependency installation and runtime checks (--config-only).')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error)) from error
