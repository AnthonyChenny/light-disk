import Foundation
import QingPanCore
import Darwin

final class Service: NSObject, HelperProtocol {
    let uid: uid_t
    let gid: gid_t
    static let operations = DispatchQueue(label: "local.qingpan.disk-operations")
    static var engines: [String: Process] = [:]
    init(uid: uid_t, gid: gid_t) { self.uid = uid; self.gid = gid }
    func perform(_ data: Data, reply: @escaping (Data) -> Void) {
        Service.operations.async {
            let response: HelperResponse
            do {
                let request = try JSONDecoder().decode(HelperRequest.self, from: data)
                response = try self.execute(request)
            } catch { response = HelperResponse(false, error.localizedDescription) }
            reply((try? JSONEncoder().encode(response)) ?? Data())
        }
    }
    private func execute(_ request: HelperRequest) throws -> HelperResponse {
        if request.action == "status" {
            guard FileManager.default.isExecutableFile(atPath: Product.engine), FileManager.default.fileExists(atPath: Product.fuse) else {
                throw Failure("读写组件未完整安装。请重新运行组件安装包。")
            }
            return HelperResponse(true, "读写组件已就绪 · FSKit")
        }
        guard ["mount", "eject"].contains(request.action), DiskPolicy.validIdentifier(request.disk) else {
            throw Failure("不支持此操作。")
        }
        var volume = try DiskInventory.info(request.disk)
        try DiskPolicy.validate(volume, expectedUUID: request.expectedUUID)
        if request.action == "eject" {
            guard let managed = try DiskInventory.externalVolumes().first(where: { $0.id == request.disk && $0.isManagedMount }) else {
                throw Failure("没有找到由轻盘挂载的对应分卷，请刷新状态。")
            }
            let unmount = try Command.run("/sbin/umount", [managed.mountPoint])
            guard unmount.status == 0 else { throw Failure("磁盘正在使用中，未强制卸载。请关闭相关文件后再推出。") }
            let eject = try Command.run("/usr/sbin/diskutil", ["eject", "/dev/" + request.disk])
            guard eject.status == 0 else { throw Failure("NTFS 分卷已卸载，但整块设备未能推出，可能有其他分卷正在使用。") }
            return HelperResponse(true, "可以安全拔出硬盘。")
        }
        if let existing = try DiskInventory.externalVolumes().first(where: { $0.id == request.disk && $0.isManagedMount && !$0.readOnly }) {
            return HelperResponse(true, "磁盘已经可以读写。", mountPoint: existing.mountPoint)
        }
        if volume.isMounted && !volume.readOnly { return HelperResponse(true, "磁盘已经可以读写。", mountPoint: volume.mountPoint) }
        let device = "/dev/" + volume.id
        let wasMounted = volume.isMounted
        if wasMounted {
            let result = try Command.run("/usr/sbin/diskutil", ["unmount", device])
            guard result.status == 0 else { throw Failure("磁盘正在使用中，未卸载。请关闭正在访问它的文件后重试。\n" + String(result.text.prefix(250))) }
        }
        var newMountPoint: String?
        do {
            // Re-resolve after unmount; disk identifiers can be reused after physical disconnect.
            volume = try DiskInventory.info(request.disk)
            try DiskPolicy.validate(volume, expectedUUID: request.expectedUUID)
            guard !volume.isMounted else { throw Failure("另一程序已重新挂载此盘，请停用原 NTFS 驱动的自动挂载。") }
            let check = try Command.run(Product.probe, ["--readwrite", device])
            guard check.status == 0 else {
                throw Failure(ProbeFailure.message(status: check.status, details: check.text))
            }
            let parent = "/Volumes/轻盘-" + volume.id + "-" + UUID().uuidString.prefix(8)
            try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755, .ownerAccountID: uid, .groupOwnerAccountID: gid])
            newMountPoint = parent
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["asuser", String(uid), "/Library/PrivilegedHelperTools/" + Product.service,
                                 "--mount-worker", String(uid), String(gid), volume.id, volume.uuid, parent]
            process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8"]
            let log = FileManager.default.temporaryDirectory.appendingPathComponent("qingpan-mount-" + UUID().uuidString)
            FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
            let output = try FileHandle(forWritingTo: log)
            process.standardOutput = output; process.standardError = output
            defer { try? output.close(); try? FileManager.default.removeItem(at: log) }
            try process.run()
            var actual: DiskVolume?
            for _ in 0..<60 {
                if let current = try? DiskInventory.info(parent), current.mountPoint == parent, current.isMounted, !current.readOnly {
                    actual = current; break
                }
                if !process.isRunning { break }
                Thread.sleep(forTimeInterval: 0.3)
            }
            if actual == nil, let current = try? DiskInventory.info(parent), current.mountPoint == parent, !current.readOnly { actual = current }
            guard let actual else {
                if process.isRunning {
                    process.terminate()
                    for _ in 0..<20 where process.isRunning { Thread.sleep(forTimeInterval: 0.1) }
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
                let details = String(data: (try? Data(contentsOf: log)) ?? Data(), encoding: .utf8) ?? ""
                throw Failure("未确认可读写挂载，已停止本次尝试。请查看下方原因；若提示扩展不可用，请检查 macFUSE 扩展授权。\n" + String(details.suffix(750)))
            }
            Service.engines[volume.id] = process
            let sourceID = volume.id
            process.terminationHandler = { _ in
                Service.operations.async { Service.engines.removeValue(forKey: sourceID); _ = rmdir(parent) }
            }
            return HelperResponse(true, "已启用读写，可以在 Finder 中复制文件。", mountPoint: actual.mountPoint)
        } catch {
            if let path = newMountPoint { _ = rmdir(path) }
            // Restore only this same volume, only if it is still unmounted. Never force an unmount.
            if wasMounted, let current = try? DiskInventory.info(request.disk), current.uuid == request.expectedUUID, !current.isMounted {
                _ = try? Command.run("/usr/sbin/diskutil", ["mount", "readOnly", device])
            }
            throw error
        }
    }
}

final class Delegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard geteuid() == 0,
              let attributes = try? FileManager.default.attributesOfItem(atPath: Product.requirement),
              (attributes[.ownerAccountID] as? NSNumber)?.intValue == 0,
              ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777) & 0o022 == 0,
              attributes[.type] as? FileAttributeType == .typeRegular,
              let requirement = try? String(contentsOfFile: Product.requirement, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              requirement.range(of: "\\Acdhash H\"[0-9a-f]{40}\"\\z", options: .regularExpression) != nil,
              let console = try? FileManager.default.attributesOfItem(atPath: "/dev/console"),
              let consoleUID = console[.ownerAccountID] as? NSNumber,
              consoleUID.uint32Value >= 501, connection.effectiveUserIdentifier == consoleUID.uint32Value else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = Service(uid: connection.effectiveUserIdentifier, gid: connection.effectiveGroupIdentifier)
        connection.resume()
        return true
    }
}

@main enum HelperMain {
    static func main() {
        guard geteuid() == 0 else { fputs("Run through the installed launchd service.\n", stderr); exit(77) }
        if CommandLine.arguments.dropFirst().first == "--mount-worker" {
            do { try MountWorker.run() }
            catch { fputs(error.localizedDescription + "\n", stderr); exit(77) }
        }
        let delegate = Delegate()
        let listener = NSXPCListener(machServiceName: Product.service)
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
        withExtendedLifetime(delegate) {}
    }
}
