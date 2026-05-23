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

echo "== Launch LUT Manager on macOS =="
"$FLUTTER_BIN" run -d macos
