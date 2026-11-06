import importlib.util
from pathlib import Path
import tempfile
import unittest

from test_render_platform import PLATFORM, ROOT

SPEC = importlib.util.spec_from_file_location('install_platform', ROOT / 'scripts/install-gcp-platform.py')
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)

class InstallTests(unittest.TestCase):
    def test_refuses_an_unrelated_cluster_context(self):
        with self.assertRaises(ValueError):
            installer.install_commands(PLATFORM, 'production-aws', Path('/tmp/rendered'), 'python3')

    def test_every_cluster_mutation_has_the_explicit_gke_context(self):
        context = 'gke_oneaction-test-123_asia-northeast3_oneaction-dev'
        commands = installer.install_commands(PLATFORM, context, Path('/tmp/rendered'), 'python3')
        self.assertEqual(len(commands), 4)
        for command in commands:
            self.assertIn(context, command)
        self.assertIn('namespaces.yaml', ' '.join(commands[0]))
        self.assertIn('platform.yaml', ' '.join(commands[-1]))

    def test_reuses_the_existing_rbac_post_renderer_only_for_the_primary_operator(self):
        context = 'gke_oneaction-test-123_asia-northeast3_oneaction-dev'
        commands = installer.install_commands(PLATFORM, context, Path('/tmp/rendered'), 'python3')
        self.assertIn('--post-renderer', commands[1])
        self.assertIn(str(ROOT / 'infra/eks-eso/scripts/post_renderer.py'), commands[1])
        self.assertNotIn('--post-renderer', commands[2])
        self.assertIn('2.12.0', commands[1])

if __name__ == '__main__': unittest.main()
