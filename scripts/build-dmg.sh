#!/bin/zsh

set -eu

ROOT_DIR=${0:A:h:h}
APP_PATH=${1:-}
OUTPUT_DIR=${2:-}

if [[ -z "$APP_PATH" || -z "$OUTPUT_DIR" ]]; then
  print -u2 -- "usage: $0 /path/to/Deadlock Runner.app /path/to/output-directory"
  exit 2
fi

if [[ ! -d "$APP_PATH/Contents" ]]; then
  print -u2 -- "app bundle is invalid: $APP_PATH"
  exit 2
fi

if [[ "$OUTPUT_DIR" == / || "$OUTPUT_DIR" == "$APP_PATH" ]]; then
  print -u2 -- "refusing unsafe output directory: $OUTPUT_DIR"
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
STAGING="$OUTPUT_DIR/.dmg-staging"
DMG="$OUTPUT_DIR/Deadlock-Runner-macOS.dmg"
CHECKSUM="$DMG.sha256"
DMG_TEMP="$OUTPUT_DIR/Deadlock-Runner-macOS.tmp.dmg"
HDIUTIL_BIN=${DEADLOCK_RUNNER_HDIUTIL:-hdiutil}

rm -rf "$STAGING"
rm -f "$DMG" "$CHECKSUM" "$DMG_TEMP" "$DMG.tmp" "$DMG.tmp.dmg"
mkdir -p "$STAGING"

rsync -aE "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT_DIR/INSTALL.txt" "$STAGING/INSTALL.txt"

if [[ ${DEADLOCK_RUNNER_TEST_MODE:-0} == 1 ]]; then
  tar -cf "$DMG" -C "$STAGING" .
else
  "$HDIUTIL_BIN" create \
    -volname 'Deadlock Runner' \
    -srcfolder "$STAGING" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_TEMP"
  mv -f "$DMG_TEMP" "$DMG"
  rm -rf "$STAGING"
fi

(
  cd "$OUTPUT_DIR"
  shasum -a 256 "${DMG:t}" > "${CHECKSUM:t}"
)

print -- "$DMG"
print -- "$CHECKSUM"
