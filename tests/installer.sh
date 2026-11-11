# The installer end to end: install.sh, profiles, add/remove, saving a profile, the menu, uninstall.
pkgs > /tmp/pkgs-before.txt

install_rig --profile desktop --select python,web,claude --yes
check "install.sh (non-interactive) ok" '[[ $? -eq 0 ]]'
check "gum installed" 'command -v gum >/dev/null'
check "profile + selection stored" 'grep -q "profile = \"desktop\"" ~/.config/chezmoi/chezmoi.toml && grep -q "\"python\"" ~/.config/chezmoi/chezmoi.toml'
check "item packages installed (github-cli, tailscale, uv, fnm)" 'pacman -Q github-cli tailscale uv fnm >/dev/null'
check "display items skipped without a display, with the reason" 'grep -q "skipped here: Ghostty: needs a display" /tmp/install.log'
check "nvim gets python + web servers" 'grep -q pyright ~/.config/nvim/lua/config/modules.lua && grep -q ts_ls ~/.config/nvim/lua/config/modules.lua'
check "claude installed and dev default" 'command -v claude >/dev/null && [[ $(dev agent) == claude ]]'
check "no work setting anywhere" '! grep -qi "work" ~/.config/rig/machine.env'
doc=$(rig doctor 2>&1); check "doctor: packages ok" '[[ $doc == *"all declared packages installed"* ]]'
check "doctor shows the profile" '[[ $doc == *"profile desktop"* ]]'
chezmoi apply > /tmp/apply2.log 2>&1
check "second apply changes nothing" '! grep -qE "installing with|setting up neovim" /tmp/apply2.log && [[ -z $(chezmoi status --exclude=scripts) ]]'

RIG_YES=1 rig remove web > /tmp/rm.log 2>&1
check "remove web: ts_ls gone from nvim" '! grep -q ts_ls ~/.config/nvim/lua/config/modules.lua'
check "remove web: node stays (python still needs it)" 'pacman -Q fnm >/dev/null'
RIG_YES=1 rig add jq htop > /tmp/add.log 2>&1
check "add jq (item) and htop (extra package)" 'pacman -Q jq htop >/dev/null && grep -q "\"htop\"" ~/.config/chezmoi/chezmoi.toml'
rig profile save mine "test profile" > /tmp/save.log 2>&1
check "profile saved into the repo" '[[ -f ~/dotfiles/home/.chezmoidata/profiles/mine.yaml ]] && grep -q jq ~/dotfiles/home/.chezmoidata/profiles/mine.yaml'
check "profile list shows it" 'rig profile list > /tmp/pl.txt; grep -q mine /tmp/pl.txt'
RIG_YES=1 rig setup --profile mine --yes > /tmp/again.log 2>&1
check "re-applying the saved profile changes nothing" 'grep -q "no item changes" /tmp/again.log'
RIG_YES=1 rig setup --profile minimal --yes > /tmp/min.log 2>&1
check "switching to minimal removes items" '! pacman -Q btop >/dev/null 2>&1 && ! command -v claude >/dev/null'

# the menu draws and quits cleanly (Esc)
RIG_YES=1 rig add zoxide >/dev/null 2>&1   # something selected, so the main menu opens directly
{ sleep 3; printf '\033'; sleep 3; } | timeout 30 script -qec "stty rows 40 cols 120; rig setup" /dev/null > /tmp/menu.out 2>&1
check "menu draws its sections and quits on Esc" 'grep -q "Review & install" /tmp/menu.out && grep -q "CLI tools" /tmp/menu.out'
check "menu shows current selection" 'grep -q "zoxide" /tmp/menu.out'
RIG_YES=1 rig setup --profile minimal --select python --yes > /tmp/pyonly.log 2>&1
check "python alone pulls in node (pyright via npm)" '[[ $? -eq 0 ]] && [[ -e ~/.local/share/nvim/mason/bin/pyright ]]'

~/.local/bin/rig uninstall --everything --yes > /tmp/un.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]'
pkgs > /tmp/pkgs-after.txt
check "packages back to before" '[[ "$(cat /tmp/pkgs-before.txt)" == "$(cat /tmp/pkgs-after.txt)" ]]'
[[ "$(cat /tmp/pkgs-before.txt)" == "$(cat /tmp/pkgs-after.txt)" ]] || { echo "  extra:"; comm -13 /tmp/pkgs-before.txt /tmp/pkgs-after.txt; }
done_tests
