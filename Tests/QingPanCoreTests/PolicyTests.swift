import Foundation
import QingPanCore
import Security

var checks = 0
func expect(_ value: Bool, _ message: String) {
    checks += 1
    if !value { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
func throwsError(_ action: () throws -> Void) -> Bool { do { try action(); return false } catch { return true } }
func volume(_ changes: [String: Any] = [:]) -> DiskVolume {
    var info: [String: Any] = ["DeviceIdentifier": "disk7s1", "VolumeName": "测试盘", "FilesystemType": "ntfs", "VolumeUUID": "test-uuid", "Internal": false, "Whole": false, "ReadOnlyMedia": false, "ReadOnlyVolume": true, "TotalSize": 1_000_000]
    info.merge(changes) { _, new in new }; return DiskVolume(info: info)
}
expect(DiskPolicy.validIdentifier("disk12s3"), "valid partition")
for value in ["disk0", "/dev/disk3s1", "disk3s1;id", "disk3s1\n", "../disk3s1", "disk3s1s1", "-disk3s1"] {
    expect(!DiskPolicy.validIdentifier(value), "reject identifier \(value.debugDescription)")
}
for changes: [String: Any] in [["Internal": true], ["Whole": true], ["ReadOnlyMedia": true], ["BusProtocol": "Disk Image"], ["FilesystemType": "apfs"], ["FilesystemType": "ufsd_NTFS"]] {
    expect(throwsError { try DiskPolicy.validate(volume(changes), expectedUUID: "test-uuid") }, "reject protected/foreign volume")
}
expect(throwsError { try DiskPolicy.validate(DiskVolume(info: [:]), expectedUUID: "test-uuid") }, "unknown devices fail closed")
expect(!throwsError { try DiskPolicy.validate(volume(), expectedUUID: "test-uuid") }, "allow external NTFS")
expect(throwsError { try DiskPolicy.validate(volume(), expectedUUID: "another-volume") }, "reject replugged identity")
expect(throwsError { try DiskPolicy.validate(volume(), expectedUUID: "") }, "reject missing identity")
let arguments = DiskPolicy.mountArguments(device: "/dev/disk7s1", path: "/Volumes/名字 含空格", uid: 501, gid: 20)
expect(arguments[1] == "/Volumes/名字 含空格", "preserve path argument")
expect(arguments[3].contains("backend=fskit"), "explicit FSKit")
expect(arguments[3].contains("norecover"), "disable recovery writes")
expect(!arguments[3].contains("remove_hiberfile"), "preserve hibernation file")
expect(arguments[3].contains("nodev,nosuid"), "safe mount flags")
let large = try Command.run("/usr/bin/seq", ["1", "50000"], timeout: 5)
expect(large.status == 0 && large.data.count > 100_000, "large subprocess output cannot deadlock")
let start = Date()
expect(throwsError { _ = try Command.run("/bin/sleep", ["4"], timeout: 0.1) }, "timeout exits")
expect(Date().timeIntervalSince(start) < 3, "timeout bounded")
let encoded = try JSONEncoder().encode(HelperRequest(action: "mount", disk: "disk7s1", expectedUUID: "真实-UUID"))
let decoded = try JSONDecoder().decode(HelperRequest.self, from: encoded)
expect(decoded.expectedUUID == "真实-UUID", "request identity round trip")
let modern = DiskVolume(info: ["DeviceIdentifier": "disk6s1", "FilesystemType": "exfat", "Internal": false, "WholeDisk": false, "WritableVolume": true, "WritableMedia": true, "FreeSpace": 63_094_784, "TotalSize": 131_928_064, "DiskUUID": "partition-id", "VolumeUUID": "volume-id"])
expect(!modern.whole && !modern.readOnly && modern.writableMedia, "macOS 27 diskutil schema")
expect(modern.free == 63_094_784, "macOS 27 free-space key")
expect(modern.uuid == "partition-id", "partition identity survives unmount")
let requirement = SignaturePolicy.requirement(hash: String(repeating: "a", count: 40))!
var parsed: SecRequirement?
expect(SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess, "OS accepts pinned signing requirement syntax")
expect(SignaturePolicy.requirement(hash: "a\" or true") == nil, "reject signing requirement injection")
let physical: [String: Any] = ["DeviceIdentifier": "disk7s1", "FilesystemType": "ntfs", "VolumeName": "实际硬盘", "DiskUUID": "physical-partition", "Internal": false, "WholeDisk": false, "WritableMedia": true, "WritableVolume": false, "BusProtocol": "USB"]
let synthetic: [String: Any] = ["DeviceIdentifier": "disk8s1", "MountPoint": "/Volumes/轻盘-disk7s1-ABCDEF12", "VolumeName": "macFUSE Volume", "DiskUUID": "synthetic-partition", "Internal": false, "WholeDisk": false, "WritableVolume": true, "FreeSpace": 100, "TotalSize": 200, "BusProtocol": "Disk Image"]
let unified = DiskInventory.normalize(records: [physical, synthetic])
expect(unified.count == 1 && unified[0].id == "disk7s1", "unify FSKit synthetic and physical device")
expect(unified[0].isManagedMount && !unified[0].readOnly && unified[0].free == 100, "use real FSKit mount state")
expect(unified[0].uuid == "physical-partition" && unified[0].name == "实际硬盘", "preserve physical identity and label")
expect(DiskInventory.sourceIdentifier(mountPoint: "/Volumes/轻盘-disk7s1-ABCDEF12/subdir") == nil, "reject mount path suffix")
let injection = DiskPolicy.mountArguments(device: "/dev/disk7s1", path: "/Volumes/x", uid: 501, gid: 20, label: "盘,remove_hiberfile=1")
expect(!injection[3].contains(",remove_hiberfile="), "disk label cannot inject mount options")
expect(ProbeFailure.message(status: 14, details: "Failed to open /dev/disk7s1: Operation not permitted").contains("系统拒绝"), "EPERM is not mislabeled as confirmed hibernation")
expect(ProbeFailure.message(status: 15, details: "").contains("未正常卸载"), "unclean volume remains read only with actionable message")
expect(ProbeFailure.message(status: 13, details: "Input/output error").contains("Input/output error"), "preserve concrete diagnostic reason")
print("PASS: \(checks) policy, identity and subprocess checks")
if CommandLine.arguments.contains("--inventory") {
    let disks = try DiskInventory.externalVolumes(includeImages: true)
    for disk in disks { print("INVENTORY: \(disk.id) \(disk.name) \(disk.format) mounted=\(disk.isMounted) readonly=\(disk.readOnly) free=\(disk.free)") }
    if CommandLine.arguments.contains("--expect-exfat-fixture") {
        expect(disks.contains { $0.name == "QPTEST" && $0.format == "exfat" && $0.isMounted && !$0.readOnly && $0.free > 0 }, "detect real mounted exFAT fixture")
        print("PASS: real exFAT inventory and read/write state")
    }
}
