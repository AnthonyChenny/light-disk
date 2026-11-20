#!/usr/bin/env python3
"""Offline source/license/link checks. Does not mount or write to any disk device."""
from pathlib import Path
import ast
import hashlib
import re
import subprocess
import tarfile
import tempfile
from urllib.parse import unquote

root = Path(__file__).resolve().parent.parent
required = ['README.md', 'README.en.md', 'LICENSE', 'VERSION', 'THIRD_PARTY_NOTICES.md',
            'docs/INSTALL.zh-CN.md', 'docs/INSTALL.en.md', 'docs/BUILD.zh-CN.md', 'docs/BUILD.en.md',
            'docs/RELEASING.zh-CN.md', 'docs/RELEASING.en.md',
            'docs/screenshots/disks.jpg', 'docs/screenshots/settings.jpg',
            'ThirdParty/NTFS-3G-COPYING', 'ThirdParty/NTFS-3G-COPYING.LIB']
for n in required:
    assert (root / n).is_file(), 'Missing: ' + n
archive = root / 'ThirdParty/ntfs-3g-2026.9.28.tar.gz'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '8a75293f07bf40df5701d296de32a4cb0e46d6ae135abb4f41b438df9868a390'
for p in root.rglob('*'):
    if not p.is_file() or any(x in p.relative_to(root).parts for x in ['.git', '.build', 'dist']):
        continue
    assert p.suffix.lower() not in ['.p12', '.pfx', '.pem', '.key', '.mobileprovision'], 'Credential file: ' + str(p)
    assert not p.name.startswith('.env'), 'Private environment file: ' + str(p)
    if p.suffix == '.py':
        ast.parse(p.read_text(), filename=str(p))
    if p.suffix == '.sh' or p.name in ['preinstall', 'postinstall']:
        subprocess.run(['/bin/bash', '-n', str(p)], check=True)
    if p.suffix == '.md':
        text = p.read_text()
        targets = re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', text) + re.findall(r'<img[^>]+src="([^"]+)"', text)
        for target in targets:
            target = target.split('#', 1)[0]
            if not target or re.match(r'^[a-zA-Z]+:', target):
                continue
            assert (p.parent / unquote(target)).exists(), 'Broken local link: ' + str(p.relative_to(root)) + ' -> ' + target
# Verify corresponding-source patch against clean upstream files.
with tempfile.TemporaryDirectory(prefix='light-disk-source-check-') as temp:
    scratch = Path(temp)
    with tarfile.open(archive) as t:
        for rel in ['src/ntfs-3g_common.c', 'src/ntfs-3g.c', 'libntfs-3g/unix_io.c']:
            dest = scratch / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(t.extractfile('ntfs-3g-2026.9.28/' + rel).read())
    subprocess.run(['patch', '-p1', '--dry-run', '-i', str(root / 'Packaging/ntfs-fd-device.patch')],
                   cwd=scratch, check=True, capture_output=True)
print('PASS: repository links, required documents, credential filenames, syntax, source checksum and patch')
