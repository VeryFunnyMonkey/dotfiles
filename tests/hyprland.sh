# The Hyprland item (with the Helium browser as the default): packages and what it includes, its configs (gruvbox from
# theme.yaml, valid for this Hyprland), desk, the login screen on a machine
# without one (greetd, with a fake systemctl: containers have no systemd),
# and that deselecting gives the original login back.
# Fake systemd: nothing enabled, every change logged.
# (in /usr/local/bin: sudo's own PATH finds it there too)
sudo tee /usr/local/bin/systemctl >/dev/null <<'SH'
#!/bin/sh
case "$*" in
  *--user*) exit 1 ;;
  *is-enabled*) echo disabled; exit 1 ;;
  *show*) echo ""; exit 0 ;;
  *) echo "systemctl $*" >> /tmp/systemctl.log; exit 0 ;;
esac
SH
sudo chmod 755 /usr/local/bin/systemctl && sudo mkdir -p /run/systemd/system && sudo touch /tmp/systemctl.log && sudo chmod 666 /tmp/systemctl.log
pkgs | sort > /tmp/pkgs-before.txt

install_rig --profile minimal --select hyprland,helium,browser-default --yes
check "install ok" '[[ $? -eq 0 ]]' || tail -30 /tmp/install.log
check "Hyprland and its tools installed" 'pacman -Q hyprland uwsm waybar fuzzel mako hyprlock hypridle hyprsunset swayosd cliphist satty wiremix bluetui thunar >/dev/null'
check "it includes Ghostty, the font, clipboard tools and yazi" 'pacman -Q ghostty ttf-jetbrains-mono-nerd wl-clipboard yazi >/dev/null'
check "a console install counts as a Wayland desktop" 'grep -q "display = \"wayland\"" ~/.config/chezmoi/chezmoi.toml'
check "configs are symlinks into the repo" '[[ $(readlink ~/.config/hypr/hyprland.lua) == */dotfiles/home/dot_config/hypr/hyprland.lua && -L ~/.config/waybar/style.css ]]'
check "colours rendered from theme.yaml" 'grep -q "bg = \"#282828\"" ~/.config/hypr/theme.lua && grep -q "^background=282828" ~/.config/fuzzel/colors.ini && grep -q "@define-color aqua #8ec07c" ~/.config/waybar/colors.css'
v=$(XDG_RUNTIME_DIR=/tmp Hyprland --verify-config 2>&1 | sed -n '/Config parsing result/,$p')
check "Hyprland accepts the config (--verify-config)" '[[ $v == *"config ok"* ]]' || echo "$v" | tail -8
check "waybar config is valid JSON" 'grep -v "^\s*//" ~/.config/waybar/config.jsonc | jq -e . >/dev/null'
check "Helium from the AUR (rig built paru for it)" 'pacman -Q helium-browser-bin paru-bin >/dev/null && command -v helium-browser >/dev/null'
check "links open in Helium" '[[ $(awk -F= "/^x-scheme-handler\/https=/ {print \$2}" ~/.config/mimeapps.list) == helium.desktop ]]'
check "drift: rig's own paru isn't reported" '! rig drift 2>&1 | grep -q paru'
check "desk works" 'desk help | grep -q "desk power" && desk nightlight status | jq -e ".class == \"off\"" >/dev/null'
check "login screen: greetd starting Hyprland through uwsm" 'grep -q "uwsm start hyprland.desktop" /etc/greetd/config.toml && grep -q "enable --now greetd.service" /tmp/systemctl.log'
check "NetworkManager enabled for the bar's Wi-Fi" 'grep -q "enable --now NetworkManager.service" /tmp/systemctl.log'
check "the original greetd config is kept in the ledger" 'grep -q "^etc-file	/etc/greetd/config.toml	" ~/.local/state/rig/system.log'
doc=$(rig doctor 2>&1); check "doctor checks the Hyprland config" '[[ $doc == *"config ok"* ]]' || echo "$doc" | tail -12

RIG_YES=1 rig remove hyprland > /tmp/remove.log 2>&1
check "deselect: original greetd config back" '! grep -q "uwsm start" /etc/greetd/config.toml'
check "deselect: Hyprland's configs gone" '[[ ! -e ~/.config/hypr/hyprland.lua && ! -e ~/.local/bin/desk ]]'

~/.local/bin/rig uninstall --everything --yes > /tmp/uninstall.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]' || tail -20 /tmp/uninstall.log
pkgs | sort > /tmp/pkgs-after.txt
check "packages back to before" '[[ "$(cat /tmp/pkgs-before.txt)" == "$(cat /tmp/pkgs-after.txt)" ]]' || diff /tmp/pkgs-before.txt /tmp/pkgs-after.txt | sed "s/^/DIFF /" | head -20
done_tests
