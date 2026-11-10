#!/bin/zsh

set -u

PREFIX=${WINEPREFIX:-}
[[ -n "$PREFIX" && -d "$PREFIX" ]] || exit 0

local link target
while IFS= read -r -d '' link; do
  target=$(readlink "$link" 2>/dev/null || true)
  if [[ "$target" == /Users/* ]]; then
    rm -f "$link"
  fi
done < <(find "$PREFIX" -type l -print0 2>/dev/null)
