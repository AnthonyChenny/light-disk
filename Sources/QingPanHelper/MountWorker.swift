import Foundation
import Darwin
import QingPanCore

// Called by the privileged service through launchctl asuser. The device is opened
// before dropping privileges; FSKit and its per-user extensions run as the console user.
enum MountWorker {
    static func run() throws -> Never {
        let args = CommandLine.arguments
        guard geteuid() == 0, args.count == 7,
              let uid = uid_t(args[2]), uid >= 501, let gid = gid_t(args[3]),
              DiskPolicy.validIdentifier(args[4]),
              DiskInventory.sourceIdentifier(mountPoint: args[6]) == args[4],
              let user = getpwuid(uid), user.pointee.pw_gid == gid else {
            throw Failure("挂载进程参数无效。")
        }
        let username = String(cString: user.pointee.pw_name)
        let userHome = String(cString: user.pointee.pw_dir)
        let console = try FileManager.default.attributesOfItem(atPath: "/dev/console")
        guard (console[.ownerAccountID] as? NSNumber)?.uint32Value == uid else {
            throw Failure("登录用户已变化，请重新打开轻盘。")
        }
        let volume = try DiskInventory.info(args[4])
        try DiskPolicy.validate(volume, expectedUUID: args[5])
        guard !volume.isMounted else { throw Failure("磁盘已被其他程序挂载。") }
        var mountStat = stat()
        guard lstat(args[6], &mountStat) == 0,
              mountStat.st_mode & S_IFMT == S_IFDIR, mountStat.st_uid == uid,
              try FileManager.default.contentsOfDirectory(atPath: args[6]).isEmpty else {
            throw Failure("挂载目录无效。")
        }
        let fd = open("/dev/" + volume.id, O_RDWR | O_NOFOLLOW)
        guard fd >= 0 else { throw Failure("无法打开指定分卷：" + String(cString: strerror(errno))) }
        var deviceStat = stat()
        guard fstat(fd, &deviceStat) == 0, deviceStat.st_mode & S_IFMT == S_IFBLK,
              fcntl(fd, F_SETFD, 0) == 0 else {
            close(fd); throw Failure("无效的磁盘设备句柄。")
        }
        // Revalidate the same partition after opening, before any engine can write.
        do { try DiskPolicy.validate(DiskInventory.info(args[4]), expectedUUID: args[5]) }
        catch { close(fd); throw error }
        var group = gid
        guard setgroups(1, &group) == 0, setgid(gid) == 0, setuid(uid) == 0,
              getuid() == uid, geteuid() == uid, getgid() == gid else {
            close(fd); throw Failure("无法切换到登录用户，已停止挂载。")
        }
        setenv("HOME", userHome, 1)
        setenv("USER", username, 1)
        setenv("LOGNAME", username, 1)
        let arguments = [Product.engine] + DiskPolicy.mountArguments(
            device: "/dev/fd/\(fd)", path: args[6], uid: uid, gid: gid, label: volume.name)
        var pointers = arguments.map { strdup($0) } + [nil]
        execv(Product.engine, &pointers)
        let message = String(cString: strerror(errno))
        close(fd)
        throw Failure("启动读写引擎失败：" + message)
    }
}
