# shellcheck shell=bash
# rig git: git accounts ("identities"). Sourced by rig; uses its helpers
# (say, info, ok, warn, bad, die, have, confirm, ledger_*, load_machine).
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

# ------------------------------------------------------------- prompts --------
tty_in() { exec 3</dev/tty || die "rig git needs a terminal"; }
ask() { # var prompt [default]
  local __v=$1 __p=$2 __d=${3:-} __r
  if [[ -n $__d ]]; then printf '  %s [%s]: ' "$__p" "$__d" >/dev/tty; else printf '  %s: ' "$__p" >/dev/tty; fi
  IFS= read -r __r <&3 || __r=""
  if [[ -z $__r ]]; then __r=$__d; fi
  printf -v "$__v" '%s' "$__r"
}
ask_yn() { # prompt default(y|n)
  local r d=${2:-n}
  printf '  %s [%s]: ' "$1" "$([[ $d == y ]] && echo Y/n || echo y/N)" >/dev/tty
  IFS= read -r r <&3 || r=""
  if [[ -z $r ]]; then r=$d; fi
  [[ $r == [yY]* ]]
}
choose() { # var prompt default option...
  local __v=$1 __p=$2 __d=$3 i=1 __r o; shift 3
  printf '  %s\n' "$__p" >/dev/tty
  for o in "$@"; do printf '    %d) %s\n' "$i" "$o" >/dev/tty; ((i++)); done
  while :; do
    printf '  choice [%s]: ' "$__d" >/dev/tty
    IFS= read -r __r <&3 || __r=""
    if [[ -z $__r ]]; then __r=$__d; fi
    if [[ $__r =~ ^[0-9]+$ ]] && ((__r >= 1 && __r <= $#)); then __r=${!__r}; fi
    for o in "$@"; do [[ $o == "$__r" ]] && { printf -v "$__v" '%s' "${o%% *}"; return; }; [[ ${o%% *} == "$__r" ]] && { printf -v "$__v" '%s' "$__r"; return; }; done
    printf '  pick one of the numbers above\n' >/dev/tty
  done
}

copy_clipboard() {
  if have pbcopy; then pbcopy
  elif have clip.exe; then clip.exe
  elif [[ -n ${WAYLAND_DISPLAY:-} ]] && have wl-copy; then wl-copy
  elif have xclip; then xclip -selection clipboard
  else return 1; fi
}
open_url() {
  if have wslview; then wslview "$1"
  elif have open && [[ $(uname) == Darwin ]]; then open "$1"
  elif have xdg-open; then xdg-open "$1" >/dev/null 2>&1
  else return 1; fi
}

# ------------------------------------------------------------- meta -----------
meta_get() { [[ -f $ID_DIR/$1.meta ]] || return 0; awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$ID_DIR/$1.meta"; }
identities() { [[ -d $ID_DIR ]] || return 0; find "$ID_DIR" -maxdepth 1 -name '*.meta' -exec basename {} .meta \; | sort; }
default_identity() { local n; for n in $(identities); do [[ $(meta_get "$n" default) == yes ]] && { echo "$n"; return; }; done; }

host_hostname() { case $1 in github) echo github.com ;; gitlab) echo gitlab.com ;; azure) echo ssh.dev.azure.com ;; bitbucket) echo bitbucket.org ;; esac; }
host_name() { case $1 in github) echo GitHub ;; gitlab) echo GitLab ;; gitea) echo Gitea/Forgejo ;; azure) echo "Azure DevOps" ;; bitbucket) echo Bitbucket ;; *) echo "the server" ;; esac; }
# the catalog item and command of a host's CLI (rig git uses it to log in and upload keys)
host_cli() { case $1 in github) echo "github gh" ;; gitlab) echo "gitlab glab" ;; gitea) echo "gitea tea" ;; esac; }
host_keys_url() {
  case $1 in
    github) echo "https://github.com/settings/keys" ;;
    gitlab) echo "https://$2/-/user_settings/ssh_keys" ;;
    gitea) echo "https://$2/user/settings/keys" ;;
    azure) echo "https://dev.azure.com/_usersSettings/keys" ;;
    bitbucket) echo "https://bitbucket.org/account/settings/ssh-keys/" ;;
  esac
}

# ------------------------------------------------------------- ssh ------------
ensure_ssh_include() {
  mkdir -p "$SSH_DIR/config.d"; chmod 700 "$SSH_DIR" "$SSH_DIR/config.d"
  local cfg=$SSH_DIR/config
  if [[ ! -f $cfg ]]; then
    printf 'Include config.d/*\n' >"$cfg"; chmod 600 "$cfg"
    printf '%s\t%s\t%s\t%s\n' ssh-include "$cfg" created "$(now)" >>"$RIG_STATE/system.log"
  elif ! grep -qxF 'Include config.d/*' "$cfg"; then
    # Include must come first so its settings apply to every host.
    { printf 'Include config.d/*\n\n'; cat "$cfg"; } >"$cfg.new" && mv "$cfg.new" "$cfg"; chmod 600 "$cfg"
    printf '%s\t%s\t%s\t%s\n' ssh-include "$cfg" added "$(now)" >>"$RIG_STATE/system.log"
  fi
  if [[ ! -f $SSH_DIR/config.d/00-rig ]]; then
    {
      echo "# Written by rig. Keys unlock once per login, then the agent holds them."
      echo "Host *"
      echo "  AddKeysToAgent yes"
      if [[ $(uname) == Darwin ]]; then echo "  IgnoreUnknown UseKeychain"; echo "  UseKeychain yes"; fi
    } >"$SSH_DIR/config.d/00-rig"
    chmod 600 "$SSH_DIR/config.d/00-rig"
  fi
}

# ------------------------------------------------------------- generate -------
git_regenerate() {
  mkdir -p "$GIT_CFG"
  local n out="$GIT_CFG/identities.gitconfig" def; def=$(default_identity)
  {
    echo "# Generated by \`rig git\` from ~/.config/git/identities/. Don't edit; run rig git add/remove."
    if [[ -n $def ]]; then
      echo "# default identity for repos that match no rule below"
      printf '[include]\n\tpath = identities/%s.gitconfig\n' "$def"
    else
      echo "# no default identity: git refuses to commit until a rule below matches"
      printf '[user]\n\tuseConfigOnly = true\n'
    fi
    for n in $(identities); do
      local folder alias
      folder=$(meta_get "$n" folder); alias=$(meta_get "$n" alias)
      [[ -n $folder ]] && printf '[includeIf "gitdir:%s/"]\n\tpath = identities/%s.gitconfig\n' "${folder%/}" "$n"
      if [[ -n $alias ]]; then printf '[includeIf "hasconfig:remote.*.url:git@%s:*/**"]\n\tpath = identities/%s.gitconfig\n' "$alias" "$n"; fi
    done
  } >"$out"

  # allowed signers (so `git log --show-signature` can verify our own commits)
  : >"$GIT_CFG/allowed_signers"
  for n in $(identities); do
    local key email
    key=$(meta_get "$n" key); email=$(meta_get "$n" email)
    if [[ -n $key && -f $key.pub ]]; then printf '%s %s\n' "$email" "$(cut -d' ' -f1,2 "$key.pub")" >>"$GIT_CFG/allowed_signers"; fi
  done

  # ssh host aliases, one per account
  mkdir -p "$SSH_DIR/config.d"
  {
    echo "# Generated by \`rig git\`. One alias per git account."
    for n in $(identities); do
      local alias hostname key
      alias=$(meta_get "$n" alias); hostname=$(meta_get "$n" hostname); key=$(meta_get "$n" key)
      if [[ -z $alias ]]; then continue; fi
      printf 'Host %s\n  HostName %s\n  User git\n  IdentityFile %s\n  IdentitiesOnly yes\n\n' "$alias" "$hostname" "$key"
    done
  } >"$SSH_DIR/config.d/rig-git"
  chmod 600 "$SSH_DIR/config.d/rig-git"
}

write_identity() { # name gitname email key sign hostname
  local n=$1 gname=$2 email=$3 key=$4 sign=$5 hostname=$6
  mkdir -p "$ID_DIR"
  {
    echo "# rig git identity '$n'${hostname:+ ($hostname)}"
    printf '[user]\n\tname = %s\n\temail = %s\n' "$gname" "$email"
    if [[ -n $key ]]; then
      printf '[core]\n\tsshCommand = ssh -i %s -o IdentitiesOnly=yes\n' "$key"
      if [[ $sign == yes ]]; then
        printf '[user]\n\tsigningkey = %s.pub\n' "$key"
        printf '[gpg]\n\tformat = ssh\n[gpg "ssh"]\n\tallowedSignersFile = %s/allowed_signers\n' "$GIT_CFG"
        printf '[commit]\n\tgpgsign = true\n[tag]\n\tgpgsign = true\n'
      fi
    fi
  } >"$ID_DIR/$n.gitconfig"
}

# ------------------------------------------------------------- verify ---------
ssh_check() { # alias host -> 0 if the key is accepted
  local out
  out=$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "git@$1" 2>&1 || true)
  case $2 in
    github|gitea) [[ $out == *"successfully authenticated"* ]] ;;
    gitlab) [[ $out == *"Welcome to GitLab"* ]] ;;
    bitbucket) [[ $out == *"authenticated via"* || $out == *"logged in as"* ]] ;;
    azure) [[ $out == *"Shell access is not supported"* ]] ;;
    *) [[ $out != *"Permission denied"* && $out != *"Could not resolve"* ]] ;;
  esac
}

# ------------------------------------------------------------- host CLIs ------
# Select the host's CLI item and install it. Inside rig setup the menu's own
# selection gets it too, so finishing setup doesn't deselect it again.
ensure_host_cli() { # item command
  local item=$1 cmd=$2
  have "$cmd" && return 0
  info "selecting $(item_label "$item") and installing it"
  state_write "$RIG_PROFILE" "$(list_add "$item" "$(state_get selected)")" "$(state_get extra_packages)" "$RIG_AGENT_DEFAULT"
  if [[ -n ${RIG_SETUP_MENU:-} ]]; then sel=$(list_add "$item" "${sel:-}"); fi
  chezmoi apply || { warn "couldn't install $cmd"; return 1; }
  load_machine; hash -r
  have "$cmd" || { warn "$cmd still isn't installed"; return 1; }
}
item_label() { cz_tmpl "{{ (index .catalog \"$1\").name }}" 2>/dev/null || printf '%s' "$1"; }
key_title() { printf '%s (rig: %s)' "$(hostname -s 2>/dev/null || uname -n)" "$1"; }

# Hosts without a CLI (or when the CLI fails): copy the key, open the page.
key_manual() { # host hostname key sign
  local url; url=$(host_keys_url "$1" "$2")
  if copy_clipboard <"$3.pub"; then ok "public key copied to the clipboard"; else say "  public key:"; sed 's/^/    /' "$3.pub"; fi
  if [[ -n $url ]]; then say "  add it here: $url"; open_url "$url" || true; fi
  if [[ $1 == gitlab && $4 == yes ]]; then say "  on GitLab, set its usage to 'Authentication & Signing'"; fi
  if [[ $1 == gitea && $4 == yes ]]; then say "  then press Verify next to it, so signed commits show as verified"; fi
  local _enter; ask _enter "Press Enter once you've added it"; : "$_enter"
}

github_connect() { # name key
  local n=$1 key=$2 user=''
  ensure_host_cli github gh || return 1
  ask user "GitHub username for this account (blank: log in and detect it)"
  if [[ -n $user ]] && gh auth status -h github.com 2>/dev/null | grep -q "account $user"; then
    gh auth switch -h github.com -u "$user" >/dev/null
  else
    info "logging in to GitHub in your browser (pick the right account there)"
    gh auth login -h github.com -p ssh --web --skip-ssh-key -s admin:public_key,admin:ssh_signing_key </dev/tty || return 1
    user=$(gh api user -q .login)
  fi
  printf 'cli_user=%s\n' "$user" >>"$ID_DIR/$n.meta"
  local title; title=$(key_title "$n")
  github_upload "$key" "$title" authentication || return 1
  if [[ $(meta_get "$n" sign) == yes ]]; then github_upload "$key" "$title" signing || return 1; fi
  ok "GitHub account $user: key added"
}
github_upload() { # key title type
  local out
  out=$(gh ssh-key add "$1.pub" --title "$2" --type "$3" 2>&1) && return 0
  if [[ $out == *"already"* ]]; then return 0; fi
  info "GitHub needs one more permission for $3 keys"
  gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key </dev/tty
  out=$(gh ssh-key add "$1.pub" --title "$2" --type "$3" 2>&1) || [[ $out == *"already"* ]] || { warn "$out"; return 1; }
}

# glab keeps one login per server: reuse it if it's this account, else log in again.
gitlab_connect() { # name key hostname
  local n=$1 key=$2 h=$3 cur='' out
  ensure_host_cli gitlab glab || return 1
  cur=$(glab auth status --hostname "$h" 2>&1 | sed -n 's/.*Logged in to [^ ]* as \([^ ]*\).*/\1/p' | head -n1)
  if [[ -z $cur ]] || ! ask_yn "glab is logged in to $h as $cur. Is that this account?" y; then
    info "logging in to GitLab ($h): pick the browser login, or paste a token with the api scope"
    glab auth login --hostname "$h" </dev/tty || return 1
    cur=$(glab auth status --hostname "$h" 2>&1 | sed -n 's/.*Logged in to [^ ]* as \([^ ]*\).*/\1/p' | head -n1)
  fi
  printf 'cli_user=%s\n' "$cur" >>"$ID_DIR/$n.meta"
  local usage=auth; [[ $(meta_get "$n" sign) == yes ]] && usage=auth_and_signing
  out=$(GITLAB_HOST=$h glab ssh-key add "$key.pub" --title "$(key_title "$n")" --usage-type "$usage" 2>&1) ||
    [[ $out == *"already been taken"* ]] || { warn "$out"; return 1; }
  ok "GitLab account ${cur:-?} on $h: key added"
}

# tea logs in with an access token; each rig account gets its own tea login.
gitea_connect() { # name key hostname
  local n=$1 key=$2 h=$3 token out
  local login="rig-$n"
  ensure_host_cli gitea tea || return 1
  if ! tea login list 2>/dev/null | grep -qw -- "$login"; then
    local url="https://$h/user/settings/applications"
    say "  tea needs an access token: create one at $url"
    say "  with read and write access to 'user' (that's what adds the key), then paste it here"
    open_url "$url" || true
    printf '  token (hidden): ' >/dev/tty; IFS= read -rs token <&3 || token=''; printf '\n' >/dev/tty
    [[ -n $token ]] || return 1
    tea login add --name "$login" --url "https://$h" --token "$token" >/dev/null || return 1
  fi
  printf 'cli_login=%s\n' "$login" >>"$ID_DIR/$n.meta"
  out=$(tea ssh-keys add --login "$login" --title "$(key_title "$n")" "$key.pub" 2>&1) ||
    [[ $out == *"already"* ]] || { warn "tea couldn't add the key: $out"; return 1; }
  ok "$h account: key added (tea login $login)"
  if [[ $(meta_get "$n" sign) == yes ]]; then say "  for verified signed commits, press Verify next to the key: https://$h/user/settings/keys"; fi
}

# ------------------------------------------------------------- add ------------
git_add() {
  load_machine; ledger_init; tty_in
  local n="${1:-}" gname email host hostname='' folder alias='' key='' sign=yes is_default=no
  local existing; existing=$(identities)
  local first_default=personal

  say; info "${B}new git account${N}"
  local ndef=''; if [[ -z $existing ]]; then ndef=$first_default; fi
  if [[ -z $n ]]; then ask n "Name for this account (e.g. personal, github-2)" "$ndef"; fi
  n=$(printf '%s' "$n" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9_-')
  [[ -n $n ]] || die "need a name"
  if [[ -f $ID_DIR/$n.meta ]]; then confirm "Account '$n' exists; set it up again?" || return 0; fi

  ask gname "Your name in commits" "$(git config --global user.name 2>/dev/null || true)"
  while :; do ask email "Email for this account" "$(meta_get "$n" email)"; [[ $email == *@* ]] && break; say "  that doesn't look like an email"; done

  choose host "Where is this account hosted?" 1 \
    "github     GitHub (logs in and adds the key for you, with gh)" \
    "gitlab     GitLab: gitlab.com or your own (with glab)" \
    "gitea      Gitea, Forgejo or Codeberg (with tea)" \
    "bitbucket  Bitbucket (you paste the key)" \
    "azure      Azure DevOps (you paste the key)" \
    "other      another git server" \
    "none       no hosting: just a name and email for commits"
  case $host in
    gitlab) ask hostname "GitLab server" gitlab.com ;;
    gitea) ask hostname "Server (Codeberg: codeberg.org)" codeberg.org ;;
    other) ask hostname "Git server hostname (e.g. git.example.com)" ;;
    none) ;;
    *) hostname=$(host_hostname "$host") ;;
  esac
  [[ $host == none || -n $hostname ]] || die "need a hostname"
  if [[ -n $hostname ]]; then alias="$hostname-$n"; fi

  local fdef="$HOME/Projects/$n"; [[ -z $existing ]] && fdef="$HOME/Projects"
  local fprev; fprev=$(meta_get "$n" folder)
  ask folder "Folder whose repos use this account" "${fprev:-$fdef}"
  folder=${folder/#\~/$HOME}; mkdir -p "$folder"

  # default account: used for repos that match no account's folder or alias
  local cur_def; cur_def=$(default_identity)
  if [[ -z $cur_def ]]; then
    ask_yn "Make '$n' the default account (used for repos that match no other)?" y && is_default=yes
  elif [[ $cur_def == "$n" ]]; then is_default=yes
  fi

  # key
  if [[ $host != none ]] || ask_yn "Sign commits with an SSH key anyway?" n; then
    local keys=() k new="$SSH_DIR/id_ed25519_$n" ktype=ed25519
    [[ $host == azure ]] && { new="$SSH_DIR/id_rsa_$n"; ktype=rsa; } # Azure DevOps wants RSA keys
    while IFS= read -r k; do [[ ${k%.pub} != "$new" ]] && keys+=("${k%.pub}"); done < <(find "$SSH_DIR" -maxdepth 1 -name '*.pub' 2>/dev/null | sort)
    key=new
    ((${#keys[@]})) && choose key "SSH key for this account" 1 "new  (create ${new/#$HOME/~})" "${keys[@]}"
    if [[ $key == new ]]; then
      key=$new
      if [[ ! -f $key ]]; then
        info "creating ${key/#$HOME/~}: pick a passphrase (the agent asks for it once per login)"
        mkdir -p "$SSH_DIR"; chmod 700 "$SSH_DIR"
        if [[ $ktype == rsa ]]; then ssh-keygen -q -t rsa -b 4096 -C "$email" -f "$key" </dev/tty
        else ssh-keygen -q -t ed25519 -C "$email" -f "$key" </dev/tty; fi
        printf '%s\t%s\t%s\t%s\n' ssh-key-created "$key" - "$(now)" >>"$RIG_STATE/system.log"
      fi
    fi
    if [[ $host == azure ]]; then sign=no; fi
    if [[ $host != azure ]] && ! ask_yn "Sign commits with this key? (shows as verified on the host)" y; then sign=no; fi
    ensure_ssh_include
    ssh-add "$key" </dev/tty 2>/dev/null || true
  else
    sign=no
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
    local connected=0
    case $host in
      github) github_connect "$n" "$key" && connected=1 ;;
      gitlab) gitlab_connect "$n" "$key" "$hostname" && connected=1 ;;
      gitea) gitea_connect "$n" "$key" "$hostname" && connected=1 ;;
    esac
    if ((connected == 0)); then
      if [[ -n $(host_cli "$host") ]]; then warn "couldn't add the key with the $(host_name "$host") CLI; add it by hand instead"; fi
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
  local host key; host=$(meta_get "$n" host); key=$(meta_get "$n" key)
  confirm "Remove account '$n'? (its SSH key stays in ~/.ssh)" || return 0
  rm -f "$ID_DIR/$n.meta" "$ID_DIR/$n.gitconfig"
  git_regenerate
  ok "removed '$n'"
  if [[ -n $key ]]; then say "  key kept: $key"; fi
  case $host in
    github) say "  to remove the key from GitHub too: gh ssh-key list, then gh ssh-key delete <id>" ;;
    gitlab) say "  to remove the key from GitLab too: glab ssh-key list, then glab ssh-key delete <id>" ;;
    gitea) say "  to remove the key from $(meta_get "$n" hostname) too: its settings page, then tea login delete rig-$n" ;;
    bitbucket|azure|other) say "  remove the key from $(host_name "$host") in its settings" ;;
  esac
  local cli item; cli=$(host_cli "$host"); item=${cli%% *}
  if [[ -n $item ]] && ! grep -lqs "^host=$host\$" "$ID_DIR"/*.meta 2>/dev/null && [[ " $RIG_SELECTED " == *" $item "* ]]; then
    if confirm "No $(host_name "$host") accounts left. Deselect the $(host_name "$host") CLI on this machine?"; then
      cmd_del "$item"
    fi
  fi
}

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

# ------------------------------------------------------------- doctor ---------
git_doctor() {
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

# ------------------------------------------------------------- uninstall ------
git_uninstall_identities() { # called by rig uninstall --identities; rig-created keys go to $1
  local archive_dir=$1 key
  while IFS= read -r key; do
    [[ -f $key ]] || continue
    mkdir -p "$archive_dir" && mv "$key" "$key.pub" "$archive_dir/" 2>/dev/null && ok "moved rig-created key ${key/#$HOME/~} to $archive_dir"
  done < <(awk -F'\t' '$1=="ssh-key-created" {print $2}' "$RIG_STATE/system.log")
  rm -rf "$ID_DIR" "$GIT_CFG/identities.gitconfig" "$GIT_CFG/allowed_signers" "$SSH_DIR/config.d/rig-git"
  ok "removed git accounts"
}

git_set_default() { # account|none
  local n=${1:-} o
  [[ -n $n ]] || die "usage: rig git default <account|none>"
  if [[ $n != none && ! -f $ID_DIR/$n.meta ]]; then die "no account '$n' (rig git list)"; fi
  for o in $(identities); do
    sed -i.bak "s/^default=.*/default=$([[ $o == "$n" ]] && echo yes || echo no)/" "$ID_DIR/$o.meta" && rm -f "$ID_DIR/$o.meta.bak"
  done
  git_regenerate
  if [[ $n == none ]]; then ok "no default account: git refuses to commit until a repo matches an account"
  else ok "default account: $n"; fi
}

cmd_git() {
  local sub=${1:-list}; (($#)) && shift
  case $sub in
    add) git_add "$@" ;;
    setup) git_setup "$@" ;;
    list|ls) git_list ;;
    which) git_which ;;
    remove|rm) git_remove "$@" ;;
    clone) git_clone "$@" ;;
    doctor) git_doctor ;;
    default) load_machine; git_set_default "$@" ;;
    *) die "usage: rig git add|list|which|remove|clone|default|doctor" ;;
  esac
}
