"""Disposable maintenance checks; never access the real Library or Keychain."""
import contextlib
import importlib.util
import io
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name).resolve()

    def git(self, *args):
        subprocess.run(['git', *args], cwd=self.root, check=True, stdout=subprocess.DEVNULL)

    def test_project_cleanup_preserves_sources_and_private_input(self):
        module = load('clean-project')
        self.git('init', '-q')
        (self.root / '.gitignore').write_text('.build/\n.local-testing/\n*.log\n')
        for relative in ('.build/test-fixture/data', '.local-testing/servers.json', 'Tests/Fixtures/source', 'tracked.log', 'debug.log'):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('synthetic')
        self.git('add', '.gitignore', 'Tests/Fixtures/source')
        self.git('add', '-f', 'tracked.log')
        for path in module.targets(self.root):
            module.remove(path)
        for relative in ('.local-testing/servers.json', 'Tests/Fixtures/source', 'tracked.log'):
            self.assertEqual((self.root / relative).read_text(), 'synthetic')
        self.assertFalse((self.root / '.build').exists())
        self.assertFalse((self.root / 'debug.log').exists())

    def test_cleanup_unlinks_generated_symlink_without_following_it(self):
        module = load('clean-project')
        self.git('init', '-q')
        outside = self.root / 'keep'
        outside.mkdir()
        (outside / 'data').write_text('keep')
        (self.root / '.build').symlink_to(outside, target_is_directory=True)
        for path in module.targets(self.root):
            module.remove(path)
        self.assertEqual((outside / 'data').read_text(), 'keep')

    def test_cleanup_refuses_tracked_generated_target(self):
        module = load('clean-project')
        self.git('init', '-q')
        (self.root / 'build').mkdir()
        (self.root / 'build/source').write_text('keep')
        self.git('add', 'build/source')
        with self.assertRaises(RuntimeError):
            module.targets(self.root)

    def test_tag_resolution_peels_annotated_tags_and_ignores_new_major(self):
        module = load('update-dependencies')
        refs = 'a\trefs/tags/3.1.0\nb\trefs/tags/3.2.0\nc\trefs/tags/3.2.0^{}\nd\trefs/tags/4.0.0\ne\trefs/tags/3.3.0-rc1'
        with patch.object(module, 'run', return_value=refs):
            self.assertEqual(module.tag_pin('url', '', 'latest', '3.1.0'), ('3.2.0', 'c'))
            with self.assertRaises(RuntimeError):
                module.tag_pin('url', '', '3.9.0', '3.1.0')

    def test_updater_rolls_back_pin_changes_on_resolution_failure(self):
        module = load('update-dependencies')
        for relative in ('scripts/update-dependencies.py', 'scripts/clean-project.py', 'scripts/prepare-dependencies.sh',
                         'UniversalRemote.xcodeproj/project.pbxproj',
                         'UniversalRemote.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
                         'Networking/WireGuard/go.mod', 'Networking/WireGuard/go.sum',
                         'ThirdParty/README.md', 'ThirdParty/WireGuard-build-modules.txt'):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, path)
        module = load('update-dependencies')
        module.ROOT = self.root
        module.PREPARE = self.root / 'scripts/prepare-dependencies.sh'
        module.PROJECT = self.root / 'UniversalRemote.xcodeproj/project.pbxproj'
        module.RESOLVED = self.root / 'UniversalRemote.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
        module.GO = self.root / 'Networking/WireGuard'
        self.git('init', '-q')
        before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file() and '.git' not in p.parts}
        with patch('sys.argv', ['update', '--swiftterm', '1.21.0', '--apply']), \
             patch.object(module, 'tag_pin', return_value=('1.21.0', 'a' * 40)), \
             patch.object(module, 'run', side_effect=RuntimeError('synthetic resolve failure')), \
             contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError):
                module.main()
        for path, content in before.items():
            self.assertEqual(path.read_bytes(), content)

    def test_user_reset_success_removes_only_owned_storage(self):
        module = load('clean-user-data')
        owned = self.root / 'Library/Application Support/UniversalRemote'
        owned.mkdir(parents=True)
        (owned / 'record').write_text('synthetic')
        other = self.root / 'Library/Application Support/OtherApp'
        other.mkdir()
        (other / 'record').write_text('keep')
        def fake_run(args, **kwargs):
            return subprocess.CompletedProcess(args, 1 if args[0] == 'pgrep' else 0)
        with patch('sys.argv', ['reset', '--apply']), patch.object(module.os, 'geteuid', return_value=501), \
             patch.object(module.Path, 'home', return_value=self.root), \
             patch.object(module.tempfile, 'gettempdir', return_value=str(self.root)), \
             patch.object(module.subprocess, 'run', side_effect=fake_run), \
             contextlib.redirect_stdout(io.StringIO()):
            module.main()
        self.assertFalse(owned.exists())
        self.assertEqual((other / 'record').read_text(), 'keep')

    def test_user_reset_refuses_running_app(self):
        module = load('clean-user-data')
        with patch('sys.argv', ['reset', '--apply']), patch.object(module.os, 'geteuid', return_value=501), \
             patch.object(module.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)), \
             contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, 'Quit'):
                module.main()

    def test_user_reset_is_exactly_scoped_and_keychain_failure_preserves_files(self):
        module = load('clean-user-data')
        library = self.root / 'Library/Application Support/UniversalRemote'
        library.mkdir(parents=True)
        (library / 'synthetic').write_text('keep')
        calls = []
        def fake_run(args, **kwargs):
            calls.append(args)
            if args[0] == 'pgrep':
                return subprocess.CompletedProcess(args, 1)
            if args[0] == 'xcrun':
                return subprocess.CompletedProcess(args, 0)
            raise subprocess.CalledProcessError(1, args)
        with patch('sys.argv', ['reset', '--apply']), patch.object(module.os, 'geteuid', return_value=501), \
             patch.object(module.Path, 'home', return_value=self.root), \
             patch.object(module.tempfile, 'gettempdir', return_value=str(self.root)), \
             patch.object(module.subprocess, 'run', side_effect=fake_run), \
             contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(subprocess.CalledProcessError):
                module.main()
        self.assertEqual((library / 'synthetic').read_text(), 'keep')
        self.assertIn('kSecAttrService', module.KEYCHAIN_SOURCE)
        self.assertIn('com.peterpo.UniversalRemote.credentials', module.KEYCHAIN_SOURCE)
        self.assertNotIn('SecItemCopyMatching', module.KEYCHAIN_SOURCE)
        self.assertFalse(any(c[0] == 'defaults' for c in calls))


if __name__ == '__main__':
    unittest.main()
