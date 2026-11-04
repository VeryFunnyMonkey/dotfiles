# shellcheck shell=bash
# rig module / runtimes / homelab / agents. Sourced by rig.

MODULES_DIR() { printf '%s/.chezmoidata/modules' "$RIG_SOURCE_DIR"; }
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

all_modules() { find "$(MODULES_DIR)" -name '*.yaml' -exec basename {} .yaml \; 2>/dev/null | sort; }
module_on() { [[ " $RIG_MODULES " == *" $1 "* ]]; }
module_field() { # module field (simple one-line string fields)
  awk -v f="$2" '$1==f":" {sub(/^[^:]*: */,""); gsub(/^"|"$/,""); print; exit}' "$(MODULES_DIR)/$1.yaml"
}

# Set a module on/off in chezmoi's config ([data.modules] "name" = bool).
set_module() { # name true|false
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
  if grep -qE "^[[:space:]]*\"$1\" = " "$cfg"; then
    sed -i.bak -E "s/^([[:space:]]*)\"$1\" = .*/\1\"$1\" = $2/" "$cfg"
  else
    sed -i.bak -E "s/^\[data\.modules\]$/[data.modules]\n    \"$1\" = $2/" "$cfg"
  fi
  rm -f "$cfg.bak"
}

reload_machine() { load_machine; }

cmd_module() {
  load_machine
  local sub=${1:-list}; (($#)) && shift
  case $sub in
    list|ls)
      local m
      for m in $(all_modules); do
        if module_on "$m"; then printf '  %s●%s %-12s %s\n' "$G" "$N" "$m" "$(module_field "$m" description)"
        else printf '  %s○ %-12s %s%s\n' "$DIM" "$m" "$(module_field "$m" description)" "$N"; fi
      done
      say "  ${DIM}rig module enable|disable <name> · rig module info <name>${N}" ;;
    info)
      local m=${1:-}; [[ -f $(MODULES_DIR)/$m.yaml ]] || die "no module '$m' (rig module list)"
      local doc; doc="$(repo_root)/docs/modules/$m.md"
      if [[ -f $doc ]]; then if have bat; then bat --style=plain --language=markdown "$doc"; else cat "$doc"; fi
      else say "$m: $(module_field "$m" description)"; fi ;;
    enable|on)
      local m=${1:-}; [[ -f $(MODULES_DIR)/$m.yaml ]] || die "no module '$m' (rig module list)"
      if module_on "$m"; then ok "$m is already on"; return 0; fi
      set_module "$m" true
      info "enabling $m"
      chezmoi apply && ok "$m enabled" ;;
    disable|off)
      local m=${1:-} purge=0; [[ ${2:-} == --purge || ${1:-} == --purge ]] && purge=1
      [[ $m == --purge ]] && m=${2:-}
      [[ -f $(MODULES_DIR)/$m.yaml ]] || die "no module '$m' (rig module list)"
      if ! module_on "$m"; then ok "$m is already off"; return 0; fi
      local before=$RIG_RUNTIMES
      set_module "$m" false
      info "disabling $m"
      chezmoi apply
      load_machine
      ok "$m disabled (its packages stay installed: rig drift lists them, rig remove takes them out)"
      if ((purge)); then
        local r
        for r in $before; do [[ " $RIG_RUNTIMES " == *" $r "* ]] || runtime_purge "$r"; done
      fi ;;
    *) die "usage: rig module list|info|enable|disable [--purge] <name>" ;;
  esac
}

# ------------------------------------------------------------- runtimes -------
# Data folders rig creates for a runtime are recorded (runtime-dir), so
# --purge and uninstall --runtimes only delete what rig made.
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
  module_on homelab || return 0
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
  if tailscale status >/dev/null 2>&1; then
    ok "tailscale: on the tailnet as $(tailscale status --self --json 2>/dev/null | sed -n 's/.*"DNSName": *"\([^"]*\)".*/\1/p' | head -1)"
  elif { : </dev/tty; } 2>/dev/null; then
    info "logging this machine in to the tailnet (follow the link)"
    sudo_ tailscale up </dev/tty || warn "tailscale up didn't finish; run: sudo tailscale up"
  else
    say "  tailscale is installed but logged out; run: sudo tailscale up"
  fi
}
