#!/usr/bin/env python3
"""Read-only GCP inventory. Never enables APIs or mutates cloud resources."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess


# Each request uses an explicit project and selects only non-secret fields.
INVENTORY = {
    'networks': ('compute.googleapis.com', ['compute', 'networks', 'list'], 'json(name,id,autoCreateSubnetworks,routingConfig)'),
    'subnets': ('compute.googleapis.com', ['compute', 'networks', 'subnets', 'list'], 'json(name,region,ipCidrRange,secondaryIpRanges,privateIpGoogleAccess)'),
    'firewalls': ('compute.googleapis.com', ['compute', 'firewall-rules', 'list'], 'json(name,network,direction,priority,disabled,allowed,denied,sourceRanges,targetTags,logConfig)'),
    'routers': ('compute.googleapis.com', ['compute', 'routers', 'list'], 'json(name,region,network,nats)'),
    'instances': ('compute.googleapis.com', ['compute', 'instances', 'list'], 'json(name,id,zone,status,machineType,disks.boot,disks.diskSizeGb,networkInterfaces.networkIP)'),
    'addresses': ('compute.googleapis.com', ['compute', 'addresses', 'list'], 'json(name,address,addressType,status,region,purpose)'),
    'disks': ('compute.googleapis.com', ['compute', 'disks', 'list'], 'json(name,zone,sizeGb,type,status,users)'),
    'clusters': ('container.googleapis.com', ['container', 'clusters', 'list'], 'json(name,location,status,currentMasterVersion,nodePools.name,nodePools.config.machineType,nodePools.initialNodeCount,locations)'),
    'sql': ('sqladmin.googleapis.com', ['sql', 'instances', 'list'], 'json(name,region,state,databaseVersion,settings.tier,settings.dataDiskSizeGb,settings.databaseFlags)'),
    'buckets': ('storage.googleapis.com', ['storage', 'buckets', 'list'], 'json(name,location,storageClass,versioning,iamConfiguration,lifecycle)'),
    'dns': ('dns.googleapis.com', ['dns', 'managed-zones', 'list'], 'json(name,dnsName,visibility,nameServers,cloudLoggingConfig)'),
    'secrets_metadata': ('secretmanager.googleapis.com', ['secrets', 'list'], 'json(name,createTime,replication)'),
    'service_accounts': ('iam.googleapis.com', ['iam', 'service-accounts', 'list'], 'json(name,email,disabled)'),
    'log_sinks': ('logging.googleapis.com', ['logging', 'sinks', 'list'], 'json(name,destination,filter,disabled)'),
    'alert_policies': ('monitoring.googleapis.com', ['monitoring', 'policies', 'list'], 'json(name,displayName,enabled)'),
}


def query(project, args, output_format='json', runner=subprocess.run):
    command = ['gcloud', *args, '--project=' + project, '--format=' + output_format, '--quiet']
    try:
        result = runner(command, capture_output=True, text=True, timeout=60,
                        env={**os.environ, 'CLOUDSDK_CORE_DISABLE_PROMPTS': '1'})
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {'status': 'UNVERIFIED', 'error_type': type(exc).__name__}
    if result.returncode:
        # Do not serialize stderr, which can contain local account/credential
        # diagnostics. A failed query never means an empty resource list.
        return {'status': 'UNVERIFIED', 'exit_code': result.returncode}
    try:
        return {'status': 'OBSERVED', 'data': json.loads(result.stdout)}
    except (ValueError, TypeError):
        return {'status': 'UNVERIFIED', 'error_type': 'InvalidJSON'}


def collect(project, region, runner=subprocess.run):
    report = {'project_id': project, 'region': region,
              'observed_at_utc': datetime.now(timezone.utc).isoformat(),
              'read_only': True}
    report['project'] = query(project, ['projects', 'describe', project],
                              'json(projectId,projectNumber,lifecycleState)', runner)
    report['billing'] = query(project, ['billing', 'projects', 'describe', project],
                              'json(projectId,billingEnabled)', runner)
    enabled = query(project, ['services', 'list', '--enabled'], 'json(config.name)', runner)
    report['enabled_services'] = enabled
    if enabled['status'] != 'OBSERVED':
        report['inventory'] = {name: {'status': 'UNVERIFIED', 'reason': 'SERVICE_LIST_UNAVAILABLE'} for name in INVENTORY}
        report['inventory']['kafka'] = {'status': 'UNVERIFIED', 'reason': 'SERVICE_LIST_UNAVAILABLE'}
        return report
    services = {s['config']['name'] for s in enabled['data']}
    entries = dict(INVENTORY)
    entries['kafka'] = ('managedkafka.googleapis.com', ['managed-kafka', 'clusters', 'list', '--location=' + region], 'json(name,state,capacityConfig,gcpConfig)')

    def one(item):
        name, (service, args, fmt) = item
        if service not in services:
            return name, {'status': 'UNVERIFIED', 'reason': 'API_DISABLED', 'service': service}
        return name, query(project, args, fmt, runner)

    with ThreadPoolExecutor(max_workers=4) as pool:
        report['inventory'] = dict(pool.map(one, entries.items()))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True)
    parser.add_argument('--region', default='asia-northeast3')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', args.project):
        parser.error('Use a valid, explicit GCP project ID.')
    report = collect(args.project, args.region)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    observed = sum(r['status'] == 'OBSERVED' for r in report['inventory'].values())
    print(json.dumps({'project': args.project, 'observed_inventory_queries': observed,
                      'output': str(args.output), 'billing': report['billing']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
