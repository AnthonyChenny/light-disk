# Publish a GitHub Beta release

🌐 [中文](RELEASING.zh-CN.md) · **English** · [README](../README.en.md)

Remote: `https://github.com/AnthonyChenny/light-disk.git`. The steps below publish code and download assets. Local preparation scripts do not commit, push, tag, upload or publish. Prepared local files are not an already-published release.

## Initial setup

1. Review screenshots, licenses, validation limits and `git status`. Never copy the original development outputs/work, disk backups or logs into this repository.
2. Confirm Public visibility and Issues in GitHub. Enable Private vulnerability reporting in Settings → Security if desired; SECURITY.md does not activate it.
3. Review unstaged/staged changes and new files, then commit. Keep credentials out of Git.

```sh
git add .
git commit -m "Prepare light-disk 0.1.3-beta.1"
```

## Build and matching source

Follow [BUILD.en.md](BUILD.en.md), or use the prepared `dist/0.1.3-beta.1/`. If the final commit changes documentation only, with App/engine source, VERSION, resources, packaging and dependencies unchanged, regenerate provenance/source metadata after committing:

```sh
python3 scripts/prepare-release.py
cd dist/0.1.3-beta.1
shasum -a 256 -c SHA256SUMS.txt
cd ../..
```

**Rebuild first if App/engine/resource/version/packaging code changed. Do not pair old binaries with new code.** `release-manifest.json` records the commit and dirty state. Initial local assets may record null/dirty; before publication, prepare again from a clean committed tree and check the manifest.

## Tag and push

Check for an existing remote tag before creating an immutable Beta tag:

```sh
git tag -a v0.1.3-beta.1 -m "light-disk / 轻盘 0.1.3-beta.1"
git push origin main
git push origin v0.1.3-beta.1
```

Use a new Beta version/tag for later changes instead of replacing published downloads. Update VERSION, the documented current version, release notes and App build number together.

## Create a pre-release

GitHub → Releases → Draft a new release. Select `v0.1.3-beta.1`; title it `light-disk / 轻盘 0.1.3-beta.1`; paste the [bilingual release notes](releases/v0.1.3-beta.1.md). **Select This is a pre-release.** Save a draft first and review the assets before publishing.

Upload all six matching files from one dist directory:

- `light-disk-0.1.3-beta.1-arm64.dmg`: the main user download with the complete installer.
- `light-disk-0.1.3-beta.1-installer.pkg`: optional direct installer download, identical to `安装轻盘.pkg` inside the DMG; ASCII naming avoids GitHub asset-name rewriting.
- `light-disk-0.1.3-beta.1-source.zip`: matching App source, original engine archive, modifications and build scripts.
- `SHA256SUMS.txt`: hashes of those assets and the next two files.
- `RELEASE_NOTES.md`: bilingual version notes.
- `release-manifest.json`: version, signing status, commit and dependency boundaries.

GitHub's generated source archives should point to the same tag; keep the verified source.zip too. Do not upload macFUSE installers, personal certificates, system settings, disk diagnostics or cleanup backups.

With GitHub CLI installed and authenticated by the maintainer, create a **draft**:

```sh
gh release create v0.1.3-beta.1 \
  --repo AnthonyChenny/light-disk --verify-tag --draft --prerelease \
  --title "light-disk / 轻盘 0.1.3-beta.1" \
  --notes-file docs/releases/v0.1.3-beta.1.md \
  dist/0.1.3-beta.1/*.dmg dist/0.1.3-beta.1/*.pkg \
  dist/0.1.3-beta.1/*-source.zip dist/0.1.3-beta.1/SHA256SUMS.txt \
  dist/0.1.3-beta.1/RELEASE_NOTES.md dist/0.1.3-beta.1/release-manifest.json
```

## Final review

Keep Beta/unnotarized status clear, the installation order complete, both languages consistent, source buildable and macFUSE separate. Clean-Mac installation remains an important uncompleted check. This build has no Developer ID/notarization and must not be advertised as a frictionless production release. See [TESTING.md](TESTING.md).

Reference: [official GitHub release documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
