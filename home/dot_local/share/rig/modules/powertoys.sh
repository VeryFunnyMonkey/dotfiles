# shellcheck shell=bash
# modules/powertoys.sh: PowerToys (the powertoys item: on every Windows
# machine). Its settings go through PowerToys' own DSC tool; the item's
# powertoys_settings say what changes (everything else stays as shipped).
# Before the first change each PowerToys module's settings are saved:
#   powertoys-dsc  key: the PowerToys module   previous: the saved settings
# and set back on undo. Command Palette's settings file (cmdpal_settings: its
# alt+space key) is a win-file, backed up the same way.

pt_dir() {
  local l d; l=$(win_env LOCALAPPDATA) || return 1
  for d in "$l/PowerToys" "/mnt/c/Program Files/PowerToys"; do
    if [[ -x $d/PowerToys.DSC.exe ]]; then printf '%s' "$d"; return 0; fi
  done
  return 1
}
# json.ps1 runs from Windows' temp folder (a script on the WSL side is a
# network path to PowerShell).
pt_json() { # args for json.ps1...
  local t; t=$(win_env TEMP) || return 1
  cp "$RIG_LIB/modules/powertoys/json.ps1" "$t/rig-json.ps1"
  win_ps -File "$(win_path "$t/rig-json.ps1")" "$@"
}
pt_item_json() { cz_tmpl "{{ (index .catalog \"powertoys\").$1 | toJson }}"; } # field -> JSON
cmdpal_file() {
  local l f; l=$(win_env LOCALAPPDATA) || return 1
  for f in "$l"/Packages/Microsoft.CommandPalette_*/LocalState; do
    if [[ -d $f ]]; then printf '%s/settings.json' "$f"; return 0; fi
  done
  return 1
}

powertoys_sync() {
  win_ready || return 0
  if module_active powertoys; then powertoys_setup; else powertoys_teardown; fi
}

powertoys_setup() {
  local dir; dir=$(pt_dir) || { warn "PowerToys isn't installed yet (rig sync)"; return 0; }
  local dsc="$dir/PowerToys.DSC.exe" mods m want saved
  mods=$(cz_tmpl '{{ range $m, $_ := (index .catalog "powertoys").powertoys_settings }}{{ $m }} {{ end }}')
  for m in $mods; do
    want=$(cz_tmpl "{{ index (index .catalog \"powertoys\").powertoys_settings \"$m\" | toJson }}")
    saved="$RIG_STATE/powertoys/$m.json"
    if ledger_has powertoys-dsc "$m"; then
      pt_json -Dsc "$(win_path "$dsc")" -Module "$m" -Want "$want" >/dev/null || warn "PowerToys: $m settings weren't applied"
    else
      mkdir -p "$RIG_STATE/powertoys"
      local t; t=$(win_env TEMP)/rig-pt-$m.json
      if pt_json -Dsc "$(win_path "$dsc")" -Module "$m" -Save "$(win_path "$t")" -Want "$want" >/dev/null; then
        mv "$t" "$saved"; ledger_record powertoys-dsc "$m" "$saved"
      else warn "PowerToys: $m settings weren't applied"; fi
    fi
  done
  ok "PowerToys settings (FancyZones off, Command Palette on)"
  powertoys_cmdpal
  if ! win_cmd 'tasklist /FI "IMAGENAME eq PowerToys.exe"' | grep -qi powertoys.exe; then win_start "$dir/PowerToys.exe"; fi
}

# Command Palette's key: its settings file, merged (it reads it when it starts).
powertoys_cmdpal() {
  local f; f=$(cmdpal_file) || { say "  ${DIM}Command Palette hasn't run yet; its key is set on the next rig sync${N}"; return 0; }
  local want wt; want=$(pt_item_json cmdpal_settings)
  # merged on a copy, so win_file_write backs up the original first
  wt="$(win_env TEMP)/rig-cmdpal.json"; rm -f "$wt"
  if [[ -f $f ]]; then cp "$f" "$wt"; fi
  pt_json -File "$(win_path "$wt")" -Want "$want" >/dev/null || { warn "Command Palette's key wasn't set"; return 0; }
  if win_file_write "$f" "$wt"; then
    win_cmd 'taskkill /IM Microsoft.CmdPal.UI.exe /F' >/dev/null 2>&1 || true   # it starts again with PowerToys, on the new key
    ok "Command Palette on alt+space"
  fi
  rm -f "$wt"
}

powertoys_teardown() {
  local m; for m in $(ledger_keys powertoys-dsc); do
    revert_powertoys_dsc "$m" "$(ledger_last powertoys-dsc "$m")"; ledger_forget powertoys-dsc "$m"
  done
  local f; f=$(cmdpal_file 2>/dev/null) && win_file_restore "$f"
  return 0
}
revert_powertoys_dsc() { # module saved-file
  local dir; dir=$(pt_dir) || return 0
  [[ -f $2 ]] || return 0
  local t; t="$(win_env TEMP)/rig-pt-restore.json"; cp "$2" "$t"
  pt_json -Dsc "$(win_path "$dir/PowerToys.DSC.exe")" -Module "$1" -Restore "$(win_path "$t")" >/dev/null &&
    ok "PowerToys: $1 settings put back"
  rm -f "$t"
}

powertoys_doctor() {
  module_active powertoys && win_ready || return 0
  info "PowerToys"
  if pt_dir >/dev/null; then check_ok "installed"; else check_bad "not installed (rig sync)"; return 0; fi
  if ledger_has powertoys-dsc App; then check_ok "settings applied"; else check_bad "settings not applied (rig modules sync powertoys)"; fi
}
