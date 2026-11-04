# shellcheck shell=bash
# pkg/managers.sh: the package managers. Each manager <m> provides
#   pm_<m>_present <name>      installed?
#   pm_<m>_install <names...>  install
#   pm_<m>_remove <names...>   uninstall
#   pm_<m>_search <query...>   search            (native managers and brew)
#   pm_<m>_upgrade             upgrade everything (native managers and brew)
#   pm_<m>_explicit            "<m>\t<name>" for each explicitly installed package
# A name can hold several packages ("gcc make") or a brew cask ("--cask x").
# Adding a manager is adding these functions; nothing else changes.

pkg_present() { # manager name
  local f="pm_$1_present"
  declare -F "$f" >/dev/null && "$f" "$2"
}
pkg_install_cmd() { # manager names...
  local m=$1; shift
  # shellcheck disable=SC2206
  local names=($*)
  "pm_${m}_install" "${names[@]}"
}
pkg_remove_cmd() { # manager names...
  local m=$1; shift
  # shellcheck disable=SC2206
  local names=($*)
  "pm_${m}_remove" "${names[@]}"
}
pkg_explicit() { # every manager in use here
  if declare -F "pm_${RIG_NATIVE:-}_explicit" >/dev/null; then "pm_${RIG_NATIVE}_explicit"; fi
  if [[ ${RIG_NATIVE:-} == pacman ]]; then pm_aur_explicit; fi
  if [[ ${RIG_NATIVE:-} != brew ]] && have brew; then pm_brew_explicit; fi
}

# ------------------------------------------------------------- pacman -------
# AUR helper if there is one (it also installs repo packages).
pacman_helper() { if have paru; then echo paru; elif have yay; then echo yay; else echo pacman; fi; }
pm_pacman_present() { pacman -Q "$1" >/dev/null 2>&1 || pacman -Qg "$1" >/dev/null 2>&1; }
pm_pacman_install() {
  local h; h=$(pacman_helper)
  if [[ $h == pacman ]]; then sudo_ pacman -S --needed --noconfirm "$@"; else "$h" -S --needed --noconfirm "$@"; fi
}
pm_pacman_remove() { sudo_ pacman -Rns --noconfirm "$@"; }
pm_pacman_search() { local h; h=$(pacman_helper); if [[ $h == pacman ]]; then pacman -Ss "$@"; else "$h" -Ss "$@"; fi; }
pm_pacman_upgrade() { local h; h=$(pacman_helper); if [[ $h == pacman ]]; then sudo_ pacman -Syu --noconfirm; else "$h" -Syu --noconfirm; fi; }
pm_pacman_explicit() { pacman -Qqen | sed 's/^/pacman\t/'; }   # repo packages (the AUR ones: pm_aur_explicit)

# ------------------------------------------------------------- aur ----------
# AUR packages, built by paru or yay. With neither, rig builds paru-bin once
# (recorded like any package it installs, so uninstall removes it again).
aur_helper() {
  if have paru; then echo paru; return 0; fi
  if have yay; then echo yay; return 0; fi
  info "installing paru (builds AUR packages)" >&2
  local tmp; tmp=$(mktemp -d)
  ledger_pkg_record pacman paru-bin paru installed
  # build, then install only paru itself (makepkg may also build a -debug package)
  git clone -q --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" >&2 &&
    (cd "$tmp/paru-bin" && makepkg -s --noconfirm --needed >&2 &&
      sudo_ pacman -U --noconfirm --needed "$(find . -maxdepth 1 -name 'paru-bin-[0-9]*.pkg.tar.*' | head -n1)" >&2) ||
    { rm -rf "$tmp"; die "couldn't build paru"; }
  rm -rf "$tmp"
  echo paru
}
pm_aur_present() { pm_pacman_present "$1"; }
pm_aur_install() { local h; h=$(aur_helper); "$h" -S --needed --noconfirm "$@"; }
pm_aur_remove() { pm_pacman_remove "$@"; }
pm_aur_explicit() { pacman -Qqem | sed 's/^/aur\t/'; }

# ------------------------------------------------------------- apt ----------
pm_apt_present() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }
pm_apt_install() { sudo_ apt-get update -qq; sudo_ env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
pm_apt_remove() { sudo_ env DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"; }
pm_apt_search() { apt-cache search "$@"; }
pm_apt_upgrade() { sudo_ apt-get update && sudo_ env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; }
pm_apt_explicit() { apt-mark showmanual | sed 's/^/apt\t/'; }

# ------------------------------------------------------------- dnf ----------
pm_dnf_present() { rpm -q "$1" >/dev/null 2>&1; }
pm_dnf_install() { sudo_ dnf install -y "$@"; }
pm_dnf_remove() { sudo_ dnf remove -y "$@"; }
pm_dnf_search() { dnf search "$@"; }
pm_dnf_upgrade() { sudo_ dnf upgrade --refresh -y; }
pm_dnf_explicit() { dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sed 's/^/dnf\t/'; }

# ------------------------------------------------------------- brew ---------
pm_brew_present() {
  if [[ $1 == --cask\ * ]]; then brew list --cask "${1#--cask }" >/dev/null 2>&1
  else brew list --formula "$1" >/dev/null 2>&1; fi
}

# brew's --cask applies to the whole command: formulas and casks go separately
pm_brew_install() {
  local f=() c=() rc=0
  while (($#)); do
    if [[ $1 == --cask ]]; then c+=("$2"); shift 2; else f+=("$1"); shift; fi
  done
  if ((${#f[@]})); then brew install "${f[@]}" || rc=1; fi
  if ((${#c[@]})); then brew install --cask "${c[@]}" || rc=1; fi
  return $rc
}

pm_brew_remove() { brew uninstall "$@"; }
pm_brew_search() { brew search "$@"; }
pm_brew_upgrade() { brew update && brew upgrade; }
pm_brew_explicit() {
  brew leaves 2>/dev/null | sed 's/^/brew\t/'
  brew list --cask 2>/dev/null | sed 's/^/brew\t--cask /'
}

# ------------------------------------------------------------- download -----
# Things rig fetches itself (pkg/downloads.sh), one at a time.
pm_download_present() { "dl_${1//-/_}_present"; }
pm_download_install() { local n; for n in "$@"; do "dl_${n//-/_}_install"; done; }
pm_download_remove() { local n; for n in "$@"; do "dl_${n//-/_}_remove"; done; }
