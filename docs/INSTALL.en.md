# Install, upgrade and uninstall

🌐 [中文](INSTALL.zh-CN.md) · **English** · [README](../README.en.md)

## Check your Mac first

Apple Silicon (M series) only. Full local validation used macOS 27.0.1; 15.4+ is a deployment target, not verified coverage for every version.

## First installation: download, install, then connect

**For a first-time setup, download only the two DMGs below. You do not need source code or other release attachments.** Install macFUSE first: it connects NTFS-3G to macOS. NTFS-3G is already included in the light-disk installer; there is no separate engine download.

| Order | File | Download |
|---|---|---|
| ① | Official `macfuse-5.5.0.dmg` | [Download macFUSE](https://github.com/macfuse/macfuse/releases/download/macfuse-5.5.0/macfuse-5.5.0.dmg) ([official release](https://github.com/macfuse/macfuse/releases/tag/macfuse-5.5.0)) |
| ② | `light-disk-0.1.3-beta.1-arm64.dmg` | [Download light-disk](https://github.com/AnthonyChenny/light-disk/releases/download/v0.1.3-beta.1/light-disk-0.1.3-beta.1-arm64.dmg) ([project release](https://github.com/AnthonyChenny/light-disk/releases/tag/v0.1.3-beta.1)) |

### Step 1: Install macFUSE

In **Finder → Downloads**, open `macfuse-5.5.0.dmg`, then double-click the **macFUSE `.pkg` installer inside**. Follow Continue → Install, and authenticate with your Mac administrator password or Touch ID in the system dialog. Restart first if the installer requests it. Skip reinstalling if 5.5.0 is already installed. You do not need `debug.tbz`, `sha256`, `sig` or `Source code` from the vendor's page.

### Step 2: Enable both macFUSE extensions

Open **System Settings → General → Login Items & Extensions → File System Extensions**. Enable **macFUSE** and **macFUSE (local)**, preferably through the “By Category” view. light-disk uses FSKit: **Recovery Mode and reduced startup security are not needed**. If the entry is missing or toggles do not respond, see [extension troubleshooting](#if-extension-switches-do-not-respond).

### Step 3: Install light-disk

Open `light-disk-0.1.3-beta.1-arm64.dmg` and double-click **`安装轻盘.pkg`** (Install QingPan) inside. Follow Continue → Install and authenticate. This installs the App in Applications, together with the engine and helper. Do not just drag an App; you do not need a second standalone `.pkg` download.

### Step 4: Authorize disk access

Open **System Settings → Privacy & Security → Full Disk Access**. Click **`+`**, press **`⌘⇧G`** in the file chooser, paste this path and press Return:

```text
/Library/PrivilegedHelperTools/local.qingpan.helper
```

Select the file, add it and switch it on. Authenticate in the system dialog if needed. Also allow the App's removable-volume prompt, or check Privacy & Security → Files & Folders → 轻盘 → Removable Volumes. Full Disk Access is a broad system permission; review it before granting it.

### Step 5: Launch and connect

Open **Finder → Applications → 轻盘**, click its disk icon in the top menu bar and connect your NTFS drive. Wait for **`可读写`** (read/write ready), then copy, paste or drag files in Finder. Click **`推出`** (Eject) and wait for completion before unplugging.

**If macOS cannot verify the developer or blocks opening:** this Beta is ad-hoc signed and not notarized. Verify the download source, then review System Settings → Privacy & Security and use Open Anyway if offered. If unavailable, stop and report the issue; do not disable Gatekeeper or SIP. [Troubleshooting, upgrade and uninstall](#troubleshooting)

## If extension switches do not respond

Try File System Extensions in the “By Category” view rather than only toggling “By Application”. See the [official guide](https://github.com/macfuse/macfuse/wiki/Getting-Started) and [upstream issue #1194](https://github.com/macfuse/macfuse/issues/1194). Report persistent failures; do not edit system databases or reduce startup security.

## Troubleshooting

- **No capacity or no device in Disk Utility:** check USB data connectivity, hubs and accessory authorization. A lit LED does not establish data enumeration. Do not format a disk to diagnose USB detection.
- **Dirty or hibernated volume:** reconnect to Windows, close files and use Safely Remove Hardware. If still inconsistent, back up and check in Windows. light-disk does not clear hibernation data or force repairs.
- **Access denied:** check Full Disk Access for the helper; updates with a different ad-hoc signature may require reauthorization.
- **Extension unavailable:** check both FSKit modules and the “By Category” view. Installed components do not guarantee a successful mount.
- **Paragon NTFS present:** disable its automatic takeover, or use its official uninstaller if appropriate. light-disk does not remove third-party components.
- **Busy disk cannot eject:** close open files, Finder previews and terminals whose working directory is on the disk; retry. No forced unmount is performed.

## Upgrade

Close files, safely eject all NTFS volumes mounted by light-disk and quit the App. Run the complete new `.pkg`. The installer refuses to update while managed NTFS mounts remain. Relaunch and check permissions. Replacing only the App may break its pinned helper-signature pairing.

## Uninstall

Eject managed NTFS volumes and disable `登录后自动启动` (launch at login). In Settings (`齿轮`) → `更多` (More) → `卸载轻盘组件…` (Uninstall components), authenticate; then quit the App and move `/Applications/轻盘.app` to Trash. The uninstaller refuses to remove components while managed mounts exist.

The light-disk uninstaller retains macFUSE and other software. Remove macFUSE separately through its official settings panel only if no other software needs it. You can remove the uninstalled helper's privacy permission entry in System Settings.
