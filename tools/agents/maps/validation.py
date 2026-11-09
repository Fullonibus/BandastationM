"""Read-only structural checks and the checkout's existing YAML maplint rules."""
import hashlib
import io
import json
from pathlib import Path

from .document import MapDocument, validate_stack


def _issue(kind, rule, message, coordinates=None, help_text=None, occurrence=0):
    identity = {'kind': kind, 'rule': rule, 'message': str(message), 'coordinates': coordinates, 'occurrence': occurrence}
    signature = hashlib.sha256(json.dumps(identity, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    result = {**identity, 'signature': signature}
    if help_text:
        result['help'] = help_text
    return result


def validation_capabilities(root: Path) -> dict:
    """Probe imports and parse the actual configured YAML rules without a map."""
    directory = Path(root) / 'tools/maplint/lints'
    result = {'available': False, 'rules_directory': str(directory),
              'rule_count': 0, 'lint_count': 0, 'diagnostics': []}
    try:
        import yaml
        from tools.maplint.source.lint import Lint
    except ImportError as exc:
        result['diagnostics'].append(f'Maplint dependency unavailable: {exc}')
        return result
    lint_files = sorted(directory.glob('*.yml'))
    if not lint_files:
        result['diagnostics'].append('No YAML maplint rules were found.')
    for lint_file in lint_files:
        try:
            lint = Lint(yaml.safe_load(lint_file.read_text(encoding='utf-8')))
        except Exception as exc:
            result['diagnostics'].append(f'{lint_file.name}: {exc}')
        else:
            result['lint_count'] += 1
            result['rule_count'] += len(lint.rules)
    result['available'] = bool(lint_files) and not result['diagnostics']
    return result


def validate_document(document: MapDocument, logical_path: str, root: Path) -> dict:
    """Never reconstruct raw DM expressions or use snapshot paths for skip_files."""
    import yaml
    from tools.maplint.source.dmm import parse_dmm
    from tools.maplint.source.error import MaplintError
    from tools.maplint.source.lint import Lint

    errors = []
    coordinates_by_key = {}
    for at, key in document.grid.items():
        coordinates_by_key.setdefault(key, []).append(at)
    for key, atoms in document.tiles.items():
        try:
            validate_stack(atoms)
        except ValueError as exc:
            for at in coordinates_by_key.get(key, ()):
                errors.append(_issue('structure', 'tile-stack', exc, list(at)))

    reader = io.StringIO(document.raw.decode('utf-8-sig').replace('\r\n', '\n'))
    reader.name = str(logical_path).replace('\\', '/')
    try:
        parsed = parse_dmm(reader)
    except (MaplintError, ValueError, TypeError, AttributeError) as exc:
        errors.append(_issue('maplint', 'parse', exc))
    else:
        lint_files = sorted((Path(root) / 'tools/maplint/lints').glob('*.yml'))
        if not lint_files:
            errors.append(_issue('maplint', 'configuration', 'No YAML maplint rules were found.'))
        for lint_file in lint_files:
            try:
                lint = Lint(yaml.safe_load(lint_file.read_text(encoding='utf-8')))
                failures = lint.run(parsed)
            except Exception as exc:
                errors.append(_issue('maplint', lint_file.stem, f'Lint could not run: {exc}'))
                continue
            occurrences = {}
            for failure in failures:
                # Native maplint truncates coordinate text and groups by pop key.
                # Expand using the lossless document so key splits cannot become new errors.
                identity = (failure.pop_id, str(failure))
                occurrence = occurrences.get(identity, 0)
                occurrences[identity] = occurrence + 1
                for at in coordinates_by_key.get(failure.pop_id, ()):
                    errors.append(_issue('maplint', lint_file.stem, failure, list(at), failure.help, occurrence))

    unique = {error['signature']: error for error in errors}
    return {'ok': not unique, 'errors': [unique[key] for key in sorted(unique)], 'runtime_checked': False}
