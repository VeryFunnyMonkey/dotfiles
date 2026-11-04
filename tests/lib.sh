# Sourced by the tests inside the container (as the test user).
set -uo pipefail
cd ~
export PATH=$HOME/.local/bin:$PATH TERM=xterm-256color
pass=0 fail=0
check() { if eval "$2"; then echo "PASS $1"; ((pass++)); else echo "FAIL $1"; ((fail++)); fi; }
done_tests() { echo "=== $pass passed, $fail failed"; ((fail == 0)); }
install_rig() { # install.sh args...
  RIG_SOURCE=~/dotfiles sh ~/dotfiles/install.sh "$@" > /tmp/install.log 2>&1
}
pkgs() { # explicitly installed packages, any distro
  if command -v pacman >/dev/null; then pacman -Qqe; else apt-mark showmanual; fi
  if command -v brew >/dev/null; then brew leaves; fi
  true
}
pretend_kde() { # make the machine look like a KDE Wayland desktop (stored detection)
  sed -i 's/^    display = .*/    display = "wayland"/; s/^    desktop = .*/    desktop = "kde"/' ~/.config/chezmoi/chezmoi.toml
}
