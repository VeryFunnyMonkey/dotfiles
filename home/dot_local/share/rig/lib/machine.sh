# shellcheck shell=bash
# lib/machine.sh: where things live, and this machine's state: the selection
# rig setup made (kept in chezmoi's config) and the facts chezmoi rendered
# into machine.env.

# shared by every part of rig
# shellcheck disable=SC2034
{
RIG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rig"
RIG_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rig"
MACHINE_ENV="$RIG_CONFIG/machine.env"
PACKAGES_TSV="$RIG_CONFIG/packages.tsv"
CZ_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
}

load_machine() {
  [[ -r $MACHINE_ENV ]] || die "this machine isn't set up yet; run: rig setup"
  # shellcheck disable=SC1090
  source "$MACHINE_ENV"
}

repo_root() { git -C "$RIG_SOURCE_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$RIG_SOURCE_DIR"; }

# Source dir: the applied one, else chezmoi's (fresh machine, before apply).
src_dir() {
  if [[ -n ${RIG_SOURCE_DIR:-} ]]; then printf '%s' "$RIG_SOURCE_DIR"
  else chezmoi source-path 2>/dev/null; fi
}

cz_tmpl() { chezmoi execute-template --source "$(src_dir)" "$1"; }

# Bring the dotfiles up to date before installing anything (rig setup, rig
# add): a fast-forward pull, only when the checkout is clean and tracks a
# branch. Otherwise, or offline, it says so and uses what's here.
repo_pull() {
  local root; root=$(repo_root 2>/dev/null) || return 0
  git -C "$root" rev-parse '@{u}' >/dev/null 2>&1 || return 0
  if [[ -n $(git -C "$root" status --porcelain 2>/dev/null) ]]; then
    say "  ${DIM}dotfiles: local changes in ${root/#$HOME/~}, not pulling${N}"; return 0
  fi
  local before; before=$(git -C "$root" rev-parse HEAD)
  if ! git -C "$root" pull -q --ff-only 2>/dev/null; then
    say "  ${DIM}dotfiles: couldn't pull (offline, or local commits); using what's here${N}"; return 0
  fi
  if [[ $(git -C "$root" rev-parse HEAD) != "$before" ]]; then
    ok "dotfiles updated ($(git -C "$root" rev-list --count "$before..HEAD") new commits)"
    CATALOG='' PROFILES=''   # the catalog may have changed
  fi
}

# ------------------------------------------------------------- selection ----
# profile / selected / extra_packages / agent_default, in chezmoi's [data].

# ------------------------------------------------------------- state ----------
state_get() { # key -> space-separated (lists) or the value
  case $1 in
    selected|extra_packages) cz_tmpl "{{ dig \"$1\" list . | join \" \" }}" ;;
    *) cz_tmpl "{{ dig \"$1\" \"\" . }}" ;;
  esac
}

toml_list() { local out='' x; for x in $1; do out+="${out:+, }\"$x\""; done; printf '[%s]' "$out"; }

# Write profile/selected/extra_packages/agent_default into chezmoi's config,
# then let chezmoi re-render it (detection, everything else kept).
state_write() { # profile "selected" "extras" agent_default
  mkdir -p "$(dirname "$CZ_CFG")"
  local tmp; tmp=$(mktemp)
  if [[ -f $CZ_CFG ]]; then
    awk -v prof="$1" -v sel="$(toml_list "$2")" -v ext="$(toml_list "$3")" -v def="$4" '
      /^[[:space:]]*profile = /        { print "    profile = \"" prof "\""; next }
      /^[[:space:]]*selected = /       { print "    selected = " sel; next }
      /^[[:space:]]*extra_packages = / { print "    extra_packages = " ext; next }
      /^[[:space:]]*agent_default = /  { print "    agent_default = \"" def "\""; next }
      { print }' "$CZ_CFG" >"$tmp"
    grep -q '^[[:space:]]*selected = ' "$tmp" || printf '[data]\n    profile = "%s"\n    selected = %s\n    extra_packages = %s\n    agent_default = "%s"\n' \
      "$1" "$(toml_list "$2")" "$(toml_list "$3")" "$4" >"$tmp"
  else
    printf '[data]\n    profile = "%s"\n    selected = %s\n    extra_packages = %s\n    agent_default = "%s"\n' \
      "$1" "$(toml_list "$2")" "$(toml_list "$3")" "$4" >"$tmp"
  fi
  mv "$tmp" "$CZ_CFG"
  chezmoi init --source "$(src_dir)" >/dev/null
}
