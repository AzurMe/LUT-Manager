#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
elif [[ -x "$HOME/flutter/bin/flutter" ]]; then
  FLUTTER_BIN="$HOME/flutter/bin/flutter"
else
  echo "Flutter was not found in PATH or at $HOME/flutter/bin/flutter."
  echo "Install Flutter first, or add it to PATH, then run this script again."
  exit 1
fi

echo "== LUT Manager macOS test runner =="
echo "Project: $ROOT_DIR"
echo "Flutter: $FLUTTER_BIN"
echo

echo "== Flutter version =="
"$FLUTTER_BIN" --version
echo

TEMP_BUILD_REAL="/private/tmp/lut_manager_flutter_build"
TEMP_BUILD_LINK="$ROOT_DIR/.lut_manager_build"

# Documents/iCloud locations can add provenance xattrs that break codesign.
# Build through a project-local symlink that points at /private/tmp instead.
restore_flutter_build_dir() {
  "$FLUTTER_BIN" config --build-dir=build >/dev/null 2>&1 || true
}

trap restore_flutter_build_dir EXIT

echo "== Use temp build directory outside Documents =="
mkdir -p "$TEMP_BUILD_REAL"
ln -sfn "$TEMP_BUILD_REAL" "$TEMP_BUILD_LINK"
/usr/bin/xattr -cr "$TEMP_BUILD_REAL" 2>/dev/null || true
"$FLUTTER_BIN" config --build-dir=.lut_manager_build >/dev/null
echo "Build output: $TEMP_BUILD_REAL"
echo

echo "== Enable macOS desktop support =="
"$FLUTTER_BIN" config --enable-macos-desktop
echo

echo "== Get dependencies =="
"$FLUTTER_BIN" pub get
echo

echo "== Static analysis =="
"$FLUTTER_BIN" analyze
echo

echo "== Tests =="
"$FLUTTER_BIN" test
echo

echo "== Clear macOS extended attributes =="
for target in \
  "$ROOT_DIR/lib" \
  "$ROOT_DIR/macos" \
  "$ROOT_DIR/pubspec.yaml" \
  "$ROOT_DIR/build/macos" \
  "$TEMP_BUILD_REAL"; do
  if [[ -e "$target" ]]; then
    /usr/bin/xattr -cr "$target" 2>/dev/null || true
  fi
done
echo

echo "== Launch LUT Manager on macOS =="
set +e
"$FLUTTER_BIN" run -d macos
RUN_STATUS=$?
set -e

if [[ $RUN_STATUS -ne 0 ]]; then
  echo
  echo "== Retry after clearing temp build extended attributes =="
  /usr/bin/xattr -cr "$ROOT_DIR/build/macos" 2>/dev/null || true
  /usr/bin/xattr -cr "$TEMP_BUILD_REAL" 2>/dev/null || true
  "$FLUTTER_BIN" run -d macos
else
  exit "$RUN_STATUS"
fi
