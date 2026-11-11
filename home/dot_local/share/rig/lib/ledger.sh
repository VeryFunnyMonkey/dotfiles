# shellcheck shell=bash
# lib/ledger.sh: the record of everything rig changed, so it can be undone.
# Files in $RIG_STATE:
#   packages.log  manager \t name \t logical \t installed|preexisting \t date
#   system.log    kind \t key \t previous \t date
#   backup/ + backup.manifest, seen      files moved aside when chezmoi took them over
# A module that changes the system calls ledger_record first and defines
# revert_<kind> (dashes as underscores) to undo it; `rig uninstall` replays
# system.log newest-first through those functions.

# ------------------------------------------------------- files moved aside ---
# backup.manifest: kind (file|dirlink) \t path relative to ~ \t backup dir \t (unused)
# seen: one path per line, every target already handled (backed up or found
# to be rig's own), so it's backed up only once. The backup script (run before
# each apply) writes them; uninstall and doctor read them.
backup_seen() { grep -qxF "$1" "$RIG_STATE/seen" 2>/dev/null; }

backup_mark() { printf '%s\n' "$1" >>"$RIG_STATE/seen"; }

backup_save() { # kind relpath backup-dir: copy ~/relpath into the backup and note it
  mkdir -p "$3/$(dirname "$2")"
  cp -aP "$HOME/$2" "$3/$2"
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "" >>"$RIG_STATE/backup.manifest"
}

backup_count() { [[ -f $RIG_STATE/backup.manifest ]] && wc -l <"$RIG_STATE/backup.manifest" | tr -d ' ' || echo 0; }

backup_paths() { if [[ -f $RIG_STATE/backup.manifest ]]; then cut -f2 "$RIG_STATE/backup.manifest"; fi; }

# The original of one file, from the backup made on the first apply (if any).
# It leaves the "seen" list, so taking the file over again backs it up again.
backup_restore_one() { # path relative to ~
  local manifest="$RIG_STATE/backup.manifest" dir
  [[ -f $manifest ]] || return 1
  dir=$(awk -F'\t' -v r="$1" '$1=="file" && $2==r {d=$3} END {print d}' "$manifest")
  [[ -n $dir ]] && { [[ -e $dir/$1 || -L $dir/$1 ]]; } || return 1
  mkdir -p "$(dirname "$HOME/$1")"
  cp -aP "$dir/$1" "$HOME/$1" && ok "put back your earlier ~/$1"
  if [[ -f $RIG_STATE/seen ]]; then grep -vxF "$1" "$RIG_STATE/seen" >"$RIG_STATE/seen.new" || true; mv "$RIG_STATE/seen.new" "$RIG_STATE/seen"; fi
}

# Every original back, newest backup first (rig uninstall).
backup_restore_all() {
  [[ -f $RIG_STATE/backup.manifest ]] || return 0
  local kind rel dir
  while IFS=$'\t' read -r kind rel dir _; do
    local src="$dir/$rel" dst="$HOME/$rel"
    [[ -e $src || -L $src ]] || continue
    case $kind in
      dirlink) [[ -d $dst && ! -L $dst ]] && { rmdir "$dst" 2>/dev/null || { warn "$dst not empty; leaving it"; continue; }; }
               cp -P "$src" "$dst" ;;
      *) mkdir -p "$(dirname "$dst")"; rm -rf "$dst"; cp -aP "$src" "$dst" ;;
    esac
    ok "restored ~/$rel"
  done < <(tac_ "$RIG_STATE/backup.manifest")
}

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
ledger_forget() { # kind key: drop its entries (a module undid the change itself)
  [[ -f $RIG_STATE/system.log ]] || return 0
  local tmp; tmp=$(mktemp)
  awk -F'\t' -v k="$1" -v n="$2" '!($1==k && $2==n)' "$RIG_STATE/system.log" >"$tmp" && mv "$tmp" "$RIG_STATE/system.log"
}
# Undo a recorded change now, not at uninstall (its item was deselected, say):
# revert_<kind> with what was there before, then it leaves the ledger, so it
# isn't undone twice. Nothing recorded: nothing to do.
ledger_undo() { # kind key
  ledger_has "$1" "$2" || return 0
  "revert_${1//-/_}" "$2" "$(ledger_last "$1" "$2")"
  ledger_forget "$1" "$2"
}
ledger_undo_all() { # kind [key-prefix]: every key recorded under kind (starting with prefix)
  local k
  while IFS= read -r k; do
    if [[ -n $k && $k == "${2:-}"* ]]; then ledger_undo "$1" "$k"; fi
  done < <(ledger_keys "$1" | awk '!seen[$0]++')
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
