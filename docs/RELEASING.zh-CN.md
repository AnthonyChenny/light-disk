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

GitHub → Releases → Draft a new release，选择 `v0.1.3-beta.1`，标题 `light-disk / 轻盘 0.1.3-beta.1`，粘贴 [中英文发布说明](releases/v0.1.3-beta.1.md)。**勾选 This is a pre-release**，先保存 Draft，核对资产后再发布。

推荐上传同一 dist 目录的六个文件：

- `light-disk-0.1.3-beta.1-arm64.dmg`：用户下载入口，内含完整安装器。
- `light-disk-0.1.3-beta.1-installer.pkg`：同一安装器的独立下载；GitHub 资产使用英文文件名，DMG 内仍为“安装轻盘.pkg”。
- `light-disk-0.1.3-beta.1-source.zip`：匹配的全部应用源码、引擎原始归档、补丁与构建脚本。
- `SHA256SUMS.txt`：上述文件及下面两项的校验值。
- `RELEASE_NOTES.md`：该版中英文说明。
- `release-manifest.json`：签名状态、版本、来源提交和依赖边界。

GitHub 自动生成的 Source code 压缩包也应对应同一标签，但建议继续附上已核对的 source.zip。不要上传 macFUSE 官方安装包、个人证书、本机配置、硬盘诊断或历史残留备份。

已安装 GitHub CLI 并通过本人授权登录后，也可创建**草稿**：

```sh
gh release create v0.1.3-beta.1 \
  --repo AnthonyChenny/light-disk --verify-tag --draft --prerelease \
  --title "light-disk / 轻盘 0.1.3-beta.1" \
  --notes-file docs/releases/v0.1.3-beta.1.md \
  dist/0.1.3-beta.1/*.dmg dist/0.1.3-beta.1/*.pkg \
  dist/0.1.3-beta.1/*-source.zip dist/0.1.3-beta.1/SHA256SUMS.txt \
  dist/0.1.3-beta.1/RELEASE_NOTES.md dist/0.1.3-beta.1/release-manifest.json
```

## 发布前最后核对

确认 Beta/未公证状态清晰、安装顺序完整、两种文档一致、对应源码能重建、macFUSE 不捆绑；在干净 Mac 试安装仍为重要的待完成验收。当前没有 Developer ID 和公证，不宣传为无拦截的正式版。验证事实见 [TESTING.md](TESTING.md)。

参考：[GitHub 官方 Release 文档](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)。
