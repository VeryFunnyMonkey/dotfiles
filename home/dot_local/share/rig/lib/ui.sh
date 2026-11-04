# shellcheck shell=bash
# lib/ui.sh: everything rig prints or asks: messages, confirmations, the
# terminal prompts used by walkthroughs, gum menu helpers, doctor checks.

# ------------------------------------------------------------- output -------
# shared by every part of rig
# shellcheck disable=SC2034
if [[ -t 1 ]]; then
  B=$'\e[1m' DIM=$'\e[2m' R=$'\e[31m' G=$'\e[32m' Y=$'\e[33m' BL=$'\e[34m' N=$'\e[0m'
else
  B='' DIM='' R='' G='' Y='' BL='' N=''
fi

say()  { printf '%s\n' "$*"; }

info() { printf '%s==>%s %s\n' "$BL" "$N" "$*"; }

ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }

warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*" >&2; }

bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; }

die()  { printf '%srig:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

# ------------------------------------------------------------- asking -------

# Can rig ask the user something? Not without a terminal, and not under
# `rig setup --yes` (RIG_NONINTERACTIVE), which reaches chezmoi's scripts too.
can_ask() { [[ ${RIG_NONINTERACTIVE:-0} != 1 ]] && { : </dev/tty; } 2>/dev/null; }

confirm() {
  local reply
  if [[ ${RIG_YES:-0} == 1 ]]; then return 0; fi
  can_ask || return 1   # nobody to ask: the answer is no
  read -r -p "$1 [y/N] " reply </dev/tty || return 1
  [[ $reply == [yY]* ]]
}

# Walkthrough prompts: they read the terminal on fd 3 (tty_in opens it), so
# they work while stdin is a pipe.

# ------------------------------------------------------------- prompts --------
tty_in() { exec 3</dev/tty || die "rig git needs a terminal"; }

ask() { # var prompt [default]
  local __v=$1 __p=$2 __d=${3:-} __r
  if [[ -n $__d ]]; then printf '  %s [%s]: ' "$__p" "$__d" >/dev/tty; else printf '  %s: ' "$__p" >/dev/tty; fi
  IFS= read -r __r <&3 || __r=""
  if [[ -z $__r ]]; then __r=$__d; fi
  printf -v "$__v" '%s' "$__r"
}

ask_yn() { # prompt default(y|n)
  local r d=${2:-n}
  printf '  %s [%s]: ' "$1" "$([[ $d == y ]] && echo Y/n || echo y/N)" >/dev/tty
  IFS= read -r r <&3 || r=""
  if [[ -z $r ]]; then r=$d; fi
  [[ $r == [yY]* ]]
}

choose() { # var prompt default option...
  local __v=$1 __p=$2 __d=$3 i=1 __r o; shift 3
  printf '  %s\n' "$__p" >/dev/tty
  for o in "$@"; do printf '    %d) %s\n' "$i" "$o" >/dev/tty; ((i++)); done
  while :; do
    printf '  choice [%s]: ' "$__d" >/dev/tty
    IFS= read -r __r <&3 || __r=""
    if [[ -z $__r ]]; then __r=$__d; fi
    if [[ $__r =~ ^[0-9]+$ ]] && ((__r >= 1 && __r <= $#)); then __r=${!__r}; fi
    for o in "$@"; do [[ $o == "$__r" ]] && { printf -v "$__v" '%s' "${o%% *}"; return; }; [[ ${o%% *} == "$__r" ]] && { printf -v "$__v" '%s' "$__r"; return; }; done
    printf '  pick one of the numbers above\n' >/dev/tty
  done
}

copy_clipboard() {
  if have pbcopy; then pbcopy
  elif have clip.exe; then clip.exe
  elif [[ -n ${WAYLAND_DISPLAY:-} ]] && have wl-copy; then wl-copy
  elif have xclip; then xclip -selection clipboard
  else return 1; fi
}

open_url() {
  if have wslview; then wslview "$1"
  elif have open && [[ $(uname) == Darwin ]]; then open "$1"
  elif have xdg-open; then xdg-open "$1" >/dev/null 2>&1
  else return 1; fi
}

# ------------------------------------------------------------- menus --------

# gum choose prints "nothing selected" when a menu is left with Esc; that's how
# you go back here, so erase the line instead of leaving it over the next menu.
gum_choose() {
  local rc=0
  gum choose "$@" || rc=$?
  if ((rc)); then printf '\033[1A\033[2K' >/dev/tty; fi
  return $rc
}

# A menu's rows change as you pick (they show the current choices), so the row
# to come back to is found by its label: the text before ":" or the padding.
row_key() { local k=${1%%:*}; printf '%s' "${k%%  *}"; }

cursor_on() { # previous-choice rows... -> --selected=<the row with the same label>, if any
  local want r; want=$(row_key "$1"); shift
  [[ -n $want ]] || return 0
  for r in "$@"; do if [[ $(row_key "$r") == "$want" ]]; then printf -- '--selected=%s' "$r"; return 0; fi; done
}

# Menu rows can't contain commas: gum reads --selected (where the cursor
# returns to) as a comma-separated list. Items are joined with " · " instead.
menu_rows() { local r; for r in "$@"; do printf '%s\n' "${r//,/;}"; done; }

# ------------------------------------------------------------- doctor -------
# Modules report health with these; rig doctor counts the problems.
DOCTOR_FAILS=0
check_ok() { ok "$@"; }
check_bad() { bad "$@"; DOCTOR_FAILS=$((DOCTOR_FAILS + 1)); }
