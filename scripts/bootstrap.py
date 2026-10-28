"""Generate SDK-owned platform scaffolding, then install reviewed native overlays.

Run from any directory: python scripts/bootstrap.py
Requires Flutter on PATH and Python 3.10+. No banking data is read or written.
"""
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


def apply_platform(mobile: Path):
    manifest = mobile / 'android/app/src/main/AndroidManifest.xml'
    tree = ET.parse(manifest)
    ET.register_namespace('android', ANDROID[1:-1])
    root = tree.getroot()
    application = root.find('application')
    if application is None:
        raise RuntimeError('Flutter Android manifest has no application')
    application.set(ANDROID + 'label', 'QRpay')
    application.set(ANDROID + 'allowBackup', 'false')
    application.set(ANDROID + 'fullBackupContent', 'false')
    application.set(ANDROID + 'usesCleartextTraffic', 'false')
    if not any(p.get(ANDROID + 'name') == 'android.permission.CAMERA'
               for p in root.findall('uses-permission')):
        ET.SubElement(root, 'uses-permission', {ANDROID + 'name': 'android.permission.CAMERA'})
    if not any(p.get(ANDROID + 'name') == 'android.hardware.camera'
               for p in root.findall('uses-feature')):
        ET.SubElement(root, 'uses-feature', {
            ANDROID + 'name': 'android.hardware.camera', ANDROID + 'required': 'false'})
    tree.write(manifest, encoding='utf-8', xml_declaration=True)
    if not any(p.get(ANDROID + 'name') == 'android.permission.INTERNET'
               for p in root.findall('uses-permission')):
        ET.SubElement(root, 'uses-permission', {ANDROID + 'name': 'android.permission.INTERNET'})
        tree.write(manifest, encoding='utf-8', xml_declaration=True)
    kotlin = mobile / 'android/app/src/main/kotlin/pg/qrpay/qrpay_bsp/MainActivity.kt'
    kotlin.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / 'platform/android/MainActivity.kt', kotlin)
    build = mobile / 'android/app/build.gradle.kts'
    text = build.read_text()
    if 'minSdk = flutter.minSdkVersion' in text:
        text = text.replace('minSdk = flutter.minSdkVersion', 'minSdk = 23')
    elif not re.search(r'minSdk\s*=\s*23', text):
        raise RuntimeError('Review generated Gradle minSdk configuration')
    build.write_text(text)
    overlay = ROOT / 'platform/android/res'
    if overlay.exists():
        shutil.copytree(overlay, mobile / 'android/app/src/main/res', dirs_exist_ok=True)
    plist = mobile / 'ios/Runner/Info.plist'
    with plist.open('rb') as f:
        info = plistlib.load(f)
    info['CFBundleDisplayName'] = 'QRpay Demo'
    info['NSCameraUsageDescription'] = 'Scan a QRpay demo merchant payment code.'
    with plist.open('wb') as f:
        plistlib.dump(info, f, sort_keys=False)


def main():
    if not shutil.which('flutter'):
        sys.exit('Install Flutter 3.35.7 and add flutter/bin to PATH, then retry.')
    mobile = ROOT / 'mobile'
    # --no-pub keeps the supplied pubspec authoritative until scaffolding exists.
    # Flutter create preserves existing source; preserve explicitly as an extra guard.
    preserved = {str(p.relative_to(mobile)): p.read_bytes()
                 for folder in ('lib', 'test')
                 for p in (mobile / folder).rglob('*') if p.is_file()}
    for name in ('pubspec.yaml', 'analysis_options.yaml'):
        preserved[name] = (mobile / name).read_bytes()
    subprocess.run(['flutter', 'create', '--no-pub', '--platforms=android,ios',
                    '--org', 'pg.qrpay', '--project-name', 'qrpay_bsp', '.'],
                   cwd=mobile, check=True)
    for name, data in preserved.items():
        (mobile / name).write_bytes(data)
    # Flutter's counter-app test does not apply to this application.
    generated_test = mobile / 'test/widget_test.dart'
    generated_test.unlink(missing_ok=True)
    apply_platform(mobile)
    subprocess.run(['flutter', 'pub', 'get'], cwd=mobile, check=True)
    print('Platform setup complete. Run flutter analyze and flutter test in mobile/.')


if __name__ == '__main__':
    main()
