#!/bin/zsh

set -eu

ROOT_DIR=${0:A:h:h}
SOURCE_APP=${1:-}
OUTPUT_DIR=${2:-}

if [[ -z "$SOURCE_APP" || -z "$OUTPUT_DIR" ]]; then
  print -u2 -- "usage: $0 /path/to/Source.app /path/to/output-directory"
  exit 2
fi

SOURCE_APP=${SOURCE_APP:A}
OUTPUT_DIR=${OUTPUT_DIR:A}

if [[ ! -d "$SOURCE_APP/Contents" ]]; then
  print -u2 -- "source app is invalid: $SOURCE_APP"
  exit 2
fi

if [[ "$OUTPUT_DIR" == / || "$OUTPUT_DIR" == "$SOURCE_APP" ]]; then
  print -u2 -- "refusing unsafe output directory: $OUTPUT_DIR"
  exit 2
fi

DEST_APP="$OUTPUT_DIR/Deadlock Runner.app"
rm -rf "$DEST_APP"
mkdir -p "$OUTPUT_DIR"

rsync -a \
  --exclude '/Contents/SharedSupport/prefix' \
  --exclude '/Contents/SharedSupport/wine-*-backup-*' \
  --exclude '/Contents/SharedSupport/Logs' \
  --exclude '/Contents/Logs' \
  "$SOURCE_APP/" "$DEST_APP/"

PREFIX="$DEST_APP/Contents/SharedSupport/prefix"
mkdir -p "$PREFIX"

if [[ ${DEADLOCK_RUNNER_TEST_MODE:-0} == 1 ]]; then
  mkdir -p "$PREFIX/drive_c/windows/system32"
else
  WINE_ROOT="$DEST_APP/Contents/SharedSupport/wine"
  WINE_BIN="$WINE_ROOT/bin/wine"
  if [[ ! -x "$WINE_BIN" ]]; then
    print -u2 -- "bundled Wine executable is missing: $WINE_BIN"
    exit 1
  fi

  FRAMEWORKS="$DEST_APP/Contents/Frameworks"
  DYLD_PATH="$WINE_ROOT/lib:$WINE_ROOT/lib64:$FRAMEWORKS:$FRAMEWORKS/GStreamer.framework/Libraries:/opt/wine/lib:/usr/lib:/usr/libexec:/usr/lib/system"
  env \
    USER=runner \
    USERNAME=runner \
    WINEPREFIX="$PREFIX" \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    DYLD_FALLBACK_LIBRARY_PATH="$DYLD_PATH" \
    "$WINE_BIN" wineboot -u

  env \
    WINEPREFIX="$PREFIX" \
    DYLD_FALLBACK_LIBRARY_PATH="$DYLD_PATH" \
    "$WINE_ROOT/bin/wineserver" -w

  rm -f "$PREFIX/dosdevices/y:"
fi

SETUP_DIR="$PREFIX/drive_c/DeadlockSetup"
mkdir -p "$SETUP_DIR"
cp "$ROOT_DIR/app/bootstrap.cmd" "$SETUP_DIR/bootstrap.cmd"

if [[ -n ${STEAM_SETUP_SOURCE:-} ]]; then
  cp "$STEAM_SETUP_SOURCE" "$SETUP_DIR/SteamSetup.exe"
else
  curl --fail --location --retry 3 \
    --output "$SETUP_DIR/SteamSetup.exe" \
    'https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe'
fi

cp "$ROOT_DIR/scripts/apply-deadlock-fixes.sh" \
  "$DEST_APP/Contents/Resources/Scripts/DeadlockFixes"
cp "$ROOT_DIR/app/StartupScript" \
  "$DEST_APP/Contents/Resources/Scripts/StartupScript"
chmod +x \
  "$DEST_APP/Contents/Resources/Scripts/DeadlockFixes" \
  "$DEST_APP/Contents/Resources/Scripts/StartupScript"

PLIST="$DEST_APP/Contents/Info.plist"
set_plist_string() {
  local key=$1
  local value=$2
  if plutil -replace "$key" -string "$value" "$PLIST" 2>/dev/null; then
    return 0
  fi
  plutil -insert "$key" -string "$value" "$PLIST"
}

set_plist_integer() {
  local key=$1
  local value=$2
  if plutil -replace "$key" -integer "$value" "$PLIST" 2>/dev/null; then
    return 0
  fi
  plutil -insert "$key" -integer "$value" "$PLIST"
}

set_plist_string CFBundleName 'Deadlock Runner'
set_plist_string CFBundleIdentifier 'io.github.desmondwebb.deadlock-runner'
set_plist_string CFBundleShortVersionString '1.0.0'
set_plist_string CFBundleVersion '1.0.0'
set_plist_string LSMinimumSystemVersion '14.6'
set_plist_string 'Program Name and Path' '/windows/system32/cmd.exe'
set_plist_string 'Program Flags' '/c C:\DeadlockSetup\bootstrap.cmd'
set_plist_integer D9VK 1
set_plist_integer DXVK 0
set_plist_integer D3DMETAL 0
set_plist_integer WINEESYNC 1
set_plist_integer WINEMSYNC 1
set_plist_integer 'Try To Use GPU Info' 0

if [[ ${DEADLOCK_RUNNER_TEST_MODE:-0} != 1 ]]; then
  codesign --force --deep --sign - "$DEST_APP"
fi

"$ROOT_DIR/scripts/scan-private-data.sh" "$DEST_APP"
print -- "$DEST_APP"
