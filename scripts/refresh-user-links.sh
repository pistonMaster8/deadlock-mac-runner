#!/bin/zsh

set -u

PREFIX=${WINEPREFIX:-}
[[ -n "$PREFIX" && -d "$PREFIX/drive_c/users" ]] || exit 0

typeset -a candidates
candidates=("$PREFIX/drive_c/users/runner" "$PREFIX"/drive_c/users/*(N/))

local user_dir=''
local candidate
for candidate in "${candidates[@]}"; do
  [[ -d "$candidate" && "${candidate:t}" != 'Public' ]] || continue
  user_dir=$candidate
  break
done
[[ -n "$user_dir" ]] || exit 0

refresh_link() {
  local destination=$1
  local source=$2
  [[ -d "$source" ]] || return 0

  if [[ -L "$destination" ]]; then
    rm -f "$destination"
  elif [[ -e "$destination" ]]; then
    return 0
  else
    mkdir -p "${destination:h}"
  fi

  ln -s "$source" "$destination"
}

refresh_link "$user_dir/Desktop" "$HOME/Desktop"
refresh_link "$user_dir/Documents" "$HOME/Documents"
refresh_link "$user_dir/Downloads" "$HOME/Downloads"
refresh_link "$user_dir/Music" "$HOME/Music"
refresh_link "$user_dir/Pictures" "$HOME/Pictures"
refresh_link "$user_dir/Videos" "$HOME/Movies"
refresh_link "$user_dir/AppData/Roaming/Microsoft/Windows/Templates" "$HOME/Templates"
