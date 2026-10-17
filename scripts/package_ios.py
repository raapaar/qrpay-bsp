"""Package a device build for subsequent personal-device signing.

This does not sign, provision, install or upload to TestFlight. A simulator build
cannot substitute for the ARM64 device build made by iphone-preview.yml.
"""
from pathlib import Path
import argparse
import plistlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def package(app: Path, output: Path):
    info_file = app / 'Info.plist'
    if not info_file.is_file():
        raise ValueError('No iPhone build found. Run flutter build ios --release --no-codesign on macOS.')
    with info_file.open('rb') as f:
        info = plistlib.load(f)
    if info.get('DTPlatformName') != 'iphoneos':
        raise ValueError('An iPhone device build is required; simulator builds cannot be installed.')
    binary = info.get('CFBundleExecutable')
    if not isinstance(binary, str) or Path(binary).name != binary or not (app / binary).is_file():
        raise ValueError('The application executable is missing or invalid.')
    if not info.get('NSCameraUsageDescription'):
        raise ValueError('Camera permission description is missing.')
    output.parent.mkdir(parents=True, exist_ok=True)
    # ZipFile.write preserves Unix executable attributes. Device frameworks in
    # an iOS bundle use flat layouts; dereference any file symlinks from Xcode.
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(app.rglob('*')):
            if path.is_file():
                archive.write(path, Path('Payload') / app.name / path.relative_to(app))
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError('IPA archive integrity failed.')
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path,
                        default=ROOT / 'mobile/build/ios/iphoneos/Runner.app')
    parser.add_argument('--output', type=Path,
                        default=ROOT / 'output/QRpay-Demo-unsigned.ipa')
    args = parser.parse_args()
    print(package(args.app.resolve(), args.output.resolve()))


if __name__ == '__main__':
    main()
