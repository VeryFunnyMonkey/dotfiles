# shellcheck shell=bash
# pkg/downloads.sh: things no package manager ships suitably, fetched by rig.
# Each download <d> provides dl_<d>_url (what it fetches), dl_<d>_present,
# dl_<d>_install, dl_<d>_remove (dashes as underscores). packages.yaml says which platforms use them.

# win32yank: the Windows clipboard for nvim on WSL
dl_win32yank_url() { echo https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip; }
dl_win32yank_present() { [[ -x $HOME/.local/bin/win32yank.exe ]]; }
dl_win32yank_install() {
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/w.zip" "$(dl_win32yank_url)"
  unzip -o -q "$tmp/w.zip" win32yank.exe -d "$HOME/.local/bin" && chmod +x "$HOME/.local/bin/win32yank.exe"
  rm -rf "$tmp"
}
dl_win32yank_remove() { rm -f "$HOME/.local/bin/win32yank.exe"; }

# JetBrainsMono Nerd Font, where the distro doesn't package it
dl_nerd_font_url() { echo https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz; }
dl_nerd_font_present() { compgen -G "$DATA_HOME/fonts/JetBrainsMonoNerdFont*" >/dev/null; }
dl_nerd_font_install() {
  local tmp; tmp=$(mktemp -d)
  mkdir -p "$DATA_HOME/fonts"
  curl -fsSL -o "$tmp/f.tar.xz" "$(dl_nerd_font_url)"
  tar -xJf "$tmp/f.tar.xz" -C "$DATA_HOME/fonts" --wildcards 'JetBrainsMonoNerdFont*'
  if have fc-cache; then fc-cache -f "$DATA_HOME/fonts" >/dev/null; fi
  rm -rf "$tmp"
}
dl_nerd_font_remove() { rm -f "$DATA_HOME/fonts/"JetBrainsMonoNerdFont*; }

# Tailscale's own installer, on distros without a suitable package
dl_tailscale_url() { echo https://tailscale.com/install.sh; }
dl_tailscale_present() { have tailscale; }
dl_tailscale_install() { curl -fsSL "$(dl_tailscale_url)" | sh; }
dl_tailscale_remove() { warn "Tailscale was installed with its own script; remove it with your package manager"; }
