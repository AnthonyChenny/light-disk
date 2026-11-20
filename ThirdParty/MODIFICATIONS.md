# NTFS-3G modifications

Modification date: 2026-11-20. Modifier: light-disk contributors.

Base: NTFS-3G 2026.9.28, unchanged upstream archive in this directory. All modifications are in `Packaging/ntfs-fd-device.patch` under the upstream files' license terms.

- `src/ntfs-3g_common.c`: preserve strictly numeric `/dev/fd/N` paths on Darwin instead of canonicalizing them incorrectly.
- `src/ntfs-3g.c`: handle an already-authorized inherited descriptor with user-space FSKit rather than Linux fuseblk privilege handling.
- `libntfs-3g/unix_io.c`: validate the inherited descriptor mode and `dup` it, avoiding a second device-node permission check after permanent privilege dropping.

The opening helper validates the physical external NTFS partition and UUID before dropping privileges. These changes do not make the engine setuid, change device-node permissions, add users to operator, enable kernel fallback, clear hibernation data or force filesystem repairs.
