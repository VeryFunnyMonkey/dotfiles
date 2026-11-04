# shellcheck shell=bash
# modules/srv.sh: server mounts (the srv command). rig's part: health, and
# unmounting plus removing srv's data on uninstall.

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
