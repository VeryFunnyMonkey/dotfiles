# packages: kconfig xdg-utils ghostty
# OS settings items on KDE (and Ghostty's config): applied, then restored exactly.
install_rig --profile minimal --yes
# pretend to be a KDE Wayland desktop (detection is stored in chezmoi's config)
pretend_kde
# a stand-in for Kate, the text handler before rig (the real app isn't installed here)
mkdir -p ~/.local/share/applications ~/.config
printf '[Desktop Entry]\nType=Application\nName=Kate\nExec=true\nMimeType=text/plain;\n' > ~/.local/share/applications/org.kde.kate.desktop
printf '[Default Applications]\ntext/plain=org.kde.kate.desktop\n' > ~/.config/mimeapps.list
# what rig writes and restores: the user's mimeapps.list defaults
mime_of() { awk -F= -v t="$1" '/^\[/ {sec=$0} sec=="[Default Applications]" && $1==t {print $2; exit}' ~/.config/mimeapps.list 2>/dev/null; }
before_mime=$(mime_of text/plain)
check "starting point: text opens in Kate" '[[ $before_mime == org.kde.kate.desktop ]]'
RIG_YES=1 rig setup --profile desktop --select terminal-default,text-in-nvim --yes > /tmp/setup.log 2>&1
check "setup ok" '[[ $? -eq 0 ]]'
check "ghostty config installed" '[[ -L ~/.config/ghostty/config && -f ~/.config/ghostty/config-os ]]'
ghostty +validate-config > /tmp/gv.log 2>&1
check "ghostty accepts the config" '[[ $? -eq 0 ]]'
cat /tmp/gv.log | head -5
check "KDE terminal set to Ghostty" '[[ $(kreadconfig6 --file kdeglobals --group General --key TerminalApplication) == ghostty ]]'
check "xdg-terminals.list" 'grep -qx com.mitchellh.ghostty.desktop ~/.config/xdg-terminals.list'
check "text opens in nvim" '[[ $(mime_of text/plain) == nvim.desktop ]]'
RIG_YES=1 rig remove text-in-nvim > /tmp/rm1.log 2>&1
check "deselect restores the previous text handler (kate)" '[[ $(mime_of text/plain) == "$before_mime" ]]'
check "and a type with no previous handler is unset again" '[[ -z $(mime_of text/x-lua) ]]'
RIG_YES=1 rig remove terminal-default > /tmp/rm2.log 2>&1
check "deselect removes the KDE keys (were unset)" '[[ -z $(kreadconfig6 --file kdeglobals --group General --key TerminalApplication) ]]'
check "and the xdg-terminals.list rig created" '[[ ! -e ~/.config/xdg-terminals.list ]]'
RIG_YES=1 rig add terminal-default text-in-nvim > /tmp/add.log 2>&1
~/.local/bin/rig uninstall --everything --yes > /tmp/un.log 2>&1
check "uninstall restores settings" '[[ $(mime_of text/plain) == "$before_mime" && -z $(kreadconfig6 --file kdeglobals --group General --key TerminalApplication) ]]' || {
  echo "text/plain: $(mime_of text/plain) (wanted $before_mime)"
  grep -iE "setting|restor|warn|error" /tmp/un.log | head -20; }
done_tests
