import importlib.util
import json
from pathlib import Path
import subprocess
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('gcp_preflight', ROOT / 'scripts/gcp-preflight.py')
preflight = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preflight)


class PreflightTests(unittest.TestCase):
    def test_permission_failure_is_not_an_empty_inventory_and_does_not_leak_diagnostics(self):
        def failed(*args, **kwargs):
            return subprocess.CompletedProcess(args[0], 1, '', 'credential-diagnostic-must-not-be-persisted')
        result = preflight.query('softbank-ghost', ['compute', 'instances', 'list'], runner=failed)
        self.assertEqual(result['status'], 'UNVERIFIED')
        self.assertNotIn('data', result)
        self.assertNotIn('credential-diagnostic', json.dumps(result))

    def test_disabled_apis_are_not_queried_or_automatically_enabled(self):
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            data = [] if command[1:3] == ['services', 'list'] else {}
            return subprocess.CompletedProcess(command, 0, json.dumps(data), '')
        result = preflight.collect('softbank-ghost', 'asia-northeast3', runner=run)
        self.assertEqual(len(calls), 3)
        self.assertTrue(all(r['reason'] == 'API_DISABLED' for r in result['inventory'].values()))
        self.assertTrue(all('--project=softbank-ghost' in c for c in calls))

    def test_enabled_service_lists_metadata_only_without_reading_secret_versions(self):
        calls = []
        lock = threading.Lock()
        def run(command, **kwargs):
            with lock:
                calls.append(command)
            if command[1:3] == ['services', 'list']:
                data = [{'config': {'name': 'secretmanager.googleapis.com'}}]
            else:
                data = []
            return subprocess.CompletedProcess(command, 0, json.dumps(data), '')
        result = preflight.collect('softbank-ghost', 'asia-northeast3', runner=run)
        self.assertEqual(result['inventory']['secrets_metadata']['status'], 'OBSERVED')
        self.assertEqual(len(calls), 4)
        self.assertIn(['secrets', 'list'], [c[1:3] for c in calls])
        self.assertTrue(all('versions' not in c and 'enable' not in c and 'create' not in c for c in calls))

    def test_missing_service_access_keeps_every_inventory_unverified(self):
        def run(command, **kwargs):
            if command[1:3] == ['services', 'list']:
                return subprocess.CompletedProcess(command, 1, '', '')
            return subprocess.CompletedProcess(command, 0, '{}', '')
        result = preflight.collect('softbank-ghost', 'asia-northeast3', runner=run)
        self.assertTrue(all(r['reason'] == 'SERVICE_LIST_UNAVAILABLE' for r in result['inventory'].values()))

    def test_timeout_is_unverified(self):
        def run(command, **kwargs):
            raise subprocess.TimeoutExpired(command, 60)
        result = preflight.query('softbank-ghost', ['projects', 'describe', 'softbank-ghost'], runner=run)
        self.assertEqual(result, {'status': 'UNVERIFIED', 'error_type': 'TimeoutExpired'})


if __name__ == '__main__':
    unittest.main()
