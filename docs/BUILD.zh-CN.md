# 从源码构建

🌐 **中文** · [English](BUILD.en.md) · [README](../README.md)

## 环境

Apple Silicon Mac，Swift 5.9+ 语言工具链以及支持 macOS 15.4+ 的 SDK；本机使用 Swift 6.4 / macOS 27 SDK。扩展设置按钮使用通用的“登录项与扩展”入口，以便兼容较早的 SDK。15.4+ 是运行目标，其他运行版本尚未实测。

安装 Xcode 或相应 Command Line Tools，**先手动安装官方 macFUSE 5.5.0（含开发头文件）**。检查 `/usr/local/include/fuse/fuse.h`、`/usr/local/lib/libfuse.dylib`。引擎构建需要 `autoconf`、`automake`、`libtool`、`gettext`；这些是构建依赖，不打入用户包。若使用 Homebrew，可执行 `brew install autoconf automake libtool gettext`；需让 `autopoint` 等工具在 PATH 中。

## 快速检查（不挂载磁盘）

在仓库根目录执行：

```sh
python3 scripts/check-repository.py
swift build -c release --scratch-path .build/swift
.build/swift/release/QingPanPolicyTests
```

CI 也只编译及执行策略检查，不会安装特权服务或写入真实磁盘。CI runner 的 SDK 变化可能影响构建；不能把 CI 成功视为实盘测试通过。

## 完整 Beta 构建

```sh
bash scripts/build-beta.sh
```

需要全新的 `.build/release/engine` 目录。脚本拒绝覆盖已有引擎源码；再次完整构建请传一个新的构建目录，例如：

```sh
bash scripts/build-beta.sh "$PWD/.build/release-second"
```

步骤包括校验原始 NTFS-3G 源码归档、应用带日期说明的 Darwin 补丁、编译引擎和 Swift 项目、运行策略检查、生成安装包和 DMG、验证 DMG、生成对应源码 ZIP 和 SHA-256。

输出位于 `dist/$(cat VERSION)/`，由 .gitignore 排除。DMG 只提供完整 `安装轻盘.pkg`、中英文说明和许可；不附带 macFUSE，也不提供易导致漏装 helper 的单独 App 拖拽入口。

macOS 包版本使用 VERSION 的数字部分，App 显示完整 Beta 字符串。当前构建为 ad-hoc 临时签名，安装器未使用 Developer ID Installer 签名。正式公证分发需另行实现证书、Hardened Runtime、时间戳、公证与票据流程；当前脚本不声称完成这些步骤。

## 手动打包

已完成引擎和 Swift 构建后：

```sh
python3 Packaging/build.py \
  --binaries "$PWD/.build/release/swift/release" \
  --engine-source "$PWD/.build/release/engine/ntfs-3g-2026.9.28" \
  --work "$PWD/.build/release/package" \
  --output "$PWD/dist/$(cat VERSION)"
python3 scripts/prepare-release.py
```

Swift 包的实际二进制目录可用 `swift build -c release --scratch-path .build/release/swift --show-bin-path` 查询。不要混用不同构建的 App 和 helper：打包器先签 helper，把其 CDHash 写入 App，再签 App，并将 App 要求写入 root-owned 配置。

## 架构与源码许可

App → 受签名校验的 XPC helper → 校验外接 NTFS 与 UUID、打开唯一目标句柄 → 用户 bootstrap 会话、永久降权 → NTFS-3G → macFUSE FSKit → Finder。

辅助服务不提供任意命令执行或任意路径挂载接口。`norecover`、外接物理盘限制、UUID 和签名检查必须保留。NTFS 源码与补丁见 [第三方声明](../THIRD_PARTY_NOTICES.md)。
