#!/usr/bin/env python3
"""Render GCP manifests; only --apply executes the displayed cluster commands."""
import argparse
import json
from pathlib import Path
import runpy
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RENDERER = runpy.run_path(str(ROOT / 'scripts/render-platform.py'))


def install_commands(platform, context, directory, python_command):
    RENDERER['validate_platform'](platform)
    cluster = platform['cluster']
    expected = 'gke_{}_{}_{}'.format(platform['project_id'], cluster['location'], cluster['name'])
    if context != expected:
        raise ValueError('Use the standard GKE context for this platform: ' + expected)
    helm = ['helm', '--kube-context', context, 'upgrade', '--install']
    chart = ['external-secrets', '--repo', 'https://charts.external-secrets.io', '--version', '2.12.0',
             '-n', 'external-secrets', '--atomic', '--wait', '--timeout', '5m', '--history-max', '3']
    return [
        ['kubectl', '--context', context, 'apply', '-f', str(directory / 'namespaces.yaml')],
        helm + ['external-secrets'] + chart + ['-f', str(directory / 'eso-platform-values.yaml'),
            '--post-renderer', python_command, '--post-renderer-args', str(ROOT / 'infra/eks-eso/scripts/post_renderer.py')],
        helm + ['external-secrets-argocd'] + chart + ['-f', str(directory / 'eso-argocd-values.yaml')],
        ['kubectl', '--context', context, 'apply', '-f', str(directory / 'platform.yaml')],
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', required=True, type=Path)
    parser.add_argument('--context', required=True)
    parser.add_argument('--output-dir', required=True, type=Path)
    parser.add_argument('--apply', action='store_true', help='Execute cluster mutations; omitted by default.')
    args = parser.parse_args()
    try:
        platform = json.loads(args.platform.read_text())
        commands = install_commands(platform, args.context, args.output_dir.resolve(), sys.executable)
        RENDERER['render'](platform, args.output_dir)
        for command in commands:
            print(shlex.join(command), flush=True)
            if args.apply:
                subprocess.run(command, check=True)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
