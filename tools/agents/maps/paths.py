"""Checkout and artifact paths for the map tools; redirects are never followed."""
from __future__ import annotations

import os
from pathlib import Path
import re
import stat
import uuid


def ordinary(path: Path) -> None:
    for entry in (path, *path.parents):
        if entry.exists() or entry.is_symlink():
            attributes = entry.lstat()
            if stat.S_ISLNK(attributes.st_mode) or getattr(attributes, 'st_file_attributes', 0) & 0x400:
                raise ValueError('Redirected paths are not supported: ' + str(entry))


class MapPaths:
    def __init__(self, root: Path):
        ordinary(root)
        self.root = root.resolve(strict=True)
        self.artifacts = self.root / 'task_state/map-tools'

    def map(self, value: str) -> Path:
        if not isinstance(value, str) or not value or '\0' in value or len(value) > 4096:
            raise ValueError('An explicit .dmm path is required')
        candidate = Path(value)
        if not candidate.is_absolute():
            candidate = self.root / candidate
        ordinary(candidate)
        candidate = candidate.resolve()
        try:
            relative = candidate.relative_to(self.root)
        except ValueError:
            raise ValueError('Map path escapes this checkout') from None
        parts = [part.casefold() for part in relative.parts]
        if not parts or any(part in ('.git', 'node_modules') for part in parts) or parts[0] in (
                '.codex', '.agents', 'task_state', 'data', 'cfg'):
            raise ValueError('Path is outside editable map scope')
        if candidate.suffix.lower() != '.dmm' or not candidate.is_file():
            raise ValueError('Map path must identify an existing .dmm file')
        if candidate.stat().st_size > 64 * 1024 * 1024:
            raise ValueError('Map exceeds the 64 MiB document limit')
        return candidate

    def artifact(self, value: Path, *, exists: bool = True) -> Path:
        ordinary(value)
        candidate = value.resolve()
        if not candidate.is_relative_to(self.artifacts.resolve()):
            raise ValueError('Artifact path escapes the owned map directory')
        if exists and not candidate.exists():
            raise ValueError('Map artifact does not exist')
        return candidate

    def create(self, prefix: str) -> Path:
        ordinary(self.artifacts)
        self.artifacts.mkdir(parents=True, exist_ok=True)
        destination = self.artifacts / (prefix + uuid.uuid4().hex)
        destination.mkdir()
        return destination

    def plan(self, plan_id: str) -> Path:
        if not isinstance(plan_id, str) or not re.fullmatch(r'[0-9a-f]{32}', plan_id):
            raise ValueError('Invalid plan_id')
        return self.artifact(self.artifacts / plan_id)

    def relative(self, path: Path) -> str:
        return path.relative_to(self.root).as_posix()


def atomic_replace(path: Path, raw: bytes, expected_sha256: str) -> None:
    """Recheck immediately before replace; unrelated external editors are not locked."""
    import hashlib
    import tempfile

    ordinary(path)
    handle, name = tempfile.mkstemp(prefix='.' + path.name + '.', suffix='.tmp', dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(handle, 'wb') as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected_sha256:
            raise ValueError('Source changed after preview; prepare a new plan')
        ordinary(path)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)
