# Third-party notices / 第三方声明

The root MIT license applies to original Swift application/helper code, original packaging scripts and original documentation only. Third-party software retains its own terms. 根目录 MIT 许可仅涵盖自写代码与文档，不覆盖第三方组件。

| Component | Version | License / treatment |
|---|---|---|
| Original light-disk code | See VERSION | [MIT](LICENSE) |
| NTFS-3G executable and modified source | 2026.9.28 + Darwin FD patch | Upstream GPL terms, see [COPYING](ThirdParty/NTFS-3G-COPYING), per-file notices and COPYING.LIB |
| libntfs-3g | Same source archive; statically linked into engine | See upstream GPL/LGPL per-file terms and [COPYING.LIB](ThirdParty/NTFS-3G-COPYING.LIB) |
| macFUSE | Tested 5.5.0 | Separate prerequisite; [vendor license](ThirdParty/macFUSE-LICENSE.txt); not bundled/downloaded automatically |
| Apple frameworks | Supplied by macOS | System dependencies; not redistributed |

NTFS-3G source archive: `ThirdParty/ntfs-3g-2026.9.28.tar.gz`, SHA-256 `8a75293f07bf40df5701d296de32a4cb0e46d6ae135abb4f41b438df9868a390`. Origin: <https://github.com/tuxera/ntfs-3g/archive/refs/tags/2026.9.28.tar.gz>.

Corresponding source for the distributed engine consists of that archive, `Packaging/ntfs-fd-device.patch`, `Packaging/build-engine.sh`, and associated build/package scripts. The patch preserves numeric Darwin FD paths, duplicates already-authorized descriptors and avoids Linux fuseblk handling for these user-session FSKit processes. Changed files carry a dated notice; see `ThirdParty/MODIFICATIONS.md`. It does not clear dirty flags or hibernation files.

Release binaries must be accompanied by equivalent access to matching corresponding source; keep equivalent source access from the same Release through GitHub’s tag archives (including the original engine archive, modifications and build scripts), or an additional matching source ZIP. A link only to an unmodified upstream project is insufficient. Preserve upstream copyright and license files. 源码、补丁和构建脚本必须与每版二进制匹配，修改后的 NTFS 引擎不改成 MIT 许可。

macFUSE is a separate vendor dependency, not presented as entirely MIT/GPL-licensed light-disk code. Its license restricts binary redistribution bundled with commercial software without written permission, including automated downloads/installation in that context. This project links users to the official vendor download and does not ship its `.pkg` or binaries. A future commercial distribution needs its own license review. See <https://raw.githubusercontent.com/macfuse/macfuse/release/macfuse/LICENSE.txt>.

No Paragon code, activation bypass, local disk data, developer credentials or machine-specific cleanup backups are part of this repository.
