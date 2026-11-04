# needs:
# rig export / rig import: the selection, git accounts (new keys, never the
# old ones), srv servers and local.zsh move to a "new machine" (this one,
# emptied), and a second import changes nothing.
tty_feed() { # input-file command...  (runs the command on a pty, typing one line per second)
  local in=$1; shift
  { sleep 2; while IFS= read -r l; do if [[ $l == @sleep\ * ]]; then sleep "${l#@sleep }"; continue; fi; printf '%s\n' "$l"; sleep 1; done <"$in"; sleep 3; } |
    timeout 400 script -qec "$*" /dev/null >/tmp/feed.out 2>&1
}

install_rig --profile minimal --select zoxide --yes
check "install ok, zoxide selected" '[[ $? -eq 0 ]] && command -v zoxide >/dev/null'

# --- this machine's own setup
printf 'Test User\nt@example.invalid\n7\n\ny\ny\n\n\n\n' >/tmp/in1
tty_feed /tmp/in1 rig git add personal
printf 'Test User\ns@example.invalid\n6\ngit.example.invalid\n~/Projects/second\n1\n\n\n\n\n' >/tmp/in2
tty_feed /tmp/in2 rig git add second
check "two git accounts" '[[ -f ~/.config/git/identities/personal.meta && -f ~/.config/git/identities/second.meta ]]'
srv add box tester@box.example.invalid:2222 "~/data" >/dev/null 2>&1
printf 'alias hi="echo hi"\n' >~/.config/zsh/local.zsh
old_key=$(cat ~/.ssh/id_ed25519_personal.pub)

# --- export
rig export ~/move.tar.gz >/tmp/export.out 2>&1
check "export written, private" '[[ -f ~/move.tar.gz && $(stat -c %a ~/move.tar.gz) == 600 ]]' || cat /tmp/export.out
check "export says what it holds" 'grep -q "git accounts: personal, second" /tmp/export.out && grep -q "srv: 1 servers" /tmp/export.out && grep -q "local.zsh" /tmp/export.out'
mkdir -p /tmp/x && tar -xzf ~/move.tar.gz -C /tmp/x
check "no keys or tokens in it" '! grep -rqE "PRIVATE KEY|ssh-ed25519" /tmp/x && ! find /tmp/x -name "id_*" | grep -q .'
check "account answers in it" 'grep -qx "folder=~/Projects/second" /tmp/x/rig/modules/git/second.account && grep -qx "haskey=yes" /tmp/x/rig/modules/git/personal.account'

# --- a "new machine": none of it here
rig remove zoxide >/dev/null 2>&1
rm -rf ~/.config/git/identities ~/.ssh/id_ed25519_* ~/.config/zsh/local.zsh
srv rm box >/dev/null 2>&1 || true
check "emptied" '! grep -q "\"zoxide\"" ~/.config/chezmoi/chezmoi.toml && [[ ! -d ~/.config/git/identities && ! -f ~/.config/zsh/local.zsh ]] && ! srv ls 2>/dev/null | grep -q box'

# --- import (two new keys: a blank passphrase each, then the manual-key prompts)
printf '@sleep 150\n\n\n\n\n\n\n\n\n\n\n\n\n' >/tmp/in3
printf '@sleep 20\n\n\n\n\n' >/tmp/in4
tty_feed /tmp/in3 rig import ~/move.tar.gz --yes
check "import ok" 'grep -q "imported" /tmp/feed.out' || tail -30 /tmp/feed.out
check "selection back" 'command -v zoxide >/dev/null && grep -q "\"zoxide\"" ~/.config/chezmoi/chezmoi.toml'
check "git accounts back" '[[ -f ~/.config/git/identities/personal.gitconfig && -f ~/.config/git/identities/second.gitconfig ]]'
check "same answers" 'grep -qx "email=s@example.invalid" ~/.config/git/identities/second.meta && grep -qx "folder=$HOME/Projects/second" ~/.config/git/identities/second.meta && grep -qx "default=yes" ~/.config/git/identities/personal.meta'
check "new keys, not the old one" '[[ -f ~/.ssh/id_ed25519_personal && -f ~/.ssh/id_ed25519_second && $(cat ~/.ssh/id_ed25519_personal.pub) != "$old_key" ]]'
check "routing works again" 'mkdir -p ~/Projects/second/r && git -C ~/Projects/second/r init -q && [[ $(git -C ~/Projects/second/r config user.email) == s@example.invalid ]]'
check "srv server back" 'srv ls 2>/dev/null | grep -q box && grep -qP "^box\ttester@box.example.invalid:2222\t~/data\tmanual$" ~/.config/srv/hosts'
check "local.zsh back" '[[ $(cat ~/.config/zsh/local.zsh) == "alias hi=\"echo hi\"" ]]'

# --- importing again changes nothing
printf 'alias mine=true\n' >~/.config/zsh/local.zsh
tty_feed /tmp/in4 rig import ~/move.tar.gz --yes
check "second import keeps what's here" 'grep -q "already here, kept" /tmp/feed.out && [[ $(grep -c "^box" ~/.config/srv/hosts) == 1 ]] && grep -q mine ~/.config/zsh/local.zsh && [[ -f ~/.config/zsh/local.zsh.imported ]]'

# --- not an export
mkdir -p /tmp/bad/etc && echo x >/tmp/bad/etc/passwd && tar -czf /tmp/bad.tar.gz -C /tmp/bad etc
check "refuses a file that isn't an export" '! rig import /tmp/bad.tar.gz --yes >/tmp/bad.out 2>&1 && grep -q "isn.t a rig export" /tmp/bad.out'
done_tests
