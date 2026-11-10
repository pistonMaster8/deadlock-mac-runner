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

create_fake_source_app() {
  local app=$1
  mkdir -p \
    "$app/Contents/MacOS" \
    "$app/Contents/Resources/Scripts" \
    "$app/Contents/Frameworks" \
    "$app/Contents/SharedSupport/wine/bin" \
    "$app/Contents/SharedSupport/wine-11.0_1-backup-20261108" \
    "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/config" \
    "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/userdata/12345" \
    "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Deadlock/game/bin/win64"

  print -r -- 'wine sikarugir 10.0 (revision 6)' > "$app/Contents/SharedSupport/wine/version"
  print -r -- 'wine sikarugir 11.0 (revision 1)' > "$app/Contents/SharedSupport/wine-11.0_1-backup-20261108/version"
  print -r -- 'personal login' > "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/config/loginusers.vdf"
  print -r -- 'personal userdata' > "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/userdata/12345/localconfig.vdf"
  print -r -- 'game binary' > "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Deadlock/game/bin/win64/deadlock.exe"
  print -r -- '#!/bin/sh' > "$app/Contents/Resources/Scripts/StartupScript"
  chmod +x "$app/Contents/Resources/Scripts/StartupScript"
  print -r -- 'fake launcher' > "$app/Contents/MacOS/launcher"
  chmod +x "$app/Contents/MacOS/launcher"

  plutil -create xml1 "$app/Contents/Info.plist"
  plutil -insert CFBundleName -string 'Megabonk Runner' "$app/Contents/Info.plist"
  plutil -insert CFBundleIdentifier -string 'com.example.megabonk' "$app/Contents/Info.plist"
  plutil -insert CFBundleShortVersionString -string '1.0' "$app/Contents/Info.plist"
  plutil -insert CFBundleVersion -string '1.0.21' "$app/Contents/Info.plist"
  plutil -insert LSMinimumSystemVersion -string '14.6' "$app/Contents/Info.plist"
  plutil -insert 'Program Name and Path' -string '/Program Files (x86)/Steam/steam.exe' "$app/Contents/Info.plist"
  plutil -insert 'Program Flags' -string '' "$app/Contents/Info.plist"
  plutil -insert D9VK -integer 1 "$app/Contents/Info.plist"
  plutil -insert DXVK -integer 0 "$app/Contents/Info.plist"
  plutil -insert D3DMETAL -integer 0 "$app/Contents/Info.plist"
  plutil -insert WINEESYNC -integer 1 "$app/Contents/Info.plist"
  plutil -insert WINEMSYNC -integer 1 "$app/Contents/Info.plist"
  plutil -insert 'Try To Use GPU Info' -integer 0 "$app/Contents/Info.plist"
}

test_app_builder_excludes_personal_prefix_and_backup_engine() {
  local temp_dir source_app output_dir built_app steam_setup
  temp_dir=$(mktemp -d)
  source_app="$temp_dir/Source Runner.app"
  output_dir="$temp_dir/output with spaces"
  steam_setup="$temp_dir/SteamSetup.exe"
  create_fake_source_app "$source_app"
  print -r -- 'official installer fixture' > "$steam_setup"

  DEADLOCK_RUNNER_TEST_MODE=1 STEAM_SETUP_SOURCE="$steam_setup" \
    zsh "$ROOT_DIR/scripts/build-app.sh" "$source_app" "$output_dir" || return 1
  built_app="$output_dir/Deadlock Runner.app"

  [[ -f "$built_app/Contents/SharedSupport/wine/version" ]] || fail "active Wine engine was not preserved" || return 1
  assert_contains "$built_app/Contents/SharedSupport/wine/version" 'wine sikarugir 10.0 (revision 6)' || return 1
  [[ ! -e "$built_app/Contents/SharedSupport/wine-11.0_1-backup-20261108" ]] || fail "backup Wine engine was staged" || return 1
  [[ ! -e "$built_app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/config/loginusers.vdf" ]] || fail "Steam login data was staged" || return 1
  [[ ! -e "$built_app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/userdata" ]] || fail "Steam userdata was staged" || return 1
  [[ ! -e "$built_app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Deadlock" ]] || fail "Deadlock game files were staged" || return 1
  [[ -f "$built_app/Contents/SharedSupport/prefix/drive_c/DeadlockSetup/SteamSetup.exe" ]] || fail "Steam installer was not staged" || return 1
  [[ -f "$built_app/Contents/SharedSupport/prefix/drive_c/DeadlockSetup/bootstrap.cmd" ]] || fail "bootstrap command was not staged" || return 1
  [[ -x "$built_app/Contents/Resources/Scripts/DeadlockFixes" ]] || fail "Deadlock startup patcher was not installed" || return 1

  [[ "$(plutil -extract CFBundleName raw "$built_app/Contents/Info.plist")" == 'Deadlock Runner' ]] || fail "bundle name was not updated" || return 1
  [[ "$(plutil -extract CFBundleIdentifier raw "$built_app/Contents/Info.plist")" == 'io.github.desmondwebb.deadlock-runner' ]] || fail "bundle identifier was not updated" || return 1
  [[ "$(plutil -extract 'Program Name and Path' raw "$built_app/Contents/Info.plist")" == '/windows/system32/cmd.exe' ]] || fail "wrapper does not launch cmd.exe" || return 1
  [[ "$(plutil -extract 'Program Flags' raw "$built_app/Contents/Info.plist")" == '/c C:\DeadlockSetup\bootstrap.cmd' ]] || fail "wrapper flags do not launch the bootstrap" || return 1

  local result=0
  rm -rf "$temp_dir"
  return $result
}

test_app_builder_returns_absolute_path_for_relative_output() {
  local temp_dir source_app steam_setup built_path result
  temp_dir=$(mktemp -d)
  source_app="$temp_dir/Source Runner.app"
  steam_setup="$temp_dir/SteamSetup.exe"
  create_fake_source_app "$source_app"
  print -r -- 'official installer fixture' > "$steam_setup"

  built_path=$(
    cd "$temp_dir" || exit 1
    DEADLOCK_RUNNER_TEST_MODE=1 STEAM_SETUP_SOURCE="$steam_setup" \
      zsh "$ROOT_DIR/scripts/build-app.sh" "$source_app" 'relative output' | tail -n 1
  )
  result=$?
  if [[ $result -eq 0 && "$built_path" == /* && -d "$built_path" ]]; then
    result=0
  else
    fail "relative output did not resolve to an absolute built-app path: $built_path"
    result=1
  fi
  rm -rf "$temp_dir"
  return $result
}

test_privacy_scanner_rejects_account_and_game_data() {
  local temp_dir app steam_root result
  [[ -x "$ROOT_DIR/scripts/scan-private-data.sh" ]] || {
    fail "privacy scanner is missing"
    return 1
  }
  temp_dir=$(mktemp -d)
  app="$temp_dir/Deadlock Runner.app"
  steam_root="$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam"
  mkdir -p "$steam_root/config" "$steam_root/steamapps/common/Deadlock"
  print -r -- 'account' > "$steam_root/config/loginusers.vdf"
  print -r -- 'game' > "$steam_root/steamapps/common/Deadlock/deadlock.exe"

  zsh "$ROOT_DIR/scripts/scan-private-data.sh" "$app" >/dev/null 2>&1
  result=$?
  rm -rf "$temp_dir"
  [[ $result -ne 0 ]] || fail "privacy scanner accepted Steam account/game data"
}

test_privacy_scanner_accepts_bootstrap_only_prefix() {
  local temp_dir app setup_root result
  [[ -x "$ROOT_DIR/scripts/scan-private-data.sh" ]] || {
    fail "privacy scanner is missing"
    return 1
  }
  temp_dir=$(mktemp -d)
  app="$temp_dir/Deadlock Runner.app"
  setup_root="$app/Contents/SharedSupport/prefix/drive_c/DeadlockSetup"
  mkdir -p "$setup_root"
  print -r -- 'installer' > "$setup_root/SteamSetup.exe"
  print -r -- '@echo off' > "$setup_root/bootstrap.cmd"

  zsh "$ROOT_DIR/scripts/scan-private-data.sh" "$app"
  result=$?
  rm -rf "$temp_dir"
  [[ $result -eq 0 ]] || fail "privacy scanner rejected a bootstrap-only prefix"
}

test_dmg_builder_stages_exact_payload_and_valid_checksum() {
  local temp_dir app output_dir staging actual expected result
  temp_dir=$(mktemp -d)
  app="$temp_dir/Deadlock Runner.app"
  output_dir="$temp_dir/dist"
  mkdir -p "$app/Contents/MacOS"
  print -r -- 'fake app' > "$app/Contents/MacOS/launcher"

  DEADLOCK_RUNNER_TEST_MODE=1 \
    zsh "$ROOT_DIR/scripts/build-dmg.sh" "$app" "$output_dir" || return 1

  staging="$output_dir/.dmg-staging"
  expected=$'Applications\nDeadlock Runner.app\nINSTALL.txt'
  actual=$(find "$staging" -mindepth 1 -maxdepth 1 -exec basename {} \; | sort)
  [[ "$actual" == "$expected" ]] || fail "DMG staging payload differs:\n$actual" || return 1
  [[ -L "$staging/Applications" ]] || fail "Applications item is not a symlink" || return 1
  [[ "$(readlink "$staging/Applications")" == '/Applications' ]] || fail "Applications link has the wrong target" || return 1
  [[ -d "$staging/Deadlock Runner.app" ]] || fail "runner app is absent from DMG staging" || return 1
  [[ -f "$staging/INSTALL.txt" ]] || fail "install guide is absent from DMG staging" || return 1
  [[ -f "$output_dir/Deadlock-Runner-macOS.dmg" ]] || fail "DMG output is absent" || return 1
  [[ -f "$output_dir/Deadlock-Runner-macOS.dmg.sha256" ]] || fail "checksum output is absent" || return 1

  (cd "$output_dir" && shasum -a 256 -c 'Deadlock-Runner-macOS.dmg.sha256')
  result=$?
  rm -rf "$temp_dir"
  [[ $result -eq 0 ]] || fail "generated checksum did not verify"
}

test_pages_document_is_valid_html() {
  local page="$ROOT_DIR/docs/index.html"
  [[ -f "$page" ]] || {
    fail "GitHub Pages index is missing"
    return 1
  }
  xmllint --noout "$page" >/dev/null 2>&1 || fail "GitHub Pages index is not well-formed HTML"
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
run_test test_app_builder_excludes_personal_prefix_and_backup_engine
run_test test_app_builder_returns_absolute_path_for_relative_output
run_test test_privacy_scanner_rejects_account_and_game_data
run_test test_privacy_scanner_accepts_bootstrap_only_prefix
run_test test_dmg_builder_stages_exact_payload_and_valid_checksum
run_test test_pages_document_is_valid_html

print -- "$PASS_COUNT passed, $FAIL_COUNT failed"
(( FAIL_COUNT == 0 ))
