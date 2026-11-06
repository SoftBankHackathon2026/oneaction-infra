#!/usr/bin/env python3
"""Render GCP bootstrap manifests using the existing AWS ESO Helm values."""
import argparse
import copy
import json
from pathlib import Path
import re

import yaml

ROOT = Path(__file__).resolve().parents[1]


def validate_platform(platform):
    if platform.get('cloud') != 'gcp':
        raise ValueError('This renderer expects the GCP platform output; AWS uses its existing installer.')
    project = platform.get('project_id', '')
    if not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', project):
        raise ValueError('A real GCP project ID is required.')
    for field in ('cluster', 'database', 'load_balancer', 'secrets', 'identities'):
        if not isinstance(platform.get(field), dict):
            raise ValueError('Missing platform field: ' + field)


def helm_values(platform, namespace, root=ROOT):
    validate_platform(platform)
    if namespace not in ('platform', 'argocd'):
        raise ValueError('Only platform and argocd scopes are supported.')
    notifications = namespace == 'argocd'
    filename = 'helm-values-argocd.yaml' if notifications else 'helm-values.yaml'
    values = copy.deepcopy(yaml.safe_load((root / 'infra/eks-eso' / filename).read_text()))
    values['extraEnv'] = [entry for entry in values.get('extraEnv', []) if not entry['name'].startswith('AWS_')]
    identity = 'notifications' if notifications else 'eso'
    values['serviceAccount']['annotations']['iam.gke.io/gcp-service-account'] = platform['identities'][identity]
    return values


def resource(api, kind, name, namespace=None, spec=None, annotations=None):
    item = {'apiVersion': api, 'kind': kind, 'metadata': {'name': name}}
    if namespace:
        item['metadata']['namespace'] = namespace
    if annotations:
        item['metadata']['annotations'] = annotations
    if spec is not None:
        item['spec'] = spec
    return item


def external_secret(platform, name, namespace, remote, properties, target=None):
    return resource('external-secrets.io/v1', 'ExternalSecret', name, namespace, {
        'refreshPolicy': 'Periodic', 'refreshInterval': '1h',
        'secretStoreRef': {'name': 'oneaction', 'kind': 'SecretStore'},
        'target': {'name': target or name, 'creationPolicy': 'Owner', 'deletionPolicy': 'Retain'},
        'data': [{'secretKey': local, 'remoteRef': {'key': platform['secrets'][remote], 'property': prop}}
                 for local, prop in properties.items()],
    })


def manifests(platform):
    validate_platform(platform)
    docs = [resource('v1', 'Namespace', ns) for ns in ('platform', 'argocd', 'external-secrets')]
    # ADC comes from the operator Pod's annotated service account; no static key.
    for ns in ('platform', 'argocd'):
        docs.append(resource('external-secrets.io/v1', 'SecretStore', 'oneaction', ns, {
            'provider': {'gcpsm': {'projectID': platform['project_id']}},
        }))
    docs.extend([
        external_secret(platform, 'review-db', 'platform', 'database',
                        {'username': 'username', 'password': 'password'}, 'review-db-credentials'),
        external_secret(platform, 'review-service-secrets', 'platform', 'review_service',
                        {'ANTHROPIC_API_KEY': 'ANTHROPIC_API_KEY', 'REVIEW_API_TOKEN': 'REVIEW_API_TOKEN', 'GITHUB_WEBHOOK_SECRET': 'GITHUB_WEBHOOK_SECRET', 'ARGOCD_WEBHOOK_TOKEN': 'ARGOCD_WEBHOOK_TOKEN'}),
        external_secret(platform, 'argocd-notifications', 'argocd', 'review_service',
                        {'ARGOCD_WEBHOOK_TOKEN': 'ARGOCD_WEBHOOK_TOKEN'}, 'argocd-notifications-secret'),
        resource('v1', 'ServiceAccount', 'review-service', 'platform', annotations={
            'iam.gke.io/gcp-service-account': platform['identities']['workload'],
        }),
        resource('cloud.google.com/v1', 'BackendConfig', 'review-service', 'platform', {
            'healthCheck': {'type': 'HTTP', 'requestPath': '/healthz', 'port': 8080},
            'logging': {'enable': True, 'sampleRate': 1.0},
        }),
        resource('v1', 'Service', 'platform', 'platform', {
            'type': 'ClusterIP', 'selector': {'app': 'review-api'},
            'ports': [{'name': 'http', 'port': 8080, 'targetPort': 'http'}],
        }, annotations={
            'cloud.google.com/neg': '{"ingress": true}',
            'cloud.google.com/backend-config': '{"default": "review-service"}',
        }),
    ])
    review = next(d for d in docs if d['kind'] == 'ExternalSecret' and d['metadata']['name'] == 'review-service-secrets')
    review['spec']['data'].append({'secretKey': 'GITHUB_TOKEN', 'remoteRef': {'key': platform['secrets']['gitops']}})
    notifications = next(d for d in docs if d['kind'] == 'ExternalSecret' and d['metadata']['namespace'] == 'argocd')
    notifications['spec']['target']['creationPolicy'] = 'Merge'
    lb = platform['load_balancer']
    annotations = {'kubernetes.io/ingress.class': 'gce', 'kubernetes.io/ingress.global-static-ip-name': lb['address_name']}
    rule = {'http': {'paths': [{'path': '/', 'pathType': 'Prefix',
                              'backend': {'service': {'name': 'platform', 'port': {'number': 8080}}}}]}}
    if lb['domain_name']:
        if not lb.get('certificate_name'):
            raise ValueError('A domain requires the managed certificate output.')
        rule['host'] = lb['domain_name']
        annotations['ingress.gcp.kubernetes.io/pre-shared-cert'] = lb['certificate_name']
        annotations['networking.gke.io/v1beta1.FrontendConfig'] = 'review-service'
        docs.append(resource('networking.gke.io/v1beta1', 'FrontendConfig', 'review-service', 'platform', {
            'redirectToHttps': {'enabled': True, 'responseCodeName': 'MOVED_PERMANENTLY_DEFAULT'},
        }))
    docs.append(resource('networking.k8s.io/v1', 'Ingress', platform['name'] + '-platform', 'platform', {'rules': [rule]}, annotations))
    return docs


def workload_patch(platform, component="api"):
    validate_platform(platform)
    return resource('apps/v1', 'Deployment', 'review-' + component, 'platform', {
        'template': {'spec': {
            'serviceAccountName': 'review-service',
            'containers': [
                {'name': component, 'env': [
                    {'name': 'DB_HOST', 'value': '127.0.0.1'},
                    {'name': 'DB_PORT', 'value': '5432'},
                    {'name': 'DB_NAME', 'value': platform['database']['name']},
                    {'name': 'DB_SSLMODE', 'value': 'disable'},
                    {'name': 'DB_USERNAME', 'valueFrom': {'secretKeyRef': {'name': 'review-db-credentials', 'key': 'username'}}},
                    {'name': 'DB_PASSWORD', 'valueFrom': {'secretKeyRef': {'name': 'review-db-credentials', 'key': 'password'}}},
                ]},
                {'name': 'cloud-sql-proxy', 'image': 'gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.18.2',
                 'args': ['--private-ip', '--port=5432', '--structured-logs', platform['database']['connection_name']],
                 'securityContext': {'runAsNonRoot': True, 'allowPrivilegeEscalation': False},
                 'resources': {'requests': {'cpu': '50m', 'memory': '64Mi'}, 'limits': {'memory': '256Mi'}}},
            ],
        }},
    })


def render(platform, directory, root=ROOT):
    validate_platform(platform)
    directory.mkdir(parents=True, exist_ok=True)
    for ns in ('platform', 'argocd'):
        (directory / ('eso-' + ns + '-values.yaml')).write_text(yaml.safe_dump(helm_values(platform, ns, root), sort_keys=False))
    docs = manifests(platform)
    (directory / 'namespaces.yaml').write_text(yaml.safe_dump_all([d for d in docs if d['kind'] == 'Namespace'], sort_keys=False))
    (directory / 'platform.yaml').write_text(yaml.safe_dump_all([d for d in docs if d['kind'] != 'Namespace'], sort_keys=False))
    (directory / 'workload-patch.yaml').write_text(yaml.safe_dump(workload_patch(platform), sort_keys=False))
    (directory / 'worker-patch.yaml').write_text(yaml.safe_dump(workload_patch(platform, 'worker'), sort_keys=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', type=Path, required=True, help='terraform output -json platform file (no secrets)')
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    try:
        render(json.loads(args.platform.read_text()), args.output_dir)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
