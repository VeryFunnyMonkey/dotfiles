# shellcheck shell=bash
# modules/git/accounts.sh: rig git list / which / remove / clone / doctor.

# ------------------------------------------------------------- list/which -----

# ------------------------------------------------------------- list/which -----
git_list() {
  local n any=0
  for n in $(identities); do
    any=1
    printf '  %s%-12s%s %-32s %-10s %s%s\n' "$B" "$n" "$N" "$(meta_get "$n" email)" "$(meta_get "$n" host)" \
      "$(meta_get "$n" folder | sed "s#^$HOME#~#")" "$([[ $(meta_get "$n" default) == yes ]] && echo '  (default)')"
  done
  ((any)) || say "  no git accounts yet: rig git add"
  if [[ -z $(default_identity) && $any == 1 ]]; then
    say "  ${DIM}no default account: repos that match no account refuse to commit (rig git default <account>)${N}"
  fi
}

git_which() {
  local email origin
  email=$(git config user.email 2>/dev/null || true)
  origin=$(git config --show-origin user.email 2>/dev/null | awk '{print $1}' | sed 's#^file:##')
  if [[ -z $email ]]; then bad "no identity here (rig git add, or move the repo into an account's folder)"; return 1; fi
  local n=${origin##*/}; n=${n%.gitconfig}
  ok "$email  (account: ${n:-?}, from ${origin/#$HOME/~})"
}

# ------------------------------------------------------------- remove ---------
git_remove() {
  load_machine; ledger_init
  local n=${1:-}; [[ -n $n && -f $ID_DIR/$n.meta ]] || die "usage: rig git remove <account> (see rig git list)"
  local host key hostname; host=$(meta_get "$n" host); key=$(meta_get "$n" key); hostname=$(meta_get "$n" hostname)
  confirm "Remove account '$n'? (its SSH key stays in ~/.ssh)" || return 0
  rm -f "$ID_DIR/$n.meta" "$ID_DIR/$n.gitconfig"
  git_regenerate
  ok "removed '$n'"
  if [[ -n $key ]]; then say "  key kept: $key"; fi
  if [[ $host != none ]]; then
    local hint; hint=$(host_field "$host" remove); hint=${hint//\{name\}/$n}
    say "  to remove the key from ${hostname:-$(host_field "$host" name)} too: $hint"
  fi
  # no accounts left on this host: offer to deselect its CLI
  local item; item=$(host_field "$host" cli)
  if [[ -n $item ]] && ! grep -lqs "^host=$host\$" "$ID_DIR"/*.meta 2>/dev/null && item_selected "$item"; then
    if confirm "No $(host_field "$host" name) accounts left. Deselect the $(host_field "$host" name) CLI on this machine?"; then
      cmd_del "$item"
    fi
  fi
}

# ------------------------------------------------------------- clone ----------

# ------------------------------------------------------------- clone ----------
git_clone() {
  local n=${1:-} url=${2:-}; [[ -n $n && -n $url ]] || die "usage: rig git clone <account> <url>"
  [[ -f $ID_DIR/$n.meta ]] || die "no account '$n' (rig git list)"
  local alias hostname folder path repo
  alias=$(meta_get "$n" alias); hostname=$(meta_get "$n" hostname); folder=$(meta_get "$n" folder)
  [[ -n $alias ]] || die "account '$n' has no hosting; clone normally"
  case $url in
    git@*:*) path=${url#*:} ;;
    https://*|http://*) path=${url#*://}; path=${path#*/} ;;
    *) path=$url ;;  # org/repo
  esac
  path=${path%.git}; repo=${path##*/}
  [[ $hostname == ssh.dev.azure.com && $url == https://* ]] && path="v3/${path/_git\//}"
  git clone "git@$alias:$path.git" "$folder/$repo" && ok "cloned into ${folder/#$HOME/~}/$repo as '$n'"
}

# ------------------------------------------------------------- test -----------
# rig git doctor: try every account's connection.
git_test() {
  local n fails=0
  [[ -n $(identities) ]] || { bad "no git accounts (rig git add)"; return 1; }
  for n in $(identities); do
    local host alias key; host=$(meta_get "$n" host); alias=$(meta_get "$n" alias); key=$(meta_get "$n" key)
    if [[ -n $key && ! -f $key ]]; then bad "$n: key missing ($key)"; ((fails++)) || true; continue; fi
    if [[ -n $alias ]]; then
      if ssh_check "$alias" "$host"; then ok "$n: $alias works"; else bad "$n: $alias refused the key (ssh -T git@$alias)"; ((fails++)) || true; fi
    else ok "$n: local identity ($(meta_get "$n" email))"; fi
  done
  ((fails == 0))
}
