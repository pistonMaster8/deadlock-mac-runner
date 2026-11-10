#!/bin/zsh

set -u

TARGET=${1:-}
if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
  print -u2 -- "usage: $0 /path/to/Deadlock Runner.app"
  exit 2
fi

typeset -a findings

while IFS= read -r -d '' file; do
  findings+=("forbidden Steam installation data: ${file#$TARGET/}")
done < <(find "$TARGET" -path '*/Program Files (x86)/Steam/*' -print0 2>/dev/null)

while IFS= read -r -d '' file; do
  findings+=("forbidden game/account artifact: ${file#$TARGET/}")
done < <(find "$TARGET" \( \
  -iname 'deadlock.exe' -o \
  -iname 'loginusers.vdf' -o \
  -iname 'localconfig.vdf' -o \
  -iname 'ssfn*' \
\) -print0 2>/dev/null)

local sensitive_file scan_status
typeset -a sensitive_files
sensitive_files=("$TARGET"/**/*.(vdf|reg)(N.))
for sensitive_file in "${sensitive_files[@]}"; do
  grep -Eiq '(SharedAuth|apptickets|CloudKey|AccountName|PersonaName)' "$sensitive_file" 2>/dev/null
  scan_status=$?
  case $scan_status in
    0) findings+=("sensitive Steam marker: ${sensitive_file#$TARGET/}") ;;
    1) ;;
    *) findings+=("privacy scan could not read: ${sensitive_file#$TARGET/}") ;;
  esac
done

local link target
while IFS= read -r -d '' link; do
  target=$(readlink "$link" 2>/dev/null || true)
  if [[ "$target" == /Users/* ]]; then
    findings+=("machine-specific symlink: ${link#$TARGET/} -> $target")
  fi
done < <(find "$TARGET" -type l -print0 2>/dev/null)

if (( ${#findings} > 0 )); then
  print -u2 -- 'Privacy scan failed:'
  local finding
  for finding in "${findings[@]}"; do
    print -u2 -- "- $finding"
  done
  exit 1
fi

print -- "Privacy scan passed: $TARGET"
