import SwiftUI
import AppKit
import QingPanCore

private let accent = Color(red: 0.12, green: 0.40, blue: 0.94)
// Use the property wrapper explicitly; CLT's SDK lacks the newer State macro plugin.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct MenuPanel: View {
    @ObservedObject var model: AppModel
    let showSettings: () -> Void
    var maximumHeight: CGFloat = 760
    private var listHeight: CGFloat {
        let rows = min(4, model.volumes.count)
        let desired = CGFloat(rows * 124 + max(0, rows - 1) * 10 + 50)
        let chrome: CGFloat = model.componentReady ? 124 : 228
        return min(desired, max(140, maximumHeight - chrome))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill").font(.system(size: 21)).foregroundStyle(accent)
                    .frame(width: 38, height: 38).background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text("轻盘").font(.system(size: 17, weight: .semibold))
                    Text(model.notice ?? "连接硬盘，继续工作").font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).help(model.notice ?? "连接硬盘，继续工作")
                }
                Spacer()
                Button { model.refresh(); model.checkComponents() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13)).frame(width: 28, height: 28)
                }.buttonStyle(.plain).help("刷新磁盘与组件状态").disabled(model.refreshing)
            }.padding(20)
            Divider().opacity(0.5)
            if model.volumes.isEmpty { emptyState } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("外接磁盘").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            Spacer(); Text("\(model.volumes.count) 个数据分卷").font(.system(size: 11)).foregroundStyle(.tertiary)
                        }.padding(.horizontal, 2).padding(.top, 3)
                        ForEach(model.volumes) { disk in DiskCard(disk: disk, model: model) }
                    }.padding(16)
                }.frame(height: listHeight)
            }
            if !model.componentReady {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "puzzlepiece.extension").foregroundStyle(accent).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("开启 NTFS 写入").font(.system(size: 12, weight: .semibold))
                        Text("首次使用需要安装读写组件").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("设置", action: showSettings).controlSize(.small)
                }.padding(13).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10)).padding([.horizontal, .bottom], 16)
            }
            Divider().opacity(0.5)
            HStack(spacing: 6) {
                Circle().fill(model.componentReady ? Color.green : Color.orange).frame(width: 5, height: 5)
                Text(model.componentReady ? "读写组件已安装" : "读写组件待设置").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(action: showSettings) { Image(systemName: "gearshape").frame(width: 25, height: 25) }.buttonStyle(.plain).help("设置")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power").frame(width: 25, height: 25) }.buttonStyle(.plain).help("退出轻盘（已挂载磁盘保持连接）")
            }.padding(.horizontal, 17).padding(.vertical, 9)
        }
        .frame(width: 380).background(Color(nsColor: .windowBackgroundColor))
        .alert("操作提示", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "externaldrive.badge.plus").font(.system(size: 40, weight: .light)).foregroundStyle(.tertiary)
                .frame(width: 90, height: 80)
            Text("等待连接硬盘").font(.system(size: 15, weight: .medium))
            Text("插入后会自动出现在这里\n文件复制与粘贴，直接在 Finder 中完成")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) { ForEach(["NTFS", "exFAT", "APFS"], id: \.self) { format in
                Text(format).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 9).padding(.vertical, 4).background(Color.primary.opacity(0.045), in: Capsule())
            }}.padding(.top, 3)
        }.frame(maxWidth: .infinity).padding(.vertical, 28)
    }
}

struct DiskCard: View {
    let disk: DiskVolume
    @ObservedObject var model: AppModel
    @ViewState private var showingDetails = false
    var working: Bool { model.busy.contains(disk.id) }
    var ejecting: Bool { model.ejecting.contains(disk.id) }
    var status: String { !disk.isMounted ? "未挂载" : disk.readOnly ? "只读" : "可读写" }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill").font(.system(size: 24)).foregroundStyle(disk.isNTFS ? accent : .secondary)
                    .frame(width: 36, height: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(disk.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(disk.format.uppercased()).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        Text("·").foregroundStyle(.tertiary)
                        if working { ProgressView().controlSize(.mini) }
                        Text(ejecting ? "正在推出…" : working ? "正在启用写入…" : status).font(.system(size: 10))
                            .foregroundStyle(working ? Color.secondary : disk.readOnly ? Color.orange : Color.green)
                    }
                }
                Spacer(minLength: 0)
                Button { showingDetails.toggle() } label: {
                    Label("详情", systemImage: "info.circle").font(.system(size: 11)).padding(.vertical, 4)
                }.buttonStyle(.plain).foregroundStyle(.secondary).help("查看磁盘信息")
                    .popover(isPresented: $showingDetails) { DiskDetails(disk: disk, message: model.messages[disk.id]) }
            }
            if disk.isMounted {
                VStack(spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.07))
                            Capsule().fill(disk.usedFraction > 0.9 ? Color.orange : accent.opacity(0.8)).frame(width: geometry.size.width * disk.usedFraction)
                        }
                    }.frame(height: 4)
                    HStack {
                        Text("\(ByteCountFormatter.string(fromByteCount: disk.free, countStyle: .decimal)) 可用")
                        Spacer(); Text("共 \(ByteCountFormatter.string(fromByteCount: disk.size, countStyle: .decimal))")
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            if let message = model.messages[disk.id] {
                Text(message).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    .help("\(message)\n可在“详情”中查看完整信息")
            }
            HStack(spacing: 8) {
                Button { model.open(disk) } label: { Label("在 Finder 打开", systemImage: "folder").frame(maxWidth: .infinity) }
                    .disabled(!disk.isMounted || working)
                if disk.isNTFS && (disk.readOnly || !disk.isMounted) {
                    Button("启用写入") { model.mount(disk) }.disabled(!model.componentReady || working)
                }
                Button { model.eject(disk) } label: { Label(ejecting ? "推出中" : "推出", systemImage: "eject") }
                    .help("安全推出整块硬盘，完成后可以拔线").disabled(working)
            }.controlSize(.small).frame(minHeight: 22)
        }
        .padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.045)))
    }
}

private struct DiskDetails: View {
    let disk: DiskVolume
    let message: String?
    @ViewState private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("磁盘详情").font(.system(size: 14, weight: .semibold))
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                item("名称", disk.name)
                item("格式", disk.format.uppercased())
                item("设备", disk.id)
                if disk.isMounted { item("位置", disk.mountPoint) }
            }.font(.system(size: 11))
            if let message {
                Divider()
                Text(message).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(copied ? "已复制" : "复制磁盘信息") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(disk.name)\n\(disk.id)\n\(disk.format)\n\(disk.uuid)\n\(disk.mountPoint)\n\(message ?? "")", forType: .string)
                copied = true
            }.controlSize(.small)
        }.padding(18).frame(width: 310)
    }
    private func item(_ title: String, _ value: String) -> some View {
        GridRow(alignment: .top) {
            Text(title).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsPanel: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                HStack(spacing: 13) {
                    Image(systemName: "externaldrive.fill").font(.system(size: 30)).foregroundStyle(accent)
                        .frame(width: 57, height: 57).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("轻盘设置").font(.system(size: 22, weight: .semibold))
                        Text("保持简单，让硬盘随时可用。").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                group("通用") {
                    setting("登录后自动启动", subtitle: "启动后仅显示菜单栏图标", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                    Divider().padding(.leading, 14)
                    setting("自动启用 NTFS 写入", subtitle: "连接硬盘时自动检查并挂载", isOn: $model.autoMount)
                    Divider().padding(.leading, 14)
                    setting("挂载后打开 Finder", subtitle: "读写就绪后打开硬盘目录", isOn: $model.openAfterMount)
                    Divider().padding(.leading, 14)
                    setting("连接与读写通知", subtitle: "仅在连接或状态变化时提醒", isOn: $model.notify)
                }
                group("读写组件") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 7) {
                            Image(systemName: model.componentReady ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(model.componentReady ? Color.green : Color.orange)
                            Text(model.componentReady ? "组件已安装" : "需要完成首次设置").font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        Text(model.componentMessage).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button(model.componentReady ? "重新安装组件…" : "安装读写组件…") { model.installComponents() }
                            Button("检查状态") { model.checkComponents(); model.refresh() }
                            Button("扩展设置") { model.openExtensionSettings() }
                        }.controlSize(.small)
                        Text("通过 FSKit 运行，无需降低启动安全性。首次安装需系统授权。").font(.system(size: 10)).foregroundStyle(.tertiary)
                    }.padding(15)
                }
                if model.hasParagon {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle").foregroundStyle(Color.orange)
                        Text("检测到 Paragon NTFS 组件。请先在原软件中停用自动挂载，再手动启用轻盘写入，避免两个驱动接管同一块盘。")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.padding(13).background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("本地运行 · 无需账号").font(.system(size: 11, weight: .medium))
                        Text("NTFS-3G 2026.9.28 · macFUSE FSKit\n开源 Beta · 临时签名，尚未通过 Apple 公证").font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
                    }
                    Spacer()
                    Menu("更多") {
                        Button("查看安装与卸载说明") { if let url = Bundle.main.url(forResource: "使用说明", withExtension: "txt") { NSWorkspace.shared.open(url) } }
                        Button("第三方许可") { if let url = Bundle.main.url(forResource: "第三方许可", withExtension: "txt") { NSWorkspace.shared.open(url) } }
                        Button("卸载轻盘组件…") { AppDelegate.shared?.showUninstall() }
                    }.menuStyle(.borderlessButton).frame(width: 60)
                }
            }.padding(28)
        }
        .frame(width: 510, height: 630).background(Color(nsColor: .windowBackgroundColor)).tint(accent)
        .onAppear { model.checkComponents() }
        .alert("操作提示", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).padding(.leading, 3)
            VStack(spacing: 0, content: content).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.04)))
        }
    }
    private func setting(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }.padding(.horizontal, 15).padding(.vertical, 13).frame(maxWidth: .infinity)
    }
}
