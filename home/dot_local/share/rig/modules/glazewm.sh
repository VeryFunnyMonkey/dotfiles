# shellcheck shell=bash
# modules/glazewm.sh: the keyboard-driven desktop (the wm item) on Windows:
# GlazeWM with rig's config (~/.config/rig/windows/glazewm.yaml, rendered from
# theme.yaml), copied to %USERPROFILE%\.glzr\glazewm\config.yaml, started at
# login (a Run value) and now. KDE and macOS do the wm item without a module,
# so elsewhere this does nothing.

GLAZE_RUN_KEY='HKCU\Software\Microsoft\Windows\CurrentVersion\Run'

glazewm_sync() {
  win_ready || return 0
  if module_active glazewm; then glazewm_setup; else glazewm_teardown; fi
}

glazewm_exe() {
  local l p; l=$(win_env LOCALAPPDATA) || return 1
  for p in "/mnt/c/Program Files/glzr.io/GlazeWM/glazewm.exe" "$l/Programs/glzr.io/GlazeWM/glazewm.exe" "/mnt/c/Program Files/glzr.io"/*/glazewm.exe; do
    if [[ -f $p ]]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}
glazewm_config() { printf '%s/.glzr/glazewm/config.yaml' "$(win_env USERPROFILE)"; }
glazewm_running() { win_running glazewm.exe; }

glazewm_setup() {
  local exe src="$CONFIG_HOME/rig/windows/glazewm.yaml"
  exe=$(glazewm_exe) || { warn "GlazeWM isn't installed yet (rig sync)"; return 0; }
  [[ -f $src ]] || { warn "GlazeWM's config isn't rendered yet (chezmoi apply)"; return 0; }
  if win_file_write "$(glazewm_config)" "$src"; then
    ok "GlazeWM config (alt+hjkl, alt+1..9; the keys: rig info wm)"
    if glazewm_running; then (cd /mnt/c && "$exe" command wm-reload-config >/dev/null 2>&1 </dev/null) || true; fi
  fi
  win_reg_set "$GLAZE_RUN_KEY" GlazeWM REG_SZ "\"$(win_path "$exe")\""
  if ! glazewm_running; then win_start "$exe"; fi
}

glazewm_teardown() {
  if ledger_has win-file "$(glazewm_config 2>/dev/null)" || ledger_has win-reg "$GLAZE_RUN_KEY|GlazeWM"; then
    if glazewm_running; then win_cmd taskkill /IM glazewm.exe >/dev/null 2>&1 || true; fi
    win_file_restore "$(glazewm_config)"
    win_reg_restore "$GLAZE_RUN_KEY" GlazeWM
  fi
}

glazewm_doctor() {
  module_active glazewm && win_ready || return 0
  info "GlazeWM (the keyboard-driven desktop)"
  if glazewm_exe >/dev/null; then check_ok "installed"; else check_bad "not installed (rig sync)"; return 0; fi
  if cmp -s "$CONFIG_HOME/rig/windows/glazewm.yaml" "$(glazewm_config)"; then check_ok "config up to date"; else check_bad "config differs (rig modules sync glazewm)"; fi
  if [[ -n $(win_reg_get "$GLAZE_RUN_KEY" GlazeWM) ]]; then check_ok "starts at login"; else check_bad "doesn't start at login (rig modules sync glazewm)"; fi
}
