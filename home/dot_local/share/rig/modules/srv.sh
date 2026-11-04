# shellcheck shell=bash
# modules/srv.sh: server mounts (the srv command). rig's part: a one-time
# offer to import your servers, moving them with rig export/import, health,
# and unmounting plus removing srv's data on uninstall.

# Once per machine: import servers from a hosts file (a simple list, or an
# Ansible inventory). Skipped when hosts are already there; srv import works
# any time.
srv_sync() {
  local hosts="$CONFIG_HOME/srv/hosts" asked="$RIG_STATE/srv-import-offered"
  have srv || return 0
  if [[ -e $asked ]] || { [[ -f $hosts ]] && grep -qv '^\s*\(#\|$\)' "$hosts"; }; then return 0; fi
  can_ask || { say "  ${DIM}srv: add your servers later with srv import <hosts file> (or srv add)${N}"; return 0; }
  touch "$asked"
  say "  srv can mount your servers at ~/Servers/<host>. Import them from a hosts file?"
  say "  ${DIM}a simple list (see extras/srv-hosts.example) or an Ansible inventory; blank to skip${N}"
  local f
  if have gum; then f=$(gum input --placeholder "path to a hosts file or inventory (blank: skip)" </dev/tty || true)
  else printf '  file: ' >/dev/tty; IFS= read -r f </dev/tty || f=''; fi
  if [[ -n $f ]]; then srv import "${f/#\~/$HOME}" || warn "import failed; try again with: srv import <file>"; fi
}

srv_export() { # dir
  have srv || return 0
  local h; h=$(srv export)
  if [[ -n $h ]]; then printf '%s\n' "$h" >"$1/hosts"; fi
}
srv_exported() { if [[ -s $1/hosts ]]; then printf 'srv: %s servers\n' "$(grep -c . "$1/hosts")"; fi; }
srv_import() { # dir
  [[ -s $1/hosts ]] || return 0
  have srv || { warn "srv isn't installed yet; the servers weren't added"; return 0; }
  srv import --merge "$1/hosts"
  touch "$RIG_STATE/srv-import-offered"
}

srv_doctor() {
  have srv || return 0
  info "servers (srv)"
  local mnt; mnt=$(srv _status 2>/dev/null || true)
  check_ok "mounted: ${mnt:-none}"
}
srv_uninstall() {
  if have srv || [[ -x $HOME/.local/bin/srv ]]; then
    info "unmounting servers"
    "$HOME/.local/bin/srv" umount --all --force >/dev/null 2>&1 || true
  fi
  rm -rf "$CONFIG_HOME/srv" "$CACHE_HOME/srv" "$STATE_HOME/srv"
}
