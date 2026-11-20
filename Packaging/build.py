#!/usr/bin/env python3
"""Assemble already-built, arm64 binaries. All paths are explicit CLI arguments."""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--binaries', required=True, type=Path)
parser.add_argument('--engine-source', required=True, type=Path)
parser.add_argument('--work', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--macfuse-license', type=Path)
args = parser.parse_args()
source = Path(__file__).resolve().parent.parent
version = (source / 'VERSION').read_text().strip()
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-beta\.[0-9]+)?', version):
    raise RuntimeError('Invalid release version')
package_version = version.split('-')[0]
build_number = '4'
license_path = args.macfuse_license or source / 'ThirdParty/macFUSE-LICENSE.txt'
work = args.work.resolve()
output = args.output.resolve()
work.mkdir(parents=True, exist_ok=True)
output.mkdir(parents=True, exist_ok=True)

def run(*cmd):
    subprocess.run([str(x) for x in cmd], check=True)

def copy(a, b):
    b = Path(b); b.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(a, b)

def sign(path, identifier=None):
    cmd = ['/usr/bin/codesign', '--force', '--sign', '-']
    if identifier: cmd += ['--identifier', identifier]
    run(*cmd, path)

def cdhash(path):
    p = subprocess.run(['/usr/bin/codesign', '-d', '--verbose=4', str(path)], text=True, capture_output=True, check=True)
    return re.search(r'^CDHash=([a-f0-9]{40})$', p.stderr, re.M)[1]

app = work / '轻盘.app'
if app.exists(): shutil.rmtree(app)
contents = app / 'Contents'
resources = contents / 'Resources'
resources.mkdir(parents=True)
copy(args.binaries / 'QingPan', contents / 'MacOS/QingPan')
helper = work / 'local.qingpan.helper'
copy(args.binaries / 'QingPanHelper', helper)
sign(helper, 'local.qingpan.helper')
iconset = work / 'AppIcon.iconset'
if iconset.exists(): shutil.rmtree(iconset)
run('/usr/bin/swift', source / 'Packaging/Icon.swift', iconset)
run('/usr/bin/iconutil', '-c', 'icns', iconset, '-o', resources / 'AppIcon.icns')
for f in (source / 'Resources').iterdir(): copy(f, resources / f.name)
licenses = 'light-disk / 轻盘 — original code: MIT. Third-party code retains its own license.\nmacFUSE is a separately installed dependency, not bundled.\n\nmacFUSE 5.5.0 license notice\n' + license_path.read_text()
licenses += '\n\nNTFS-3G 2026.9.28\n' + (args.engine_source / 'COPYING').read_text()
licenses += '\n\n' + (args.engine_source / 'COPYING.LIB').read_text()
(resources / '第三方许可.txt').write_text(licenses)
info = {
    'CFBundleIdentifier': 'local.qingpan.app', 'CFBundleName': '轻盘',
    'CFBundleDisplayName': '轻盘', 'CFBundleExecutable': 'QingPan',
    'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': version,
    'CFBundleVersion': build_number, 'LSUIElement': True, 'LSMinimumSystemVersion': '15.4',
    'NSHighResolutionCapable': True, 'CFBundleIconFile': 'AppIcon',
    'NSRemovableVolumesUsageDescription': '轻盘需要显示外接磁盘并在 Finder 中启用 NTFS 读写。',
    'QingPanHelperHash': cdhash(helper),
}
with (contents / 'Info.plist').open('wb') as f: plistlib.dump(info, f)
sign(app)
root = work / 'payload'
if root.exists(): shutil.rmtree(root)
engine = root / 'Library/Application Support/QingPan/Engine/bin'
engine.mkdir(parents=True)
for name in ['ntfs-3g', 'ntfs-3g.probe']:
    copy(args.engine_source / 'src' / name, engine / name)
    # Refuse accidental dependencies on this developer's Homebrew installation.
    libs = subprocess.check_output(['/usr/bin/otool', '-L', str(engine/name)], text=True)
    if any('/opt/homebrew/' in line or '/Users/' in line for line in libs.splitlines()[1:]):
        raise RuntimeError('Nonportable runtime dependency: ' + libs)
    sign(engine / name)
copy(helper, root / 'Library/PrivilegedHelperTools/local.qingpan.helper')
support = root / 'Library/Application Support/QingPan'
(support / 'client.requirement').write_text('cdhash H"' + cdhash(app) + '"\n')
copy(resources / '第三方许可.txt', support / '第三方许可.txt')
copy(resources / 'uninstall.sh', support / 'uninstall.sh')
daemon = {
    'Label': 'local.qingpan.helper',
    'ProgramArguments': ['/Library/PrivilegedHelperTools/local.qingpan.helper'],
    'MachServices': {'local.qingpan.helper': True}, 'ProcessType': 'Interactive',
    'UserName': 'root', 'GroupName': 'wheel', 'Umask': 0o022,
    'StandardOutPath': '/var/log/qingpan-helper.log',
    'StandardErrorPath': '/var/log/qingpan-helper.log',
}
plist = root / 'Library/LaunchDaemons/local.qingpan.helper.plist'
plist.parent.mkdir(parents=True)
with plist.open('wb') as f: plistlib.dump(daemon, f)
shutil.copytree(app, root / 'Applications/轻盘.app')
scripts = work / 'scripts'
scripts.mkdir(exist_ok=True)
for name in ['preinstall', 'postinstall']:
    copy(source / 'Packaging' / name, scripts / name)
    (scripts / name).chmod(0o755)
pkg = output / '安装轻盘.pkg'
component_pkg = work / 'QingPanComponents.pkg'
components = work / 'components.plist'
with components.open('wb') as f:
    plistlib.dump([{'RootRelativeBundlePath': 'Applications/轻盘.app',
                   'BundleIsRelocatable': False, 'BundleHasStrictIdentifier': True,
                   'BundleIsVersionChecked': False, 'BundleOverwriteAction': 'upgrade'}], f)
run('/usr/bin/pkgbuild', '--root', root, '--scripts', scripts, '--identifier',
    'local.qingpan.components', '--version', package_version, '--install-location', '/',
    '--component-plist', components, '--ownership', 'recommended', component_pkg)
# A product archive supplies an explicit product name. A bare component package
# made Installer derive it from "安装轻盘.pkg", yielding "安装安装轻盘" in Chinese.
distribution = work / 'Distribution.xml'
distribution.write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>轻盘</title>
    <options customize="never" hostArchitectures="arm64" require-scripts="false"/>
    <domains enable_localSystem="true" enable_currentUserHome="false" enable_anywhere="false"/>
    <choices-outline><line choice="qingpan"/></choices-outline>
    <choice id="qingpan" title="轻盘" visible="false">
        <pkg-ref id="local.qingpan.components"/>
    </choice>
    <pkg-ref id="local.qingpan.components" version="{package_version}" onConclusion="none">QingPanComponents.pkg</pkg-ref>
</installer-gui-script>
''', encoding='utf-8')
run('/usr/bin/productbuild', '--distribution', distribution,
    '--package-path', work, pkg)
stage = work / 'dmg'
if stage.exists(): shutil.rmtree(stage)
stage.mkdir()
copy(pkg, stage / pkg.name)
copy(resources / '使用说明.txt', stage / '请先阅读-ReadMe.txt')
copy(resources / 'Installation-English.txt', stage / 'ReadMe-English.txt')
copy(resources / '第三方许可.txt', stage / '第三方许可.txt')
# The packaged text guides use absolute upstream/repository URLs for offline opening.
copy(source / 'LICENSE', stage / 'LICENSE-MIT.txt')
copy(source / 'ThirdParty/NTFS-3G-COPYING', stage / 'LICENSE-NTFS-3G.txt')
copy(source / 'ThirdParty/NTFS-3G-COPYING.LIB', stage / 'LICENSE-NTFS-3G-LIB.txt')
dmg = output / f'light-disk-{version}-arm64.dmg'
if dmg.exists(): dmg.unlink()
run('/usr/bin/hdiutil', 'create', '-volname', 'light-disk', '-srcfolder', stage,
    '-ov', '-format', 'UDZO', dmg)
(output / 'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n' for p in [dmg, pkg]))
run('/usr/bin/hdiutil', 'verify', dmg)
print('Built:', dmg)
