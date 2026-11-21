"""Invalid worker input must produce a JSON error instead of a process crash."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest


WORKER = Path(__file__).resolve().parents[1] / 'maps/worker.py'


class MapWorkerTests(unittest.TestCase):
    def test_excessively_nested_json_returns_error_envelope(self):
        payload = (b'{"tool":"dmm_capabilities","arguments":{"unexpected":'
                   + b'[' * 1500 + b'0' + b']' * 1500 + b'}}')
        process = subprocess.run(
            [sys.executable, '-B', '-X', 'utf8', str(WORKER)],
            input=payload, capture_output=True, timeout=15)
        self.assertEqual(process.returncode, 0, process.stderr.decode('utf-8'))
        self.assertEqual(process.stderr, b'')
        self.assertEqual(len(process.stdout.splitlines()), 1)
        self.assertLess(len(process.stdout), 1024)
        response = json.loads(process.stdout)
        self.assertIs(response['ok'], False)
        self.assertEqual(response['error']['code'], 'invalid_request')
        self.assertIsInstance(response['error']['message'], str)
        self.assertTrue(response['error']['message'])


if __name__ == '__main__':
    unittest.main()
