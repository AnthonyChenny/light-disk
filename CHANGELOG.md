# Changelog / 更新记录

## 0.1.3-beta.1 — 2026-11-20

首次整理为公开开源 Beta / First public-source Beta preparation.

- 项目统一命名 light-disk / 轻盘；中英文 README、安装、构建和发布指南。
- GitHub 问题模板、CI、第三方声明、明确的许可证边界和对应源码发布工具。
- macFUSE 改为用户独立从官网下载；DMG 不附带 App 拖拽入口或 macFUSE 安装器，统一使用完整轻盘安装包。
- 保留 0.1.2 界面及 0.1.1 NTFS 会话修正；公开版仍是 ad-hoc 签名、未公证。

Public packaging and bilingual docs; macFUSE is installed separately. The DMG contains the complete light-disk installer and instructions. Existing disk behavior is retained. This is an ad-hoc signed, unnotarized pre-release.

## 0.1.2 — local testing / 本地测试

明确的详情与推出按钮；约四卡片高度；推出即时状态与旧扫描防回填；隐藏真正的 EFI 分区；修复安装器重复标题。

Clear details/eject labels, four-card sizing, immediate eject feedback, stale-scan protection, hidden EFI system partitions, corrected installer title.

## 0.1.1 — local testing / 本地测试

通过用户会话运行 FSKit，继承单一授权磁盘句柄；完善权限和脏卷错误提示。两块 NTFS 实盘完成双向摘要校验。

User-session FSKit and authorized descriptor inheritance; improved permission/dirty-volume messages. Two physical NTFS drives passed round-trip hashes.
