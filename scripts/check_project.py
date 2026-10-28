"""Source privacy gates and platform-overlay regression check. Not a Flutter build."""
from pathlib import Path
import importlib.util
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bootstrap', ROOT / 'scripts/bootstrap.py')
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)
ios_spec = importlib.util.spec_from_file_location('package_ios', ROOT / 'scripts/package_ios.py')
package_ios = importlib.util.module_from_spec(ios_spec)
ios_spec.loader.exec_module(package_ios)


class SourceChecks(unittest.TestCase):
    def test_iphone_package_preserves_executable_and_payload_layout(self):
        import zipfile
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / 'Runner.app'
            app.mkdir()
            binary = app / 'Runner'
            binary.write_bytes(b'test fixture, not a compiled application')
            binary.chmod(0o755)
            (app / 'Info.plist').write_bytes(plistlib.dumps({
                'DTPlatformName': 'iphoneos', 'CFBundleExecutable': 'Runner',
                'NSCameraUsageDescription': 'Scan demo QR',
            }))
            output = package_ios.package(app, Path(tmp) / 'preview.ipa')
            with zipfile.ZipFile(output) as archive:
                self.assertIn('Payload/Runner.app/Info.plist', archive.namelist())
                entry = archive.getinfo('Payload/Runner.app/Runner')
                self.assertTrue((entry.external_attr >> 16) & 0o111)
                self.assertIsNone(archive.testzip())

    def test_iphone_package_rejects_simulator_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / 'Runner.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({
                'DTPlatformName': 'iphonesimulator', 'CFBundleExecutable': 'Runner',
            }))
            with self.assertRaisesRegex(ValueError, 'simulator'):
                package_ios.package(app, Path(tmp) / 'preview.ipa')

    def test_banking_protocol_remains_separate_from_optional_backup(self):
        source = (ROOT / 'mobile/lib/payment.dart').read_text()
        self.assertIn('Live BSP payment transport is not configured.', source)
        for dependency in ['http', 'sqflite', 'printing']:
            self.assertIn(dependency + ':', (ROOT / 'mobile/pubspec.yaml').read_text())
        cloud = (ROOT / 'mobile/lib/data/cloud_client.dart').read_text()
        self.assertIn("store.enabled('cloudConsent')", cloud)
        self.assertNotIn('sendUssdRequest', cloud)
        self.assertNotIn('SmsManager', cloud)

    def test_native_handoff_never_submits_or_accepts_commands(self):
        source = (ROOT / 'platform/android/MainActivity.kt').read_text()
        self.assertIn('Intent.ACTION_DIAL', source)
        self.assertIn('"*131*6#"', source)
        self.assertIn('FLAG_SECURE', source)
        for forbidden in ['ACTION_CALL', 'sendUssdRequest(', 'SmsManager',
                          'call.arguments', 'Log.', 'SharedPreferences']:
            self.assertNotIn(forbidden, source)

    def test_platform_overlay_is_idempotent_and_disables_backup(self):
        with tempfile.TemporaryDirectory() as tmp:
            mobile = Path(tmp)
            manifest = mobile / 'android/app/src/main/AndroidManifest.xml'
            manifest.parent.mkdir(parents=True)
            manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
                                '<application android:label="app" /></manifest>')
            build = mobile / 'android/app/build.gradle.kts'
            build.write_text('android { defaultConfig { minSdk = flutter.minSdkVersion } }')
            plist = mobile / 'ios/Runner/Info.plist'
            plist.parent.mkdir(parents=True)
            plist.write_bytes(plistlib.dumps({'CFBundleDisplayName': 'app'}))
            bootstrap.apply_platform(mobile)
            bootstrap.apply_platform(mobile)
            root = ET.parse(manifest).getroot()
            app = root.find('application')
            self.assertEqual(app.get(bootstrap.ANDROID + 'allowBackup'), 'false')
            self.assertEqual(app.get(bootstrap.ANDROID + 'fullBackupContent'), 'false')
            permissions = [p.get(bootstrap.ANDROID + 'name')
                           for p in root.findall('uses-permission')]
            self.assertEqual(permissions, ['android.permission.CAMERA', 'android.permission.INTERNET'])
            self.assertIn('minSdk = 23', build.read_text())
            self.assertIn('NSCameraUsageDescription', plistlib.loads(plist.read_bytes()))
            native = mobile / 'android/app/src/main/kotlin/pg/qrpay/qrpay_bsp/MainActivity.kt'
            self.assertEqual(native.read_bytes(),
                             (ROOT / 'platform/android/MainActivity.kt').read_bytes())


if __name__ == '__main__':
    unittest.main(verbosity=2)
