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
    function brace_delta(value, copy, count) {
      copy = value
      count = gsub(/\{/, "{", copy)
      copy = value
      count -= gsub(/\}/, "}", copy)
      return count
    }
    function emit_bindings(first, last, k, has_ping, has_tab, tab_seen, indent) {
      has_ping = has_tab = tab_seen = 0
      for (k = first; k <= last; k++) {
        if (lines[k] ~ /"binding"[[:space:]]+"game_action GameControls Ping, , "/) has_ping = 1
        if (lines[k] ~ /"binding"[[:space:]]+"key_press TAB, , "/) has_tab = 1
      }
      for (k = first; k <= last; k++) {
        if (has_ping && lines[k] ~ /"binding"[[:space:]]+"key_press TAB, , "/) {
          tab_seen++
          if (tab_seen > 1) continue
        }
        print lines[k]
        if (has_ping && !has_tab && lines[k] ~ /"binding"[[:space:]]+"game_action GameControls Ping, , "/) {
          indent = lines[k]
          sub(/"binding".*/, "", indent)
          print indent "\"binding\"\t\t\"key_press TAB, , \""
        }
      }
    }
    {
      line = $0
      if (line ~ /"revision"[[:space:]]+"112"/) sub(/"112"/, "\"113\"", line)
      lines[NR] = line
    }
    END {
      i = 1
      while (i <= NR) {
        if (lines[i] ~ /^[[:space:]]*"bindings"[[:space:]]*$/ && i < NR && lines[i + 1] ~ /^[[:space:]]*\{/) {
          depth = 0
          last = 0
          for (j = i + 1; j <= NR; j++) {
            depth += brace_delta(lines[j])
            if (depth == 0) {
              last = j
              break
            }
          }
          if (last) {
            emit_bindings(i, last)
            i = last + 1
            continue
          }
        }
        print lines[i]
        i++
      }
    }
  ' "$file" > "$temp_file" || {
    rm -f "$temp_file"
    return 1
  }

  install_if_changed "$file" "$temp_file"
}
patch_controller_ptt_binding() {
  local file=$1
  patch_with_sed "$file" \
    -e 's#^([[:space:]]*"binding"[[:space:]]+)"controller_action SCREENSHOT, , "#\1"key_press T, , "#'
}

patch_glyph_config() {
  local file=$1
  patch_with_sed "$file" \
    -e 's#^([[:space:]]*"steam_inputhandler_glyph_lock_mode"[[:space:]]+)"[^"]*"#\1"2"#'
}
patch_voice_config() {
  local file=$1
  patch_with_sed "$file" \
    -e 's#^([[:space:]]*"voice_in_process"[[:space:]]+)"[^"]*"#\1"false"#' \
    -e 's#^([[:space:]]*"voice_always_sample_mic\$[0-9]*"[[:space:]]+)"[^"]*"#\1"false"#' \
    -e 's#^([[:space:]]*"voice_device_override"[[:space:]]+)"[^"]*"#\1"Mike’s AirPods Max"#' \
    -e '/^[[:space:]]*"voice_threshold"[[:space:]]+/d' || return 1

  local temp_file
  temp_file=$(mktemp "$file.deadlock-runner.XXXXXX") || return 1
  awk '
    function brace_delta(value, copy, count) {
      copy = value
      count = gsub(/\{/, "{", copy)
      copy = value
      count -= gsub(/\}/, "}", copy)
      return count
    }
    {
      line = $0
      if (line ~ /^[[:space:]]*"voice_in_process"[[:space:]]+/) {
        if (!found) {
          print "\t\t\"voice_in_process\"\t\t\"false\""
          found = 1
        }
        depth += brace_delta(line)
        next
      }
      if (!found && depth == 2 && line ~ /^[[:space:]]*}/) {
        print "\t\t\"voice_in_process\"\t\t\"false\""
        found = 1
      }
      print line
      depth += brace_delta(line)
    }
  ' "$file" > "$temp_file" || {
    rm -f "$temp_file"
    return 1
  }

  install_if_changed "$file" "$temp_file"
}

patch_ptt_key_config() {
  local file=$1
  [[ -f "$file" ]] || return 0

  local temp_file
  temp_file=$(mktemp "$file.deadlock-runner.XXXXXX") || return 1
  awk '
    function brace_delta(value, copy, count) {
      copy = value
      count = gsub(/\{/, "{", copy)
      copy = value
      count -= gsub(/\}/, "}", copy)
      return count
    }
    {
      line = $0
      if (line ~ /^[[:space:]]*"T"[[:space:]]+/) {
        if (!found) {
          print "\t\t\"T\"\t\t\"+voicerecord\""
          found = 1
        }
        depth += brace_delta(line)
        next
      }
      if (!found && depth == 2 && line ~ /^[[:space:]]*}/) {
        print "\t\t\"T\"\t\t\"+voicerecord\""
        found = 1
      }
      print line
      depth += brace_delta(line)
    }
  ' "$file" > "$temp_file" || {
    rm -f "$temp_file"
    return 1
  }

  install_if_changed "$file" "$temp_file"
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
  patch_controller_ptt_binding "$cfg_root/xbox_one_mapping.vdf" || return 1

  local userdata_root="$prefix/drive_c/Program Files (x86)/Steam/userdata"
  [[ -d "$userdata_root" ]] || return 0

  local file
  while IFS= read -r -d '' file; do
    patch_glyph_config "$file" || return 1
  done < <(find "$userdata_root" -type f \
    \( -name 'user_convars.vcfg' -o -name 'user_convars_0_slot0.vcfg' \) \
    -path '*/1422450/*' -print0 2>/dev/null)

  while IFS= read -r -d '' file; do
    patch_voice_config "$file" || return 1
  done < <(find "$userdata_root" -type f -name 'machine_convars.vcfg' \
    -path '*/1422450/local/cfg/machine_convars.vcfg' -print0 2>/dev/null)

  while IFS= read -r -d '' file; do
    patch_ptt_key_config "$file" || return 1
  done < <(find "$userdata_root" -type f -name 'user_keys_0_slot0.vcfg' \
    -path '*/1422450/local/cfg/user_keys_0_slot0.vcfg' -print0 2>/dev/null)


  while IFS= read -r -d '' file; do
    patch_video_config "$file" || return 1
  done < <(find "$userdata_root" -type f -name 'video.txt' \
    -path '*/1422450/local/cfg/video.txt' -print0 2>/dev/null)
}

main "$@"
