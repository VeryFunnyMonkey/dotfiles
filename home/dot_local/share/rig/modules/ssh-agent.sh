# shellcheck shell=bash
# modules/ssh-agent.sh: an SSH agent per login, so a key's passphrase is asked
# once. Linux (and WSL with systemd): the systemd user socket. Without systemd
# (WSL without it): zsh starts one ssh-agent and shares it (.zshrc). macOS
# uses its own agent + Keychain (set in ~/.ssh/config.d/00-rig by the git module).

ssh_agent_sync() {
  is_darwin && return 0
  if ! have_user_systemd; then return 0; fi   # zsh starts the agent instead (.zshrc)
  if [[ -z $(systemctl --user list-unit-files ssh-agent.socket --no-legend 2>/dev/null) ]]; then
    warn "this distro has no ssh-agent.socket user unit; skipping"; return 0
  fi
  if [[ $(systemctl --user is-enabled ssh-agent.socket 2>/dev/null || true) != enabled ]]; then
    unit_enable_user ssh-agent.socket
    ok "enabled the ssh-agent socket (new shells pick it up)"
  fi
}

ssh_agent_doctor() {
  info "ssh agent"
  local how
  case ${SSH_AUTH_SOCK:-} in
    */ssh-agent.socket) how="systemd's socket" ;;
    */ssh-agent.zsh.sock | */.ssh/agent.sock) how="started by zsh (no systemd here)" ;;
    *launchd*) how="macOS (Keychain)" ;;
    *) how=${SSH_AUTH_SOCK:-} ;;
  esac
  if [[ -n ${SSH_AUTH_SOCK:-} ]] && { ssh-add -l >/dev/null 2>&1; (($? != 2)); }; then
    check_ok "agent reachable: $how"
  elif is_darwin || ! have_user_systemd; then
    check_bad "no ssh agent reachable (open a new shell: zsh starts one)"
  else
    check_bad "no ssh agent reachable (open a new shell; else: systemctl --user status ssh-agent.socket)"
  fi
}
