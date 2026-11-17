#!/bin/zsh

set -euo pipefail

ROOT_DIR=${0:A:h:h}
RUNTIME_APP=${1:-}
OUTPUT_DIR=${2:-}

if [[ -z "$RUNTIME_APP" || -z "$OUTPUT_DIR" ]]; then
  print -u2 -- "usage: $0 /path/to/Megabonk Runner.app /path/to/output-directory"
  exit 2
fi

RUNTIME_APP=${RUNTIME_APP:A}
OUTPUT_DIR=${OUTPUT_DIR:A}
[[ -d "$RUNTIME_APP/Contents/SharedSupport/prefix" ]] || {
  print -u2 -- "runtime app has no SharedSupport/prefix: $RUNTIME_APP"
  exit 2
}

mkdir -p "$OUTPUT_DIR/.runtime"
rm -rf "$OUTPUT_DIR/.runtime/Megabonk Runner.app"
ditto "$RUNTIME_APP" "$OUTPUT_DIR/.runtime/Megabonk Runner.app"
PATCHER="$OUTPUT_DIR/.runtime/Megabonk Runner.app/Contents/Resources/Scripts/DeadlockFixes"
mkdir -p "${PATCHER:h}"
cp "$ROOT_DIR/scripts/apply-deadlock-fixes.sh" "$PATCHER"
chmod +x "$PATCHER"
WINEPREFIX="$OUTPUT_DIR/.runtime/Megabonk Runner.app/Contents/SharedSupport/prefix" \
  DEADLOCK_ROOT="$OUTPUT_DIR/.runtime/Megabonk Runner.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Deadlock" \
  zsh "$PATCHER"

(
  cd "$ROOT_DIR/tools/native-launcher"
  swift build -c release --product WineSupervisor
)
BIN_DIR=$(cd "$ROOT_DIR/tools/native-launcher" && swift build -c release --show-bin-path)
SUPERVISOR="$BIN_DIR/WineSupervisor"
[[ -x "$SUPERVISOR" ]] || { print -u2 -- "native supervisor was not built"; exit 1; }

build_bundle() {
  local name=$1
  local mode=$2
  local bundle="$OUTPUT_DIR/$name.app"
  rm -rf "$bundle"
  mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
  local icon_file="$name.icns"
  if [[ "$mode" == "steam" && -f "/Applications/Steam.app/Contents/Resources/Steam.icns" ]]; then
    cp "/Applications/Steam.app/Contents/Resources/Steam.icns" "$bundle/Contents/Resources/$icon_file"
  else
    cp "$RUNTIME_APP/Contents/Resources/Configure.icns" "$bundle/Contents/Resources/$icon_file"
  fi
  cp "$SUPERVISOR" "$bundle/Contents/MacOS/WineSupervisor"
  chmod +x "$bundle/Contents/MacOS/WineSupervisor"
  plutil -create xml1 "$bundle/Contents/Info.plist"
  plutil -insert CFBundleIconFile -string "$icon_file" "$bundle/Contents/Info.plist"
  plutil -insert CFBundleIconName -string "${icon_file:r}" "$bundle/Contents/Info.plist"
  plutil -insert CFBundleName -string "$name" "$bundle/Contents/Info.plist"
  plutil -insert CFBundleDisplayName -string "$name" "$bundle/Contents/Info.plist"
  plutil -insert CFBundleIdentifier -string "io.github.desmondwebb.native-$mode" "$bundle/Contents/Info.plist"
  plutil -insert CFBundlePackageType -string APPL "$bundle/Contents/Info.plist"
  plutil -insert CFBundleExecutable -string WineSupervisor "$bundle/Contents/Info.plist"
  plutil -insert CFBundleShortVersionString -string 1.0.0 "$bundle/Contents/Info.plist"
  plutil -insert CFBundleVersion -string 1 "$bundle/Contents/Info.plist"
  plutil -insert LSMinimumSystemVersion -string 14.0 "$bundle/Contents/Info.plist"
  plutil -insert LSMultipleInstancesProhibited -bool true "$bundle/Contents/Info.plist"
  plutil -insert LSUIElement -bool false "$bundle/Contents/Info.plist"
  plutil -insert WineLauncherMode -string "$mode" "$bundle/Contents/Info.plist"
  codesign --force --deep --sign - "$bundle" >/dev/null
}

build_bundle Steam steam
build_bundle Deadlock deadlock
build_bundle Megabonk megabonk

print -- "$OUTPUT_DIR/Steam.app"
print -- "$OUTPUT_DIR/Deadlock.app"
print -- "$OUTPUT_DIR/Megabonk.app"
