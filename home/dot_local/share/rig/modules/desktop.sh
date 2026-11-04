# shellcheck shell=bash
# modules/desktop.sh: what the Hyprland item needs beyond packages and its
# config files (the hyprland item: `module: desktop`).
#   login     on a machine with no login manager: greetd with tuigreet (in
#             gruvbox), starting Hyprland through uwsm. Where one exists
#             (SDDM on KDE, ...), it already lists "Hyprland (uwsm-managed)".
#   services  NetworkManager (Wi-Fi from the bar) unless another network
#             manager runs, and Bluetooth.
# Every change goes in the ledger; deselecting or uninstalling undoes it.

GREETD_CONFIG=/etc/greetd/config.toml

desktop_sync() {
  if module_active desktop; then desktop_setup; else desktop_teardown; fi
}

desktop_setup() {
  have Hyprland || { warn "Hyprland isn't installed yet (rig sync)"; return 0; }
  if ! have_system_systemd; then
    warn "no systemd here: start Hyprland with: uwsm start hyprland.desktop"
    return 0
  fi
  desktop_services
  if desktop_has_login_manager; then
    ok "Hyprland is a session at your login screen: \"Hyprland (uwsm-managed)\""
  else
    desktop_greeter
  fi
}

# A display manager other than the greetd rig set up?
desktop_has_login_manager() {
  local dm; dm=$(systemctl show -p Id --value display-manager.service 2>/dev/null || true)
  [[ -n $dm && $dm != greetd.service ]] && systemctl is-enabled display-manager.service >/dev/null 2>&1
}

desktop_greeter() {
  if ! pkg_present pacman greetd || ! pkg_present pacman greetd-tuigreet; then
    info "installing greetd (the login screen)"
    local p; for p in greetd greetd-tuigreet; do
      if pkg_present pacman "$p"; then ledger_pkg_record pacman "$p" "$p" preexisting
      else ledger_pkg_record pacman "$p" "$p" installed; fi
    done
    pkg_install_cmd pacman greetd greetd-tuigreet
  fi
  local want; want=$(desktop_greetd_config)
  if [[ $(cat "$GREETD_CONFIG" 2>/dev/null) != "$want" ]]; then
    etc_file_write "$GREETD_CONFIG" "$want"
    ok "login screen: tuigreet, starting Hyprland"
  fi
  if [[ $(systemctl is-enabled greetd.service 2>/dev/null || true) != enabled ]]; then
    unit_enable_system greetd.service
    ok "greetd enabled (takes over at the next boot)"
  fi
}

desktop_greetd_config() {
  # tuigreet's colours: gruvbox-ish names it understands
  cat <<'EOF'
# Written by rig (the hyprland item). The previous file is restored when the
# item is deselected or rig is uninstalled.
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --asterisks --greeting 'welcome back' --theme 'border=darkgray;text=gray;prompt=green;time=yellow;action=gray;button=yellow;input=white' --cmd 'uwsm start hyprland.desktop'"
user = "greeter"
EOF
}

desktop_services() {
  local nm_alternatives="systemd-networkd.service iwd.service connman.service"
  local s other=''
  for s in $nm_alternatives; do
    if systemctl is-enabled "$s" >/dev/null 2>&1; then other=$s; fi
  done
  if [[ -n $other ]]; then
    say "  ${DIM}network: $other manages it here (the bar's Wi-Fi click opens nmtui, which needs NetworkManager)${N}"
  elif [[ $(systemctl is-enabled NetworkManager.service 2>/dev/null || true) != enabled ]]; then
    unit_enable_system NetworkManager.service
  fi
  if [[ $(systemctl is-enabled bluetooth.service 2>/dev/null || true) != enabled ]] && [[ -d /sys/class/bluetooth ]]; then
    unit_enable_system bluetooth.service
  fi
}

# Deselected: give the login back, turn off what rig turned on.
desktop_teardown() {
  if ledger_has etc-file "$GREETD_CONFIG"; then
    if [[ $(ledger_last system-unit greetd.service) != enabled ]] && [[ -n $(ledger_last system-unit greetd.service) ]]; then
      warn "greetd was your login screen; it's off from the next boot (log in on the console, or enable another display manager)"
      sudo_ systemctl disable greetd.service 2>/dev/null || true
    fi
    etc_file_restore "$GREETD_CONFIG"
  fi
  local u; for u in NetworkManager.service bluetooth.service; do
    if [[ -n $(ledger_last system-unit "$u") && $(ledger_last system-unit "$u") != enabled ]]; then
      sudo_ systemctl disable --now "$u" 2>/dev/null || true
    fi
  done
}

desktop_doctor() {
  module_active desktop || return 0
  info "desktop (Hyprland)"
  if ! have Hyprland; then check_bad "Hyprland not installed (rig sync)"; return 0; fi
  local out; out=$(XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-$(mktemp -d)} Hyprland --verify-config 2>&1 | sed -n '/Config parsing result/,$p' | tail -n +3)
  if [[ $out == *"config ok"* ]]; then check_ok "Hyprland $(Hyprland --version 2>/dev/null | awk 'NR==1 {print $2}'): config ok"
  else check_bad "Hyprland config: $(head -n 3 <<<"$out" | tr '\n' ' ')"; fi
  if desktop_has_login_manager || systemctl is-enabled greetd.service >/dev/null 2>&1; then check_ok "a login screen offers Hyprland"
  else check_bad "no login screen (rig modules sync desktop)"; fi
}

# ------------------------------------------------------------- /etc files -----
# A file under /etc that rig writes: the original is copied into the ledger's
# backup first and put back on undo ("none": rig created it, so it's removed).
etc_file_write() { # path content
  local path=$1 backup="$RIG_STATE/etc-backup${1}"
  if ! ledger_has etc-file "$path"; then
    if [[ -e $path ]]; then
      mkdir -p "$(dirname "$backup")" && sudo_ cat "$path" >"$backup"
      ledger_record etc-file "$path" "$backup"
    else
      ledger_record etc-file "$path" none
    fi
  fi
  sudo_ mkdir -p "$(dirname "$path")"
  printf '%s\n' "$2" | sudo_ tee "$path" >/dev/null
}
etc_file_restore() { # path
  local prev; prev=$(ledger_last etc-file "$1")
  [[ -n $prev ]] || return 0
  revert_etc_file "$1" "$prev"
}
revert_etc_file() { # path backup|none
  if [[ $2 == none ]]; then sudo_ rm -f "$1" && ok "removed $1 (rig created it)"
  elif [[ -f $2 ]]; then sudo_ tee "$1" <"$2" >/dev/null && ok "restored $1"; fi
}

# local.lua: this machine's monitors, keyboard and overrides (not in the repo)
desktop_local() { printf '%s/hypr/local.lua' "$CONFIG_HOME"; }
desktop_export() { local_file_export "$1" "$(desktop_local)"; }
desktop_exported() { local_file_exported "$1" "$(desktop_local)"; }
desktop_import() { local_file_import "$1" "$(desktop_local)"; }

desktop_cmd() {
  load_machine; ledger_init
  case ${1:-sync} in
    sync) desktop_sync ;;
    *) die "usage: rig desktop sync" ;;
  esac
}
