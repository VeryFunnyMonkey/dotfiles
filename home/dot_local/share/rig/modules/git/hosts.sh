# shellcheck shell=bash
# modules/git/hosts.sh: the git hosts rig knows. One row per host; a host
# whose keys rig uploads itself also has a git_connect_<id> function below.
# Adding a host is one row (and optionally a connect function).
#
# id|label (in the walkthrough)|name|hostname (default)|ask for the hostname|
#   CLI item|CLI command|keys page ({host})|ssh greeting (alternatives: ;)|
#   key type|signs|how to remove a key ({name})|signing hint

GIT_HOSTS='github|GitHub (logs in and adds the key for you, with gh)|GitHub|github.com||github|gh|https://github.com/settings/keys|successfully authenticated|ed25519|yes|gh ssh-key list, then gh ssh-key delete <id>|
gitlab|GitLab: gitlab.com or your own (with glab)|GitLab|gitlab.com|GitLab server|gitlab|glab|https://{host}/-/user_settings/ssh_keys|Welcome to GitLab|ed25519|yes|glab ssh-key list, then glab ssh-key delete <id>|on GitLab, set its usage to '"'"'Authentication & Signing'"'"'
gitea|Gitea, Forgejo or Codeberg (with tea)|Gitea/Forgejo|codeberg.org|Server (Codeberg: codeberg.org)|gitea|tea|https://{host}/user/settings/keys|successfully authenticated|ed25519|yes|its settings page, then tea login delete rig-{name}|then press Verify next to it, so signed commits show as verified
bitbucket|Bitbucket (you paste the key)|Bitbucket|bitbucket.org||||https://bitbucket.org/account/settings/ssh-keys/|authenticated via;logged in as|ed25519|yes|its settings page|
azure|Azure DevOps (you paste the key)|Azure DevOps|ssh.dev.azure.com||||https://dev.azure.com/_usersSettings/keys|Shell access is not supported|rsa|no|its settings page|
other|another git server|the server||Git server hostname (e.g. git.example.com; blank to cancel)||||||ed25519|yes|its settings page|'

git_hosts() { printf '%s\n' "$GIT_HOSTS" | cut -d'|' -f1; }
host_field() { # id field
  local col
  case $2 in
    label) col=2 ;; name) col=3 ;; hostname) col=4 ;; prompt) col=5 ;; cli) col=6 ;; cmd) col=7 ;;
    keys) col=8 ;; greeting) col=9 ;; key) col=10 ;; signs) col=11 ;; remove) col=12 ;; sign_hint) col=13 ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$GIT_HOSTS" | awk -F'|' -v id="$1" -v c="$col" '$1==id {print $c; exit}'
}
host_keys_url() { local u; u=$(host_field "$1" keys); printf '%s' "${u//\{host\}/$2}"; }

# ssh -T to an account's alias: did the host accept the key?
ssh_check() { # alias host
  local out greeting g
  out=$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "git@$1" 2>&1 || true)
  greeting=$(host_field "$2" greeting)
  if [[ -z $greeting ]]; then [[ $out != *"Permission denied"* && $out != *"Could not resolve"* ]]; return; fi
  local IFS=';'
  for g in $greeting; do [[ $out == *"$g"* ]] && return 0; done
  return 1
}

# Upload the key with the host's own CLI, if rig knows how. 1: do it by hand.
host_connect() { # host name key hostname
  declare -F "git_connect_$1" >/dev/null || return 1
  "git_connect_$1" "$2" "$3" "$4"
}

# Hosts without a CLI (or when the CLI fails): copy the key, open the page.
key_manual() { # host hostname key sign
  local url hint; url=$(host_keys_url "$1" "$2"); hint=$(host_field "$1" sign_hint)
  if copy_clipboard <"$3.pub"; then ok "public key copied to the clipboard"; else say "  public key:"; sed 's/^/    /' "$3.pub"; fi
  if [[ -n $url ]]; then say "  add it here: $url"; open_url "$url" || true; fi
  if [[ $4 == yes && -n $hint ]]; then say "  $hint"; fi
  local _enter; ask _enter "Press Enter once you've added it"; : "$_enter"
}

# ------------------------------------------------------------- host CLIs ------
# Select the host's CLI item and install it. Inside rig setup the menu's own
# selection gets it too, so finishing setup doesn't deselect it again.
ensure_host_cli() { # host
  local item cmd; item=$(host_field "$1" cli); cmd=$(host_field "$1" cmd)
  have "$cmd" && return 0
  info "selecting $(item_label "$item") and installing it"
  state_write "$RIG_PROFILE" "$(list_add "$item" "$(state_get selected)")" "$(state_get extra_packages)" "$RIG_AGENT_DEFAULT"
  if [[ -n ${RIG_SETUP_MENU:-} ]]; then sel=$(list_add "$item" "${sel:-}"); fi
  chezmoi apply || { warn "couldn't install $cmd"; return 1; }
  load_machine; hash -r
  have "$cmd" || { warn "$cmd still isn't installed"; return 1; }
}

key_title() { printf '%s (rig: %s)' "$(hostname -s 2>/dev/null || uname -n)" "$1"; }

git_connect_github() { # name key [hostname]
  local n=$1 key=$2 user=''
  ensure_host_cli github || return 1
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
git_connect_gitlab() { # name key hostname
  local n=$1 key=$2 h=$3 cur='' out
  ensure_host_cli gitlab || return 1
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
git_connect_gitea() { # name key hostname
  local n=$1 key=$2 h=$3 token out
  local login="rig-$n"
  ensure_host_cli gitea || return 1
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
