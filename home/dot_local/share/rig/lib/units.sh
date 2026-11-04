# shellcheck shell=bash
# lib/units.sh: systemd units rig enables. Each is recorded with its previous
# state, so deselecting or uninstalling disables only what rig turned on.

have_user_systemd() { have systemctl && systemctl --user show-environment >/dev/null 2>&1; }
have_system_systemd() { have systemctl && [[ -d /run/systemd/system ]]; }

unit_enable_user() { # unit
  local prev; prev=$(systemctl --user is-enabled "$1" 2>/dev/null || true)
  if [[ $prev == enabled ]]; then return 0; fi
  systemctl --user enable --now "$1"
  ledger_record user-unit "$1" "${prev:-disabled}"
}
unit_enable_system() { # unit
  local prev; prev=$(systemctl is-enabled "$1" 2>/dev/null || true)
  if [[ $prev == enabled ]]; then return 0; fi
  sudo_ systemctl enable --now "$1"
  ledger_record system-unit "$1" "${prev:-disabled}"
}
# Turn off a unit rig enabled (its item was deselected). The record stays, so
# an uninstall later is still correct.
unit_release_user() { # unit
  local prev; prev=$(ledger_last user-unit "$1")
  if [[ -n $prev && $prev != enabled ]]; then systemctl --user disable --now "$1" 2>/dev/null || true; fi
}

revert_user_unit() { # unit previous
  if [[ $2 != enabled ]]; then systemctl --user disable --now "$1" 2>/dev/null || true; ok "disabled $1"; fi
}
revert_system_unit() { # unit previous
  if [[ $2 != enabled ]]; then sudo_ systemctl disable --now "$1" 2>/dev/null || true; ok "disabled $1"; fi
}
