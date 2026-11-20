import Foundation
import QingPanCore

enum DiskPresentation {
    static func inventory(includeImages: Bool) throws -> [DiskVolume] {
        // Query only external partitions. Walking every internal disk first delayed
        // both refreshes and ejects, and triggered unnecessary raw-device checks.
        let list = try Command.plist("/usr/sbin/diskutil", ["list", "-plist", "external"])
        let ids = (list["AllDisks"] as? [String] ?? []).filter {
            $0.range(of: "\\Adisk[0-9]+s[0-9]+(?:s[0-9]+)?\\z", options: .regularExpression) != nil
        }
        let records = ids.compactMap { try? Command.plist("/usr/sbin/diskutil", ["info", "-plist", $0]) }
        return DiskInventory.normalize(records: records, includeImages: includeImages).filter {
            // A user data volume merely named EFI should remain visible.
            $0.raw["Content"] != "EFI"
        }
    }

    static func physicalDisk(_ disk: DiskVolume) -> String {
        // A managed FSKit volume keeps the original physical partition identity.
        if let parent = disk.raw["ParentWholeDisk"] { return parent }
        guard let range = disk.id.range(of: "\\Adisk[0-9]+", options: .regularExpression) else { return disk.id }
        return String(disk.id[range])
    }
}
