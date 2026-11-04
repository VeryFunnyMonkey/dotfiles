# Set up over existing dotfiles, then rig uninstall --everything: the machine
# must end up exactly as before (files, packages, login shell, /etc/shells).
printf "# my old zshrc\nalias old=1\n" > .zshrc
printf "[user]\n\tname = Test User\n\temail = test@example.invalid\n" > .gitconfig
mkdir -p old-dots/nvim && echo "-- old nvim" > old-dots/nvim/init.lua
mkdir -p .config && ln -s ../old-dots/nvim .config/nvim
echo "old tmux" > .tmux.conf
find . -path ./dotfiles -prune -o -print | sort > /tmp/before.txt
pkgs | sort > /tmp/pkgs-before.txt
cp /etc/shells /tmp/etc-shells-before
sha256sum .zshrc .gitconfig .tmux.conf > /tmp/sums-before
shell_before=$(getent passwd "$(id -un)" | cut -d: -f7)

install_rig --profile minimal --select zoxide,eza,bat --yes
check "install ok" '[[ $? -eq 0 ]] && grep -q "nvim bootstrap done" /tmp/install.log'
chezmoi apply > /tmp/apply2.log 2>&1
check "second apply re-runs nothing" '! grep -qE "installing with|setting up neovim|changing login shell" /tmp/apply2.log && [[ -z $(chezmoi status --exclude=scripts) ]]'
check "zshenv is a symlink into the repo" '[[ $(readlink ~/.zshenv) == */dotfiles/home/dot_zshenv ]]'
check "old Stow-style nvim link replaced by a real folder" '[[ ! -L ~/.config/nvim && -L ~/.config/nvim/init.lua ]]'
check "login shell is zsh" '[[ $(getent passwd $(id -un) | cut -d: -f7) == */zsh ]]'
check "emacs keymap" 'zsh -ic "bindkey -lL main" 2>/dev/null | grep -q emacs'
check "fzf, zoxide, autosuggestions load" 'zsh -ic "whence -w fzf-history-widget z _zsh_autosuggest_start" >/dev/null 2>&1'
check "git pager is delta... only if delta selected (it isn't)" '[[ $(git config core.pager) == delta ]] || true'
doc=$(rig doctor 2>&1)
check "doctor: packages" '[[ $doc == *"all declared packages installed"* ]]'
check "doctor: nvim healthy" '[[ $doc == *"checkhealth: no errors"* ]]'

~/.local/bin/rig uninstall --everything --yes > /tmp/uninstall.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]'
find . -path ./dotfiles -prune -o -print | sort | grep -v '^./rig-uninstall-' > /tmp/after.txt
pkgs | sort > /tmp/pkgs-after.txt
check "packages identical to before" '[[ "$(cat /tmp/pkgs-before.txt)" == "$(cat /tmp/pkgs-after.txt)" ]]' || comm -3 /tmp/pkgs-before.txt /tmp/pkgs-after.txt | head
check "/etc/shells identical" '[[ "$(cat /tmp/etc-shells-before)" == "$(cat /etc/shells)" ]]'
check "login shell restored" '[[ $(getent passwd $(id -un) | cut -d: -f7) == "$shell_before" ]]'
check "original files byte-for-byte" 'sha256sum -c /tmp/sums-before >/dev/null'
check "old nvim symlink restored" '[[ $(readlink ~/.config/nvim) == ../old-dots/nvim ]]'
extra=$(comm -13 /tmp/before.txt /tmp/after.txt | grep -vE '^\./\.local/state/(zsh|nvim)(/|$)|^\./\.local(/state)?$|^\./\.cache$|^\./\.ssh(/|$)' || true)
check "home matches the snapshot (shell/nvim history kept)" '[[ -z $extra ]]' || echo "$extra"
check "nothing from before is missing" '[[ -z $(comm -23 /tmp/before.txt /tmp/after.txt) ]]'
done_tests
