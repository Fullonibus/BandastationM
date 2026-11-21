"""TGM documents retaining the source bytes of definitions and grid tokens.

DM values are opaque text. The scanner only balances delimiters, quotes and
comments; it never evaluates or normalizes a mapped atom's variable values.
"""

from __future__ import annotations

import hashlib
import re
from collections.abc import Iterator

from tools.mapmerge2.dmm import MAX_KEY_LENGTH, TGM_HEADER, base52, max_key_for, num_to_key

Coord = tuple[int, int, int]
_PATH = re.compile(r"/[A-Za-z_][A-Za-z_0-9]*(?:/[A-Za-z_][A-Za-z_0-9]*)*")
_COORD_HEADER = re.compile(r'\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)\s*=\s*\{"')
_OPEN = {"(": ")", "[": "]", "{": "}"}


def _comment_end(text: str, start: int) -> int:
    if text.startswith("//", start):
        end = text.find("\n", start + 2)
        return len(text) if end == -1 else end + 1
    depth, pos = 1, start + 2
    while depth:
        if pos >= len(text):
            raise ValueError("Unterminated block comment")
        if text.startswith("/*", pos):
            depth += 1
            pos += 2
        elif text.startswith("*/", pos):
            depth -= 1
            pos += 2
        else:
            pos += 1
    return pos


def _skip(text: str, pos: int) -> int:
    while pos < len(text):
        if text[pos] in " \t\r\n":
            pos += 1
        elif text.startswith(("//", "/*"), pos):
            pos = _comment_end(text, pos)
        else:
            break
    return pos


def _quoted_end(text: str, start: int) -> int:
    quote, pos = text[start], start + 1
    while pos < len(text):
        if text[pos] == "\\":
            pos += 2
        elif quote == '"' and text[pos] == "[":
            pos = _balanced_end(text, pos)
        elif text[pos] == quote:
            return pos + 1
        else:
            pos += 1
    raise ValueError("Unterminated quoted literal")


def _balanced_end(text: str, start: int) -> int:
    stack, pos = [_OPEN[text[start]]], start + 1
    while stack:
        if pos >= len(text):
            raise ValueError("Unterminated atom or dictionary definition")
        char = text[pos]
        if text.startswith(("//", "/*"), pos):
            pos = _comment_end(text, pos)
        elif char in "\"'":
            pos = _quoted_end(text, pos)
        elif char in _OPEN:
            stack.append(_OPEN[char])
            pos += 1
        elif char in ")]}":
            if char != stack.pop():
                raise ValueError("Mismatched DM delimiters")
            pos += 1
        else:
            pos += 1
    return pos


def _split_atoms(text: str) -> tuple[str, ...]:
    atoms, start, pos = [], 0, 0
    while pos < len(text):
        char = text[pos]
        if text.startswith(("//", "/*"), pos):
            pos = _comment_end(text, pos)
        elif char in "\"'":
            pos = _quoted_end(text, pos)
        elif char in _OPEN:
            pos = _balanced_end(text, pos)
        elif char == ",":
            atoms.append(text[start:pos].strip())
            pos += 1
            start = pos
        elif char in ")]}":
            raise ValueError("Unexpected DM delimiter")
        else:
            pos += 1
    atoms.append(text[start:].strip())
    for atom in atoms:
        atom_path(atom)
    return tuple(atoms)


def atom_path(atom: str) -> str:
    """Return a single raw atom's typepath, rejecting trailing/injected atoms."""
    if not isinstance(atom, str) or not atom or "\x00" in atom:
        raise ValueError("Atom must be a nonempty raw DM string")
    start = _skip(atom, 0)
    match = _PATH.match(atom, start)
    if not match:
        raise ValueError("Atom must start with an absolute DM typepath")
    pos = _skip(atom, match.end())
    if pos < len(atom) and atom[pos] == "{":
        pos = _skip(atom, _balanced_end(atom, pos))
    if pos != len(atom):
        raise ValueError("Unsupported text after atom typepath or variable block")
    return match.group()


def _category(atom: str) -> str:
    return atom_path(atom).split("/", 2)[1]


def _ends_in_line_comment(atom: str) -> bool:
    pos = 0
    while pos < len(atom):
        if atom.startswith("//", pos):
            end = atom.find("\n", pos + 2)
            if end == -1:
                return True
            pos = end + 1
        elif atom.startswith("/*", pos):
            pos = _comment_end(atom, pos)
        elif atom[pos] in "\"'":
            pos = _quoted_end(atom, pos)
        elif atom[pos] in _OPEN:
            pos = _balanced_end(atom, pos)
        else:
            pos += 1
    return False


def validate_stack(atoms: tuple[str, ...]) -> None:
    """Require objects/mobs followed by exactly one turf and one area."""
    if not isinstance(atoms, tuple) or len(atoms) < 2:
        raise ValueError("A tile must be a tuple containing one turf and one area")
    categories = [_category(atom) for atom in atoms]
    if categories[-2:] != ["turf", "area"] or categories.count("turf") != 1 or categories.count("area") != 1:
        raise ValueError("Tile must contain exactly one turf then one area, after all objects")
    if any(category not in {"obj", "mob"} for category in categories[:-2]):
        raise ValueError("Only /obj and /mob atoms may precede the turf and area")


def _coordinate(value: object, size: Coord, name: str = "coordinate") -> Coord:
    if not isinstance(value, (list, tuple)) or len(value) != 3 or any(type(component) is not int for component in value):
        raise ValueError(f"{name} must contain three integer coordinates")
    at = tuple(value)
    if any(component < 1 or component > maximum for component, maximum in zip(at, size)):
        raise ValueError(f"{name} is outside the map bounds {size}")
    return at


def normalize_region(region: dict | None, size: Coord) -> tuple[Coord, Coord]:
    if region is None:
        return (1, 1, 1), size
    if not isinstance(region, dict) or set(region) != {"min", "max"}:
        raise ValueError("Region must contain only min and max")
    low = _coordinate(region["min"], size, "region.min")
    high = _coordinate(region["max"], size, "region.max")
    if any(a > b for a, b in zip(low, high)):
        raise ValueError("Region min must not exceed max")
    return low, high


class MapDocument:
    """A rectangular TGM map with byte offsets for every source grid token."""

    @classmethod
    def from_bytes(cls, raw: bytes) -> MapDocument:
        if not isinstance(raw, bytes):
            raise ValueError("Map input must be bytes")
        try:
            raw.decode("utf-8")
        except UnicodeDecodeError as error:
            raise ValueError("Map must be UTF-8") from error
        if b"\x00" in raw:
            raise ValueError("Map contains NUL bytes")
        # Latin-1 gives each byte one character, so offsets never drift on UTF-8.
        text = raw.decode("latin-1")
        pos = 3 if raw.startswith(b"\xef\xbb\xbf") else 0
        if not text.startswith(TGM_HEADER, pos):
            raise ValueError("Only TGM maps with the conversion header are supported")
        document = cls()
        document.raw = raw
        document.sha256 = hashlib.sha256(raw).hexdigest()
        document.grid = {}
        document.tiles = {}
        document._grid_spans = {}
        document._newline = "\r\n" if b"\r\n" in raw else "\n"
        document._insert_offset = None
        key_length = None
        columns = {}
        while True:
            pos = _skip(text, pos)
            if pos == len(text):
                break
            if text[pos] == '"' and document._insert_offset is None:
                end = _quoted_end(text, pos)
                key = text[pos + 1:end - 1]
                if not key or any(char not in base52 for char in key) or len(key) > MAX_KEY_LENGTH:
                    raise ValueError("Unsupported dictionary key")
                if key_length is None:
                    key_length = len(key)
                if len(key) != key_length or key in document.tiles:
                    raise ValueError("Dictionary keys must be unique and have uniform length")
                key_number = 0
                for char in key:
                    key_number = key_number * len(base52) + base52.index(char)
                if key_number >= max_key_for(key_length):
                    raise ValueError("Dictionary key exceeds BYOND key space")
                pos = _skip(text, end)
                if pos == len(text) or text[pos] != "=":
                    raise ValueError("Expected dictionary assignment")
                pos = _skip(text, pos + 1)
                if pos == len(text) or text[pos] != "(":
                    raise ValueError("Expected dictionary atom list")
                end = _balanced_end(text, pos)
                atoms_text = raw[pos + 1:end - 1].decode("utf-8")
                document.tiles[key] = _split_atoms(atoms_text)
                document._definition_end = end
                pos = end
            elif text[pos] == "(":
                if key_length is None:
                    raise ValueError("Map has no dictionary definitions")
                if document._insert_offset is None:
                    document._insert_offset = document._definition_end
                match = _COORD_HEADER.match(text, pos)
                if not match:
                    raise ValueError("Unsupported TGM grid header")
                x, y, z = map(int, match.groups())
                if min(x, y, z) < 1 or y != 1 or (x, z) in columns:
                    raise ValueError("TGM columns must be unique and start at Y=1")
                end = text.find('"}', match.end())
                if end == -1:
                    raise ValueError("Unterminated TGM grid column")
                body = text[match.end():end]
                if not body.startswith(("\n", "\r\n")):
                    raise ValueError("TGM grid columns require a newline before keys")
                lines = body.splitlines(keepends=True)
                if not lines or lines[0].strip() or not lines[-1].endswith("\n"):
                    raise ValueError("TGM grid columns require newline-delimited keys")
                keys, offset = [], match.end() + len(lines[0])
                for line in lines[1:]:
                    key = line.removesuffix("\n").removesuffix("\r")
                    if len(key) != key_length or key not in document.tiles:
                        raise ValueError("Grid references an undefined or invalid-length dictionary key")
                    keys.append((key, offset))
                    offset += len(line)
                if not keys:
                    raise ValueError("Empty TGM grid column")
                height = len(keys)
                columns[x, z] = height
                for index, (key, offset) in enumerate(keys):
                    at = (x, height - index, z)
                    document.grid[at] = key
                    document._grid_spans[at] = (offset, offset + key_length)
                pos = end + 2
            else:
                raise ValueError(f"Unsupported TGM syntax at byte {pos}")
        if not columns:
            raise ValueError("Map has no grid columns")
        width = max(x for x, z in columns)
        depth = max(z for x, z in columns)
        heights = set(columns.values())
        if len(heights) != 1 or len(columns) != width * depth:
            raise ValueError("TGM grid must be rectangular and contiguous from (1,1,1)")
        document.size = (width, heights.pop(), depth)
        document._key_length = key_length
        return document

    def tile(self, at: Coord) -> tuple[str, ...]:
        return self.tiles[self.grid[_coordinate(at, self.size)]]

    def coordinates(self, region: dict | None = None) -> Iterator[Coord]:
        low, high = normalize_region(region, self.size)
        for z in range(low[2], high[2] + 1):
            for y in range(low[1], high[1] + 1):
                for x in range(low[0], high[0] + 1):
                    yield (x, y, z)

    def rewrite(self, changes: dict[Coord, tuple[str, ...]]) -> bytes:
        if not isinstance(changes, dict):
            raise ValueError("Changes must be a coordinate-to-stack dictionary")
        effective = {}
        for at, atoms in changes.items():
            at = _coordinate(at, self.size)
            validate_stack(atoms)
            if atoms != self.tile(at):
                effective[at] = atoms
        if not effective:
            return self.raw
        stack_keys = {}
        for key, atoms in self.tiles.items():
            stack_keys.setdefault(atoms, key)
        used_keys = set(self.tiles)
        additions, replacements, next_key = [], [], 0
        newline = self._newline
        for at in sorted(effective, key=lambda at: (at[2], at[1], at[0])):
            atoms = effective[at]
            key = stack_keys.get(atoms)
            if key is None:
                while next_key < max_key_for(self._key_length):
                    key = num_to_key(next_key, self._key_length)
                    next_key += 1
                    if key not in used_keys:
                        break
                else:
                    raise ValueError("Dictionary key space exhausted; key length expansion is unsupported")
                used_keys.add(key)
                stack_keys[atoms] = key
                definition = [f'"{key}" = ({newline}']
                for index, atom in enumerate(atoms):
                    # Maplint requires canonical same-line delimiters. Only a
                    # terminal raw // comment needs a protective line break.
                    suffix = ")" if index == len(atoms) - 1 else ","
                    definition.append(atom + (newline if _ends_in_line_comment(atom) else "") + suffix + newline)
                additions.append("".join(definition).encode("utf-8"))
            start, end = self._grid_spans[at]
            replacements.append((start, end, key.encode("ascii")))
        if additions:
            # Insert before the original dictionary/grid separator: maplint
            # stops reading definitions at its first blank line.
            definitions = newline.encode("ascii") + b"".join(additions).removesuffix(newline.encode("ascii"))
            replacements.append((self._insert_offset, self._insert_offset, definitions))
        parts, start = [], 0
        for low, high, content in sorted(replacements):
            parts.extend((self.raw[start:low], content))
            start = high
        parts.append(self.raw[start:])
        result = b"".join(parts)
        after = MapDocument.from_bytes(result)
        if after.size != self.size or any(after.tile(at) != effective.get(at, self.tile(at)) for at in self.grid):
            raise ValueError("Rewritten map does not match the declared changes")
        return result
