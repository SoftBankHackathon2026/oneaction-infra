import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('render_platform', ROOT / 'scripts/render-platform.py')
renderer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(renderer)

PLATFORM = {
    'cloud': 'gcp', 'project_id': 'oneaction-test-123', 'region': 'asia-northeast3',
    'name': 'oneaction-dev',
    'cluster': {'name': 'oneaction-dev', 'location': 'asia-northeast3'},
    'database': {'connection_name': 'oneaction-test-123:asia-northeast3:oneaction-dev-review', 'name': 'oneaction_review'},
    'load_balancer': {'address_name': 'oneaction-dev-platform', 'domain_name': '', 'certificate_name': None},
    'secrets': {'database': 'oneaction-dev-review-db', 'gitops': 'oneaction-dev-gitops-token', 'review_service': 'oneaction-dev-review-service'},
    'identities': {'eso': 'eso@oneaction-test-123.iam.gserviceaccount.com', 'notifications': 'notifications@oneaction-test-123.iam.gserviceaccount.com', 'workload': 'review@oneaction-test-123.iam.gserviceaccount.com'},
}

class RenderTests(unittest.TestCase):
    def test_reuses_aws_values_without_aws_credentials(self):
        values = renderer.helm_values(PLATFORM, 'platform', ROOT)
        self.assertEqual(values['image']['tag'], 'v2.12.0')
        self.assertEqual(values['scopedNamespace'], 'platform')
        self.assertEqual(values['serviceAccount']['annotations']['iam.gke.io/gcp-service-account'], PLATFORM['identities']['eso'])
        self.assertFalse(any(e['name'].startswith('AWS_') for e in values.get('extraEnv', [])))
        self.assertEqual(values['resources']['limits']['memory'], '256Mi')

    def test_notifications_keep_their_own_identity_and_scope(self):
        values = renderer.helm_values(PLATFORM, 'argocd', ROOT)
        self.assertFalse(values['installCRDs'])
        self.assertEqual(values['scopedNamespace'], 'argocd')
        self.assertEqual(values['serviceAccount']['annotations']['iam.gke.io/gcp-service-account'], PLATFORM['identities']['notifications'])

    def test_store_uses_pod_identity_and_keeps_database_secret_contract(self):
        docs = renderer.manifests(PLATFORM)
        store = next(d for d in docs if d['kind'] == 'SecretStore' and d['metadata']['namespace'] == 'platform')
        self.assertEqual(store['spec']['provider'], {'gcpsm': {'projectID': PLATFORM['project_id']}})
        external = next(d for d in docs if d['kind'] == 'ExternalSecret' and d['metadata']['name'] == 'review-db')
        self.assertEqual(external['spec']['target']['name'], 'review-db-credentials')
        self.assertEqual([d['secretKey'] for d in external['spec']['data']], ['username', 'password'])
        self.assertEqual(external['spec']['data'][0]['remoteRef']['key'], PLATFORM['secrets']['database'])

    def test_native_ingress_has_neg_and_matches_healthcheck_port(self):
        docs = renderer.manifests(PLATFORM)
        service = next(d for d in docs if d['kind'] == 'Service')
        self.assertIn('cloud.google.com/neg', service['metadata']['annotations'])
        ingress = next(d for d in docs if d['kind'] == 'Ingress')
        self.assertNotIn('ingress.gcp.kubernetes.io/pre-shared-cert', ingress['metadata']['annotations'])
        config = next(d for d in docs if d['kind'] == 'BackendConfig')
        self.assertEqual(config['spec']['healthCheck']['port'], 8080)

    def test_domain_enables_certificate_and_https_redirect(self):
        p = copy.deepcopy(PLATFORM)
        p['load_balancer'].update(domain_name='review.example.com', certificate_name='oneaction-cert')
        docs = renderer.manifests(p)
        ingress = next(d for d in docs if d['kind'] == 'Ingress')
        self.assertEqual(ingress['metadata']['annotations']['ingress.gcp.kubernetes.io/pre-shared-cert'], 'oneaction-cert')
        self.assertTrue(next(d for d in docs if d['kind'] == 'FrontendConfig')['spec']['redirectToHttps']['enabled'])

    def test_proxy_is_private_and_uses_workload_identity(self):
        patch = renderer.workload_patch(PLATFORM)
        spec = patch['spec']['template']['spec']
        self.assertEqual(spec['serviceAccountName'], 'review-service')
        proxy = next(c for c in spec['containers'] if c['name'] == 'cloud-sql-proxy')
        self.assertIn('--private-ip', proxy['args'])
        self.assertNotIn('--address=0.0.0.0', proxy['args'])
        self.assertIn(PLATFORM['database']['connection_name'], proxy['args'])

    def test_rejects_wrong_cloud_and_placeholder_project(self):
        for cloud in ['aws', 'unknown']:
            with self.assertRaises(ValueError): renderer.validate_platform(dict(PLATFORM, cloud=cloud))
        with self.assertRaises(ValueError): renderer.validate_platform(dict(PLATFORM, project_id='YOUR_PROJECT_ID'))

if __name__ == '__main__': unittest.main()
