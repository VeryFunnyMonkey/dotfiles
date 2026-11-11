# shellcheck shell=bash
# lib/base.sh: what every tool here starts from (rig, dev, srv, desk): output,
# `have`, the theme's colours and the fzf picker. A tool sets TOOL (die's
# prefix) before loading it.
# shellcheck disable=SC2034

# ------------------------------------------------------------- output -------
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

die()  { printf '%s%s:%s %s\n' "$R" "${TOOL:-rig}" "$N" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------- theme --------
# THEME_<COLOUR> ('#rrggbb') and FZF_COLORS, rendered from theme.yaml. Not
# there yet (run from the repo before chezmoi apply): tools keep their own colours.
if [[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/rig/theme.sh ]]; then
  # shellcheck source=/dev/null
  source "${XDG_CONFIG_HOME:-$HOME/.config}/rig/theme.sh"
fi

# A theme colour ('#rrggbb') as a 24-bit terminal escape; the fallback
# (an escape) when there's no theme.
fg_hex() { # colour fallback
  local h=${1#\#}
  if [[ ${#h} == 6 ]]; then printf '\e[38;2;%d;%d;%dm' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; else printf '%s' "${2:-}"; fi
}

# gum's menus in the theme's accent, like pick_many and fzf
if [[ -n ${THEME_AQUA:-} ]]; then
  export GUM_CHOOSE_CURSOR_FOREGROUND=$THEME_AQUA GUM_CHOOSE_SELECTED_FOREGROUND=$THEME_AQUA
fi

# ------------------------------------------------------------- picker -------
# fzf the same way in every tool: full height, list at the top, the theme's
# colours. Options spelled out, so it looks the same in a tmux popup as in a
# shell. The rest (prompt, header, preview, keys) is the caller's.
pick() {
  fzf --height=100% --layout=reverse --border=none --info=hidden --no-scrollbar --gutter=' ' \
    ${FZF_COLORS:+"--color=$FZF_COLORS"} "$@"
}

# For --bind "start,resize:transform:$PREVIEW_FIT": the preview fits the
# space, beside the list when wide, below it when tall enough, hidden when
# small (ctrl-/ toggles it). Re-checked on every resize.
PREVIEW_FIT='if [ "$FZF_COLUMNS" -ge 100 ]; then echo "change-preview-window:right,45%,border-left,wrap,noinfo"; elif [ "$FZF_LINES" -ge 24 ]; then echo "change-preview-window:down,40%,border-top,wrap,noinfo"; else echo "change-preview-window:hidden"; fi'
