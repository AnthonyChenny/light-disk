#!/usr/bin/env python3
"""Create matching corresponding-source ZIP and checksums beside existing Beta binaries."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
version = (root / 'VERSION').read_text().strip()
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+', version):
    raise SystemExit('A public Beta must have a -beta.N VERSION')
out = root / 'dist' / version
assets = [out / f'light-disk-{version}-arm64.dmg', out / '安装轻盘.pkg']
if not all(p.is_file() for p in assets):
    raise SystemExit('Build the DMG and installer first; see docs/BUILD.en.md')
subprocess.run(['python3', str(root / 'scripts/check-repository.py')], check=True)
# Explicit source roots avoid developer scratch directories, ignored binaries and .git.
source_roots = ['Sources', 'Tests', 'Packaging', 'Resources', 'ThirdParty', 'docs', 'scripts', '.github']
source_files = ['VERSION', 'Package.swift', 'LICENSE', 'README.md', 'README.en.md',
                'THIRD_PARTY_NOTICES.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'SECURITY.md',
                '.gitignore', '.gitattributes']
files = [root / n for n in source_files]
for n in source_roots:
    files.extend(p for p in (root / n).rglob('*') if p.is_file())
archive = out / f'light-disk-{version}-source.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(files):
        if p.name == '.DS_Store' or '__pycache__' in p.parts or p.suffix == '.pyc':
            continue
        if p.is_symlink():
            raise SystemExit('Source archive refuses symlinks: ' + str(p.relative_to(root)))
        z.write(p, 'light-disk-' + version + '/' + str(p.relative_to(root)))
assets.append(archive)
notes = out / 'RELEASE_NOTES.md'
notes.write_bytes((root / 'docs/releases' / f'v{version}.md').read_bytes())
commit = subprocess.run(['git', '-C', str(root), 'rev-parse', 'HEAD'], capture_output=True, text=True)
status = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain'], text=True)
manifest = out / 'release-manifest.json'
manifest.write_text(json.dumps({
    'project': 'light-disk / 轻盘', 'version': version, 'tag': 'v' + version,
    'architecture': 'arm64', 'signing': 'ad-hoc', 'notarized': False,
    'macfuse_bundled': False, 'macfuse_tested': '5.5.0',
    'source_commit': commit.stdout.strip() if commit.returncode == 0 else None,
    'source_tree_dirty': bool(status.strip()),
    'source_zip': archive.name,
    'note': 'Local assets only; this command does not commit, tag, upload or publish.'
}, ensure_ascii=False, indent=2) + '\n')
assets += [notes, manifest]
(out / 'SHA256SUMS.txt').write_text(''.join(
    hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n' for p in assets))
print('Prepared local release assets:', out)
if status.strip() or commit.returncode:
    print('Before publishing: commit the reviewed source, then rerun prepare-release.py to record the exact revision.')
