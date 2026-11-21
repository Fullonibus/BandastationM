"""Regression checks for map validation and bounded, coordinate-aware previews."""
import contextlib
import hashlib
import importlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
from PIL.PngImagePlugin import PngInfo

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))


def tgm(definitions=None, columns=None):
    definitions = definitions or {"a": ("/turf/open/floor", "/area/template_noop")}
    columns = columns or [["a"]]
    text = '//MAP CONVERTED BY dmm2tgm.py THIS HEADER COMMENT PREVENTS RECONVERSION, DO NOT REMOVE\n'
    for key, atoms in definitions.items():
        text += f'"{key}" = (\n' + ',\n'.join(atoms) + ')\n'
    text += '\n'
    for x, column in enumerate(columns, 1):
        text += f'({x},1,1) = {{"\n' + '\n'.join(column) + '\n"}\n'
    return text.encode()


class MapRenderingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'snapshot.dmm'
        self.out = self.root / 'out'
        self.renderer = importlib.import_module('tools.agents.maps.renderer')
        self.validation = importlib.import_module('tools.agents.maps.validation')
        self.document = importlib.import_module('tools.agents.maps.document')

    def validate(self, raw, logical='_maps/ordinary.dmm'):
        lint_dir = self.root / 'tools/maplint/lints'
        lint_dir.mkdir(parents=True, exist_ok=True)
        (lint_dir / 'noop.yml').write_text('/area/template_noop:\n  banned_neighbors:\n    - /turf/open\n  skip_files:\n    - _maps/templates\n')
        return self.validation.validate_document(self.document.MapDocument.from_bytes(raw), logical, self.root)

    def test_maplint_uses_logical_path_and_stable_cell_signatures(self):
        raw = tgm(columns=[['a', 'a']])
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            skipped = self.validate(raw, '_maps/templates/room.dmm')
            first = self.validate(raw)
            # Splitting the same stack among keys must not invent new lint errors.
            second = self.validate(tgm({'b': ('/turf/open/floor', '/area/template_noop'), 'c': ('/turf/open/floor', '/area/template_noop')}, [['b', 'c']]))
        self.assertTrue(skipped['ok'])
        self.assertFalse(first['ok'])
        self.assertEqual({e['signature'] for e in first['errors']}, {e['signature'] for e in second['errors']})
        self.assertEqual({tuple(e['coordinates']) for e in first['errors']}, {(1, 1, 1), (1, 2, 1)})
        self.assertEqual(stdout.getvalue(), '')
        self.assertFalse(first['runtime_checked'])

    def test_structure_rejects_tile_without_turf(self):
        # Parsing may accept existing bad stacks; validation must still report them.
        raw = tgm({'a': ('/obj/item', '/area/test')})
        result = self.validate(raw)
        self.assertFalse(result['ok'])
        self.assertTrue(any(e['kind'] == 'structure' for e in result['errors']))

    def test_maplint_capabilities_reports_missing_yaml_dependency(self):
        original_import = __import__

        def missing_yaml(name, *args, **kwargs):
            if name == 'yaml':
                raise ModuleNotFoundError('No module named yaml')
            return original_import(name, *args, **kwargs)

        with patch('builtins.__import__', side_effect=missing_yaml):
            result = self.validation.validation_capabilities(self.root)
        self.assertFalse(result['available'])
        self.assertEqual(result['rule_count'], 0)
        self.assertTrue(any('yaml' in item for item in result['diagnostics']))

    def test_adding_duplicate_banned_atom_creates_a_new_lint_signature(self):
        lint_dir = self.root / 'tools/maplint/lints'
        lint_dir.mkdir(parents=True)
        (lint_dir / 'banned.yml').write_text('/obj/banned:\n  banned: true\n')
        first = self.validate(tgm({'a': ('/obj/banned', '/turf/open/floor', '/area/test')}))
        second = self.validate(tgm({'a': ('/obj/banned', '/obj/banned', '/turf/open/floor', '/area/test')}))
        baseline = {item['signature'] for item in first['errors']}
        added = {item['signature'] for item in second['errors']} - baseline
        self.assertEqual(len(added), 1)

    def test_capabilities_refuse_wrong_digest_and_missing_smoothing_pass(self):
        executable = self.root / 'BandaStation/agent-tools/maps/dmm-tools.exe'
        executable.parent.mkdir(parents=True)
        executable.write_bytes(b'test renderer executable')
        with patch.dict('os.environ', {'LOCALAPPDATA': str(self.root)}):
            with patch.object(self.renderer.subprocess, 'run', side_effect=AssertionError('untrusted executable ran')):
                rejected = self.renderer.renderer_capabilities(self.root)
            self.assertFalse(rejected['available'])
            self.assertIn('SHA256', rejected['diagnostics'][0])

            def native(command, **kwargs):
                response = 'dmm-tools 1.12.0' if command[-1] == '--version' else '[{"name":"only-powernet","default":false},{"name":"only-pipenet","default":false}]'
                return subprocess.CompletedProcess(command, 0, response, '')

            digest = hashlib.sha256(executable.read_bytes()).hexdigest()
            with patch.object(self.renderer, 'RENDERER_SHA256', digest), patch.object(self.renderer.subprocess, 'run', side_effect=native):
                rejected = self.renderer.renderer_capabilities(self.root)
            self.assertFalse(rejected['available'])
            self.assertIn('icon-smoothing-2025', rejected['diagnostics'][0])

    def test_compatibility_renames_only_dmi_metadata_and_cleans_wrapper(self):
        compat = importlib.import_module('tools.agents.maps.renderer_compat')
        asset = self.root / 'icons/turf/walls/plastitanium_wall.dmi'
        asset.parent.mkdir(parents=True)
        metadata = PngInfo()
        metadata.add_text('Description', '# BEGIN DMI\nversion = 4.0\nwidth = 32\nheight = 32\nstate = "wall-5-diagonal"\n\tdirs = 1\n\tframes = 1\n# END DMI\n', zip=True)
        Image.new('RGBA', (32, 32), (30, 40, 50, 255)).save(asset, format='PNG', pnginfo=metadata)
        original = asset.read_bytes()
        self.out.mkdir()
        before = set(self.root.iterdir())
        with self.assertRaisesRegex(RuntimeError, 'failed subprocess'):
            with compat.render_environment(self.root, self.out) as (environment, info):
                self.assertEqual(environment.parent, self.root)
                text = environment.read_text()
                self.assertIn('#define CBT', text)
                self.assertIn(str(self.root / 'tgstation.dme').replace('\\', '/'), text)
                staged = Path(info['assets'][0]['staged_path'])
                with Image.open(staged) as alias, Image.open(asset) as source:
                    self.assertIn('state = "wall-5-d"', alias.info['Description'])
                    self.assertEqual(alias.tobytes(), source.tobytes())
                self.assertEqual(asset.read_bytes(), original)
                raise RuntimeError('failed subprocess')
        self.assertFalse(environment.exists())
        self.assertEqual(set(self.root.iterdir()), before)
        self.assertEqual(asset.read_bytes(), original)

    def test_cardinal_diagonal_alias_keeps_the_original_cardinal_pixels(self):
        # Native2025 also asks for -d at single cardinal junctions, whereas
        # runtime uses the unsuffixed frame there. Never invent a diagonal image.
        from tools.dmi import Dmi
        compat = importlib.import_module('tools.agents.maps.renderer_compat')
        asset = self.root / 'icons/turf/walls/plastitanium_wall.dmi'
        asset.parent.mkdir(parents=True)
        source = Dmi(32, 32)
        source.state('wall-1').frame(Image.new('RGBA', (32, 32), 'red'))
        source.state('wall-5-diagonal').frame(Image.new('RGBA', (32, 32), 'blue'))
        source.to_file(asset)
        original = asset.read_bytes()
        self.out.mkdir()
        with compat.render_environment(self.root, self.out) as (_, info):
            result = Dmi.from_file(info['assets'][0]['staged_path'])
            self.assertEqual(result.get_state('wall-1-d').get_frame().tobytes(), source.get_state('wall-1').get_frame().tobytes())
            self.assertEqual(result.get_state('wall-5-d').get_frame().tobytes(), source.get_state('wall-5-diagonal').get_frame().tobytes())
        self.assertEqual(asset.read_bytes(), original)

    def test_area_colors_and_north_orientation_survive_key_renaming(self):
        raw = tgm({'a': ('/turf/open/floor', '/area/south'), 'b': ('/turf/open/floor', '/area/north')}, [['b', 'a']])
        self.source.write_bytes(raw)
        first = self.renderer.render_requests(self.root, [{'path': str(self.source), 'view': 'areas', 'context': 0}], self.out)
        info = first['images'][0]
        self.assertTrue(info['schematic'])
        self.assertEqual(info['bounds'], {'min': [1, 1, 1], 'max': [1, 2, 1]})
        with Image.open(info['path']) as im:
            self.assertEqual(im.size, (32, 64))
            north, south = im.getpixel((16, 16)), im.getpixel((16, 48))
        legend = {item['typepath']: tuple(item['color']) for item in info['legend']}
        self.assertEqual(north[:3], legend['/area/north'])
        self.assertEqual(south[:3], legend['/area/south'])
        self.source.write_bytes(raw.replace(b'"a"', b'"c"').replace(b'\na\n', b'\nc\n'))
        second = self.renderer.render_requests(self.root, [{'path': str(self.source), 'view': 'areas', 'context': 0}], self.root / 'out2')
        self.assertEqual(Path(info['path']).read_bytes(), Path(second['images'][0]['path']).read_bytes())

    def test_region_and_batch_limits_reject_before_native_execution(self):
        self.source.write_bytes(tgm())
        for request in [
            {'region': {'min': [0, 1, 1], 'max': [1, 1, 1]}},
            {'context': True}, {'scale': 3}, {'max_size': 999999}, {'view': 'unknown'},
        ]:
            with self.subTest(request=request), self.assertRaises(ValueError):
                self.renderer.render_requests(self.root, [{'path': str(self.source), **request}], self.out)
        with self.assertRaises(ValueError):
            self.renderer.render_requests(self.root, [{'path': str(self.source), 'view': 'areas'}] * 9, self.out)
        with patch.object(self.renderer, 'MAX_NATIVE_PIXELS', 1023), self.assertRaises(ValueError):
            self.renderer.render_requests(self.root, [{'path': str(self.source), 'view': 'areas'}], self.out)

    def test_native_protocol_scaling_and_bad_image_rejection(self):
        self.source.write_bytes(tgm(columns=[['a', 'a'], ['a', 'a']]))
        capabilities = {'available': True, 'path': 'dmm-tools.exe', 'passes': [
            {'name': 'hide-areas', 'default': True}, {'name': 'random', 'default': True},
            {'name': 'spawners', 'default': True},
            {'name': 'icon-smoothing-2025', 'default': False}, {'name': 'only-powernet', 'default': False},
            {'name': 'only-pipenet', 'default': False}], 'diagnostics': []}

        def native(command, **kwargs):
            self.assertEqual(command[-3], '--env')
            self.assertEqual(command[-1], 'render-many')
            environment = Path(command[-2])
            self.assertEqual(environment.parent, self.root)
            self.assertIn('#define CBT', environment.read_text())
            payload = json.loads(kwargs['input'])
            self.assertEqual(payload['disable'], ['all'])
            self.assertIn('only-powernet', payload['enable'])
            self.assertNotIn('random', payload['enable'])
            self.assertIn('spawners', payload['enable'])
            chunk = payload['files'][0]['chunks'][0]
            self.assertEqual(chunk, {'z': 1, 'min_x': 1, 'min_y': 1, 'max_x': 2, 'max_y': 2})
            directory = Path(payload['output_directory'])
            directory.mkdir(parents=True, exist_ok=True)
            Image.new('RGBA', (64, 64), (10, 20, 30, 255)).save(directory / 'native.png')
            return subprocess.CompletedProcess(command, 0, json.dumps({'files': [{'chunks': [{'filename': 'native.png'}]}]}), 'warning: resource diagnostic')

        with patch.object(self.renderer, 'renderer_capabilities', return_value=capabilities), patch.object(self.renderer.subprocess, 'run', side_effect=native):
            result = self.renderer.render_requests(self.root, [{'path': str(self.source), 'view': 'power', 'region': {'min': [2, 2, 1], 'max': [2, 2, 1]}, 'context': 1, 'scale': 4, 'max_size': 128}], self.out)
        info = result['images'][0]
        self.assertEqual(info['native_size'], [64, 64])
        self.assertEqual(info['preview_size'], [128, 128])
        self.assertEqual(info['pixels_per_tile'], 64)
        self.assertTrue(result['diagnostics'])

        def bad_native(command, **kwargs):
            payload = json.loads(kwargs['input'])
            directory = Path(payload['output_directory'])
            directory.mkdir(parents=True, exist_ok=True)
            (directory / 'bad.png').write_bytes(b'not a PNG')
            return subprocess.CompletedProcess(command, 0, '{"files":[{"chunks":[{"filename":"bad.png"}]}]}', '')

        with patch.object(self.renderer, 'renderer_capabilities', return_value=capabilities), patch.object(self.renderer.subprocess, 'run', side_effect=bad_native), self.assertRaises(ValueError):
            self.renderer.render_requests(self.root, [{'path': str(self.source)}], self.root / 'bad-out')


if __name__ == '__main__':
    unittest.main()
