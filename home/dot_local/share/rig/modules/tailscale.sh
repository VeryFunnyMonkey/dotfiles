# shellcheck shell=bash
# modules/tailscale.sh: Tailscale running and logged in (the tailscale item:
# `module: tailscale`).

tailscale_sync() {
  module_active tailscale || return 0
  if is_darwin; then
    have tailscale || [[ -d /Applications/Tailscale.app ]] || { warn "Tailscale isn't installed yet"; return 0; }
    say "  Tailscale on macOS: open the Tailscale app once and log in (it then starts at login)"
    return 0
  fi
  have tailscale || { warn "tailscale isn't installed yet (rig sync)"; return 0; }
  if have_system_systemd && [[ $(systemctl is-enabled tailscaled 2>/dev/null || true) != enabled ]]; then
    info "enabling tailscaled"
    unit_enable_system tailscaled
  fi
  if tailscale status >/dev/null 2>&1; then
    ok "tailscale: on the tailnet as $(tailscale status --self --json 2>/dev/null | sed -n 's/.*"DNSName": *"\([^"]*\)".*/\1/p' | head -1)"
  elif can_ask; then
    info "logging this machine in to the tailnet (follow the link)"
    sudo_ tailscale up </dev/tty || warn "tailscale up didn't finish; run: sudo tailscale up"
  else
    say "  tailscale is installed but logged out; run: sudo tailscale up"
  fi
}

tailscale_doctor() {
  module_active tailscale && have tailscale || return 0
  info "tailscale"
  if tailscale status >/dev/null 2>&1; then check_ok "tailscale connected"; else check_bad "tailscale logged out (sudo tailscale up)"; fi
}

tailscale_cmd() {
  load_machine; ledger_init
  case ${1:-sync} in
    sync) tailscale_sync ;;
    *) die "usage: rig tailscale sync" ;;
  esac
}
