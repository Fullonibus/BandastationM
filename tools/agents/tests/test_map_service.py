"""Map transactions must not broaden edits or overwrite a changed source."""
from __future__ import annotations

import hashlib
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

try:
    from tools.agents.maps.service import MapService
except ModuleNotFoundError:
    MapService = None


FIXTURE = b'''//MAP CONVERTED BY dmm2tgm.py THIS HEADER COMMENT PREVENTS RECONVERSION, DO NOT REMOVE
"a" = (
/obj/item/crowbar,
/turf/open/floor/iron,
/area/shuttle/argos)

(1,1,1) = {"
a
a
"}
(2,1,1) = {"
a
a
"}
'''


def one_cell(atoms):
    return (FIXTURE.split(b'\n', 1)[0] + b'\n"a" = (\n' +
            ',\n'.join(atoms).encode() + b')\n\n(1,1,1) = {"\na\n"}\n')


class MapServiceTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(MapService, 'MapService is not implemented')
        self.stage = tempfile.TemporaryDirectory(prefix='bandastation-maps-service-')
        self.addCleanup(self.stage.cleanup)
        self.root = Path(self.stage.name)
        (self.root / '_maps').mkdir()
        (self.root / 'tools/maplint/lints').mkdir(parents=True)
        (self.root / 'tools/maplint/lints/fixture.yml').write_text(
            '=/obj/item/map_test_sentinel:\n  banned: true\n', encoding='utf-8')
        self.target = self.root / '_maps/example.dmm'
        self.target.write_bytes(FIXTURE)
        self.service = MapService(self.root)

    def call(self, tool, **arguments):
        return self.service.call(tool, arguments)

    def prepare(self, operations=None):
        return self.call('dmm_prepare_patch', path='_maps/example.dmm',
                         expected_sha256=hashlib.sha256(FIXTURE).hexdigest(),
                         operations=operations if operations is not None else [{
                             'op': 'replace_atom', 'at': [1, 1, 1], 'atom_index': 0,
                             'expected_atom': '/obj/item/crowbar', 'atom': '/obj/item/screwdriver'}])

    def test_preview_and_apply_change_one_shared_key_occurrence(self):
        plan = self.prepare()
        self.assertEqual(self.target.read_bytes(), FIXTURE)
        self.assertEqual(plan['diff']['changed_cells'], 1)
        preview = self.call('dmm_read', source=plan['sources']['after'], coordinates=[[1, 1, 1], [2, 1, 1]])
        self.assertEqual(preview['items'][0]['atoms'][0]['typepath'], '/obj/item/screwdriver')
        self.assertEqual(preview['items'][1]['atoms'][0]['typepath'], '/obj/item/crowbar')
        applied = self.call('dmm_apply_patch', plan_id=plan['plan_id'])
        self.assertEqual(applied['status'], 'applied')
        modified_at = self.target.stat().st_mtime_ns
        again = self.call('dmm_apply_patch', plan_id=plan['plan_id'])
        self.assertEqual(again['status'], 'already_applied')
        self.assertEqual(self.target.stat().st_mtime_ns, modified_at)

    def test_stale_source_and_tampered_candidate_are_rejected(self):
        plan = self.prepare()
        self.target.write_bytes(FIXTURE + b'\n')
        with self.assertRaisesRegex(ValueError, '(?i)changed|stale|hash'):
            self.call('dmm_apply_patch', plan_id=plan['plan_id'])
        self.assertEqual(self.target.read_bytes(), FIXTURE + b'\n')
        self.target.write_bytes(FIXTURE)
        candidate = self.root / 'task_state/map-tools' / plan['plan_id'] / 'after.dmm'
        candidate.write_bytes(FIXTURE)
        with self.assertRaisesRegex(ValueError, '(?i)integrity|candidate|hash'):
            self.call('dmm_apply_patch', plan_id=plan['plan_id'])
        self.assertEqual(self.target.read_bytes(), FIXTURE)

    def test_noop_does_not_rewrite_file(self):
        before = self.target.stat()
        plan = self.prepare([])
        self.assertTrue(plan['no_op'])
        result = self.call('dmm_apply_patch', plan_id=plan['plan_id'])
        self.assertEqual(result['status'], 'no_op')
        after = self.target.stat()
        self.assertEqual((before.st_mtime_ns, before.st_ino), (after.st_mtime_ns, after.st_ino))

    def test_cursor_is_bounded_and_bound_to_query_and_snapshot(self):
        source = {'path': '_maps/example.dmm'}
        first = self.call('dmm_read', source=source, limit=1)
        self.assertEqual(len(first['items']), 1)
        self.assertTrue(first['truncated'])
        second = self.call('dmm_read', source=source, limit=1, cursor=first['next_cursor'])
        self.assertNotEqual(first['items'][0]['at'], second['items'][0]['at'])
        with self.assertRaises(ValueError):
            self.call('dmm_read', source=source, limit=1, coordinates=[[2, 2, 1]], cursor=first['next_cursor'])
        self.target.write_bytes(FIXTURE + b'\n')
        with self.assertRaises(ValueError):
            self.call('dmm_read', source=source, limit=1, cursor=first['next_cursor'])

    def test_path_and_unknown_argument_rejection_has_no_side_effects(self):
        for path in ('../outside.dmm', '.git/objects/sample.dmm', 'task_state/map-tools/fake.dmm'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.call('dmm_info', path=path)
        with self.assertRaises(ValueError):
            self.call('dmm_info', path='_maps/example.dmm', command='unsafe')
        with self.assertRaises(ValueError):
            self.call('dmm_read', source={'path': '_maps/example.dmm'}, limit=True)
        self.assertFalse((self.root / 'task_state').exists())

    def test_new_maplint_errors_block_transaction_but_baseline_is_reported(self):
        rule = self.root / 'tools/maplint/lints/example.yml'
        rule.write_text('=/obj/item/screwdriver:\n  banned: true\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, '(?i)lint|validation'):
            self.prepare()
        self.assertEqual(self.target.read_bytes(), FIXTURE)
        rule.write_text('=/obj/item/crowbar:\n  banned: true\n', encoding='utf-8')
        baseline = self.call('dmm_validate', source={'path': '_maps/example.dmm'})
        self.assertFalse(baseline['ok'])
        self.assertFalse(baseline['runtime_checked'])
        plan = self.prepare()
        self.assertEqual(plan['validation']['introduced_errors'], [])
        self.assertGreater(len(plan['validation']['baseline_errors']), 0)

    def test_unavailable_lint_configuration_blocks_a_real_edit(self):
        (self.root / 'tools/maplint/lints/fixture.yml').unlink()
        with self.assertRaisesRegex(ValueError, '(?i)configuration|validation|lint'):
            self.prepare()
        self.assertEqual(self.target.read_bytes(), FIXTURE)

    def test_removing_last_banned_atom_does_not_lint_retained_unused_definition(self):
        raw = one_cell(('/obj/banned', '/turf/open/floor', '/area/test'))
        self.target.write_bytes(raw)
        (self.root / 'tools/maplint/lints/banned.yml').write_text('/obj/banned:\n  banned: true\n')
        plan = self.call('dmm_prepare_patch', path='_maps/example.dmm', expected_sha256=hashlib.sha256(raw).hexdigest(),
                         operations=[{'op': 'remove_atom', 'at': [1, 1, 1], 'atom_index': 0, 'expected_atom': '/obj/banned'}])
        self.assertEqual(len(plan['validation']['baseline_errors']), 1)
        self.assertEqual(plan['validation']['candidate_errors'], [])
        candidate = self.root / 'task_state/map-tools' / plan['plan_id'] / 'after.dmm'
        self.assertIn(b'"a" = (\n/obj/banned,', candidate.read_bytes())
        self.assertEqual(self.target.read_bytes(), raw)

    def test_adding_item_preserves_only_the_existing_last_used_key_violation(self):
        raw = one_cell(('/obj/banned', '/turf/open/floor', '/area/test'))
        self.target.write_bytes(raw)
        (self.root / 'tools/maplint/lints/banned.yml').write_text('/obj/banned:\n  banned: true\n')
        plan = self.call('dmm_prepare_patch', path='_maps/example.dmm', expected_sha256=hashlib.sha256(raw).hexdigest(),
                         operations=[{'op': 'add_atom', 'at': [1, 1, 1], 'atom': '/obj/item'}])
        old = plan['validation']['baseline_errors']
        new = plan['validation']['candidate_errors']
        self.assertEqual([item['signature'] for item in new], [item['signature'] for item in old])
        self.assertEqual([item['coordinates'] for item in new], [[1, 1, 1]])
        self.assertEqual(self.target.read_bytes(), raw)

    def test_repairing_last_invalid_stack_does_not_create_unused_structural_error(self):
        atoms = ('/obj/item', '/area/test')
        raw = one_cell(atoms)
        self.target.write_bytes(raw)
        plan = self.call('dmm_prepare_patch', path='_maps/example.dmm', expected_sha256=hashlib.sha256(raw).hexdigest(),
                         operations=[{'op': 'set_tile', 'at': [1, 1, 1], 'expected_atoms': list(atoms),
                                      'atoms': ['/turf/open/floor', '/area/test']}])
        self.assertEqual([item['kind'] for item in plan['validation']['baseline_errors']], ['structure'])
        self.assertEqual(plan['validation']['candidate_errors'], [])
        candidate = self.root / 'task_state/map-tools' / plan['plan_id'] / 'after.dmm'
        self.assertIn(b'"a" = (\n/obj/item,\n/area/test)', candidate.read_bytes())
        self.assertEqual(self.target.read_bytes(), raw)

    def test_new_used_banned_atom_still_rejects_whole_prepare(self):
        raw = one_cell(('/turf/open/floor', '/area/test'))
        self.target.write_bytes(raw)
        (self.root / 'tools/maplint/lints/banned.yml').write_text('/obj/banned:\n  banned: true\n')
        with self.assertRaisesRegex(ValueError, '(?i)validation.*banned'):
            self.call('dmm_prepare_patch', path='_maps/example.dmm', expected_sha256=hashlib.sha256(raw).hexdigest(),
                      operations=[{'op': 'add_atom', 'at': [1, 1, 1], 'atom': '/obj/banned'}])
        self.assertEqual(self.target.read_bytes(), raw)

    def test_capabilities_reports_maplint_rules_and_configuration_failures(self):
        ready = self.call('dmm_capabilities')['maplint']
        self.assertTrue(ready['available'])
        self.assertEqual(ready['rule_count'], 1)
        self.assertEqual(ready['diagnostics'], [])
        self.assertEqual(Path(ready['rules_directory']), self.root / 'tools/maplint/lints')

        rule = self.root / 'tools/maplint/lints/fixture.yml'
        rule.write_text('/obj/bad:\n  unknown_lint_option: true\n')
        broken = self.call('dmm_capabilities')['maplint']
        self.assertFalse(broken['available'])
        self.assertEqual(broken['rule_count'], 0)
        self.assertTrue(any('fixture.yml' in item for item in broken['diagnostics']))

        rule.unlink()
        absent = self.call('dmm_capabilities')['maplint']
        self.assertFalse(absent['available'])
        self.assertEqual(absent['rule_count'], 0)
        self.assertTrue(absent['diagnostics'])


if __name__ == '__main__':
    unittest.main()
