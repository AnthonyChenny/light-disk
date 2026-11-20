# Build from source

🌐 [中文](BUILD.zh-CN.md) · **English** · [README](../README.en.md)

## Environment

Apple Silicon, Swift language level 5.9+, and an SDK supporting macOS 15.4+. Local validation used Swift 6.4 and the macOS 27 SDK. The extension settings button uses the general Login Items & Extensions entry point for compatibility with earlier SDKs. The deployment target is 15.4+; other runtime versions remain unverified.

Install Xcode or matching Command Line Tools. **Manually install official macFUSE 5.5.0 with its development headers first.** Check `/usr/local/include/fuse/fuse.h` and `/usr/local/lib/libfuse.dylib`. The engine build needs `autoconf`, `automake`, `libtool` and `gettext`; these are build dependencies, not bundled user dependencies. With Homebrew: `brew install autoconf automake libtool gettext`. Ensure tools including `autopoint` are on PATH.

## Source checks without mounting disks

From the repository root:

```sh
python3 scripts/check-repository.py
swift build -c release --scratch-path .build/swift
.build/swift/release/QingPanPolicyTests
```

CI compiles and runs policy checks only; it does not install a privileged service or write to physical disks. Runner SDK changes may affect builds. Green CI is not filesystem integration validation.

## Complete Beta build

```sh
bash scripts/build-beta.sh
```

Use a fresh engine build directory; existing extracted source is not overwritten. For another full build, use a new directory:

```sh
bash scripts/build-beta.sh "$PWD/.build/release-second"
```

The script validates the original NTFS source checksum, applies the dated Darwin patch, builds the engine and Swift targets, runs policy checks, packages/validates the installer and DMG, then creates the matching source ZIP and SHA-256 file.

Outputs are in ignored `dist/$(cat VERSION)/`. The DMG includes the complete `安装轻盘.pkg`, bilingual instructions and licenses. It does not bundle macFUSE or a separate drag-to-install App that could omit the helper.

The package version uses the numeric part of VERSION; the App shows the full Beta string. This workflow produces ad-hoc signed code and an installer without a Developer ID Installer signature. Developer ID, Hardened Runtime, timestamps, notarization and stapling require a separate formal distribution workflow; they are not implemented or claimed here.

## Manual packaging

After building the engine and Swift code:

```sh
python3 Packaging/build.py \
  --binaries "$PWD/.build/release/swift/release" \
  --engine-source "$PWD/.build/release/engine/ntfs-3g-2026.9.28" \
  --work "$PWD/.build/release/package" \
  --output "$PWD/dist/$(cat VERSION)"
python3 scripts/prepare-release.py
```

Use `swift build -c release --scratch-path .build/release/swift --show-bin-path` to find the actual binary directory. Do not mix builds: the packager signs the helper, embeds its CDHash into the App, signs the App and stores its requirement in the root-owned configuration.

## Architecture and licensing

App → signature-checked XPC helper → validate external NTFS partition/UUID and open one descriptor → user bootstrap session and permanent privilege drop → NTFS-3G → macFUSE FSKit → Finder.

The helper exposes no general command-execution or arbitrary-path mount interface. Keep `norecover`, external physical disk restrictions, UUID and signature validation. See [third-party notices](../THIRD_PARTY_NOTICES.md) for corresponding source and license boundaries.
