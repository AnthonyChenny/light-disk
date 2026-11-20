import AppKit
import SwiftUI
import DiskArbitration
import ServiceManagement
import UserNotifications
import UniformTypeIdentifiers
import QingPanCore

final class MountClient {
    func perform(_ request: HelperRequest, completion: @escaping (HelperResponse) -> Void) {
        guard let hash = Bundle.main.object(forInfoDictionaryKey: "QingPanHelperHash") as? String,
              let requirement = SignaturePolicy.requirement(hash: hash) else {
            completion(HelperResponse(false, "组件签名信息缺失，请重新安装轻盘。")); return
        }
        let connection = NSXPCConnection(machServiceName: Product.service, options: .privileged)
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.resume()
        let lock = NSLock()
        var finished = false
        func finish(_ response: HelperResponse) {
            lock.lock(); guard !finished else { lock.unlock(); return }; finished = true; lock.unlock()
            connection.invalidate()
            DispatchQueue.main.async { completion(response) }
        }
        connection.interruptionHandler = { finish(HelperResponse(false, "读写服务已断开，请稍后重试。")) }
        connection.invalidationHandler = { finish(HelperResponse(false, "无法连接读写组件，请运行组件安装包。")) }
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish(HelperResponse(false, "读写服务尚未安装或未获授权，请完成组件安装。")) }) as? HelperProtocol,
              let data = try? JSONEncoder().encode(request) else {
            finish(HelperResponse(false, "无法发起磁盘操作。")); return
        }
        proxy.perform(data) { data in
            finish((try? JSONDecoder().decode(HelperResponse.self, from: data)) ?? HelperResponse(false, "读写服务返回了无效结果。"))
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 65) { finish(HelperResponse(false, "磁盘操作等待超时，请刷新状态。")) }
    }
}

final class AppModel: ObservableObject {
    @Published var volumes: [DiskVolume] = []
    @Published var refreshing = false
    @Published var busy: Set<String> = []
    @Published var ejecting: Set<String> = []
    @Published var notice: String?
    @Published var messages: [String: String] = [:]
    @Published var error: String?
    @Published var componentReady = false
    @Published var componentMessage = "正在检查读写组件…"
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var installing = false
    @Published var autoMount = UserDefaults.standard.object(forKey: "autoMount") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoMount, forKey: "autoMount"); if autoMount { mountEligible() } }
    }
    @Published var openAfterMount = UserDefaults.standard.bool(forKey: "openAfterMount") {
        didSet { UserDefaults.standard.set(openAfterMount, forKey: "openAfterMount") }
    }
    @Published var notify = UserDefaults.standard.bool(forKey: "notify") {
        didSet {
            UserDefaults.standard.set(notify, forKey: "notify")
            if notify { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
        }
    }
    var hasParagon: Bool { FileManager.default.fileExists(atPath: "/Library/Filesystems/ufsd_NTFS.fs") }
    private let worker = DispatchQueue(label: "local.qingpan.inventory", qos: .utility)
    private let operations = DispatchQueue(label: "local.qingpan.operations", qos: .userInitiated)
    private let client = MountClient()
    private var session: DASession?
    private var debounce: DispatchWorkItem?
    private var attempted: Set<String> = []
    private var initialized = false
    private var needsRefresh = false
    private var inventoryRevision = 0

    func start() {
        session = DASessionCreate(kCFAllocatorDefault)
        if let session {
            let context = Unmanaged.passUnretained(self).toOpaque()
            DARegisterDiskAppearedCallback(session, nil, { _, context in
                guard let context else { return }; Unmanaged<AppModel>.fromOpaque(context).takeUnretainedValue().scheduleRefresh()
            }, context)
            DARegisterDiskDisappearedCallback(session, nil, { _, context in
                guard let context else { return }; Unmanaged<AppModel>.fromOpaque(context).takeUnretainedValue().scheduleRefresh()
            }, context)
            DARegisterDiskDescriptionChangedCallback(session, nil, nil, { _, _, context in
                guard let context else { return }; Unmanaged<AppModel>.fromOpaque(context).takeUnretainedValue().scheduleRefresh()
            }, context)
            DASessionSetDispatchQueue(session, .main)
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh(); self?.checkComponents() }
        checkComponents(); refresh()
    }
    func scheduleRefresh() {
        debounce?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refresh() }
        debounce = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }
    func refresh() {
        guard !refreshing else { needsRefresh = true; return }; refreshing = true
        let revision = inventoryRevision
        worker.async { [weak self] in
            let result = Result { try DiskPresentation.inventory(includeImages: CommandLine.arguments.contains("--test-images")) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshing = false
                // A scan begun before an eject must not restore a removed card.
                guard revision == self.inventoryRevision else { self.needsRefresh = false; self.scheduleRefresh(); return }
                switch result {
                case .success(let disks):
                    let old = Set(self.volumes.map(\.fingerprint))
                    self.volumes = disks
                    self.attempted.formIntersection(Set(disks.map(\.fingerprint)))
                    if disks.contains(where: { !old.contains($0.fingerprint) }) { self.notice = nil }
                    if self.initialized {
                        for disk in disks where !old.contains(disk.fingerprint) { self.sendNotification("已连接 \(disk.name)", disk.isNTFS ? "正在检查 NTFS 读写状态" : "可以在 Finder 中使用") }
                    }
                    self.initialized = true
                    self.mountEligible()
                case .failure(let error): self.error = error.localizedDescription
                }
                if self.needsRefresh { self.needsRefresh = false; self.scheduleRefresh() }
            }
        }
    }
    func checkComponents() {
        guard FileManager.default.isExecutableFile(atPath: Product.engine),
              FileManager.default.isExecutableFile(atPath: "/Library/PrivilegedHelperTools/" + Product.service) else {
            componentReady = false
            componentMessage = "首次使用需安装 NTFS 引擎与辅助服务。点击下方安装按钮，完成一次系统授权。"
            loginEnabled = SMAppService.mainApp.status == .enabled
            return
        }
        client.perform(HelperRequest(action: "status")) { [weak self] response in
            self?.componentReady = response.success
            self?.componentMessage = response.success ? "NTFS 引擎与辅助服务已安装。FSKit 授权会在挂载时核对；只有实际挂载为可读写后，磁盘才会显示成功。" : response.message
            self?.loginEnabled = SMAppService.mainApp.status == .enabled
            // FSClient only exposes modules visible to this application's identity.
            // A third-party module missing from its list is not proof it is disabled.
            if response.success { self?.mountEligible() }
        }
    }
    private func mountEligible() {
        guard autoMount, componentReady else { return }
        for disk in volumes where disk.isNTFS && (disk.readOnly || !disk.isMounted) && !attempted.contains(disk.fingerprint) && !busy.contains(disk.id) {
            // An existing driver needs a deliberate first manual operation, not an automatic takeover.
            if hasParagon { messages[disk.id] = "检测到其他 NTFS 驱动，请先停用其自动挂载"; continue }
            mount(disk)
        }
    }
    func mount(_ disk: DiskVolume) {
        guard !busy.contains(disk.id) else { return }
        notice = nil
        attempted.insert(disk.fingerprint); busy.insert(disk.id); messages[disk.id] = "正在启用写入…"
        client.perform(HelperRequest(action: "mount", disk: disk.id, expectedUUID: disk.uuid)) { [weak self] response in
            guard let self else { return }; self.busy.remove(disk.id)
            self.messages[disk.id] = response.success ? nil : response.message
            if response.success {
                if self.openAfterMount, let path = response.mountPoint { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
                self.sendNotification("\(disk.name) 已可读写", "可以在 Finder 中双向复制文件")
            } else { self.error = response.message }
            self.refresh()
        }
    }
    func open(_ disk: DiskVolume) {
        guard disk.isMounted else { error = "磁盘尚未挂载。"; return }
        NSWorkspace.shared.open(URL(fileURLWithPath: disk.mountPoint))
    }
    func eject(_ disk: DiskVolume) {
        let parent = DiskPresentation.physicalDisk(disk)
        let related = volumes.filter { DiskPresentation.physicalDisk($0) == parent }
        let ids = Set(related.map(\.id))
        guard busy.isDisjoint(with: ids), !ids.isEmpty else { return }
        let identities = Dictionary(uniqueKeysWithValues: related.map { ($0.id, $0.fingerprint) })
        inventoryRevision += 1
        busy.formUnion(ids); ejecting.formUnion(ids); notice = nil
        for id in ids { messages[id] = nil }
        func complete(_ response: HelperResponse) {
            self.inventoryRevision += 1
            self.busy.subtract(ids); self.ejecting.subtract(ids)
            if response.success {
                self.volumes.removeAll { identities[$0.id] == $0.fingerprint }
                for id in ids { self.messages[id] = nil }
                self.notice = "已推出「\(disk.name)」，可以拔线"
            } else { self.error = response.message }
            self.refresh()
        }
        if disk.isManagedMount {
            client.perform(HelperRequest(action: "eject", disk: disk.id, expectedUUID: disk.uuid), completion: complete)
            return
        }
        operations.async {
            let result = Result { try Command.run("/usr/sbin/diskutil", ["eject", "/dev/" + disk.id]) }
            DispatchQueue.main.async {
                switch result {
                case .success(let output) where output.status == 0: complete(HelperResponse(true, "已安全推出"))
                case .success: complete(HelperResponse(false, "磁盘正在使用中，未推出。请关闭相关文件后重试。"))
                case .failure(let error): complete(HelperResponse(false, error.localizedDescription))
                }
            }
        }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { self.error = "无法修改登录启动：" + error.localizedDescription }
    }
    func installComponents() {
        let sibling = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("安装轻盘.pkg")
        if FileManager.default.fileExists(atPath: sibling.path) { NSWorkspace.shared.open(sibling); return }
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil) ?? []
        if let url = mounted.map({ $0.appendingPathComponent("安装轻盘.pkg") }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.open(url); return
        }
        let panel = NSOpenPanel()
        panel.title = "选择轻盘安装包"; panel.message = "请先打开轻盘 DMG，再选择其中的「安装轻盘.pkg」。"
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false; panel.allowedContentTypes = [.package]
        if panel.runModal() == .OK, let url = panel.url { NSWorkspace.shared.open(url) }
    }
    func openExtensionSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
    private func sendNotification(_ title: String, _ body: String) {
        guard notify else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
