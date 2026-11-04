# shellcheck shell=bash
# rig runtimes / homelab. Sourced by rig.

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# ------------------------------------------------------------- runtimes -------
# Data folders rig creates for a runtime are recorded (runtime-dir), so
# deselecting (with confirmation) and uninstall --runtimes only delete what rig made.
runtime_dirs() {
  case $1 in
    node) echo "$DATA_HOME/fnm" ;;
    go) echo "$DATA_HOME/go" ;;
    rust) echo "$DATA_HOME/rustup $DATA_HOME/cargo" ;;
  esac
}
note_runtime_dirs() {
  local d
  for d in $(runtime_dirs "$1"); do
    if [[ ! -e $d ]] && ! grep -q "^runtime-dir	$d	" "$RIG_STATE/system.log"; then
      printf '%s\t%s\t%s\t%s\n' runtime-dir "$d" created "$(now)" >>"$RIG_STATE/system.log"
    fi
  done
}
runtime_purge() {
  local d
  for d in $(runtime_dirs "$1"); do
    if grep -q "^runtime-dir	$d	created" "$RIG_STATE/system.log" && [[ -e $d ]]; then
      confirm "Delete $d ($1, no longer needed)?" && rm -rf "$d" && ok "deleted $d"
    fi
  done
}

with_node() { if have fnm; then eval "$(fnm env --shell bash)"; fi; }

cmd_runtimes() {
  load_machine; ledger_init
  case ${1:-sync} in
    sync)
      local r
      for r in $RIG_RUNTIMES; do
        note_runtime_dirs "$r"
        case $r in
          node)
            have fnm || { warn "fnm missing (rig sync)"; continue; }
            with_node
            if ! fnm list 2>/dev/null | grep -q 'default'; then
              info "installing Node LTS with fnm"
              fnm install --lts && fnm default lts-latest
            fi
            ok "node $(fnm exec --using default node --version 2>/dev/null || echo '?')" ;;
          go) have go && ok "$(go version | cut -d' ' -f3)" || warn "go missing (rig sync)" ;;
          rust)
            export RUSTUP_HOME="$DATA_HOME/rustup" CARGO_HOME="$DATA_HOME/cargo"
            have rustup || { warn "rustup missing (rig sync)"; continue; }
            if ! rustup toolchain list 2>/dev/null | grep -q stable; then
              info "installing the stable Rust toolchain"
              rustup default stable
            fi
            rustup component add rustfmt clippy rust-analyzer >/dev/null
            ok "rust $(rustup run stable rustc --version 2>/dev/null | cut -d' ' -f2) + rustfmt, clippy, rust-analyzer" ;;
        esac
      done
      [[ -n $RIG_RUNTIMES ]] || ok "no runtimes needed" ;;
    list) say "  ${RIG_RUNTIMES:-none}" ;;
    *) die "usage: rig runtimes sync|list" ;;
  esac
}

# ------------------------------------------------------------- homelab --------
cmd_homelab() {
  load_machine; ledger_init
  [[ " $RIG_SELECTED " == *" tailscale "* ]] || return 0
  if [[ $(uname) == Darwin ]]; then
    have tailscale || [[ -d /Applications/Tailscale.app ]] || { warn "Tailscale isn't installed yet"; return 0; }
    say "  Tailscale on macOS: open the Tailscale app once and log in (it then starts at login)"
    return 0
  fi
  have tailscale || { warn "tailscale isn't installed yet (rig sync)"; return 0; }
  if have systemctl && [[ -d /run/systemd/system ]]; then
    local prev; prev=$(systemctl is-enabled tailscaled 2>/dev/null || true)
    if [[ $prev != enabled ]]; then
      info "enabling tailscaled"
      sudo_ systemctl enable --now tailscaled
      printf '%s\t%s\t%s\t%s\n' system-unit tailscaled "${prev:-disabled}" "$(now)" >>"$RIG_STATE/system.log"
    fi
  fi
  homelab_offer_import
  if tailscale status >/dev/null 2>&1; then
    ok "tailscale: on the tailnet as $(tailscale status --self --json 2>/dev/null | sed -n 's/.*"DNSName": *"\([^"]*\)".*/\1/p' | head -1)"
  elif { : </dev/tty; } 2>/dev/null; then
    info "logging this machine in to the tailnet (follow the link)"
    sudo_ tailscale up </dev/tty || warn "tailscale up didn't finish; run: sudo tailscale up"
  else
    say "  tailscale is installed but logged out; run: sudo tailscale up"
  fi
}

# After an apply: runtimes no longer needed by anything selected.
runtimes_cleanup() { # old-runtimes
  local r
  for r in $1; do [[ " $RIG_RUNTIMES " == *" $r "* ]] || runtime_purge "$r"; done
}

# With Tailscale selected: offer to import hosts into srv from a hosts file
# (srv's simple list or an Ansible inventory), once.
homelab_offer_import() {
  local hosts="${XDG_CONFIG_HOME:-$HOME/.config}/srv/hosts"
  have srv || return 0
  if [[ -f $hosts ]] && grep -qE $'\t(import|homelab)$' "$hosts"; then return 0; fi
  { : </dev/tty; } 2>/dev/null || { say "  ${DIM}srv: add your servers later with srv import <hosts file> (or srv add)${N}"; return 0; }
  say "  srv can mount your servers at ~/Servers/<host>. Import them from a hosts file?"
  say "  ${DIM}a simple list (see extras/srv-hosts.example) or an Ansible inventory; blank to skip${N}"
  local f
  if have gum; then f=$(gum input --placeholder "path to a hosts file or inventory (blank: skip)" </dev/tty || true)
  else printf '  file: ' >/dev/tty; IFS= read -r f </dev/tty || f=''; fi
  if [[ -n $f ]]; then srv import "$f" || warn "import failed; try again with: srv import <file>"; fi
}
