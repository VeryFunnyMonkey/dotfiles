# shellcheck shell=bash
# modules/shell.sh: zsh as the login shell (the previous one is recorded and
# restored on uninstall), and zsh's own data: the plugins chezmoi fetches and
# the completion cache.

login_shell() {
  if is_darwin; then dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}'
  else getent passwd "$USER" | cut -d: -f7; fi
}

shell_sync() {
  # Prefer a zsh /etc/shells already lists (e.g. /usr/bin/zsh), else whatever's on PATH.
  local zsh='' s current
  while IFS= read -r s; do
    if [[ $s == */zsh && -x $s ]]; then zsh=$s; break; fi
  done < <(grep -v '^#' /etc/shells 2>/dev/null)
  [[ -n $zsh ]] || zsh=$(command -v zsh || true)
  [[ -n $zsh ]] || { warn "zsh not found; skipping the login shell"; return 0; }
  current=$(login_shell)
  # Already a working zsh (on Arch /bin/zsh and /usr/bin/zsh are the same file)? Done.
  if [[ ${current##*/} == zsh && -x $current ]]; then return 0; fi
  if ! grep -qxF "$zsh" /etc/shells; then
    echo "$zsh" | sudo_ tee -a /etc/shells >/dev/null
    ledger_record etc-shells "$zsh" added
  fi
  info "changing login shell to $zsh"
  # macOS asks for your password; sudo (if it doesn't need one) works without.
  # If neither can, carry on: the login shell isn't worth failing the install.
  local changed=0
  if is_darwin; then
    if sudo -n true 2>/dev/null; then
      if sudo chsh -s "$zsh" "$USER"; then changed=1; fi
    elif can_ask; then
      if chsh -s "$zsh" </dev/tty; then changed=1; fi
    fi
  elif sudo_ chsh -s "$zsh" "$USER"; then changed=1
  fi
  if ((changed == 0)); then warn "couldn't change the login shell; run: chsh -s $zsh"; return 0; fi
  ledger_record shell "$USER" "$current"
}

shell_doctor() {
  info "shell"
  local login; login=$(login_shell)
  if [[ $login == *zsh ]]; then check_ok "login shell: $login"; else check_bad "login shell is $login (not zsh)"; fi
  if [[ -e $HOME/.zshenv ]]; then check_ok "$HOME/.zshenv in place"; else check_bad "$HOME/.zshenv missing"; fi
}

shell_reset() {
  confirm "Reset zsh plugins and the completion cache?" || return 0
  rm -rf "$DATA_HOME/zsh/plugins" "$CACHE_HOME/zsh/zcompdump"*
  chezmoi apply --refresh-externals=always
}

shell_uninstall() { rm -rf "$DATA_HOME/zsh/plugins" "$CACHE_HOME/zsh/zcompdump"*; }

revert_shell() { # user previous-shell
  if is_darwin; then chsh -s "$2" || warn "chsh failed"; else sudo_ chsh -s "$2" "$1" || warn "chsh failed"; fi
  ok "login shell back to $2"
}
revert_etc_shells() { # path
  sudo_ sed -i.bak "\#^$1\$#d" /etc/shells && ok "removed $1 from /etc/shells"
}

# local.zsh: this machine's own additions to zsh (not in the repo)
shell_local() { printf '%s/zsh/local.zsh' "$CONFIG_HOME"; }
shell_export() { local_file_export "$1" "$(shell_local)"; }
shell_exported() { local_file_exported "$1" "$(shell_local)"; }
shell_import() { local_file_import "$1" "$(shell_local)"; }
