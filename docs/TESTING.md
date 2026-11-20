# Test coverage / 验证范围

This is a record of observed tests, not certification. 此记录不构成所有机器、系统或硬盘的兼容保证。

| Scope | Observed result |
|---|---|
| Local environment | Apple Silicon M4 Pro, macOS 27.0.1; arm64 release build |
| Policy/identity/subprocess tests | 40 checks passed in local 0.1.2 lineage; rerun for public Beta |
| Earlier NTFS disposable images | 64 MiB, Unicode/spaces, 200 small files, directories, rename/delete, unmount/remount |
| Earlier >4 GiB image test | 4,295,032,832-byte round trip and remount SHA-256 passed before final descriptor integration |
| Final descriptor integration image | 8 MiB round trip after pathname access was removed; Unicode, rename/delete passed |
| Final NTFS physical checks | 1 TB and 5 TB drives, each 16 MiB SHA-256 round trip, 20 small files, Unicode, rename/delete; unique test folders cleaned |
| Native exFAT | 128 MiB image integration; physical 5 TB drive observed read/write |
| 0.1.2 UI/eject | Four normal cards visible; details; busy eject preserves card; success during refresh removes it; disposable fixtures cleaned |

当前 Beta 把上述本机实现整理为公开仓库与无 macFUSE 捆绑的包。真实硬盘测试主要发生在 0.1.1，界面调整在 0.1.2；公开 Beta 的打包测试不等于重新完成所有历史文件系统测试。

Not yet verified: clean installation on another Mac, Intel, every targeted macOS version, Windows rereading newly created test data, sustained stress, interrupted power, sleep/wake and reboot/login startup as a complete matrix. macOS 15.4+ is a deployment target, not the verified coverage list.

Avoid publishing personal volume names, serial numbers, full device dumps or development-machine repair/cleanup archives in issues. Start device-specific testing with disposable data and independent backups.

## Public Beta build check — 2026-11-20

The v0.1.3-beta.1 source tree was built from its pinned NTFS source archive and dated patch. The full build script completed, 40 policy checks passed and the DMG checksum verified. The package product title, App version, ad-hoc signatures and mutual App/helper CDHash pins were checked. The public DMG has no macFUSE installer or standalone App copy.

The freshly built engine also passed an 8 MiB read/write round trip using an inherited descriptor after pathname access was removed; Unicode/spaces, rename and delete passed. This used only a disposable NTFS image. No physical user disk was written in this public-packaging round.

GitHub Actions subsequently passed repository checks, a release build and policy checks on commit `f751673` ([run](https://github.com/AnthonyChenny/light-disk/actions/runs/44670157230)). The extension settings entry point was adjusted to compile with the hosted runner SDK. Hosted CI does not extend physical-disk or clean-install coverage. Source is pushed to GitHub; binary assets remain local until a Release is explicitly created.
