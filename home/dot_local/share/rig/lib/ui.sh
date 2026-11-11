# shellcheck shell=bash
# lib/ui.sh: everything rig prints or asks: messages, confirmations, the
# terminal prompts used by walkthroughs, gum menu helpers, doctor checks.

# Output (say, info, ok, warn, bad, die) and colours are in lib/base.sh.

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

# A multi-select menu. Not gum choose --no-limit: in gum 2 space doesn't tick
# there (charmbracelet/gum#1143). Keys: up/down or j/k move, space (or x, tab)
# ticks, a ticks all or none, enter is done, esc or q goes back (returns 1).
# Draws on the terminal; prints the ticked rows, in order.
pick_many() { # header height ticked-rows(one per line) rows...
  local header=$1 height=$2 pre=$3; shift 3
  local rows=("$@") n=$# cur=0 top=0 i k rest drawn=0 cols tick=() any line
  ((n)) || return 1
  cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}'); if ((${cols:-0} < 20)); then cols=80; fi
  for ((i = 0; i < n; i++)); do
    if grep -qxF -- "${rows[i]}" <<<"$pre"; then tick[i]=1; else tick[i]=0; fi
  done
  ((height < n)) || height=$n
  local hi dim=$'\e[2m' off=$'\e[0m'
  hi=$(fg_hex "${THEME_AQUA:-}" $'\e[38;5;212m')
  pick_draw() {
    local out='' r p
    if ((drawn)); then out+=$'\e['"${drawn}F"; fi
    drawn=0
    while IFS= read -r line; do out+=$'\e[2K'"${line:0:cols-1}"$'\n'; drawn=$((drawn + 1)); done <<<"$header"
    for ((r = top; r < top + height; r++)); do
      if ((tick[r])); then p="✓ "; else p="• "; fi
      line="${rows[r]:0:cols-5}"
      if ((r == cur)); then out+=$'\e[2K'"$hi> $p$line$off"$'\n'; else out+=$'\e[2K'"  $p$line"$'\n'; fi
      drawn=$((drawn + 1))
    done
    out+=$'\e[2K'"$dim  ↑↓ move · space tick · a all · enter done · esc back$off"$'\n'; drawn=$((drawn + 1))
    printf '%s' "$out" >/dev/tty
  }
  pick_end() { printf '\e[%dF\e[J\e[?25h' "$drawn" >/dev/tty; }
  trap 'pick_end; exit 130' INT
  printf '\e[?25l' >/dev/tty
  while :; do
    pick_draw
    IFS= read -rsn1 k </dev/tty || { pick_end; return 1; }
    if [[ $k == $'\e' ]]; then
      rest=''; IFS= read -rsn2 -t 0.05 rest </dev/tty || true
      case $rest in '[A' | OA) k=up ;; '[B' | OB) k=down ;; *) k=esc ;; esac
    fi
    case $k in
      up | k) if ((cur > 0)); then cur=$((cur - 1)); fi ;;
      down | j) if ((cur < n - 1)); then cur=$((cur + 1)); fi ;;
      ' ' | x | $'\t') tick[cur]=$((1 - tick[cur])) ;;
      a)
        any=0; for ((i = 0; i < n; i++)); do if ((!tick[i])); then any=1; fi; done
        for ((i = 0; i < n; i++)); do tick[i]=$any; done ;;
      '') break ;;
      esc | q) pick_end; return 1 ;;
    esac
    if ((cur < top)); then top=$cur; fi
    if ((cur >= top + height)); then top=$((cur - height + 1)); fi
  done
  pick_end
  for ((i = 0; i < n; i++)); do if ((tick[i])); then printf '%s\n' "${rows[i]}"; fi; done
}

# Menu rows can't contain commas: gum reads --selected (where the cursor
# returns to) as a comma-separated list. Items are joined with " · " instead.
menu_rows() { local r; for r in "$@"; do printf '%s\n' "${r//,/;}"; done; }

# ------------------------------------------------------------- doctor -------
# Modules report health with these; rig doctor counts the problems.
DOCTOR_FAILS=0
check_ok() { ok "$@"; }
check_bad() { bad "$@"; DOCTOR_FAILS=$((DOCTOR_FAILS + 1)); }
