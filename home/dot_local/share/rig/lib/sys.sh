# shellcheck shell=bash
# lib/sys.sh: small system helpers (commands, time, sudo, lists).

now() { date +%Y-%m-%dT%H:%M:%S; }

# ------------------------------------------------------------- packages -------
sudo_() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# tac isn't on macOS; tail -r is BSD's
tac_() { if have tac; then tac "$@"; else tail -r "$@"; fi; }

# Space-separated lists (selections, ids).

in_list() { [[ " $2 " == *" $1 "* ]]; }

list_add() { if in_list "$1" "$2"; then printf '%s' "$2"; else printf '%s' "${2:+$2 }$1"; fi; }

list_del() { local out='' x; for x in $2; do [[ $x == "$1" ]] || out+="${out:+ }$x"; done; printf '%s' "$out"; }

prune_empty() { local d; for d in "$@"; do [[ -d $d ]] && rmdir "$d" 2>/dev/null || true; done; }
