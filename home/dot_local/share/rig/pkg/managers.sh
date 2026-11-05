# shellcheck shell=bash
# pkg/managers.sh: the package managers. Each manager <m> provides
#   pm_<m>_present <name>      installed?
#   pm_<m>_install <names...>  install
#   pm_<m>_remove <names...>   uninstall
#   pm_<m>_search <query...>   search            (native managers and brew)
#   pm_<m>_upgrade             upgrade everything (native managers and brew)
#   pm_<m>_explicit            "<m>\t<name>" for each explicitly installed package
#   pm_<m>_exists <name>       is there a package by that name to install? 0 yes,
#                              1 no, 2 couldn't tell (network); for
#                              scripts/check-packages.sh, which catches upstream renames
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
# The AUR helper if there is one (it also installs and upgrades repo packages,
# so rig update updates AUR packages too): yay, else paru, else plain pacman.
pacman_helper() { if have yay; then echo yay; elif have paru; then echo paru; else echo pacman; fi; }
pm_pacman_present() { pacman -Q "$1" >/dev/null 2>&1 || pacman -Qg "$1" >/dev/null 2>&1; }
pm_pacman_install() {
  local h; h=$(pacman_helper)
  if [[ $h == pacman ]]; then sudo_ pacman -S --needed --noconfirm "$@"; else "$h" -S --needed --noconfirm "$@"; fi
}
pm_pacman_remove() { sudo_ pacman -Rns --noconfirm "$@"; }
pm_pacman_search() { local h; h=$(pacman_helper); if [[ $h == pacman ]]; then pacman -Ss "$@"; else "$h" -Ss "$@"; fi; }
pm_pacman_upgrade() { local h; h=$(pacman_helper); if [[ $h == pacman ]]; then sudo_ pacman -Syu --noconfirm; else "$h" -Syu --noconfirm; fi; }
pm_pacman_explicit() { pacman -Qqen | sed 's/^/pacman\t/'; }   # repo packages (the AUR ones: pm_aur_explicit)
pm_pacman_exists() { pacman -Si -- "$1" >/dev/null 2>&1 || [[ -n $(pacman -Sgq -- "$1" 2>/dev/null) ]]; }

# ------------------------------------------------------------- aur ----------
# AUR packages, built by the AUR helper. On Arch the bootstrap installs yay
# (yay-bin) unless yay or paru is already there.
aur_helper() {
  if have yay; then echo yay; elif have paru; then echo paru
  else die "no AUR helper (yay); run: chezmoi state delete-bucket --bucket=scriptState && chezmoi apply"; fi
}
pm_aur_present() { pm_pacman_present "$1"; }
pm_aur_install() { local h; h=$(aur_helper); "$h" -S --needed --noconfirm "$@"; }
pm_aur_remove() { pm_pacman_remove "$@"; }
pm_aur_explicit() { pacman -Qqem | sed 's/^/aur\t/'; }
pm_aur_exists() {
  local out; out=$(curl -fsS --retry 3 "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=$1") || return 2
  [[ $out == *'"resultcount":1'* ]]
}

# ------------------------------------------------------------- apt ----------
pm_apt_present() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }
pm_apt_install() { sudo_ apt-get update -qq; sudo_ env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
pm_apt_remove() { sudo_ env DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"; }
pm_apt_search() { apt-cache search "$@"; }
pm_apt_upgrade() { sudo_ apt-get update && sudo_ env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; }
pm_apt_explicit() { apt-mark showmanual | sed 's/^/apt\t/'; }
pm_apt_exists() { [[ -n $(apt-cache policy -- "$1" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)"') ]]; }

# ------------------------------------------------------------- dnf ----------
pm_dnf_present() { rpm -q "$1" >/dev/null 2>&1; }
pm_dnf_install() { sudo_ dnf install -y "$@"; }
pm_dnf_remove() { sudo_ dnf remove -y "$@"; }
pm_dnf_search() { dnf search "$@"; }
pm_dnf_upgrade() { sudo_ dnf upgrade --refresh -y; }
pm_dnf_explicit() { dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sed 's/^/dnf\t/'; }
pm_dnf_exists() { [[ -n $(dnf -q repoquery --qf '%{name}\n' -- "$1" 2>/dev/null) ]]; }

# ------------------------------------------------------------- brew ---------
pm_brew_present() {
  if [[ $1 == --cask\ * ]]; then
    local c=${1#--cask } app
    brew list --cask "$c" >/dev/null 2>&1 && return 0
    # installed another way (the App Store, a download): the cask's app is there,
    # so rig doesn't install over it (and, as "already there", never removes it)
    app=$(brew info --cask --json=v2 "$c" 2>/dev/null | brew_cask_app)
    [[ -n $app ]] && { [[ -d /Applications/$app ]] || [[ -d $HOME/Applications/$app ]]; }
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

# The app a cask puts in Applications, from `brew info --cask --json=v2` (the
# text output varies): its app artifact, or for casks that run an installer
# (.pkg) instead, its name + .app.
brew_cask_app() {
  local j app name
  j=$(tr -d '\n' | tr -s ' ')
  app=$(printf '%s' "$j" | grep -o '"app": *\[ *"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
  name=$(printf '%s' "$j" | grep -o '"name": *\[ *"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
  if [[ -n $app ]]; then printf '%s\n' "$app"; elif [[ -n $name ]]; then printf '%s.app\n' "$name"; fi
}
pm_brew_remove() { brew uninstall "$@"; }
pm_brew_search() { brew search "$@"; }
pm_brew_upgrade() { brew update && brew upgrade; }
pm_brew_explicit() {
  brew leaves 2>/dev/null | sed 's/^/brew\t/'
  brew list --cask 2>/dev/null | sed 's/^/brew\t--cask /'
}
# Asks Homebrew's API (no brew needed, so it runs on any machine). A name in a
# tap (user/tap/name) is looked up in the tap's repository.
pm_brew_exists() {
  local kind=formula n=$1
  if [[ $n == --cask\ * ]]; then kind=cask; n=${n#--cask }; fi
  if [[ $n == */*/* ]]; then
    local user=${n%%/*} rest=${n#*/}; local tap=${rest%%/*} name=${rest#*/} dir=Formula
    [[ $kind == cask ]] && dir=Casks
    url_exists "https://raw.githubusercontent.com/$user/homebrew-$tap/HEAD/$dir/$name.rb"
  else
    url_exists "https://formulae.brew.sh/api/$kind/$n.json"
  fi
}

# ------------------------------------------------------------- winget -------
# Windows (WSL): packages on the Windows side, through winget.exe (WSL's
# interop). Per user where the package offers it (PowerToys), so there's no
# admin prompt; GlazeWM installs for all users, so Windows asks once.
winget_() { local w; w=$(win_exe winget.exe) || { warn "winget isn't on this Windows (App Installer, from the Microsoft Store)"; return 1; }; (cd /mnt/c && "$w" "$@" --accept-source-agreements --disable-interactivity); }
pm_winget_present() { winget_ list --id "$1" --exact --source winget >/dev/null 2>&1; }
pm_winget_install() {
  local id rc=0
  for id in "$@"; do
    # per user if the package offers it; else for all users (Windows asks for admin)
    winget_ install --id "$id" --exact --source winget --silent --scope user --accept-package-agreements >/dev/null 2>&1 ||
      winget_ install --id "$id" --exact --source winget --silent --accept-package-agreements || rc=1
  done
  return $rc
}
pm_winget_remove() { local id; for id in "$@"; do winget_ uninstall --id "$id" --exact --source winget --silent || true; done; }
pm_winget_upgrade() { winget_ upgrade --all --silent --accept-package-agreements || true; }
pm_winget_search() { winget_ search "$@"; }
pm_winget_explicit() { :; }   # Windows' own list isn't rig's to judge (drift stays on the Linux side)
# winget's package index on GitHub (no winget needed, so it runs anywhere):
# Publisher.Name lives at manifests/<p>/<Publisher>/<Name> (p: its first letter, lowercase).
pm_winget_exists() {
  local pub=${1%%.*} name=${1#*.} letter
  letter=$(printf '%s' "${pub:0:1}" | tr '[:upper:]' '[:lower:]')
  url_exists "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$letter/$pub/${name//.//}"
}

# ------------------------------------------------------------- download -----
# Things rig fetches itself (pkg/downloads.sh), one at a time.
pm_download_present() { "dl_${1//-/_}_present"; }
pm_download_install() { local n; for n in "$@"; do "dl_${n//-/_}_install"; done; }
pm_download_remove() { local n; for n in "$@"; do "dl_${n//-/_}_remove"; done; }
pm_download_exists() { url_exists "$("dl_${1//-/_}_url")"; }

# 0 the URL answers, 1 it's gone (404/410), 2 no answer (retried; network, 5xx)
url_exists() {
  local code; code=$(curl -sSL --retry 3 -o /dev/null -w '%{http_code}' -r 0-0 "$1" 2>/dev/null) || code=000
  case $code in 2??) return 0 ;; 404|410) return 1 ;; *) return 2 ;; esac
}
