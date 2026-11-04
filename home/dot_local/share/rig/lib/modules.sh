# shellcheck shell=bash
# lib/modules.sh: the module registry. A module is modules/<name>.sh (helpers
# in modules/<name>/), one feature each. It may define, with dashes in the
# name as underscores:
#   <m>_sync       make this machine match the selection (set up, or undo
#                  what it set up when deselected); run by chezmoi's scripts
#   <m>_doctor     report health with check_ok / check_bad
#   <m>_update     its part of rig update
#   <m>_reset      rig reset <m>: rebuild it
#   <m>_uninstall  its part of rig uninstall (UNINSTALL_* say what was asked)
#   <m>_cmd        rig <m> <subcommand>...
#   <m>_export <dir>    rig export: this machine's own settings for it (never
#                       keys or tokens), as files in <dir>
#   <m>_exported <dir>  one line saying what <dir> holds (rig import shows it)
#   <m>_import <dir>    rig import: set them up here; what's already here stays
#   revert_<kind>  undo one ledger entry of that kind
# Core modules always apply. Item modules belong to catalog items (an item's
# `module:` field) and are active while one of those items is selected.

# Order matters for doctor, update and uninstall: srv unmounts first;
# agents go before runtimes (npm agents need node to uninstall).
RIG_CORE_MODULES=(srv shell ssh-agent git agents runtimes nvim settings)

modules_all() { # core first, then item modules, alphabetically
  local m f
  for m in "${RIG_CORE_MODULES[@]}"; do printf '%s\n' "$m"; done
  for f in "$RIG_LIB"/modules/*.sh; do
    m=$(basename "$f" .sh)
    in_list "$m" "${RIG_CORE_MODULES[*]}" || printf '%s\n' "$m"
  done
}
module_fn() { printf '%s_%s' "${1//-/_}" "$2"; }
module_has() { declare -F "$(module_fn "$1" "$2")" >/dev/null; }
module_active() { in_list "$1" "${RIG_CORE_MODULES[*]}" || in_list "$1" "${RIG_ITEM_MODULES:-}"; }
module_exists() { [[ -f $RIG_LIB/modules/$1.sh ]]; }

modules_run() { # hook [args]: every module that has it, in order
  local hook=$1 m; shift
  while IFS= read -r m; do
    if module_has "$m" "$hook"; then "$(module_fn "$m" "$hook")" "$@"; fi
  done < <(modules_all)
}

# rig modules sync <name>... | --items | list
cmd_modules() {
  load_machine; ledger_init
  local sub=${1:-list}; (($#)) && shift
  case $sub in
    sync)
      local m
      if [[ ${1:-} == --items ]]; then
        while IFS= read -r m; do
          in_list "$m" "${RIG_CORE_MODULES[*]}" && continue
          if module_has "$m" sync; then "$(module_fn "$m" sync)"; fi
        done < <(modules_all)
        return 0
      fi
      for m in "$@"; do
        module_exists "$m" || die "no module '$m' (rig modules list)"
        if module_has "$m" sync; then "$(module_fn "$m" sync)"; fi
      done ;;
    list|ls)
      local m kind
      while IFS= read -r m; do
        if in_list "$m" "${RIG_CORE_MODULES[*]}"; then kind=core
        elif module_active "$m"; then kind="${G}on${N}"
        else kind="${DIM}off${N}"; fi
        printf '  %-12s %s\n' "$m" "$kind"
      done < <(modules_all) ;;
    *) die "usage: rig modules sync <name>...|--items | list" ;;
  esac
}

# For <m>_export/<m>_import: a machine-local file (not in the repo) moves as
# is. One that's already here stays; the incoming copy lands next to it.
local_file_export() { # dir path
  if [[ -f $2 ]]; then mkdir -p "$1/files"; cp "$2" "$1/files/$(basename "$2")"; fi
}
local_file_exported() { # dir path
  if [[ -f $1/files/$(basename "$2") ]]; then printf '%s\n' "${2/#$HOME/\~}"; fi
}
local_file_import() { # dir path
  local f; f="$1/files/$(basename "$2")"
  [[ -f $f ]] || return 0
  if [[ ! -f $2 ]]; then
    mkdir -p "$(dirname "$2")"; cp "$f" "$2"; ok "${2/#$HOME/\~}"
  elif cmp -s "$f" "$2"; then :
  else
    cp "$f" "$2.imported"
    warn "${2/#$HOME/\~} is already here, kept; the imported one is ${2/#$HOME/\~}.imported"
  fi
}
