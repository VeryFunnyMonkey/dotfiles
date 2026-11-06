# shellcheck shell=bash
# modules/winterm.sh: Windows Terminal (the windows-terminal item).
#   font      JetBrainsMono Nerd Font, installed for your Windows user (no admin)
#   fragment  rig's fragment: the gruvbox scheme, and this distro's profile with
#             the font, starting at home (Fragments\rig\rig.json; settings.json
#             stays yours)
#   default   this distro as the default profile: the one line rig changes in
#             settings.json, recorded (win-wt-default) and put back on undo
# Files and registry values go through lib/windows.sh (win-file, win-reg).

WT_FONTS_KEY='HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
WT_DYNAMIC_NS='{2bde4a90-d05f-401c-9492-e40884ead1d8}'   # Windows Terminal's own profiles (WSL's)

winterm_sync() {
  win_ready || return 0
  if module_active winterm; then winterm_setup; else winterm_teardown; fi
}

winterm_setup() {
  winterm_font
  winterm_fragment
  winterm_default
}

# This distro's name in Windows (WSL_DISTRO_NAME is lost under sudo -i: the
# root folder's Windows path has it too, \\wsl.localhost\<name>\).
winterm_distro() {
  if [[ -n ${WSL_DISTRO_NAME:-} ]]; then printf '%s' "$WSL_DISTRO_NAME"; return; fi
  wslpath -w / 2>/dev/null | tr -d '\r' | awk -F'\\' '{print $4}'
}
winterm_fonts_dir() { printf '%s/Microsoft/Windows/Fonts' "$(win_env LOCALAPPDATA)"; }
winterm_fragment_file() { printf '%s/Microsoft/Windows Terminal/Fragments/rig/rig.json' "$(win_env LOCALAPPDATA)"; }
winterm_settings_files() { # every Windows Terminal's settings.json here (Store, Preview, unpackaged)
  local l f; l=$(win_env LOCALAPPDATA) || return 0
  for f in "$l"/Packages/Microsoft.WindowsTerminal*_8wekyb3d8bbwe/LocalState/settings.json "$l/Microsoft/Windows Terminal/settings.json"; do
    if [[ -f $f ]]; then printf '%s\n' "$f"; fi
  done
}

# The distro's profile: as Windows Terminal listed it in settings.json, else
# the GUID it gives a WSL distro (from the name).
winterm_guid() {
  local d f g; d=$(winterm_distro)
  [[ -n $d ]] || return 1
  while IFS= read -r f; do
    g=$(awk -v d="$d" '
      /^[[:space:]]*\{[[:space:]]*$/ { g = ""; n = 0 }
      /"guid"[[:space:]]*:/ { if (match($0, /\{[0-9a-fA-F-]+\}/)) g = substr($0, RSTART, RLENGTH) }
      index($0, "\"name\": \"" d "\"") { n = 1 }
      n && g { print g; exit }' "$f")
    if [[ -n $g ]]; then printf '%s' "$g"; return 0; fi
  done < <(winterm_settings_files)
  uuid5 "$WT_DYNAMIC_NS" "$d"
}

winterm_font() {
  local dir; dir=$(winterm_fonts_dir)
  if [[ -f $dir/JetBrainsMonoNerdFont-Regular.ttf ]] && [[ -n $(win_reg_get "$WT_FONTS_KEY" "JetBrainsMonoNerdFont-Regular (TrueType)") ]]; then return 0; fi
  info "installing JetBrainsMono Nerd Font for Windows"
  local tmp f b n=0; tmp=$(mktemp -d)
  if ! curl -fsSL -o "$tmp/f.tar.xz" "$(dl_nerd_font_url)" || ! tar -xJf "$tmp/f.tar.xz" -C "$tmp" --wildcards 'JetBrainsMonoNerdFont-*.ttf'; then
    warn "couldn't download the font; rig sync tries again"; rm -rf "$tmp"; return 0
  fi
  for f in "$tmp"/JetBrainsMonoNerdFont-*.ttf; do
    b=$(basename "$f")
    win_file_write "$dir/$b" "$f" || true
    win_reg_set "$WT_FONTS_KEY" "${b%.ttf} (TrueType)" REG_SZ "$(win_path "$dir/$b")"
    n=$((n + 1))
  done
  rm -rf "$tmp"
  ok "JetBrainsMono Nerd Font for Windows ($n styles; apps started from now on see it)"
}

winterm_fragment() {
  local src="$CONFIG_HOME/rig/windows/wt-fragment.json" guid tmp
  [[ -f $src ]] || { warn "the fragment isn't rendered yet (chezmoi apply)"; return 0; }
  guid=$(winterm_guid) || { warn "couldn't tell which WSL distro this is; Windows Terminal's profile wasn't changed"; return 0; }
  tmp=$(mktemp); sed "s/@PROFILE_GUID@/$guid/" "$src" >"$tmp"
  if win_file_write "$(winterm_fragment_file)" "$tmp"; then ok "Windows Terminal: gruvbox and the Nerd Font for $(winterm_distro)"; fi
  rm -f "$tmp"
}

winterm_default() {
  local guid f cur n=0; guid=$(winterm_guid) || return 0
  while IFS= read -r f; do
    n=$((n + 1))
    cur=$(grep -o '"defaultProfile"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
    [[ -n $cur ]] || continue
    [[ ${cur,,} == "${guid,,}" ]] && continue
    if ! ledger_has win-wt-default "$f"; then ledger_record win-wt-default "$f" "$cur"; fi
    winterm_set_default "$f" "$guid"
    ok "Windows Terminal opens $(winterm_distro) by default (the one line rig changed in its settings.json; it was $cur, and rig uninstall puts that back)"
  done < <(winterm_settings_files)
  if ((n == 0)); then say "  ${DIM}Windows Terminal hasn't been opened yet: open it once, then rig modules sync winterm makes $(winterm_distro) its default${N}"; fi
}
winterm_set_default() { # settings.json guid
  sed -i "s|\"defaultProfile\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"defaultProfile\": \"$2\"|" "$1"
}
revert_win_wt_default() { # settings.json previous-guid
  if [[ -f $1 ]]; then winterm_set_default "$1" "$2"; fi
}

winterm_teardown() {
  local f k
  for f in $(ledger_keys win-wt-default); do
    revert_win_wt_default "$f" "$(ledger_last win-wt-default "$f")"; ledger_forget win-wt-default "$f"
  done
  win_file_restore "$(winterm_fragment_file)"
  while IFS= read -r f; do win_file_restore "$f"; done < <(ledger_keys win-file | grep -F "$(winterm_fonts_dir)/JetBrainsMonoNerdFont-" || true)
  while IFS= read -r k; do win_reg_restore "${k%|*}" "${k##*|}"; done < <(ledger_keys win-reg | grep -F "$WT_FONTS_KEY|JetBrainsMonoNerdFont-" || true)
}

winterm_doctor() {
  module_active winterm && win_ready || return 0
  info "Windows Terminal"
  if [[ -f $(winterm_fonts_dir)/JetBrainsMonoNerdFont-Regular.ttf ]]; then check_ok "Nerd Font installed for Windows"; else check_bad "Nerd Font missing (rig modules sync winterm)"; fi
  if [[ -f $(winterm_fragment_file) ]]; then check_ok "rig's fragment (gruvbox, $(winterm_distro))"; else check_bad "fragment missing (rig modules sync winterm)"; fi
}
