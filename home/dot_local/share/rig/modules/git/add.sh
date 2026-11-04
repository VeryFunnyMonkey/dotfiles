# shellcheck shell=bash
# modules/git/add.sh: the walkthrough that sets up one account (rig git add),
# the first-run offer from setup, and moving accounts to another machine
# (rig export / rig import).

# ------------------------------------------------------------- add ------------
git_add() {
  load_machine; ledger_init; tty_in
  local n="${1:-}" gname email host hostname='' folder key='' sign=yes is_default=no
  local existing; existing=$(identities)
  local first_default=personal

  say; info "${B}new git account${N}"
  local ndef=''; if [[ -z $existing ]]; then ndef=$first_default; fi
  # A wrong answer asks again; a blank one (with no default) cancels, so the
  # setup menu gets control back instead of rig exiting.
  if [[ -z $n ]]; then ask n "Name for this account (e.g. personal, github-2; blank to cancel)" "$ndef"; fi
  n=$(printf '%s' "$n" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9_-')
  if [[ -z $n ]]; then say "  cancelled"; return 1; fi
  if [[ -f $ID_DIR/$n.meta ]]; then confirm "Account '$n' exists; set it up again?" || return 0; fi

  ask gname "Your name in commits" "$(git config --global user.name 2>/dev/null || true)"
  while :; do
    ask email "Email for this account (blank to cancel)" "$(meta_get "$n" email)"
    if [[ -z $email ]]; then say "  cancelled"; return 1; fi
    if [[ $email == *@* ]]; then break; fi
    say "  that doesn't look like an email"
  done

  local choices=() h
  for h in $(git_hosts); do choices+=("$(printf '%-10s %s' "$h" "$(host_field "$h" label)")"); done
  choose host "Where is this account hosted?" 1 "${choices[@]}" \
    "none       no hosting: just a name and email for commits"
  if [[ $host != none ]]; then
    if [[ -n $(host_field "$host" prompt) ]]; then ask hostname "$(host_field "$host" prompt)" "$(host_field "$host" hostname)"
    else hostname=$(host_field "$host" hostname); fi
  fi
  if [[ $host != none && -z $hostname ]]; then say "  cancelled"; return 1; fi

  local fdef="$HOME/Projects/$n"; [[ -z $existing ]] && fdef="$HOME/Projects"
  local fprev; fprev=$(meta_get "$n" folder)
  ask folder "Folder whose repos use this account" "${fprev:-$fdef}"
  folder=${folder/#\~/$HOME}

  # default account: used for repos that match no account's folder or alias
  local cur_def; cur_def=$(default_identity)
  if [[ -z $cur_def ]]; then
    ask_yn "Make '$n' the default account (used for repos that match no other)?" y && is_default=yes
  elif [[ $cur_def == "$n" ]]; then is_default=yes
  fi

  # key
  if [[ $host != none ]] || ask_yn "Sign commits with an SSH key anyway?" n; then
    local keys=() k ktype; ktype=$(host_field "$host" key); ktype=${ktype:-ed25519}
    local new="$SSH_DIR/id_${ktype}_$n"
    while IFS= read -r k; do [[ ${k%.pub} != "$new" ]] && keys+=("${k%.pub}"); done < <(find "$SSH_DIR" -maxdepth 1 -name '*.pub' 2>/dev/null | sort)
    key=new
    ((${#keys[@]})) && choose key "SSH key for this account" 1 "new  (create ${new/#$HOME/~})" "${keys[@]}"
    if [[ $key == new ]]; then key=$new; fi
    if [[ $(host_field "$host" signs) == no ]]; then sign=no
    elif ! ask_yn "Sign commits with this key? (shows as verified on the host)" y; then sign=no; fi
  else
    sign=no
  fi
  git_account_make "$n" "$gname" "$email" "$host" "$hostname" "$folder" "$is_default" "$key" "$sign"
}

# Set up an account from its answers: the key (created if it isn't there),
# its files, the host login and key upload, the connection check. key is a
# path, or blank for no key.
git_account_make() { # name gitname email host hostname folder default key sign
  local n=$1 gname=$2 email=$3 host=$4 hostname=$5 folder=$6 is_default=$7 key=$8 sign=$9 alias=''
  if [[ -n $hostname ]]; then alias="$hostname-$n"; fi
  mkdir -p "$folder"
  if [[ -n $key ]]; then
    if [[ ! -f $key ]]; then
      info "creating ${key/#$HOME/~}: pick a passphrase (the agent asks for it once per login)"
      mkdir -p "$SSH_DIR"; chmod 700 "$SSH_DIR"
      local kok=0
      if [[ $(host_field "$host" key) == rsa ]]; then ssh-keygen -q -t rsa -b 4096 -C "$email" -f "$key" </dev/tty && kok=1
      else ssh-keygen -q -t ed25519 -C "$email" -f "$key" </dev/tty && kok=1; fi
      if ((kok == 0)); then bad "the key wasn't created; nothing was saved"; return 1; fi
      ledger_record ssh-key-created "$key" -
    fi
    ensure_ssh_include
    ssh-add "$key" </dev/tty 2>/dev/null || true
  fi

  mkdir -p "$ID_DIR"
  {
    printf 'host=%s\nhostname=%s\nalias=%s\nfolder=%s\nkey=%s\nemail=%s\nsign=%s\ndefault=%s\n' \
      "$host" "$hostname" "$alias" "$folder" "$key" "$email" "$sign" "$is_default"
  } >"$ID_DIR/$n.meta"
  if [[ $is_default == yes ]]; then
    local o; for o in $(identities); do [[ $o != "$n" ]] && sed -i.bak 's/^default=yes$/default=no/' "$ID_DIR/$o.meta" && rm -f "$ID_DIR/$o.meta.bak"; done
  fi
  write_identity "$n" "$gname" "$email" "$key" "$sign" "$hostname"
  git_regenerate
  ok "account '$n' written"

  # connect the key to the host
  if [[ $host != none ]]; then
    if ! host_connect "$host" "$n" "$key" "$hostname"; then
      if [[ -n $(host_field "$host" cli) ]]; then warn "couldn't add the key with the $(host_field "$host" name) CLI; add it by hand instead"; fi
      key_manual "$host" "$hostname" "$key" "$sign"
    fi
  fi
  if [[ -n $alias ]]; then
    if ssh_check "$alias" "$host"; then ok "connection works (ssh git@$alias)"
    else warn "couldn't confirm the connection yet (check: ssh -T git@$alias); rig git doctor re-checks"; fi
  fi
  say
  say "  repos in ${folder/#$HOME/~} use '$n'; to clone elsewhere: rig git clone $n <url>"
}

# First-run loop, from the setup script. Skips quietly without a terminal.
git_setup() {
  load_machine
  if [[ -n $(identities) ]]; then return 0; fi
  can_ask || { say "rig: no terminal; set up git accounts later with: rig git add"; return 0; }
  tty_in
  say; info "${B}git accounts${N}"
  say "  Set up the git accounts this machine uses: name, email, SSH key, and the host login."
  ask_yn "Set one up now? (later: rig git add)" y || return 0
  while :; do
    git_add || true
    ask_yn "Add another account?" n || break
  done
}

# ------------------------------------------------------------- export/import --
# rig export: one file per account with its answers. Never the key (a new
# machine gets its own) or a token (the host's CLI logs in again).
git_export() { # dir
  local n f
  for n in $(identities); do
    f="$1/$n.account"
    {
      printf 'gitname=%s\n' "$(git config -f "$ID_DIR/$n.gitconfig" user.name 2>/dev/null || true)"
      printf 'email=%s\nhost=%s\nhostname=%s\n' "$(meta_get "$n" email)" "$(meta_get "$n" host)" "$(meta_get "$n" hostname)"
      local folder; folder=$(meta_get "$n" folder)
      printf 'folder=%s\n' "${folder/#$HOME/\~}"
      printf 'haskey=%s\nsign=%s\ndefault=%s\n' "$([[ -n $(meta_get "$n" key) ]] && echo yes || echo no)" "$(meta_get "$n" sign)" "$(meta_get "$n" default)"
    } >"$f"
  done
}
git_exported() { # dir -> one line: what's in it
  local f out=''; for f in "$1"/*.account; do [[ -f $f ]] && out+="${out:+, }$(basename "$f" .account)"; done
  if [[ -n $out ]]; then printf 'git accounts: %s (new keys here)\n' "$out"; fi
}
acct_get() { awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$1"; } # file key
# rig import: each account that isn't here yet is set up again from its
# answers, with a new key for this machine, uploaded the usual way.
git_import() { # dir
  load_machine; ledger_init; tty_in
  local f n host ktype key folder def
  for f in "$1"/*.account; do
    [[ -f $f ]] || continue
    n=$(basename "$f" .account)
    if [[ -f $ID_DIR/$n.meta ]]; then say "  git account '$n': already here, kept"; continue; fi
    host=$(acct_get "$f" host); key=''
    if [[ $(acct_get "$f" haskey) == yes ]]; then
      ktype=$(host_field "$host" key); key="$SSH_DIR/id_${ktype:-ed25519}_$n"
    fi
    folder=$(acct_get "$f" folder); folder=${folder/#\~/$HOME}
    def=$(acct_get "$f" default); [[ $def == yes && -n $(default_identity) ]] && def=no
    say; info "${B}git account '$n'${N} ($(acct_get "$f" email), ${host})"
    git_account_make "$n" "$(acct_get "$f" gitname)" "$(acct_get "$f" email)" "$host" "$(acct_get "$f" hostname)" "$folder" "$def" "$key" "$(acct_get "$f" sign)" ||
      warn "account '$n' wasn't set up; add it with: rig git add $n"
  done
}
