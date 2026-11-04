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
check "Helium from the AUR, through yay (installed by the bootstrap)" 'pacman -Q helium-browser-bin yay-bin >/dev/null && command -v helium-browser >/dev/null'
check "links open in Helium" '[[ $(awk -F= "/^x-scheme-handler\/https=/ {print \$2}" ~/.config/mimeapps.list) == helium.desktop ]]'
check "drift: rig's own yay isn't reported" '! rig drift 2>&1 | grep -q yay'
# every program the desktop starts or a key runs must be installed (a minimal
# Arch install lacks things a container image happens to have, like less)
cmds="waybar hypridle hyprlock swayosd-server swayosd-client wl-paste wl-copy cliphist fuzzel ghostty thunar yazi wiremix nmtui bluetui hyprsunset grim slurp satty jq gtk-launch xdg-settings notify-send uwsm playerctl brightnessctl wpctl loginctl less pgrep xdg-user-dirs-update"
missing=$(for c in $cmds; do command -v "$c" >/dev/null || printf '%s ' "$c"; done)
check "every program the desktop calls is installed" '[[ -z $missing ]]' || echo "  missing: $missing"
check "the welcome page renders" 'desk welcome --print | grep -q "Welcome to Hyprland" && desk welcome --print | grep -q "rig info hyprland"'
check "desk works" 'desk help | grep -q "desk power" && desk nightlight status | jq -e ".class == \"off\"" >/dev/null'
# the battery: a fake one, and a notify-send that writes down what it's asked
mkdir -p /tmp/ps/BAT0 /tmp/nbin; printf '#!/bin/sh\necho "$*" >> /tmp/notified\n' >/tmp/nbin/notify-send; chmod +x /tmp/nbin/notify-send
bat() { echo "$1" >/tmp/ps/BAT0/capacity; echo "$2" >/tmp/ps/BAT0/status; PATH=/tmp/nbin:$PATH DESK_POWER_SUPPLY=/tmp/ps desk battery check "$3"; }
bat 50 Discharging 0; bat 14 Discharging 0; bat 4 Discharging 1; bat 14 Charging 2
check "battery: low and critical notifications" '[[ $(grep -c "Battery low: 14%" /tmp/notified) == 1 && $(grep -c -- "-u critical Battery at 4%" /tmp/notified) == 1 && $(wc -l </tmp/notified) == 2 ]]' || cat /tmp/notified
check "battery: no battery, nothing to watch" 'DESK_POWER_SUPPLY=/tmp/none timeout 5 desk battery watch'
check "battery: plugged in, no suspend" 'DESK_POWER_SUPPLY=/tmp/ps desk battery suspend-if-unplugged'
check "idle suspends on battery only" 'grep -q "desk battery suspend-if-unplugged" ~/.config/hypr/hypridle.conf'
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
