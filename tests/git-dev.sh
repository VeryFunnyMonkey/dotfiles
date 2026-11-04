# needs: 
# Git accounts (rig git) and dev workspaces: routing by folder/remote/default,
# signed commits, no-default refusal, workspaces, agent pane, worktrees.
# packages: tmux
tty_feed() { # input-file command...  (runs the command on a pty, typing one line per second)
  local in=$1; shift
  { sleep 2; while IFS= read -r l; do printf '%s\n' "$l"; sleep 1; done <"$in"; sleep 3; } |
    timeout 120 script -qec "$*" /dev/null >/tmp/feed.out 2>&1
}

install_rig --profile minimal --select github --yes
check "install ok, gh selected" '[[ $? -eq 0 ]] && command -v gh >/dev/null'
check "git setup skipped without a terminal" 'grep -q "set up git accounts later" /tmp/install.log'

# --- git: a local-only personal account with a signing key
printf 'Test User\nt@example.invalid\n6\n\ny\ny\n\n\n\n' > /tmp/in1
tty_feed /tmp/in1 rig git add personal
check "personal account written" '[[ -f ~/.config/git/identities/personal.gitconfig ]]'
check "key created" '[[ -f ~/.ssh/id_ed25519_personal ]]'
# --- git: a second account on another server
printf 'Test User\ns@example.invalid\n5\ngit.example.invalid\n\n1\n\n\n\n\n' > /tmp/in2
tty_feed /tmp/in2 rig git add second
check "second account written" '[[ -f ~/.config/git/identities/second.gitconfig ]]'
check "ssh alias generated" 'grep -q "Host git.example.invalid-second" ~/.ssh/config.d/rig-git'
check "ssh Include added" '[[ $(head -n1 ~/.ssh/config) == "Include config.d/*" ]]'

mkdir -p ~/Projects/x ~/Projects/second/y /tmp/z /tmp/elsewhere
for d in ~/Projects/x ~/Projects/second/y /tmp/z /tmp/elsewhere; do git -C $d init -q; done
git -C /tmp/elsewhere remote add origin git@git.example.invalid-second:org/r.git
check "Projects repo -> personal" '[[ $(git -C ~/Projects/x config user.email) == t@example.invalid ]]'
check "Projects/second repo -> second" '[[ $(git -C ~/Projects/second/y config user.email) == s@example.invalid ]]'
check "repo with second remote elsewhere -> second" '[[ $(git -C /tmp/elsewhere config user.email) == s@example.invalid ]]'
check "unmatched repo -> default (personal)" '[[ $(git -C /tmp/z config user.email) == t@example.invalid ]]'
(cd ~/Projects/x && echo a > a && git add a && git commit -qm one)
check "commit is signed and verifies" 'git -C ~/Projects/x log --show-signature -1 2>&1 | grep -q "Good \"git\" signature"'
check "rig git which" '(cd ~/Projects/second/y && rig git which) | grep -q second'
gl=$(rig git list 2>&1); check "rig git list shows the default" '[[ $gl == *"(default)"* ]]' || echo "$gl"

# no default -> git refuses to commit outside the account folders
printf 'y\n' > /tmp/yes; tty_feed /tmp/yes rig git remove personal
check "removed personal" '[[ ! -f ~/.config/git/identities/personal.meta ]]'
(cd /tmp/z && echo b > b && git add b && git commit -qm two) >/tmp/commit.out 2>&1
check "unmatched repo refuses to commit with no default" 'grep -qiE "no email was given|identity unknown" /tmp/commit.out'

# --- dev
mkdir -p ~/proj1 && git -C ~/proj1 init -q
dev agent set 'echo AGENT-RAN' >/dev/null
(cd ~/proj1 && DEV_NO_ATTACH=1 dev)
sleep 2
check "default workspace: session with 2 panes" '[[ $(tmux list-panes -t proj1:code | wc -l) == 2 ]]'
check "agent ran in left pane" 'tmux capture-pane -p -t proj1:code.1 | grep -q AGENT-RAN'
check "nvim in right pane" '[[ $(tmux display -p -t proj1:code.2 "#{pane_current_command}") == nvim ]]'
(cd ~/proj1 && DEV_NO_ATTACH=1 dev)
check "re-run attaches, no duplicate" '[[ $(tmux list-sessions | grep -c "^proj1:") == 1 && $(tmux list-panes -t proj1:code | wc -l) == 2 ]]'

mkdir -p ~/proj2 && git -C ~/proj2 init -q
printf '[code]\nagent\nshell\n\n[run] tiled\necho ONE\necho TWO\nshell\n' > ~/proj2/.dev
(cd ~/proj2 && DEV_NO_ATTACH=1 dev --no-agent)
sleep 2
check "two windows from .dev" '[[ $(tmux list-windows -t proj2 -F "#{window_name}" | tr "\n" " ") == "code run " ]]'
check "run window has 3 panes" '[[ $(tmux list-panes -t proj2:run | wc -l) == 3 ]]'
check "pane commands ran" 'tmux capture-pane -p -t proj2:run.1 | grep -q ONE && tmux capture-pane -p -t proj2:run.2 | grep -q TWO'
check "--no-agent left a plain shell" '! tmux capture-pane -p -t proj2:code.1 | grep -q AGENT-RAN'

mkdir -p ~/proj3 && git -C ~/proj3 init -q
dev agent set 'definitely-not-installed --flag' >/dev/null
(cd ~/proj3 && DEV_NO_ATTACH=1 dev); sleep 1
check "missing agent prints a hint" 'tmux capture-pane -p -t proj3:code.1 | grep -q "dev agent set"'

(cd ~/proj3 && EDITOR=true dev init --local >/dev/null)
check "init --local writes to the local store" '[[ -f ~/.config/dev/projects/proj3 && ! -f ~/proj3/.dev ]]'
printf '[only]\nshell\n' > ~/proj3/.dev
tmux kill-session -t proj3; (cd ~/proj3 && DEV_NO_ATTACH=1 dev)
check "./.dev wins over the local store" '[[ $(tmux list-windows -t proj3 -F "#{window_name}") == only ]]'
check "picker lists sessions and workspaces" '[[ $(dev _items | grep -c "^●") -ge 3 ]]'

# worktrees
(cd ~/proj1 && echo x > f && git add f && git -c user.name=T -c user.email=t@example.invalid commit -qm init --no-gpg-sign && DEV_NO_ATTACH=1 dev wt feat-x) >/dev/null 2>&1
check "worktree created" '[[ -d ~/proj1.wt/feat-x ]]'
check "worktree window exists" 'tmux list-windows -t proj1 -F "#{window_name}" | grep -qx "wt:feat-x"'
echo dirty > ~/proj1.wt/feat-x/d
(cd ~/proj1 && dev wt rm feat-x) >/tmp/wt.out 2>&1
check "wt rm refuses with uncommitted changes" 'grep -q "uncommitted" /tmp/wt.out && [[ -d ~/proj1.wt/feat-x ]]'
rm ~/proj1.wt/feat-x/d; (cd ~/proj1 && dev wt rm feat-x) >/dev/null 2>&1
check "wt rm removes worktree and window" '[[ ! -d ~/proj1.wt/feat-x ]] && ! tmux list-windows -t proj1 -F "#{window_name}" | grep -qx "wt:feat-x"'
tmux kill-server

# --- uninstall --identities
rig uninstall --identities --yes >/tmp/un.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]'
check "identities removed" '[[ ! -d ~/.config/git/identities ]]'
check "rig-created keys archived, not deleted" 'ls ~/rig-uninstall-keys-*/id_ed25519_second >/dev/null 2>&1'
check "ssh config created by rig removed" '[[ ! -f ~/.ssh/config ]]'
done_tests
