# WSL (run on a real WSL2 distro by CI's wsl job, not in a container):
# detection, the Windows-side pieces (win32yank, wslview), what's skipped.
install_rig --profile minimal --select clipboard,zoxide,ghostty,nerd-font --yes
check "install ok" '[[ $? -eq 0 ]] && grep -q "nvim bootstrap done" /tmp/install.log' || tail -30 /tmp/install.log
check "WSL detected and stored" 'grep -q "wsl = true" ~/.config/chezmoi/chezmoi.toml && grep -q "display = \"wsl\"" ~/.config/chezmoi/chezmoi.toml'
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
doc=$(rig doctor 2>&1); check "doctor: packages" '[[ $doc == *"all declared packages installed"* ]]' || echo "$doc"
~/.local/bin/rig uninstall --everything --yes > /tmp/uninstall.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]' || tail -20 /tmp/uninstall.log
check "win32yank removed" '[[ ! -e ~/.local/bin/win32yank.exe ]]'
done_tests
