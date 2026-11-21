"""Narrow, disposable adaptations for suite-1.12 and this checkout's wall DMI."""
from contextlib import contextmanager
import hashlib
import os
from pathlib import Path
import re
import struct
import tempfile
import zlib


# These are the icon assignments of every current diagonal wall family in
# code/game/turfs/closed/{wall/mineral_walls,wall/reinf_walls,indestructible}.dm.
# Include diagonal child assignments too; nodiagonal children keep their own
# original icons because the native engine does not request -d for those types.
WALL_ICONS = {
    'abductor_wall': ('/turf/closed/wall/mineral/abductor', '/turf/closed/indestructible/alien'),
    'shuttle_wall': ('/turf/closed/wall/mineral/titanium', '/turf/closed/wall/mineral/titanium/overspace'),
    'plastitanium_wall': ('/turf/closed/wall/mineral/plastitanium',
                         '/turf/closed/wall/mineral/plastitanium/overspace', '/turf/closed/wall/r_wall/plastitanium',
                         '/turf/closed/wall/r_wall/plastitanium/overspace', '/turf/closed/wall/r_wall/plastitanium/syndicate/overspace'),
    'plastinum_wall': ('/turf/closed/indestructible/riveted/plastinum',),
    'dark_pod': ('/turf/closed/wall/mineral/plastitanium/darkpod',),
    'red_pod': ('/turf/closed/wall/mineral/plastitanium/redpod',),
    'survival_pod_walls': ('/turf/closed/wall/mineral/plastitanium/survival',),
}


def _diagonal_metadata(raw):
    """Rename DMI states without touching a single encoded PNG pixel chunk."""
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Compatibility DMI is not a PNG.')
    result, offset, count = [raw[:8]], 8, 0
    while offset < len(raw):
        if offset + 12 > len(raw):
            raise ValueError('Truncated compatibility DMI chunk.')
        length = struct.unpack('>I', raw[offset:offset + 4])[0]
        end = offset + length + 12
        if end > len(raw):
            raise ValueError('Truncated compatibility DMI payload.')
        kind = raw[offset + 4:offset + 8]
        data = raw[offset + 8:end - 4]
        compressed = kind == b'zTXt' and data.startswith(b'Description\x00\x00')
        textual = kind == b'tEXt' and data.startswith(b'Description\x00')
        if compressed or textual:
            prefix = b'Description\x00\x00' if compressed else b'Description\x00'
            description = zlib.decompress(data[len(prefix):]) if compressed else data[len(prefix):]
            description, renamed = re.subn(rb'(?m)^(state\s*=\s*"[^"\r\n]+)-diagonal("\s*)$', rb'\1-d\2', description)
            # suite-1.12 also requests -d for single cardinal junctions, unlike
            # the game. On diagonal-only icons these names use the normal frame.
            description, cardinals = re.subn(rb'(?m)^(state\s*=\s*"[^"\r\n]+-(?:1|2|4|8))("\s*)$', rb'\1-d\2', description)
            count += renamed + cardinals
            payload = prefix + (zlib.compress(description) if compressed else description)
            result.append(struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload)))
        else:
            result.append(raw[offset:end])
        offset = end
    return b''.join(result), count


@contextmanager
def render_environment(root: Path, output: Path):
    """Keep icon lookup at checkout root and remove the exclusive wrapper on exit."""
    root, output = Path(root), Path(output)
    content = ['#define CBT', f'#include "{(root / "tgstation.dme").as_posix()}"', '#undef CBT']
    smoothing = root / 'modular_bandastation/aesthetics/smoothing/code/smoothing.dm'
    if smoothing.is_file():
        # This source supplies renderer-only List overrides for the game's encoded
        # smoothing groups. Reapplying vars after CBT preserves native adjacency.
        content.append(f'#include "{smoothing.as_posix()}"')
    assets = []
    for stem, typepaths in WALL_ICONS.items():
        source = root / 'icons/turf/walls' / (stem + '.dmi')
        if not source.is_file():
            continue
        raw = source.read_bytes()
        aliased, count = _diagonal_metadata(raw)
        if not count:
            continue
        target = output / (stem + '-native.dmi')
        target.write_bytes(aliased)
        literal = target.as_posix().replace("'", "\\'")
        content.extend(f"{typepath}\n\ticon = '{literal}'" for typepath in typepaths)
        assets.append({'source_path': str(source), 'staged_path': str(target), 'renamed_states': count,
                       'source_sha256': hashlib.sha256(raw).hexdigest(), 'staged_sha256': hashlib.sha256(aliased).hexdigest()})
    # This nodiagonal child inherits icon from its diagonal parent rather than
    # assigning one itself. Keep its cardinal state names on the original DMI.
    abductor = root / 'icons/turf/walls/abductor_wall.dmi'
    if abductor.is_file():
        literal = abductor.as_posix().replace("'", "\\'")
        content.append(f"/turf/closed/indestructible/alien/nodiagonal\n\ticon = '{literal}'")
    descriptor, filename = tempfile.mkstemp(prefix='.maps-preview-', suffix='.test.dme', dir=root)
    path = Path(filename)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8', newline='\n') as stream:
            stream.write('\n'.join(content) + '\n')
        yield path, {'runtime_map_switch': True, 'diagonal_suffix': '-d', 'assets': assets,
                     'renderer_smoothing_overrides': smoothing.is_file(), 'temporary_environment_cleaned': True}
    finally:
        path.unlink(missing_ok=True)
