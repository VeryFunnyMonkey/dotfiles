# shellcheck shell=bash
# modules/runtimes.sh: shared toolchains (node, go, rust) that items declare
# with `needs:` (.chezmoidata/runtimes.yaml). Installed while something needs
# them; their data folders are recorded when rig creates them, so deselecting
# (with confirmation) and uninstall --runtimes only delete what rig made.

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
    if [[ ! -e $d ]] && ! ledger_has runtime-dir "$d"; then ledger_record runtime-dir "$d" created; fi
  done
}
runtime_purge() {
  local d
  for d in $(runtime_dirs "$1"); do
    if ledger_has runtime-dir "$d" created && [[ -e $d ]]; then
      if confirm "Delete $d ($1, no longer needed)?"; then rm -rf "$d" && ok "deleted $d"; fi
    fi
  done
}

with_node() { if have fnm; then eval "$(fnm env --shell bash)"; fi; }

runtimes_sync() {
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
      go) if have go; then ok "$(go version | cut -d' ' -f3)"; else warn "go missing (rig sync)"; fi ;;
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
  [[ -n $RIG_RUNTIMES ]] || ok "no runtimes needed"
  # no longer needed by anything selected: offer to delete what rig created
  for r in node go rust; do in_list "$r" "$RIG_RUNTIMES" || runtime_purge "$r"; done
}

runtimes_update() {
  if in_list rust "$RIG_RUNTIMES" && have rustup; then
    info "rust"
    RUSTUP_HOME="$DATA_HOME/rustup" rustup update >/dev/null && ok "rust toolchain updated"
  fi
}

runtimes_doctor() {
  info "runtimes"
  check_ok "${RIG_RUNTIMES:-none needed}"
}

# rig uninstall --runtimes: the data folders rig created
runtimes_uninstall() {
  [[ ${UNINSTALL_RUNTIMES:-0} == 1 ]] || return 0
  local d
  while IFS= read -r d; do
    if [[ -e $d ]]; then rm -rf "$d" && ok "deleted runtime data $d"; fi
  done < <(ledger_keys runtime-dir created)
}
revert_runtime_dir() { :; }   # deleted by --runtimes (above)

runtimes_cmd() {
  load_machine; ledger_init
  case ${1:-sync} in
    sync) runtimes_sync ;;
    list) say "  ${RIG_RUNTIMES:-none}" ;;
    *) die "usage: rig runtimes sync|list" ;;
  esac
}
