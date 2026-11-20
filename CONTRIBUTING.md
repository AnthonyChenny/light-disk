# Contributing / 贡献指南

🌐 中文与 English

欢迎报告问题、完善文档和提交小范围修复。先读 [中文构建指南](docs/BUILD.zh-CN.md) / [English build guide](docs/BUILD.en.md)。界面当前为中文，新增文档请同步更新两种语言。

- 新的文件系统行为或特权接口应先讨论边界。不要移除 UUID、外接物理设备或代码签名校验。
- 测试使用可丢弃磁盘镜像；没有明确授权不要对真实用户盘写入或强制卸载。
- 不提交密码、证书、Token、完整设备序列号、系统隐私数据库、用户文件或本机备份。
- 修改自写代码沿用 MIT；修改 NTFS-3G 时更新 GPL 补丁、修改日期与对应源文件声明，保留上游版权。
- 运行 `swift build -c release --scratch-path .build/swift`、策略测试及 `python3 scripts/check-repository.py`。与磁盘相关的变化需说明额外镜像验证。
- PR 写清触发条件、最终行为、验证范围和已知限制；不要把单台机器成功描述为通用兼容。

Contributions are welcome as focused PRs. Keep Chinese/English docs aligned. Discuss changes to privileged interfaces first; retain identity, external-device and signature checks. Use disposable images and do not force operations on real user disks. Keep credentials and personal data out of issues and commits. Original-code changes remain MIT; upstream engine changes retain upstream licenses and require updated patch notices. Run the build, policy tests and repository checker, and describe meaningful integration testing in your PR.
