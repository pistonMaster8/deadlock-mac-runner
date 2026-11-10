#!/bin/zsh

set -u

backup_once() {
  local file=$1
  local backup="$file.deadlock-runner.bak"
  [[ -e "$backup" ]] || cp -p "$file" "$backup"
}

install_if_changed() {
  local source_file=$1
  local replacement=$2

  if cmp -s "$source_file" "$replacement"; then
    rm -f "$replacement"
    return 0
  fi

  backup_once "$source_file"
  chmod "$(stat -f '%Lp' "$source_file")" "$replacement"
  touch -r "$source_file" "$replacement"
  mv -f "$replacement" "$source_file"
}

patch_with_sed() {
  local file=$1
  shift
  [[ -f "$file" ]] || return 0

  local temp_file
  temp_file=$(mktemp "$file.deadlock-runner.XXXXXX") || return 1
  sed -E "$@" "$file" > "$temp_file" || {
    rm -f "$temp_file"
    return 1
  }
  install_if_changed "$file" "$temp_file"
}

patch_boot_renderer() {
  local file=$1
  patch_with_sed "$file" \
    -e 's#^([[:space:]]*"DefaultRenderSystemOption"[[:space:]]+)"[^"]*"#\1"-dx11"#'
}

patch_controller_mapping() {
  local file=$1
  [[ -f "$file" ]] || return 0

  local temp_file
  temp_file=$(mktemp "$file.deadlock-runner.XXXXXX") || return 1

  awk '
    {
      line = $0
      if (line ~ /"revision"[[:space:]]+"112"/) {
        sub(/"112"/, "\"113\"", line)
      }
      print line
      if (!has_tab && line ~ /"binding"[[:space:]]+"game_action GameControls Ping, , "/) {
        indent = line
        sub(/"binding".*/, "", indent)
        print indent "\"binding\"\t\t\"key_press TAB, , \""
        inserted = 1
      }
    }
    /"binding"[[:space:]]+"key_press TAB, , "/ { has_tab = 1 }
  ' "$file" > "$temp_file" || {
    rm -f "$temp_file"
    return 1
  }

  if grep -Fq '"binding"' "$file" && grep -Fq 'key_press TAB, , ' "$file"; then
    # The file was already patched; remove any line inserted before the original TAB line.
    awk '
      /"binding"[[:space:]]+"key_press TAB, , "/ {
        if (seen_tab) next
        seen_tab = 1
      }
      { print }
    ' "$file" > "$temp_file"
    sed -E 's#^([[:space:]]*"revision"[[:space:]]+)"112"#\1"113"#' "$temp_file" > "$temp_file.revision"
    mv -f "$temp_file.revision" "$temp_file"
  fi

  install_if_changed "$file" "$temp_file"
}

patch_glyph_config() {
  local file=$1
  patch_with_sed "$file" \
    -e 's#^([[:space:]]*"steam_inputhandler_glyph_lock_mode"[[:space:]]+)"[^"]*"#\1"2"#'
}

patch_video_config() {
  local file=$1
  patch_with_sed "$file" \
    -e 's#^([[:space:]]*"VendorID"[[:space:]]+)"[^"]*"#\1"4203"#' \
    -e 's#^([[:space:]]*"DeviceID"[[:space:]]+)"[^"]*"#\1"0"#' \
    -e 's#^([[:space:]]*"setting.gpu_mem_level"[[:space:]]+)"[^"]*"#\1"3"#' \
    -e 's#^([[:space:]]*"setting.fullscreen"[[:space:]]+)"[^"]*"#\1"0"#' \
    -e 's#^([[:space:]]*"setting.nowindowborder"[[:space:]]+)"[^"]*"#\1"1"#'
}

main() {
  local prefix=${WINEPREFIX:-}
  [[ -n "$prefix" ]] || return 0

  local default_deadlock="$prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Deadlock"
  local deadlock_root=${DEADLOCK_ROOT:-$default_deadlock}
  local cfg_root="$deadlock_root/game/citadel/cfg"

  patch_boot_renderer "$cfg_root/boot.vcfg" || return 1
  patch_controller_mapping "$cfg_root/xbox_one_mapping.vdf" || return 1

  local userdata_root="$prefix/drive_c/Program Files (x86)/Steam/userdata"
  [[ -d "$userdata_root" ]] || return 0

  local file
  while IFS= read -r -d '' file; do
    patch_glyph_config "$file" || return 1
  done < <(find "$userdata_root" -type f \
    \( -name 'user_convars.vcfg' -o -name 'user_convars_0_slot0.vcfg' \) \
    -path '*/1422450/*' -print0 2>/dev/null)

  while IFS= read -r -d '' file; do
    patch_video_config "$file" || return 1
  done < <(find "$userdata_root" -type f -name 'video.txt' \
    -path '*/1422450/local/cfg/video.txt' -print0 2>/dev/null)
}

main "$@"
