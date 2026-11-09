"""Map integrity regressions for the source-preserving TGM editor."""

import hashlib
import io
from pathlib import Path
import string
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from tools.agents.maps.document import MapDocument, atom_path, normalize_region, validate_stack
from tools.agents.maps.patch import build_changes
from tools.maplint.source.dmm import parse_dmm


HEADER = b"//MAP CONVERTED BY dmm2tgm.py THIS HEADER COMMENT PREVENTS RECONVERSION, DO NOT REMOVE\n"
FLOOR = "/turf/open/floor"
AREA = "/area/test"
BASE = ("/obj/item/a", FLOOR, AREA)


def tgm(tiles=None, columns=None, newline="\n"):
    tiles = tiles or {"a": BASE}
    columns = columns or {(1, 1): ["a", "a"], (2, 1): ["a", "a"]}
    text = HEADER.decode()
    for key, atoms in tiles.items():
        text += '"' + key + '" = (\n' + ',\n'.join(atoms) + ')\n'
    text += "\n// dictionary retained, including unused keys\n"
    for (x, z), keys in columns.items():
        text += f'({x},1,{z}) = {{"\n' + '\n'.join(keys) + '\n"}\n\n'
    return text.replace("\n", newline).encode("utf-8")


class DocumentTests(unittest.TestCase):
    def test_shared_key_changes_only_selected_cell(self):
        raw = tgm()
        doc = MapDocument.from_bytes(raw)
        replacement = ("/obj/item/b", FLOOR, AREA)
        result = doc.rewrite({(1, 1, 1): replacement})
        after = MapDocument.from_bytes(result)
        self.assertEqual(after.tile((1, 1, 1)), replacement)
        for at in ((1, 2, 1), (2, 1, 1), (2, 2, 1)):
            self.assertEqual(after.tile(at), BASE)
        self.assertIn(b'"a" = (\n/obj/item/a,\n/turf/open/floor,\n/area/test)\n', result)
        self.assertEqual(doc.raw, raw)
        self.assertEqual(doc.sha256, hashlib.sha256(raw).hexdigest())

    def test_rewritten_normal_definitions_remain_maplint_compatible(self):
        raw = tgm().replace(b'// dictionary retained, including unused keys\n', b'')

        def parse(raw):
            reader = io.StringIO(raw.decode("utf-8"))
            reader.name = "_maps/example.dmm"
            return parse_dmm(reader)

        self.assertEqual(len(parse(raw).pops), 1)
        replacement = ("/obj/item/screwdriver", FLOOR, AREA)
        rewritten = MapDocument.from_bytes(raw).rewrite({(1, 1, 1): replacement})
        parsed = parse(rewritten)
        self.assertEqual([str(atom.path) for atom in parsed.pops["b"]], list(replacement))
        self.assertEqual(parsed.turfs[0][0], ["a", "b"])

    def test_noop_and_existing_stack_reuse(self):
        raw = tgm({"a": BASE, "b": (FLOOR, AREA)})
        doc = MapDocument.from_bytes(raw)
        self.assertEqual(doc.rewrite({}), raw)
        self.assertEqual(doc.rewrite({(1, 1, 1): BASE}), raw)
        result = doc.rewrite({(1, 1, 1): (FLOOR, AREA)})
        self.assertEqual(result, raw.replace(b'a\na\n"}', b'a\nb\n"}', 1))

    def test_deterministic_allocation_independent_of_change_order(self):
        doc = MapDocument.from_bytes(tgm())
        first, second = ("/obj/item/b", FLOOR, AREA), ("/obj/item/c", FLOOR, AREA)
        left = doc.rewrite({(2, 1, 1): second, (1, 1, 1): first})
        right = doc.rewrite({(1, 1, 1): first, (2, 1, 1): second})
        self.assertEqual(left, right)
        parsed = MapDocument.from_bytes(left)
        self.assertEqual(parsed.grid[(1, 1, 1)], "b")
        self.assertEqual(parsed.grid[(2, 1, 1)], "c")

    def test_complex_atoms_and_unrelated_comment_bytes_survive(self):
        atom = r'''/obj/item/a{
	name = "Кириллица, \"quoted, close ) }\"";
	icon = 'icons/a,b.dmi';
	values = list("a,b" = list(1, 2), /obj/item/a);
	/* comma, and brackets ) } */ desc = "backslash: \\\\";
	// comma, close ) }
	dir = 4
	}'''
        raw = tgm({"a": (atom, FLOOR, AREA), "z": ("/obj/unused", FLOOR, AREA)}, newline="\r\n")
        doc = MapDocument.from_bytes(raw)
        self.assertEqual(doc.tile((1, 1, 1))[0], atom.replace("\n", "\r\n"))
        result = doc.rewrite({(1, 1, 1): ("/obj/new",) + doc.tile((1, 1, 1))})
        separator = raw.index(b'\r\n\r\n// dictionary')
        self.assertTrue(result.startswith(raw[:separator]))
        self.assertIn(raw[separator:raw.index(b'(1,1,1)')], result)
        self.assertEqual(MapDocument.from_bytes(result).tile((1, 1, 1))[1], doc.tile((1, 1, 1))[0])
        self.assertIn(b'"z" = (\r\n/obj/unused,\r\n/turf/open/floor,\r\n/area/test)', result)

    def test_asymmetric_multi_z_uses_north_up_and_zyx_iteration(self):
        tiles = {key: (f"/obj/{key}", FLOOR, AREA) for key in "abcdef"}
        doc = MapDocument.from_bytes(tgm(tiles, {(1, 1): list("abc"), (2, 1): list("def"), (1, 2): list("fed"), (2, 2): list("cba")}))
        self.assertEqual(doc.size, (2, 3, 2))
        self.assertEqual(doc.tile((1, 3, 1)), tiles["a"])
        self.assertEqual(doc.tile((2, 1, 2)), tiles["a"])
        self.assertEqual(list(doc.coordinates({"min": [1, 2, 1], "max": [2, 3, 2]})), [(x, y, z) for z in (1, 2) for y in (2, 3) for x in (1, 2)])

    def test_raw_trailing_line_comments_remain_separate_from_delimiters(self):
        raw = tgm()
        doc = MapDocument.from_bytes(raw)
        atoms = ("/obj/commented // delimiters, ) } are a comment", FLOOR, AREA)
        after = MapDocument.from_bytes(doc.rewrite({(1, 1, 1): atoms}))
        self.assertEqual(after.tile((1, 1, 1)), atoms)

    def test_interpolated_dm_string_handles_nested_quotes_and_brackets(self):
        atom = '/obj/item/a{name = "prefix [list(\")\", list(\",\", \"[1 + 2]\"))] suffix"}'
        doc = MapDocument.from_bytes(tgm({"a": (atom, FLOOR, AREA)}))
        self.assertEqual(doc.tile((1, 1, 1)), (atom, FLOOR, AREA))
        after = MapDocument.from_bytes(doc.rewrite({(1, 1, 1): ("/obj/new", atom, FLOOR, AREA)}))
        self.assertEqual(after.tile((1, 1, 1)), ("/obj/new", atom, FLOOR, AREA))

    def test_invalid_structure_and_regions_fail_explicitly(self):
        raw = tgm()
        for broken in (raw.replace(b'(2,1,1)', b'(3,1,1)'), raw.replace(b'a\na\n"}', b'a\n"}', 1), raw.replace(b'a\na\n"}', b'a\nz\n"}', 1), raw.replace(b'(2,1,1)', b'(1,1,1)'), raw.replace(b'a\na\n"}', b'aa\naa\n"}', 1), raw.replace(b'"a" =', b'"aa" =', 1), raw.replace(HEADER, b'')):
            with self.subTest(broken=broken[-100:]), self.assertRaises(ValueError):
                MapDocument.from_bytes(broken)
        for region in ({"min": [True, 1, 1], "max": [2, 2, 1]}, {"min": [1, 1.0, 1], "max": [2, 2, 1]}, {"min": [0, 1, 1], "max": [2, 2, 1]}, {"min": [2, 1, 1], "max": [1, 2, 1]}, {"min": [1, 1, 1], "max": [2, 2, 1], "extra": 1}):
            with self.subTest(region=region), self.assertRaises(ValueError):
                normalize_region(region, (2, 2, 1))

    def test_exhausted_keyspace_rejected_without_mutation(self):
        tiles = {key: (f"/obj/{key}", FLOOR, AREA) for key in string.ascii_letters}
        doc = MapDocument.from_bytes(tgm(tiles))
        with self.assertRaisesRegex(ValueError, "key.*(space|exhaust)|exhaust.*key"):
            doc.rewrite({(1, 1, 1): ("/obj/new", FLOOR, AREA)})
        self.assertEqual(doc.tile((1, 1, 1)), tiles["a"])

    def test_atom_validation_rejects_injection_and_wrong_categories(self):
        self.assertEqual(atom_path('/obj/foo{v = list("a,b", 1)}'), "/obj/foo")
        for atoms in ((FLOOR,), (AREA, FLOOR), (FLOOR, FLOOR, AREA), (FLOOR, AREA, "/obj/a"), ("/obj/a,/obj/b", FLOOR, AREA), ("/obj/a{v = 1} garbage", FLOOR, AREA), ("/obj/a{v = list(1,2)", FLOOR, AREA)):
            with self.subTest(atoms=atoms), self.assertRaises(ValueError):
                validate_stack(atoms)


class PatchTests(unittest.TestCase):
    def document(self, atoms=BASE):
        return MapDocument.from_bytes(tgm({"a": atoms}))

    def test_edited_stacks_accept_only_obj_and_mob_before_turf(self):
        doc = self.document()
        for invalid in ("/datum", "/proc/foo", "/list"):
            with self.subTest(invalid=invalid):
                baseline = self.document((invalid, FLOOR, AREA))
                self.assertEqual(baseline.tile((1, 1, 1)), (invalid, FLOOR, AREA))
                self.assertEqual(baseline.rewrite({}), baseline.raw)
                with self.assertRaises(ValueError):
                    build_changes(doc, [{"op": "add_atom", "at": [1, 1, 1], "atom": invalid}])
                with self.assertRaises(ValueError):
                    doc.rewrite({(1, 1, 1): (invalid, FLOOR, AREA)})
        operations = [{"op": "add_atom", "at": [1, 1, 1], "atom": atom} for atom in ("/obj/item/crowbar", "/mob/living/basic")]
        after = MapDocument.from_bytes(doc.rewrite(build_changes(doc, operations)))
        self.assertEqual(after.tile((1, 1, 1)), (BASE[0], "/obj/item/crowbar", "/mob/living/basic", FLOOR, AREA))

    def test_duplicate_atoms_and_indices_reference_original_snapshot(self):
        duplicate = "/obj/item/same"
        doc = self.document((duplicate, duplicate, "/obj/third", FLOOR, AREA))
        changes = build_changes(doc, [{"op": "remove_atom", "at": [1, 1, 1], "atom_index": 0, "expected_atom": duplicate}, {"op": "remove_atom", "at": [1, 1, 1], "atom_index": 1, "expected_atom": duplicate}, {"op": "replace_atom", "at": [1, 1, 1], "atom_index": 2, "expected_atom": "/obj/third", "atom": "/obj/replaced"}])
        self.assertEqual(changes, {(1, 1, 1): ("/obj/replaced", FLOOR, AREA)})
        self.assertEqual(doc.tile((1, 1, 1)), (duplicate, duplicate, "/obj/third", FLOOR, AREA))

    def test_add_positions_and_turf_area_replacements(self):
        doc = self.document()
        changes = build_changes(doc, [{"op": "add_atom", "at": [1, 1, 1], "atom": "/obj/new"}, {"op": "add_atom", "at": [1, 1, 1], "atom": "/obj/first", "position": 0}, {"op": "set_turf", "at": [1, 1, 1], "expected_atom": FLOOR, "atom": "/turf/closed/wall"}, {"op": "set_area", "at": [1, 1, 1], "expected_atom": AREA, "atom": "/area/new"}])
        self.assertEqual(changes[(1, 1, 1)], ("/obj/first", "/obj/item/a", "/obj/new", "/turf/closed/wall", "/area/new"))

    def test_overlapping_copy_reads_original_snapshot(self):
        tiles = {key: (f"/obj/{key}", FLOOR, AREA) for key in "abc"}
        doc = MapDocument.from_bytes(tgm(tiles, {(1, 1): ["a"], (2, 1): ["b"], (3, 1): ["c"]}))
        changes = build_changes(doc, [{"op": "copy_region", "source_region": {"min": [1, 1, 1], "max": [2, 1, 1]}, "at": [2, 1, 1]}])
        self.assertEqual(changes, {(2, 1, 1): tiles["a"], (3, 1, 1): tiles["b"]})

    def test_fill_and_set_tile(self):
        doc = self.document()
        new = [FLOOR, AREA]
        changes = build_changes(doc, [{"op": "fill_region", "region": {"min": [1, 1, 1], "max": [2, 1, 1]}, "atoms": new}, {"op": "set_tile", "at": [1, 2, 1], "expected_atoms": list(BASE), "atoms": new}])
        self.assertEqual(changes, {(1, 1, 1): tuple(new), (2, 1, 1): tuple(new), (1, 2, 1): tuple(new)})

    def test_conflicts_and_stale_expected_atoms_reject_whole_transaction(self):
        doc = self.document()
        remove = {"op": "remove_atom", "at": [1, 1, 1], "atom_index": 0, "expected_atom": BASE[0]}
        conflicts = [[remove, remove], [remove, {"op": "replace_atom", "at": [1, 1, 1], "atom_index": 0, "expected_atom": BASE[0], "atom": "/obj/b"}], [remove, {"op": "set_tile", "at": [1, 1, 1], "expected_atoms": list(BASE), "atoms": [FLOOR, AREA]}], [{"op": "fill_region", "region": {"min": [1, 1, 1], "max": [2, 2, 1]}, "atoms": [FLOOR, AREA]}, {"op": "set_tile", "at": [1, 1, 1], "expected_atoms": list(BASE), "atoms": ["/obj/b", FLOOR, AREA]}], [{**remove, "expected_atom": "/obj/stale"}]]
        for operations in conflicts:
            with self.subTest(operations=operations), self.assertRaises(ValueError):
                build_changes(doc, operations)
        self.assertEqual(doc.tile((1, 1, 1)), BASE)

    def test_strict_arguments_categories_and_bounds(self):
        doc = self.document()
        invalid = [{"op": "add_atom", "at": [True, 1, 1], "atom": "/obj/a"}, {"op": "add_atom", "at": [1, 1, 1], "atom": "/obj/a", "position": True}, {"op": "add_atom", "at": [1, 1, 1], "atom": "/turf/closed"}, {"op": "add_atom", "at": [1, 1, 1], "atom": "/obj/a", "unknown": 0}, {"op": "remove_atom", "at": [1, 1, 1], "atom_index": True, "expected_atom": BASE[0]}, {"op": "set_turf", "at": [1, 1, 1], "expected_atom": FLOOR, "atom": "/area/wrong"}, {"op": "set_area", "at": [1, 1, 1], "expected_atom": AREA, "atom": "/obj/wrong"}, {"op": "copy_region", "source_region": {"min": [1, 1, 1], "max": [2, 2, 1]}, "at": [2, 1, 1]}, {"op": "set_tile", "at": [1, 1, 1], "expected_atoms": [FLOOR, AREA], "atoms": [FLOOR, AREA]}]
        for operation in invalid:
            with self.subTest(operation=operation), self.assertRaises(ValueError):
                build_changes(doc, [operation])


if __name__ == "__main__":
    unittest.main()
