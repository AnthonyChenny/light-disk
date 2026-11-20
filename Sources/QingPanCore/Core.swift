import Foundation
import Darwin

public enum Product {
    public static let service = "local.qingpan.helper"
    public static let support = "/Library/Application Support/QingPan"
    public static let engine = support + "/Engine/bin/ntfs-3g"
    public static let probe = support + "/Engine/bin/ntfs-3g.probe"
    public static let requirement = support + "/client.requirement"
    public static let fuse = "/Library/Filesystems/macfuse.fs"
}

public enum SignaturePolicy {
    public static func requirement(hash: String) -> String? {
        guard hash.range(of: "\\A[0-9a-f]{40}\\z", options: .regularExpression) != nil else { return nil }
        return "cdhash H\"" + hash + "\""
    }
}

@objc public protocol HelperProtocol {
    func perform(_ request: Data, reply: @escaping (Data) -> Void)
}

public struct HelperRequest: Codable {
    public let action: String
    public let disk: String
    public let expectedUUID: String
    public init(action: String, disk: String = "", expectedUUID: String = "") {
        self.action = action; self.disk = disk; self.expectedUUID = expectedUUID
    }
}
public struct HelperResponse: Codable {
    public let success: Bool
    public let message: String
    public let mountPoint: String?
    public init(_ success: Bool, _ message: String, mountPoint: String? = nil) {
        self.success = success; self.message = message; self.mountPoint = mountPoint
    }
}

public struct CommandResult {
    public let status: Int32
    public let data: Data
    public var text: String { String(data: data, encoding: .utf8) ?? "" }
}

public enum Command {
    // Use a temporary file, not a pipe: a full stderr pipe must never deadlock a disk operation.
    public static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 20) throws -> CommandResult {
        let location = FileManager.default.temporaryDirectory.appendingPathComponent("qingpan-" + UUID().uuidString)
        guard FileManager.default.createFile(atPath: location.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw Failure("无法创建操作日志")
        }
        defer { try? FileManager.default.removeItem(at: location) }
        let file = try FileHandle(forWritingTo: location)
        defer { try? file.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8"]
        process.standardOutput = file; process.standardError = file
        let completed = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completed.signal() }
        try process.run()
        if completed.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if completed.wait(timeout: .now() + 2) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            throw Failure("操作超时，未强制卸载磁盘。请检查磁盘状态后重试。")
        }
        let data = try Data(contentsOf: location)
        return CommandResult(status: process.terminationStatus, data: data)
    }
    public static func plist(_ path: String, _ args: [String]) throws -> [String: Any] {
        let result = try run(path, args)
        guard result.status == 0, let value = try PropertyListSerialization.propertyList(from: result.data, format: nil) as? [String: Any] else {
            throw Failure("读取磁盘信息失败：" + String(result.text.prefix(300)))
        }
        return value
    }
}

public struct Failure: Error, LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public enum ProbeFailure {
    public static func message(status: Int32, details: String) -> String {
        if details.localizedCaseInsensitiveContains("Operation not permitted") || status == 19 {
            return "系统拒绝访问磁盘。请在系统设置 → 隐私与安全 → 完全磁盘访问权限中，允许 local.qingpan.helper。"
        }
        switch status {
        case 14:
            return "NTFS 检查返回代码 14，可能是 Windows 休眠或访问被拒绝。请核对系统磁盘访问权限；若权限已允许，请回 Windows 完整关机并安全弹出硬盘。\n" + String(details.suffix(500))
        case 15:
            return "此 NTFS 分卷未正常卸载，已保留只读。请接回 Windows，关闭该盘文件后使用“安全删除硬件”弹出，再接回 Mac。若仍提示异常，请先在 Windows 检查磁盘。"
        case 16:
            return "磁盘正被其他程序使用，未强制卸载。请关闭相关文件后重试。"
        default:
            return "NTFS 未通过可写检查（代码 \(status)），已停止写入接管。\n" + String(details.suffix(500))
        }
    }
}

public struct DiskVolume: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let format: String
    public let uuid: String
    public let mountPoint: String
    public let size: Int64
    public let free: Int64
    public let readOnly: Bool
    public let isInternal: Bool
    public let isImage: Bool
    public let whole: Bool
    public let writableMedia: Bool
    public let raw: [String: String]
    public var isNTFS: Bool { format.lowercased().contains("ntfs") }
    public var isMounted: Bool { !mountPoint.isEmpty }
    public var isManagedMount: Bool { DiskInventory.sourceIdentifier(mountPoint: mountPoint) == id }
    public var usedFraction: Double { size > 0 ? min(1, max(0, Double(size - free) / Double(size))) : 0 }
    public var fingerprint: String { uuid.isEmpty ? id + ":" + String(size) + ":" + name : uuid }
    public init(info: [String: Any]) {
        id = info["DeviceIdentifier"] as? String ?? ""
        name = info["VolumeName"] as? String ?? "未命名磁盘"
        format = info["FilesystemType"] as? String ?? ""
        // Partition UUID remains available while a volume is unmounted.
        uuid = info["DiskUUID"] as? String ?? info["VolumeUUID"] as? String ?? ""
        mountPoint = info["MountPoint"] as? String ?? ""
        size = (info["TotalSize"] as? NSNumber)?.int64Value ?? 0
        free = (info["FreeSpace"] as? NSNumber)?.int64Value ?? (info["VolumeFreeSpace"] as? NSNumber)?.int64Value ?? 0
        if let writable = info["WritableVolume"] as? Bool { readOnly = !writable }
        else { readOnly = info["ReadOnlyVolume"] as? Bool ?? true }
        if let writable = info["WritableMedia"] as? Bool { writableMedia = writable }
        else { writableMedia = !(info["ReadOnlyMedia"] as? Bool ?? true) }
        isInternal = info["Internal"] as? Bool ?? true
        isImage = info["BusProtocol"] as? String == "Disk Image"
        whole = info["WholeDisk"] as? Bool ?? info["Whole"] as? Bool ?? true
        raw = info.reduce(into: [:]) { if let s = $1.value as? String { $0[$1.key] = s } }
    }
    public static func == (a: DiskVolume, b: DiskVolume) -> Bool {
        a.id == b.id && a.mountPoint == b.mountPoint && a.readOnly == b.readOnly && a.free == b.free && a.name == b.name && a.format == b.format
    }
}

public enum DiskPolicy {
    public static func validIdentifier(_ disk: String) -> Bool {
        disk.range(of: "\\Adisk[0-9]+s[0-9]+\\z", options: .regularExpression) != nil
    }
    public static func validate(_ volume: DiskVolume, expectedUUID: String) throws {
        guard validIdentifier(volume.id), !volume.whole, !volume.isInternal, !volume.isImage else {
            throw Failure("仅支持外接物理硬盘上的分卷，不会接管内置磁盘或磁盘镜像。")
        }
        guard volume.isNTFS else { throw Failure("此分卷不是 NTFS；请使用 macOS 原生挂载。") }
        guard volume.writableMedia else { throw Failure("设备处于硬件只读状态。") }
        guard !expectedUUID.isEmpty, volume.uuid == expectedUUID else { throw Failure("磁盘身份已变化，请刷新后重试。") }
        guard volume.format.lowercased() == "ntfs" else {
            throw Failure("此分卷由其他 NTFS 驱动管理，请先在原驱动中停用自动挂载。")
        }
    }
    public static func mountArguments(device: String, path: String, uid: uid_t, gid: gid_t, label: String = "NTFS") -> [String] {
        // Do not let a disk label inject additional comma-separated mount options.
        let safeLabel = String(label.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .replacingOccurrences(of: ",", with: "，").replacingOccurrences(of: "\\", with: "／").replacingOccurrences(of: "=", with: "＝")
        return [device, path, "-o", "backend=fskit,local,norecover,windows_names,uid=\(uid),gid=\(gid),umask=022,nodev,nosuid,no_detach,volname=\(safeLabel)"]
    }
}

public enum DiskInventory {
    public static func info(_ disk: String) throws -> DiskVolume {
        DiskVolume(info: try Command.plist("/usr/sbin/diskutil", ["info", "-plist", disk]))
    }
    public static func externalVolumes(includeImages: Bool = false) throws -> [DiskVolume] {
        let list = try Command.plist("/usr/sbin/diskutil", ["list", "-plist"])
        let ids = list["AllDisks"] as? [String] ?? []
        let records = ids.compactMap { try? Command.plist("/usr/sbin/diskutil", ["info", "-plist", $0]) }
        return normalize(records: records, includeImages: includeImages)
    }
    public static func sourceIdentifier(mountPoint: String) -> String? {
        let regex = try! NSRegularExpression(pattern: "\\A/Volumes/轻盘-(disk[0-9]+s[0-9]+)-[0-9A-Fa-f]{8}\\z")
        guard let match = regex.firstMatch(in: mountPoint, range: NSRange(mountPoint.startIndex..., in: mountPoint)),
              let range = Range(match.range(at: 1), in: mountPoint) else { return nil }
        return String(mountPoint[range])
    }
    public static func normalize(records: [[String: Any]], includeImages: Bool = false) -> [DiskVolume] {
        var managed: [String: [String: Any]] = [:]
        for record in records {
            guard let path = record["MountPoint"] as? String, let source = sourceIdentifier(mountPoint: path),
                  let original = records.first(where: { $0["DeviceIdentifier"] as? String == source }) else { continue }
            var merged = original
            for key in ["MountPoint", "WritableVolume", "ReadOnlyVolume", "FreeSpace", "VolumeFreeSpace", "TotalSize"] {
                if let value = record[key] { merged[key] = value }
            }
            merged["FilesystemType"] = "ntfs"
            merged["QingPanMountedDevice"] = record["DeviceIdentifier"]
            managed[source] = merged
        }
        let filtered = records.compactMap { record -> DiskVolume? in
            if let path = record["MountPoint"] as? String, let source = sourceIdentifier(mountPoint: path), managed[source] != nil { return nil }
            let id = record["DeviceIdentifier"] as? String ?? ""
            return DiskVolume(info: managed[id] ?? record)
        }
        return filtered.filter {
            !$0.isInternal && !$0.whole && (includeImages || !$0.isImage) && !$0.format.isEmpty && !$0.id.isEmpty
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
