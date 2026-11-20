#!/bin/sh
set -eu
if [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo '请通过轻盘设置授权卸载。' >&2
    exit 77
fi
if /sbin/mount | /usr/bin/grep -F ' on /Volumes/轻盘-' >/dev/null; then
    echo '请先在 Finder 安全推出轻盘挂载的 NTFS 磁盘，再卸载组件。' >&2
    exit 75
fi
/bin/launchctl bootout system/local.qingpan.helper 2>/dev/null || true
/bin/rm -f /Library/LaunchDaemons/local.qingpan.helper.plist
/bin/rm -f /Library/PrivilegedHelperTools/local.qingpan.helper
/bin/rm -rf '/Library/Application Support/QingPan'
/usr/sbin/pkgutil --forget local.qingpan.components >/dev/null 2>&1 || true
echo '已卸载轻盘组件，保留 macFUSE。'
