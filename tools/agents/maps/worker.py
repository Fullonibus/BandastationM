"""One JSON request per subprocess. stdout is reserved for the MCP bridge."""
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))


def main():
    from tools.agents.maps.service import MapService, fields
    try:
        payload = sys.stdin.buffer.read(1024 * 1024 + 1)
        if len(payload) > 1024 * 1024:
            raise ValueError('Request exceeds the 1 MiB limit')
        request = json.loads(payload)
        fields(request, ('tool', 'arguments'), ('tool', 'arguments'))
        result = MapService(ROOT).call(request['tool'], request['arguments'])
        response = {'ok': True, 'result': result}
    except (ValueError, OSError, KeyError, TypeError, RecursionError) as error:
        response = {'ok': False, 'error': {'code': 'invalid_request', 'message': str(error)}}
    raw = json.dumps(response, ensure_ascii=False, separators=(',', ':'))
    if len(raw.encode('utf-8')) > 8 * 1024 * 1024:
        raw = json.dumps({'ok': False, 'error': {'code': 'output_limit', 'message': 'Response exceeds 8 MiB; use a narrower query'}})
    sys.stdout.write(raw + '\n')


if __name__ == '__main__':
    main()
