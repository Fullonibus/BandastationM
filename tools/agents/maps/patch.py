"""Resolve map operations against one immutable original document snapshot."""

from __future__ import annotations

from tools.agents.maps.document import Coord, MapDocument, _coordinate, atom_path, normalize_region, validate_stack

_FIELDS = {
    "add_atom": ({"op", "at", "atom"}, {"position"}),
    "remove_atom": ({"op", "at", "atom_index", "expected_atom"}, set()),
    "replace_atom": ({"op", "at", "atom_index", "expected_atom", "atom"}, set()),
    "set_turf": ({"op", "at", "expected_atom", "atom"}, set()),
    "set_area": ({"op", "at", "expected_atom", "atom"}, set()),
    "set_tile": ({"op", "at", "expected_atoms", "atoms"}, set()),
    "fill_region": ({"op", "region", "atoms"}, set()),
    "copy_region": ({"op", "source_region", "at"}, set()),
}


def _atoms(value: object, name: str) -> tuple[str, ...]:
    if not isinstance(value, list) or any(not isinstance(atom, str) for atom in value):
        raise ValueError(f"{name} must be an array of raw atom strings")
    return tuple(value)


def _index(value: object, maximum: int, name: str) -> int:
    if type(value) is not int or value < 0 or value > maximum:
        raise ValueError(f"{name} must be an integer between 0 and {maximum}")
    return value


def build_changes(document: MapDocument, operations: list[dict]) -> dict[Coord, tuple[str, ...]]:
    """Build complete final cell assignments without mutating the document.

    Atom edits address original indices; additions address gaps before original
    indices. Multiple additions to a gap retain their operation order. Whole-tile
    and atom-level assignments to the same cell cannot be mixed.
    """
    if not isinstance(operations, list):
        raise ValueError("Operations must be an array")
    whole = {}
    edits = {}

    def assign(at: Coord, atoms: tuple[str, ...]) -> None:
        validate_stack(atoms)
        if at in edits or (at in whole and whole[at] != atoms):
            raise ValueError(f"Conflicting tile assignments at {at}")
        whole[at] = atoms

    for operation in operations:
        if not isinstance(operation, dict):
            raise ValueError("Each operation must be an object")
        kind = operation.get("op")
        if not isinstance(kind, str) or kind not in _FIELDS:
            raise ValueError("Unknown map operation")
        required, optional = _FIELDS[kind]
        if not required <= operation.keys() or operation.keys() - required - optional:
            raise ValueError(f"Invalid fields for {kind}")
        if kind == "fill_region":
            atoms = _atoms(operation["atoms"], "atoms")
            validate_stack(atoms)
            # A required region cannot be null (None means full map only for reads).
            if operation["region"] is None:
                raise ValueError("fill_region requires an explicit region")
            for at in document.coordinates(operation["region"]):
                assign(at, atoms)
            continue
        at = _coordinate(operation["at"], document.size)
        if kind == "copy_region":
            if operation["source_region"] is None:
                raise ValueError("copy_region requires an explicit source_region")
            low, high = normalize_region(operation["source_region"], document.size)
            destination_high = tuple(at[axis] + high[axis] - low[axis] for axis in range(3))
            _coordinate(destination_high, document.size, "copy destination")
            for source in document.coordinates(operation["source_region"]):
                destination = tuple(at[axis] + source[axis] - low[axis] for axis in range(3))
                assign(destination, document.tile(source))
            continue
        original = document.tile(at)
        if kind == "set_tile":
            if _atoms(operation["expected_atoms"], "expected_atoms") != original:
                raise ValueError(f"Expected tile does not match original snapshot at {at}")
            assign(at, _atoms(operation["atoms"], "atoms"))
            continue
        if at in whole:
            raise ValueError(f"Conflicting tile and atom assignments at {at}")
        replacements, additions = edits.setdefault(at, ({}, {}))
        if kind == "add_atom":
            atom = operation["atom"]
            path = atom_path(atom)
            if path.split("/", 2)[1] in {"turf", "area"}:
                raise ValueError("add_atom accepts objects or mobs; use set_turf/set_area for those categories")
            if "position" in operation:
                index = _index(operation["position"], len(original), "position")
            else:
                validate_stack(original)
                index = len(original) - 2
            additions.setdefault(index, []).append(atom)
            continue
        if kind in {"set_turf", "set_area"}:
            category = kind.removeprefix("set_")
            matching = [index for index, atom in enumerate(original) if atom_path(atom).split("/", 2)[1] == category]
            if len(matching) != 1:
                raise ValueError(f"Original tile must contain exactly one {category}")
            index = matching[0]
            if atom_path(operation["atom"]).split("/", 2)[1] != category:
                raise ValueError(f"{kind} replacement must be a /{category} atom")
        else:
            index = _index(operation["atom_index"], len(original) - 1, "atom_index")
        if not isinstance(operation["expected_atom"], str) or operation["expected_atom"] != original[index]:
            raise ValueError(f"Expected atom does not match original snapshot at {at}, index {index}")
        if index in replacements:
            raise ValueError(f"Conflicting atom assignments at {at}, index {index}")
        if kind == "remove_atom":
            replacements[index] = None
        else:
            atom_path(operation["atom"])
            replacements[index] = operation["atom"]
    result = dict(whole)
    for at, (replacements, additions) in edits.items():
        atoms = []
        original = document.tile(at)
        for index in range(len(original) + 1):
            atoms.extend(additions.get(index, ()))
            if index < len(original):
                atom = replacements.get(index, original[index])
                if atom is not None:
                    atoms.append(atom)
        final = tuple(atoms)
        validate_stack(final)
        result[at] = final
    return {at: atoms for at, atoms in result.items() if atoms != document.tile(at)}
