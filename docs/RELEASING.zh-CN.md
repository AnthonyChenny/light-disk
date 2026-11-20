# GitHub Beta 发布指南

🌐 **中文** · [English](RELEASING.en.md) · [README](../README.md)

本仓库已关联 `https://github.com/AnthonyChenny/light-disk.git`。以下步骤会公开代码与下载文件；本地准备脚本不会自动 commit、push、创建标签或上传。整理完成不代表远端已发布。

## 首次准备

1. 检查 README 截图、许可证、验证范围及 `git status`。不要把原开发目录的 outputs、work、磁盘备份或日志复制进仓库。
2. 在 GitHub 确认仓库设为 Public，启用 Issues；建议在 Settings → Security 启用 Private vulnerability reporting。SECURITY.md 本身不会替你打开该设置。
3. 查看 `git diff`、`git diff --cached` 和新增文件，再提交源码。证书、密钥和 Token 不进入仓库。

```sh
git add .
git commit -m "Prepare light-disk 0.1.3-beta.1"
```

## 构建与对应源码

按 [构建指南](BUILD.zh-CN.md) 生成 Beta，或使用已准备的 `dist/0.1.3-beta.1/`。如果本次只提交文档且应用源码、VERSION、资源、打包脚本和依赖均未变化，可在最终 commit 后运行以下命令重新记录源码版本：

```sh
python3 scripts/prepare-release.py
cd dist/0.1.3-beta.1
shasum -a 256 -c SHA256SUMS.txt
cd ../..
```

**若应用/引擎/资源/版本/打包代码改变，先完整重新构建，再生成源码包；不能把旧二进制配上新代码。** `release-manifest.json` 记录提交与源码树状态。首次本地整理的资产可能记录 null 或 dirty；对外发布前应在源码干净并已提交的状态重新准备，检查 manifest。

## 标签和推送

确认没有同名远端标签，使用不可变的 Beta 标签：

```sh
git tag -a v0.1.3-beta.1 -m "light-disk / 轻盘 0.1.3-beta.1"
git push origin main
git push origin v0.1.3-beta.1
```

后续改动使用新的 Beta 版本和标签，不覆盖用户已下载文件。维护者需在 VERSION、文档当前版本与发布说明同步变更；App 构建号也应递增。

## 创建预发布 Release

GitHub → Releases → Draft a new release，选择对应 Beta 标签，标题 `light-disk / 轻盘 0.1.3-beta.1`，粘贴[中英文发布说明](releases/v0.1.3-beta.1.md)。勾选 **This is a pre-release**，先存草稿并核对后再公开。

**普通用户的附件只上传 DMG：** `light-disk-0.1.3-beta.1-arm64.dmg`。macFUSE 从官方独立安装，下载链接和完整先后顺序必须保留在 Release 正文。校验值也写在正文，不再向用户提供重复的 `.pkg`、手动源码 ZIP、JSON 或说明附件。

GitHub 会自动提供标签对应的 `Source code (zip)` 和 `Source code (tar.gz)`，无法逐项隐藏。保留版本标签中的 NTFS-3G 原始归档、补丁、许可证和构建脚本，并从发布正文链接该归档，以继续提供 GPL 对应源码。不要只链接未修改的上游源码，也不要在发布后删除或重写该标签。

`prepare-release.py` 生成的其他文件是本地审计记录，仍留在 `dist/`；不必全部上传。已发布包不因 README 更新而重打包或替换。若改动实际程序、资源或包装内容，使用新版本。

GitHub CLI 草稿示例：

```sh
gh release create v0.1.3-beta.1 \
  --repo AnthonyChenny/light-disk --verify-tag --draft --prerelease \
  --title "light-disk / 轻盘 0.1.3-beta.1" \
  --notes-file docs/releases/v0.1.3-beta.1.md \
  dist/0.1.3-beta.1/light-disk-0.1.3-beta.1-arm64.dmg
```

发布前确认源码可从同一个 Release 的标签归档下载、对应二进制；确认 macFUSE 下载链接、安装顺序、临时签名与测试范围写清楚。源代码归档保留不是要求普通用户下载。完整验证范围见 [TESTING.md](TESTING.md)。

参考：[GitHub 官方 Release 文档](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)。
