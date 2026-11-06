# shellcheck shell=bash
# modules/git.sh: git accounts ("identities"): the module's hooks and the
# rig git command. The parts: modules/git/identities.sh (the files),
# add.sh (the walkthrough), accounts.sh (list, remove, clone, ...),
# hosts.sh (GitHub, GitLab, ... and how to connect to each).
#
# Everything here is machine-local; nothing personal goes in the repo.
#   ~/.config/git/identities/<name>.gitconfig   name, email, key, signing
#   ~/.config/git/identities/<name>.meta        host, folder, alias, ...
#   ~/.config/git/identities.gitconfig          generated: which identity applies where
#   ~/.config/git/allowed_signers               generated: verifies signed commits
#   ~/.ssh/config.d/rig-git                     generated: one host alias per account
#   ~/.ssh/config.d/00-rig                      AddKeysToAgent (+ Keychain on macOS)

GIT_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/git"
ID_DIR="$GIT_CFG/identities"
SSH_DIR="$HOME/.ssh"

# ------------------------------------------------------------- module hooks ---
git_sync() { git_setup; }

git_doctor() {
  info "git"
  if [[ -n $(identities) ]]; then
    local ids def; ids=$(identities | tr '\n' ' '); def=$(default_identity)
    check_ok "accounts: $ids$(if [[ -n $def ]]; then printf '(default: %s)' "$def"; else printf '(no default)'; fi)"
    say "  ${DIM}rig git doctor tests each account's connection${N}"
  else
    check_bad "no git accounts yet (rig git add)"
  fi
  git_global_written
}

# `git config --global` (yours, or a tool's: gh auth setup-git, an editor)
# writes ~/.config/git/config, which is rig's (a link into the repo): git
# swaps the link for a file of its own, and rig's git config stops reaching
# this machine. Say what was added, and where it belongs.
git_global_written() {
  local cfg="$GIT_CFG/config" repo; repo="$(src_dir)/dot_config/git/config"
  [[ -e $cfg && ! -L $cfg && -f $repo ]] || return 0
  check_bad "rig's git config (~/.config/git/config) was replaced: something ran git config --global"
  local added; added=$(comm -13 <(git config -f "$repo" --list | sort) <(git config -f "$cfg" --list | sort))
  if [[ -n $added ]]; then
    say "  what it added (this machine's settings belong in ~/.config/git/local.gitconfig):"
    printf '%s\n' "$added" | sed 's/^/    /'
  fi
  say "  to fix: git config -f ~/.config/git/local.gitconfig <name> <value> for each line above, then:"
  say "    rm ~/.config/git/config && chezmoi apply ~/.config/git/config"
}

# rig uninstall --identities: rig-created keys are archived, never deleted
git_uninstall() {
  [[ ${UNINSTALL_IDENTITIES:-0} == 1 ]] || return 0
  info "removing git accounts"
  local key archive_dir; archive_dir="$HOME/rig-uninstall-keys-$(date +%Y%m%d-%H%M%S)"
  while IFS= read -r key; do
    [[ -f $key ]] || continue
    mkdir -p "$archive_dir" && mv "$key" "$key.pub" "$archive_dir/" 2>/dev/null && ok "moved rig-created key ${key/#$HOME/~} to $archive_dir"
  done < <(ledger_keys ssh-key-created)
  rm -rf "$ID_DIR" "$GIT_CFG/identities.gitconfig" "$GIT_CFG/allowed_signers" "$SSH_DIR/config.d/rig-git"
  ok "removed git accounts"
}

revert_ssh_key_created() { :; }   # keys are archived by --identities, never deleted
revert_ssh_include() { # ~/.ssh/config, created|added
  if [[ $2 == created ]]; then
    rm -f "$1" && ok "removed $1 (rig created it)"
  elif [[ -f $1 ]]; then
    awk 'NR==1 && $0=="Include config.d/*" {skip=1; next} skip && NR==2 && $0=="" {next} {print}' "$1" >"$1.new" && mv "$1.new" "$1"
    ok "removed rig's Include line from $1"
  fi
  rm -f "$HOME/.ssh/config.d/00-rig"; rmdir "$HOME/.ssh/config.d" 2>/dev/null || true
}

git_cmd() {
  local sub=${1:-list}; (($#)) && shift
  case $sub in
    add) git_add "$@" ;;
    setup) git_setup "$@" ;;
    list|ls) git_list ;;
    which) git_which ;;
    remove|rm) git_remove "$@" ;;
    clone) git_clone "$@" ;;
    doctor|test) git_test ;;
    default) load_machine; git_set_default "$@" ;;
    *) die "usage: rig git add|list|which|remove|clone|default|doctor" ;;
  esac
}
