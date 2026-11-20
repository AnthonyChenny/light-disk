#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
[ "$(uname -m)" = arm64 ] || { echo 'This Beta build supports Apple Silicon only.' >&2; exit 69; }
[ -f /usr/local/include/fuse/fuse.h ] || { echo 'Install official macFUSE 5.5.0 first (including developer headers).' >&2; exit 69; }
TASK_BUILD="${1:-$PROJECT_ROOT/.build/release}"
mkdir -p "$TASK_BUILD"
TASK_BUILD="$(cd "$TASK_BUILD" && pwd)"
python3 scripts/check-repository.py
bash Packaging/build-engine.sh "$TASK_BUILD/engine"
swift build -c release --scratch-path "$TASK_BUILD/swift"
SWIFT_BIN="$(swift build -c release --scratch-path "$TASK_BUILD/swift" --show-bin-path)"
"$SWIFT_BIN/QingPanPolicyTests"
VERSION="$(tr -d '\n' < VERSION)"
python3 Packaging/build.py --binaries "$SWIFT_BIN" \
  --engine-source "$TASK_BUILD/engine/ntfs-3g-2026.9.28" \
  --work "$TASK_BUILD/package" --output "$PROJECT_ROOT/dist/$VERSION"
python3 scripts/prepare-release.py
