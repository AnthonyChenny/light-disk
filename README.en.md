# light-disk / 轻盘

🌐 [中文](README.md) · **English**

A lightweight macOS menu bar utility that enables NTFS read/write access and lets you copy, paste and drag files in Finder.

**Open-source Beta · Apple Silicon · Ad-hoc signed, not notarized by Apple.** The application UI is currently Chinese; these English documents explain installation and operation.

[Download Beta](https://github.com/AnthonyChenny/light-disk/releases) · [Installation](docs/INSTALL.en.md) · [Build](docs/BUILD.en.md) · [Release guide](docs/RELEASING.en.md) · [Report an issue](https://github.com/AnthonyChenny/light-disk/issues)

## Screenshots

<img src="docs/screenshots/disks.jpg" alt="Data volumes with details, Finder and safe eject actions" width="380">
<img src="docs/screenshots/settings.jpg" alt="Settings for login startup, automatic writing and component status" width="510">

These are real screenshots from 0.1.2. The public Beta retains this interface. The local-signing notice shown in the UI accurately describes the Beta signing status.

## Features

- Automatically mount NTFS read/write and copy files in both directions in Finder.
- Use native macOS support for exFAT, FAT32, APFS and HFS+.
- View capacity, access state and disk details; safely eject disks. About four normal cards fit on a regular screen.
- Optional launch at login. No account, advertising, telemetry or cloud sync.
- NTFS-3G with the macFUSE FSKit backend; no automatic kernel-extension fallback. Unsafe volumes are not taken over for writing.

## Requirements

| Item | Status |
|---|---|
| CPU | Apple Silicon (M series) only; no Intel installer |
| macOS | Deployment target 15.4+; full local validation on 27.0.1; other versions unverified |
| Dependency | macFUSE 5.5.0, installed separately from the vendor |
| Signing | Ad-hoc; no Developer ID or Apple notarization |
| Excluded | BitLocker unlocking, partitioning, formatting, automatic repair, ext4 |

## Install in this order

**macFUSE → enable FSKit extensions → light-disk package → disk permissions → connect your disk.**

1. **Install macFUSE first.** Download from the [official website](https://macfuse.github.io/) or the [official 5.5.0 release](https://github.com/macfuse/macfuse/releases/tag/macfuse-5.5.0). Our DMG **does not bundle, download or automatically install macFUSE**.
2. **Enable file system extensions.** Open System Settings → General → Login Items & Extensions → File System Extensions, and enable `macFUSE` and `macFUSE (local)`. Prefer the “By Category” view. FSKit does not require reduced startup security or Recovery Mode setup.
3. **Install light-disk.** Download `light-disk-0.1.3-beta.1-arm64.dmg` from Releases. Open it and run `安装轻盘.pkg` (Install QingPan). Authenticate in the system dialog. The package installs the App, NTFS-3G and a restricted helper; **copying only the App is insufficient**.
4. **Authorize disk access.** In System Settings → Privacy & Security → Full Disk Access, add and enable `/Library/PrivilegedHelperTools/local.qingpan.helper`. Use `⌘⇧G` in the file chooser to enter the path. Full Disk Access is broad: review the permission before granting it; the helper needs it for physical disks. Also allow removable-volume access when requested, or enable the App's Removable Volumes entry under Files & Folders.
5. **Launch and connect a disk.** Open `轻盘` in Applications and click its menu bar disk icon. `可读写` means read/write is ready. Use Finder for file operations and `推出` to eject before disconnecting.

Gatekeeper may block this downloaded Beta. After verifying its origin and SHA-256, review the warning in System Settings → Privacy & Security and use Open Anyway if offered. If no override is available, stop and report the issue. Do not disable Gatekeeper or SIP. [Full installation, upgrade and uninstall guide](docs/INSTALL.en.md)

## Open source and releases

The original Swift code is [MIT-licensed](LICENSE). NTFS-3G and our modifications retain their GPL/LGPL terms. macFUSE is a separate dependency with its own license, including restrictions on commercial binary bundling. **MIT does not cover the entire dependency collection.** See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

A Release should include the DMG, corresponding source ZIP and SHA256SUMS.txt. Use a `beta` tag and select **This is a pre-release** on GitHub. Local upload assets live in ignored `dist/`, outside Git history. [Current release notes](docs/releases/v0.1.3-beta.1.md)

## Validation and limitations

Earlier local builds passed disposable NTFS/exFAT image tests, a file larger than 4 GiB, 16 MiB round trips on two physical NTFS drives, and UI/eject checks. This public Beta adds documentation and packaging on that foundation. **A clean installation on another Mac is not yet validated.** Sleep/wake, power interruption and all OS versions remain unverified. See [test coverage](docs/TESTING.md).

Start with disposable data on your own setup and keep separate backups of important data. Hibernated, dirty or busy volumes are not forcibly repaired or unmounted. The NTFS engine cannot enumerate a USB disk that macOS itself does not detect.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). Include OS version, chip, filesystem and sanitized errors in reports. Do not upload file contents, complete disk serials or passwords.
