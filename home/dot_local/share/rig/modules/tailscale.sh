# shellcheck shell=bash
# modules/tailscale.sh: Tailscale running and logged in (the tailscale item:
# `module: tailscale`), and a one-time offer to import servers into srv.

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
  tailscale_offer_import
  if tailscale status >/dev/null 2>&1; then
    ok "tailscale: on the tailnet as $(tailscale status --self --json 2>/dev/null | sed -n 's/.*"DNSName": *"\([^"]*\)".*/\1/p' | head -1)"
  elif can_ask; then
    info "logging this machine in to the tailnet (follow the link)"
    sudo_ tailscale up </dev/tty || warn "tailscale up didn't finish; run: sudo tailscale up"
  else
    say "  tailscale is installed but logged out; run: sudo tailscale up"
  fi
}

# With Tailscale selected: offer to import hosts into srv from a hosts file
# (srv's simple list or an Ansible inventory), once.
tailscale_offer_import() {
  local hosts="${XDG_CONFIG_HOME:-$HOME/.config}/srv/hosts"
  have srv || return 0
  if [[ -f $hosts ]] && grep -qE $'\t(import|homelab)$' "$hosts"; then return 0; fi
  can_ask || { say "  ${DIM}srv: add your servers later with srv import <hosts file> (or srv add)${N}"; return 0; }
  say "  srv can mount your servers at ~/Servers/<host>. Import them from a hosts file?"
  say "  ${DIM}a simple list (see extras/srv-hosts.example) or an Ansible inventory; blank to skip${N}"
  local f
  if have gum; then f=$(gum input --placeholder "path to a hosts file or inventory (blank: skip)" </dev/tty || true)
  else printf '  file: ' >/dev/tty; IFS= read -r f </dev/tty || f=''; fi
  if [[ -n $f ]]; then srv import "$f" || warn "import failed; try again with: srv import <file>"; fi
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
