# Windows, through WSL (run on a real WSL2 distro by CI's windows job, not in a container):
# detection, the Windows-side pieces (win32yank, wslview), what's skipped, and
# the Windows items: Windows Terminal (font, fragment), GlazeWM (the wm item),
# PowerToys (always), all put back by rig uninstall.
# Windows' state before, to compare after the uninstall
for f in lib/sys.sh lib/ui.sh lib/windows.sh pkg/managers.sh; do source ~/dotfiles/home/dot_local/share/rig/$f; done
RIG_STATE=$(mktemp -d); export RIG_STATE
LAD=$(win_env LOCALAPPDATA); UP=$(win_env USERPROFILE)
fonts_before=$(ls "$LAD/Microsoft/Windows/Fonts" 2>/dev/null | grep -c JetBrainsMonoNerdFont || true)
install_rig --profile minimal --select clipboard,zoxide,ghostty,nerd-font,windows-terminal,wm --yes
check "install ok" '[[ $? -eq 0 ]] && grep -q "nvim bootstrap done" /tmp/install.log' || tail -30 /tmp/install.log
check "Windows detected and stored" 'grep -q "wsl = true" ~/.config/chezmoi/chezmoi.toml && grep -q "display = \"windows\"" ~/.config/chezmoi/chezmoi.toml'
check "clipboard on WSL: win32yank" '[[ -x ~/.local/bin/win32yank.exe ]]'
check "wslu (wslview opens the Windows browser)" 'command -v wslview >/dev/null'
check "no Linux clipboard tools on WSL" '! command -v wl-copy >/dev/null && ! command -v xclip >/dev/null'
check "Ghostty and the font skipped, with the reason" 'grep -q "skipped here: Ghostty" /tmp/install.log && grep -qi "nerd" /tmp/install.log'
# Homebrew's tools (nvim) on PATH for this bash, as the zsh config does
for b in /home/linuxbrew/.linuxbrew/bin/brew; do [[ -x $b ]] && eval "$("$b" shellenv)"; done
# nvim copies to and pastes from the Windows clipboard (through win32yank)
printf 'vim.fn.setreg("+", "rig-nvim")\nio.write(vim.fn.getreg("+"))\n' > /tmp/clip.lua
check "nvim uses the Windows clipboard" '[[ $(nvim --headless -l /tmp/clip.lua 2>&1) == *rig-nvim* ]]' || nvim --headless -l /tmp/clip.lua 2>&1 | tail -5
# the runner has no desktop session, so the Windows clipboard may refuse; report, don't fail
if printf rig-clip | ~/.local/bin/win32yank.exe -i 2>/dev/null && [[ $(~/.local/bin/win32yank.exe -o --lf 2>/dev/null) == rig-clip ]]; then
  echo "note: Windows clipboard round trip works"; else echo "note: Windows clipboard not reachable here (no desktop session)"; fi
# --- the Windows side
RIG_STATE=~/.local/state/rig
check "PowerToys always selected, not in the menus" 'rig modules list | grep -E "^ +powertoys +" | grep -q on && ! chezmoi execute-template "{{ includeTemplate \"catalog-tsv\" . }}" | grep -q powertoys'
check "winget installed PowerToys and GlazeWM" 'grep -qP "^winget\tMicrosoft.PowerToys\t" $RIG_STATE/packages.log && grep -qP "^winget\tglzr-io.glazewm\t" $RIG_STATE/packages.log' || grep winget /tmp/install.log
check "Windows Terminal: Nerd Font for Windows" '[[ -f "$LAD/Microsoft/Windows/Fonts/JetBrainsMonoNerdFont-Regular.ttf" ]] && win_reg query "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts" /v "JetBrainsMonoNerdFont-Regular (TrueType)" >/dev/null'
frag="$LAD/Microsoft/Windows Terminal/Fragments/rig/rig.json"
check "Windows Terminal: fragment with gruvbox and this distro's profile" 'grep -q "rig gruvbox" "$frag" && grep -qE "\"updates\": \"\{[0-9a-f-]{36}\}\"" "$frag"' || cat "$frag"
check "GlazeWM: rig's config, starts at login" 'cmp -s ~/.config/rig/windows/glazewm.yaml "$UP/.glzr/glazewm/config.yaml" && grep -q "alt+shift+h" "$UP/.glzr/glazewm/config.yaml" && win_reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v GlazeWM >/dev/null'
check "PowerToys: settings saved, then applied" '[[ -s $RIG_STATE/powertoys/App.json ]] && grep -qP "^powertoys-dsc\tApp\t" $RIG_STATE/system.log' || grep -i powertoys /tmp/install.log
doc=$(rig doctor 2>&1); check "doctor: packages" '[[ $doc == *"all declared packages installed"* ]]' || echo "$doc"
~/.local/bin/rig uninstall --everything --yes > /tmp/uninstall.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]' || tail -20 /tmp/uninstall.log
check "win32yank removed" '[[ ! -e ~/.local/bin/win32yank.exe ]]'
check "Windows put back: fragment, font, GlazeWM config and login entry" '[[ ! -e "$frag" && ! -e "$UP/.glzr/glazewm/config.yaml" ]] && [[ $(ls "$LAD/Microsoft/Windows/Fonts" 2>/dev/null | grep -c JetBrainsMonoNerdFont || true) == "$fonts_before" ]] && ! win_reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v GlazeWM >/dev/null 2>&1'
check "PowerToys and GlazeWM uninstalled (rig installed them)" '! pm_winget_present Microsoft.PowerToys && ! pm_winget_present glzr-io.glazewm'
done_tests
