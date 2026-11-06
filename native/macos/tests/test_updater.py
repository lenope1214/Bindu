"""Real macOS filesystem/code-signing/LaunchServices tests. All apps and data live in a temporary directory."""
import hashlib
import fcntl
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[3]
HELPER = ROOT / 'build/macos/BinduUpdater'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs)


def wait_for(test, timeout=12):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if test():
            return
        time.sleep(.1)
    raise AssertionError('Timed out waiting for native updater')


class UpdaterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        run(str(ROOT / 'build_macos.command'), '--helper-only')
        cls.fixture_dir = tempfile.TemporaryDirectory(prefix='bindu-fixture-')
        cls.fixture = Path(cls.fixture_dir.name) / 'Fixture'
        run('xcrun', 'clang', '-fobjc-arc', '-framework', 'Cocoa',
            str(ROOT / 'native/macos/tests/fixture.m'), '-o', str(cls.fixture))

    @classmethod
    def tearDownClass(cls):
        cls.fixture_dir.cleanup()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='bindu updater space-')
        self.dir = Path(self.tmp.name).resolve()
        self.events = self.dir / 'events.log'
        self.app = self.bundle(self.dir / 'installed/한글 Bindu.app', '1.0.0')
        self.source = self.bundle(self.dir / 'source/Bindu.app', '1.0.1')
        self.stage = self.app.parent / ('.bindu-update-' + uuid.uuid4().hex)
        self.stage.mkdir(mode=0o700)
        self.receipt = self.dir / 'result.json'
        self.parent = None
        self.helper = None
        self.helper_log = None
        self.saved = self.dir / 'user-data/progress.cfg'
        self.saved.parent.mkdir()
        self.saved.write_text('save must remain unchanged')

    def tearDown(self):
        if self.helper and self.helper.poll() is None:
            self.helper.kill()
            self.helper.wait()
        if self.parent and self.parent.poll() is None:
            self.parent.terminate()
            self.parent.wait()
        if self.events.exists():
            for line in self.events.read_text().splitlines():
                try:
                    os.kill(int(line.split()[-1]), signal.SIGTERM)
                except ProcessLookupError:
                    pass
        output = Path('/tmp/bindu-macos-native-output')
        output.mkdir(exist_ok=True)
        if self.events.exists():
            shutil.copy2(self.events, output / (self._testMethodName + '.events.log'))
        if self.helper_log:
            self.helper_log.close()
            shutil.copy2(self.dir / 'helper.log', output / (self._testMethodName + '.helper.log'))
        self.tmp.cleanup()

    def bundle(self, app, version, **extra):
        (app / 'Contents/MacOS').mkdir(parents=True)
        (app / 'Contents/Resources').mkdir()
        shutil.copy2(self.fixture, app / 'Contents/MacOS/Fixture')
        (app / 'Contents/Resources/file.txt').write_text('resource')
        (app / 'Contents/Resources/link.txt').symlink_to('file.txt')
        p = dict(CFBundleIdentifier='kr.chat.anon.bindu', CFBundleExecutable='Fixture',
                 CFBundleName='Bindu', CFBundlePackageType='APPL',
                 CFBundleShortVersionString=version, CFBundleVersion=version,
                 BinduTestOutput=str(self.events), **extra)
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(p))
        run('/usr/bin/codesign', '--force', '--sign', '-', str(app))
        return app

    def archive(self):
        path = self.stage / 'update.zip'
        run('/usr/bin/ditto', '-c', '-k', '--norsrc', '--keepParent', str(self.source), str(path))
        return path

    def prepare(self, sha=None, version='1.0.1'):
        path = self.stage / 'update.zip'
        if not path.exists():
            self.archive()
        sha = sha or hashlib.sha256(path.read_bytes()).hexdigest()
        return subprocess.run([str(HELPER), 'prepare', str(self.app), str(self.stage), sha, version, str(self.receipt)],
                              capture_output=True, text=True)

    def version(self):
        return plistlib.loads((self.app / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']

    def test_prepare_preserves_permissions_symlinks_and_signatures(self):
        r = self.prepare()
        self.assertEqual(r.returncode, 0, r.stderr)
        new = self.stage / 'unpacked/Bindu.app'
        self.assertTrue(os.access(new / 'Contents/MacOS/Fixture', os.X_OK))
        self.assertTrue((new / 'Contents/Resources/link.txt').is_symlink())
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(new))
        self.assertEqual(self.version(), '1.0.0')

    def test_hash_mismatch_keeps_original(self):
        self.assertNotEqual(self.prepare(sha='0' * 64).returncode, 0)
        self.assertEqual(self.version(), '1.0.0')

    def test_wrong_version_keeps_original(self):
        self.assertNotEqual(self.prepare(version='9.9.9').returncode, 0)
        self.assertEqual(self.version(), '1.0.0')

    def test_modified_bundle_signature_is_rejected(self):
        (self.source / 'Contents/Resources/file.txt').write_text('tampered')
        self.assertNotEqual(self.prepare().returncode, 0)
        self.assertEqual(self.version(), '1.0.0')

    def test_unwritable_install_parent_keeps_original(self):
        try:
            self.app.parent.chmod(0o500)
            self.assertNotEqual(self.prepare().returncode, 0)
            self.assertEqual(self.version(), '1.0.0')
        finally:
            self.app.parent.chmod(0o700)

    def test_wrong_bundle_identifier_is_rejected(self):
        path = self.source / 'Contents/Info.plist'
        p = plistlib.loads(path.read_bytes())
        p['CFBundleIdentifier'] = 'other.application'
        path.write_bytes(plistlib.dumps(p))
        run('/usr/bin/codesign', '--force', '--sign', '-', str(self.source))
        self.assertNotEqual(self.prepare().returncode, 0)
        self.assertEqual(self.version(), '1.0.0')

    def test_corrupt_zip_with_matching_hash_is_rejected(self):
        (self.stage / 'update.zip').write_bytes(b'not a zip')
        self.assertNotEqual(self.prepare().returncode, 0)
        self.assertEqual(self.version(), '1.0.0')

    def test_concurrent_install_is_rejected_before_original_exits(self):
        self.assertEqual(self.prepare().returncode, 0)
        with (self.app.parent / '.bindu-update.lock').open('w') as lock:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            r = subprocess.run([str(HELPER), 'install', str(self.app), str(self.stage), str(os.getpid())], capture_output=True, text=True)
            self.assertNotEqual(r.returncode, 0)
            self.assertFalse((self.stage / 'installing.json').exists())
            self.assertEqual(self.version(), '1.0.0')

    def test_archive_traversal_and_external_symlink_are_rejected(self):
        for kind in ['traversal', 'symlink']:
            path = self.stage / 'update.zip'
            with zipfile.ZipFile(path, 'w') as z:
                if kind == 'traversal':
                    z.writestr('Bindu.app/../../escaped.txt', b'escape')
                else:
                    link = zipfile.ZipInfo('Bindu.app/link')
                    link.create_system = 3
                    link.external_attr = 0o120777 << 16
                    z.writestr(link, '../../escaped')
                    z.writestr('Bindu.app/link/out.txt', b'escape')
            self.assertNotEqual(self.prepare().returncode, 0)
            self.assertFalse((self.app.parent / 'escaped.txt').exists())
            unpacked = self.stage / 'unpacked'
            if unpacked.exists():
                shutil.rmtree(unpacked)
        self.assertEqual(self.version(), '1.0.0')

    def start_install(self):
        r = self.prepare()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.parent = subprocess.Popen([str(self.app / 'Contents/MacOS/Fixture')])
        wait_for(lambda: self.events.exists() and '1.0.0 ' in self.events.read_text())
        self.helper_log = (self.dir / 'helper.log').open('w')
        self.helper = subprocess.Popen([str(HELPER), 'install', str(self.app), str(self.stage), str(self.parent.pid)],
                                       stdout=self.helper_log, stderr=subprocess.STDOUT, text=True)
        wait_for(lambda: (self.stage / 'installing.json').exists())
        self.assertEqual(self.version(), '1.0.0', 'must wait for old app exit')
        self.parent.terminate()
        self.parent.wait()

    def test_real_app_swap_launch_ack_cleanup_and_save_preservation(self):
        self.start_install()
        self.helper.wait(timeout=20)
        self.assertEqual(self.helper.returncode, 0, (self.dir / 'helper.log').read_text())
        self.assertEqual(self.version(), '1.0.1')
        self.assertFalse(self.stage.exists())
        self.assertIn('1.0.1 ', self.events.read_text())
        self.assertEqual(self.saved.read_text(), 'save must remain unchanged')
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(self.app))

    def test_new_app_crash_restores_and_relaunches_old_app(self):
        shutil.rmtree(self.source)
        self.source = self.bundle(self.source, '1.0.1', BinduTestCrash=True)
        self.start_install()
        self.helper.wait(timeout=55)
        self.assertNotEqual(self.helper.returncode, 0, (self.dir / 'helper.log').read_text())
        self.assertEqual(self.version(), '1.0.0')
        wait_for(lambda: self.events.read_text().count('1.0.0 ') == 2)
        self.assertIn('error', json.loads(self.receipt.read_text()))
        self.assertEqual(self.saved.read_text(), 'save must remain unchanged')
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(self.app))

    def test_missing_startup_ack_restores_previous_app(self):
        shutil.rmtree(self.source)
        self.source = self.bundle(self.source, '1.0.1', BinduTestNoAck=True)
        self.start_install()
        self.helper.wait(timeout=55)
        self.assertNotEqual(self.helper.returncode, 0)
        self.assertEqual(self.version(), '1.0.0')
        wait_for(lambda: self.events.read_text().count('1.0.0 ') == 2)
        self.assertIn('error', json.loads(self.receipt.read_text()))
        self.assertEqual(self.saved.read_text(), 'save must remain unchanged')


if __name__ == '__main__':
    unittest.main(verbosity=2)
