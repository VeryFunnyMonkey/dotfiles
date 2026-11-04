# packages: kconfig xdg-utils
# The keyboard-driven desktop item on KDE: shortcuts applied, then restored exactly.
rd() { kreadconfig6 --file "$1" --group "$2" --key "$3"; }
install_rig --profile minimal --yes
pretend_kde
# seed what Plasma has by default
kwriteconfig6 --file kglobalshortcutsrc --group ksmserver --key "Lock Session" "$(printf 'Screensaver\tMeta+L,Screensaver\tMeta+L,Lock Session')"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Switch Window Left" "Meta+Alt+Left,Meta+Alt+Left,Switch to Window to the Left"
kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate task manager entry 1" "Meta+1,Meta+1,Activate Task Manager Entry 1"
cp ~/.config/kglobalshortcutsrc /tmp/ksc-before
lock_before=$(rd kglobalshortcutsrc ksmserver "Lock Session")
RIG_YES=1 rig add wm > /tmp/add.log 2>&1
check "add wm ok" '[[ $? -eq 0 ]]'
check "mod+h focuses left" '[[ $(rd kglobalshortcutsrc kwin "Switch Window Left") == "Meta+H,Meta+Alt+Left,Switch to Window to the Left" ]]'
check "desktops 1-9 on mod+N" '[[ $(rd kglobalshortcutsrc kwin "Switch to Desktop 9") == Meta+9,* ]]'
check "lock screen moved to Meta+Escape (tab kept)" '[[ $(rd kglobalshortcutsrc ksmserver "Lock Session") == "$(printf "Screensaver\tMeta+Escape,Screensaver\tMeta+L,Lock Session")" ]]'
check "taskbar Meta+1 cleared" '[[ $(rd kglobalshortcutsrc plasmashell "activate task manager entry 1") == none,* ]]'
check "krunner on Meta+Space (nested group)" '[[ $(kreadconfig6 --file kglobalshortcutsrc --group services --group org.kde.krunner.desktop --key _launch) == "Meta+Space" ]]'
check "9 desktops" '[[ $(rd kwinrc Desktops Number) == 9 ]]'
check "no AeroSpace config on Linux" '[[ ! -e ~/.config/aerospace ]]'
RIG_YES=1 rig remove wm > /tmp/rm.log 2>&1
check "deselect restores lock screen exactly" '[[ $(rd kglobalshortcutsrc ksmserver "Lock Session") == "$lock_before" ]]'
check "deselect restores Switch Window Left" '[[ $(rd kglobalshortcutsrc kwin "Switch Window Left") == "Meta+Alt+Left,Meta+Alt+Left,Switch to Window to the Left" ]]'
check "keys that weren't set are gone again" '[[ -z $(rd kglobalshortcutsrc kwin "Switch to Desktop 9") && -z $(rd kwinrc Desktops Number) ]]'
check "settings ledger empty" '[[ ! -s ~/.local/state/rig/applied-settings ]]' || { echo "ledger left:"; cat ~/.local/state/rig/applied-settings; }
done_tests
