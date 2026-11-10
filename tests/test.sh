#!/bin/zsh

set -u

ROOT_DIR=${0:A:h:h}
PATCHER="$ROOT_DIR/scripts/apply-deadlock-fixes.sh"
PASS_COUNT=0
FAIL_COUNT=0

fail() {
  print -u2 -- "FAIL: $1"
  return 1
}

assert_contains() {
  local file=$1
  local text=$2
  grep -Fq -- "$text" "$file" || fail "$file does not contain: $text"
}

assert_count() {
  local expected=$1
  local text=$2
  local file=$3
  local actual
  actual=$(grep -Fc -- "$text" "$file" 2>/dev/null || true)
  [[ "$actual" == "$expected" ]] || fail "$file contains '$text' $actual times; expected $expected"
}

run_patcher() {
  local prefix=$1
  local deadlock_root=${2:-}
  WINEPREFIX="$prefix" DEADLOCK_ROOT="$deadlock_root" zsh "$PATCHER"
}

make_deadlock_tree() {
  local base=$1
  mkdir -p "$base/game/citadel/cfg"
  print -r -- "$base"
}

test_missing_files_are_normal() {
  local temp_dir
  temp_dir=$(mktemp -d)
  run_patcher "$temp_dir/prefix" "$temp_dir/missing-game"
  local result=$?
  rm -rf "$temp_dir"
  [[ $result -eq 0 ]] || fail "missing Steam/Deadlock files returned $result"
}

test_boot_renderer_changes_to_dx11_and_backs_up() {
  local temp_dir deadlock_root boot_file
  temp_dir=$(mktemp -d)
  deadlock_root=$(make_deadlock_tree "$temp_dir/Deadlock")
  boot_file="$deadlock_root/game/citadel/cfg/boot.vcfg"
  printf '%b\n' '"boot"\n{\n\t"DefaultRenderSystemOption"\t\t"-vulkan"\n}' > "$boot_file"

  run_patcher "$temp_dir/prefix" "$deadlock_root" || return 1

  assert_contains "$boot_file" $'"DefaultRenderSystemOption"\t\t"-dx11"' || return 1
  cmp -s "$boot_file.deadlock-runner.bak" <(printf '%b\n' '"boot"\n{\n\t"DefaultRenderSystemOption"\t\t"-vulkan"\n}') || fail "boot backup does not preserve the original"
  local result=$?
  rm -rf "$temp_dir"
  return $result
}

test_controller_tab_binding_is_added_once() {
  local temp_dir deadlock_root mapping
  temp_dir=$(mktemp -d)
  deadlock_root=$(make_deadlock_tree "$temp_dir/Deadlock")
  mapping="$deadlock_root/game/citadel/cfg/xbox_one_mapping.vdf"
  printf '%b\n' '"controller_mappings"\n{\n\t"revision"\t\t"112"\n\t"bindings"\n\t{\n\t\t"binding"\t\t"game_action GameControls Ping, , "\n\t}\n}' > "$mapping"

  run_patcher "$temp_dir/prefix" "$deadlock_root" || return 1
  run_patcher "$temp_dir/prefix" "$deadlock_root" || return 1

  assert_contains "$mapping" $'"revision"\t\t"113"' || return 1
  assert_count 1 $'"binding"\t\t"key_press TAB, , "' "$mapping"
  local result=$?
  rm -rf "$temp_dir"
  return $result
}

test_user_glyph_mode_is_forced_to_controller() {
  local temp_dir cfg_dir config_file
  temp_dir=$(mktemp -d)
  cfg_dir="$temp_dir/prefix/drive_c/Program Files (x86)/Steam/userdata/12345/1422450/local/cfg"
  mkdir -p "$cfg_dir"
  config_file="$cfg_dir/user_convars_0_slot0.vcfg"
  printf '%b\n' '"config"\n{\n\t"convars"\n\t{\n\t\t"steam_inputhandler_glyph_lock_mode"\t\t"0"\n\t}\n}' > "$config_file"

  run_patcher "$temp_dir/prefix" || return 1

  assert_contains "$config_file" $'"steam_inputhandler_glyph_lock_mode"\t\t"2"'
  local result=$?
  rm -rf "$temp_dir"
  return $result
}

test_video_config_gets_safe_mac_defaults_without_changing_resolution() {
  local temp_dir cfg_dir video_file
  temp_dir=$(mktemp -d)
  cfg_dir="$temp_dir/prefix/drive_c/Program Files (x86)/Steam/userdata/12345/1422450/local/cfg"
  mkdir -p "$cfg_dir"
  video_file="$cfg_dir/video.txt"
  printf '%b\n' '"video.cfg"\n{\n\t"VendorID"\t\t"9999"\n\t"DeviceID"\t\t"100"\n\t"setting.gpu_mem_level"\t\t"0"\n\t"setting.defaultres"\t\t"2560"\n\t"setting.defaultresheight"\t\t"1440"\n\t"setting.fullscreen"\t\t"1"\n\t"setting.nowindowborder"\t\t"0"\n}' > "$video_file"

  run_patcher "$temp_dir/prefix" || return 1

  assert_contains "$video_file" $'"VendorID"\t\t"4203"' || return 1
  assert_contains "$video_file" $'"DeviceID"\t\t"0"' || return 1
  assert_contains "$video_file" $'"setting.gpu_mem_level"\t\t"3"' || return 1
  assert_contains "$video_file" $'"setting.fullscreen"\t\t"0"' || return 1
  assert_contains "$video_file" $'"setting.nowindowborder"\t\t"1"' || return 1
  assert_contains "$video_file" $'"setting.defaultres"\t\t"2560"' || return 1
  assert_contains "$video_file" $'"setting.defaultresheight"\t\t"1440"'
  local result=$?
  rm -rf "$temp_dir"
  return $result
}

test_second_run_is_byte_identical() {
  local temp_dir deadlock_root boot_file mapping cfg_dir config_file video_file before after
  temp_dir=$(mktemp -d)
  deadlock_root=$(make_deadlock_tree "$temp_dir/Deadlock")
  boot_file="$deadlock_root/game/citadel/cfg/boot.vcfg"
  mapping="$deadlock_root/game/citadel/cfg/xbox_one_mapping.vdf"
  cfg_dir="$temp_dir/prefix/drive_c/Program Files (x86)/Steam/userdata/12345/1422450/local/cfg"
  config_file="$cfg_dir/user_convars_0_slot0.vcfg"
  video_file="$cfg_dir/video.txt"
  mkdir -p "$cfg_dir"
  printf '%b\n' '"boot"\n{\n\t"DefaultRenderSystemOption"\t\t"-vulkan"\n}' > "$boot_file"
  printf '%b\n' '"controller_mappings"\n{\n\t"revision"\t\t"112"\n\t"bindings"\n\t{\n\t\t"binding"\t\t"game_action GameControls Ping, , "\n\t}\n}' > "$mapping"
  printf '%b\n' '"config"\n{\n\t"convars"\n\t{\n\t\t"steam_inputhandler_glyph_lock_mode"\t\t"0"\n\t}\n}' > "$config_file"
  printf '%b\n' '"video.cfg"\n{\n\t"VendorID"\t\t"9999"\n\t"DeviceID"\t\t"100"\n\t"setting.gpu_mem_level"\t\t"0"\n\t"setting.defaultres"\t\t"1920"\n\t"setting.defaultresheight"\t\t"1080"\n\t"setting.fullscreen"\t\t"1"\n\t"setting.nowindowborder"\t\t"0"\n}' > "$video_file"

  run_patcher "$temp_dir/prefix" "$deadlock_root" || return 1
  before=$(shasum -a 256 "$boot_file" "$mapping" "$config_file" "$video_file")
  run_patcher "$temp_dir/prefix" "$deadlock_root" || return 1
  after=$(shasum -a 256 "$boot_file" "$mapping" "$config_file" "$video_file")

  [[ "$before" == "$after" ]] || fail "second patcher run changed already-patched files"
  local result=$?
  rm -rf "$temp_dir"
  return $result
}

run_test() {
  local name=$1
  if "$name"; then
    print -- "PASS: $name"
    (( PASS_COUNT += 1 ))
  else
    (( FAIL_COUNT += 1 ))
  fi
}

run_test test_missing_files_are_normal
run_test test_boot_renderer_changes_to_dx11_and_backs_up
run_test test_controller_tab_binding_is_added_once
run_test test_user_glyph_mode_is_forced_to_controller
run_test test_video_config_gets_safe_mac_defaults_without_changing_resolution
run_test test_second_run_is_byte_identical

print -- "$PASS_COUNT passed, $FAIL_COUNT failed"
(( FAIL_COUNT == 0 ))
