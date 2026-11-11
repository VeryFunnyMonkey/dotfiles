# shellcheck shell=bash
# commands/uninstall.sh: rig uninstall puts the machine back as it was before
# rig. Order: archive everything; each module undoes its part
# (<module>_uninstall); the ledger's system changes are reverted; managed
# files go and the originals come back; then packages and rig itself.

cmd_uninstall() {
  UNINSTALL_PACKAGES=0 UNINSTALL_RUNTIMES=0 UNINSTALL_IDENTITIES=0 UNINSTALL_AGENTS=0
  local dry=1 restore=''
  while (($#)); do
    case $1 in
      --packages) UNINSTALL_PACKAGES=1 ;;
      --runtimes) UNINSTALL_RUNTIMES=1 ;;
      --identities) UNINSTALL_IDENTITIES=1 ;;
      --agents) UNINSTALL_AGENTS=1 ;;
      --everything) UNINSTALL_PACKAGES=1 UNINSTALL_RUNTIMES=1 UNINSTALL_IDENTITIES=1 UNINSTALL_AGENTS=1 ;;
      --yes) RIG_YES=1 ;;
      --run) dry=0 ;;
      --dry-run) dry=1 ;;
      --restore) restore=$2; shift ;;
      *) die "unknown option $1" ;;
    esac
    shift
  done
  [[ -n $restore ]] && { uninstall_restore "$restore"; return; }
  if [[ ${RIG_YES:-0} == 1 ]]; then dry=0; fi
  load_machine; ledger_init

  local managed dirs
  managed=$(chezmoi managed --include=files,symlinks --path-style=absolute 2>/dev/null || true)
  dirs=$(chezmoi managed --include=dirs --path-style=absolute 2>/dev/null | sort -r || true)
  uninstall_plan "$managed"
  if ((dry)); then say; say "${DIM}dry run; to do it: rig uninstall --run [flags]${N}"; return 0; fi
  confirm "Go ahead?" || return 0

  local archive; archive="$HOME/rig-uninstall-$(date +%Y%m%d-%H%M%S).tar.gz"
  uninstall_archive "$archive" "$managed"

  modules_run uninstall
  info "reverting system changes"
  ledger_revert_all

  info "removing managed files"
  while IFS= read -r f; do [[ -n $f ]] && { [[ -e $f || -L $f ]] && rm -f "$f"; }; done <<<"$managed"
  while IFS= read -r d; do [[ -n $d && -d $d ]] && rmdir "$d" 2>/dev/null || true; done <<<"$dirs"
  info "restoring original files"
  backup_restore_all

  if ((UNINSTALL_PACKAGES)); then info "uninstalling packages rig added"; pkg_uninstall_all; fi
  if ((UNINSTALL_RUNTIMES)) && ledger_has brew-installed homebrew && [[ $(uname) == Linux ]]; then
    info "removing Homebrew on Linux (rig installed it)"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || warn "brew uninstall failed"
    rm -rf "$HOME/.homebrew" "$CACHE_HOME/Homebrew"
  fi

  info "deleting rig's data (keeping your shell history and nvim history/undo)"
  chezmoi_forget
  # chezmoi itself, if install.sh installed it (rig no longer needs it)
  local czbin; czbin=$(ledger_keys chezmoi-installed | tail -n1)
  if [[ -n $czbin && -x $czbin ]]; then rm -f "$czbin" && ok "removed chezmoi (install.sh installed it)"; fi
  rm -rf "$RIG_CONFIG" "$RIG_STATE"
  prune_empty "$DATA_HOME/fonts" "$DATA_HOME/zsh" "$DATA_HOME/nvim/site/pack" "$DATA_HOME/nvim/site" "$DATA_HOME/nvim" \
    "$CACHE_HOME/zsh" "$CACHE_HOME/nvim" "$STATE_HOME/zsh" "$STATE_HOME/nvim" "$DATA_HOME" "$CACHE_HOME" "$STATE_HOME" \
    "$CONFIG_HOME/git" "$CONFIG_HOME" "$HOME/.local/bin" "$HOME/.local"
  ok "uninstalled. Archive: $archive (rig uninstall --restore needs rig; or: tar -xzf it -C ~)"
  say "  ${DIM}open a new terminal to get your previous shell setup${N}"
}

uninstall_plan() { # managed files
  info "rig uninstall will:"
  say "  1. remove $(wc -l <<<"$1" | tr -d ' ') managed files and put back $(backup_count) original(s) from the first apply"
  say "  2. revert $(ledger_count) system change(s):"
  sed 's/^/       /' "$RIG_STATE/system.log"
  say "  3. unmount servers (srv), then delete rig's data: zsh plugins, nvim plugins/parsers/Mason, srv's hosts, chezmoi config and state"
  if ((UNINSTALL_PACKAGES)); then
    say "  4. uninstall packages rig installed (not ones that were already there):"
    awk -F'\t' '$4=="installed" {print "       " $1 ": " $2}' "$RIG_STATE/packages.log"
  else say "  4. keep all packages (--packages to remove the ones rig added)"; fi
  if ((UNINSTALL_RUNTIMES)); then say "     + runtimes rig installed (Homebrew on Linux, if rig installed it)"; fi
  if ((UNINSTALL_IDENTITIES)); then say "     + git identities (SSH keys are archived, never deleted)"; fi
  if ((UNINSTALL_AGENTS)); then say "     + coding agents rig installed"; fi
  say "  Kept always: the repo ($(repo_root)), your SSH keys, Tailscale login."
}

uninstall_archive() { # archive managed-files
  info "archiving to $1"
  {
    printf '%s\n' "$2"
    printf '%s\n' "$RIG_STATE" "$RIG_CONFIG" "$CONFIG_HOME/chezmoi"
  } | sed "s#^$HOME/##" | while IFS= read -r p; do [[ -e $HOME/$p || -L $HOME/$p ]] && printf '%s\n' "$p"; done \
    | tar -czf "$1" -C "$HOME" -T - 2>/dev/null || warn "archive incomplete"
}

chezmoi_forget() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi" def="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"
  rm -rf "$cfg" "${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi"
  # Only delete the source if it's chezmoi's own clone with nothing unpushed.
  if [[ -d $def/.git ]]; then
    if [[ -z $(git -C "$def" status --porcelain) ]] && [[ -z $(git -C "$def" log '@{u}..' --oneline 2>/dev/null || echo x) ]]; then
      rm -rf "$def"
    else warn "kept $def: it has local changes or unpushed commits"; fi
  fi
}

uninstall_restore() {
  [[ -f $1 ]] || die "no such archive: $1"
  confirm "Restore everything in $1 into ~ (overwrites those paths)?" || return 0
  tar -xzf "$1" -C "$HOME" && ok "restored; run chezmoi apply (or chezmoi init) to resume"
}

# Core ledger kinds handled above rather than replayed
revert_brew_installed() { :; }      # with --runtimes, after the packages
revert_chezmoi_installed() { :; }   # last of all
