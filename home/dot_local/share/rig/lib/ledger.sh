# shellcheck shell=bash
# lib/ledger.sh: the record of everything rig changed, so it can be undone.
# Files in $RIG_STATE:
#   packages.log  manager \t name \t logical \t installed|preexisting \t date
#   system.log    kind \t key \t previous \t date
#   backup/ + backup.manifest, seen      files replaced on the first apply
# A module that changes the system calls ledger_record first and defines
# revert_<kind> (dashes as underscores) to undo it; `rig uninstall` replays
# system.log newest-first through those functions.

# ---------------------------------------------------------------- ledger ------
ledger_init() { mkdir -p "$RIG_STATE"; touch "$RIG_STATE/packages.log" "$RIG_STATE/system.log"; }

# ------------------------------------------------------------- packages -----

# packages.log: manager \t name \t logical \t installed|preexisting \t date
ledger_pkg_known() { awk -F'\t' -v m="$1" -v n="$2" '$1==m && $2==n {f=1} END {exit !f}' "$RIG_STATE/packages.log"; }

ledger_pkg_record() { ledger_pkg_known "$1" "$2" || printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$(now)" >>"$RIG_STATE/packages.log"; }

ledger_pkg_status() { awk -F'\t' -v m="$1" -v n="$2" '$1==m && $2==n {print $4; exit}' "$RIG_STATE/packages.log"; }

ledger_pkg_forget() {
  local tmp; tmp=$(mktemp)
  awk -F'\t' -v m="$1" -v n="$2" '!($1==m && $2==n)' "$RIG_STATE/packages.log" >"$tmp" && mv "$tmp" "$RIG_STATE/packages.log"
}

# ------------------------------------------------------------- system -------
ledger_record() { # kind key previous
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(now)" >>"$RIG_STATE/system.log"
}
ledger_has() { # kind key [previous]
  awk -F'\t' -v k="$1" -v n="$2" -v p="${3:-}" '$1==k && $2==n && (p=="" || $3==p) {f=1} END {exit !f}' \
    "$RIG_STATE/system.log" 2>/dev/null
}
ledger_last() { # kind key -> the latest "previous" recorded for it
  awk -F'\t' -v k="$1" -v n="$2" '$1==k && $2==n {v=$3} END {print v}' "$RIG_STATE/system.log" 2>/dev/null
}
ledger_keys() { # kind [previous] -> every key recorded under kind
  awk -F'\t' -v k="$1" -v p="${2:-}" '$1==k && (p=="" || $3==p) {print $2}' "$RIG_STATE/system.log" 2>/dev/null
}
ledger_count() { [[ -f $RIG_STATE/system.log ]] && wc -l <"$RIG_STATE/system.log" | tr -d ' ' || echo 0; }

ledger_revert_all() {
  [[ -f $RIG_STATE/system.log ]] || return 0
  local kind key prev _d fn
  while IFS=$'\t' read -r kind key prev _d; do
    [[ -n $kind ]] || continue
    fn="revert_${kind//-/_}"
    if declare -F "$fn" >/dev/null; then "$fn" "$key" "$prev"
    else warn "unknown system change '$kind $key'; skipped"; fi
  done < <(tac_ "$RIG_STATE/system.log")
}
