# shellcheck shell=bash
# commands/transfer.sh: rig export / rig import. Moves what's only on this
# machine to another one: the selection (profile, items, extra packages), and
# each module's own part (<m>_export / <m>_import: git accounts, srv servers,
# local.zsh, hypr/local.lua). Never keys or tokens: the new machine makes its
# own keys and logs in again. The file holds emails and server names, so it's
# private (mode 600) and never goes in the repo.

cmd_export() { # [file]
  load_machine
  local out=${1:-$HOME/rig-export-$(hostname -s 2>/dev/null || uname -n)-$(date +%Y-%m-%d).tar.gz}
  out=${out/#\~/$HOME}
  xfer_tmp; local tmp=$RIG_XFER_TMP
  mkdir -p "$tmp/rig"
  {
    printf 'profile=%s\n' "$(state_get profile)"
    printf 'selected=%s\n' "$(state_get selected)"
    printf 'extra_packages=%s\n' "$(state_get extra_packages)"
    printf 'agent_default=%s\n' "$(state_get agent_default)"
  } >"$tmp/rig/selection"
  printf 'rig export from %s, %s\n' "$(hostname -s 2>/dev/null || uname -n)" "$(now)" >"$tmp/rig/about"
  local m
  while IFS= read -r m; do
    module_has "$m" export || continue
    mkdir -p "$tmp/rig/modules/$m"
    "$(module_fn "$m" export)" "$tmp/rig/modules/$m"
    rmdir "$tmp/rig/modules/$m" 2>/dev/null || true   # nothing to move
  done < <(modules_all)
  (umask 077 && tar -czf "$out" -C "$tmp" rig) || die "couldn't write $out"
  chmod 600 "$out"
  ok "exported to ${out/#$HOME/~}"
  export_summary "$tmp/rig" | sed 's/^/  /'
  say "  ${DIM}no keys or tokens; it has your emails and server names, so keep it private.${N}"
  say "  on the other machine: rig import ${out##*/}"
}

# What an export holds, one line per part.
export_summary() { # dir
  local d=$1 m
  local sel extra; sel=$(sel_get "$d" selected); extra=$(sel_get "$d" extra_packages)
  printf 'selection: profile %s, %s items\n' "$(sel_get "$d" profile)" "$(wc -w <<<"$sel" | tr -d ' ')"
  if [[ -n $extra ]]; then printf 'extra packages: %s\n' "$extra"; fi
  while IFS= read -r m; do
    [[ -d $d/modules/$m ]] && module_has "$m" exported || continue
    "$(module_fn "$m" exported)" "$d/modules/$m"
  done < <(modules_all)
}
sel_get() { awk -F= -v k="$2" '$1==k {sub(/^[^=]*=/,""); print; exit}' "$1/selection"; } # dir key

cmd_import() { # file [--yes]
  local file='' yes=0 a
  for a in "$@"; do case $a in --yes|-y) yes=1 ;; *) file=$a ;; esac; done
  [[ -n $file ]] || die "usage: rig import <file from rig export> [--yes]"
  file=${file/#\~/$HOME}; [[ -f $file ]] || die "no file at $file"
  load_machine; load_catalog
  xfer_tmp; local tmp=$RIG_XFER_TMP
  # only plain relative paths under rig/
  if tar -tzf "$file" | grep -qvE '^rig(/|$)' || tar -tzf "$file" | grep -qE '(^|/)\.\.(/|$)'; then
    die "$file isn't a rig export"
  fi
  tar -xzf "$file" -C "$tmp" --no-same-owner 2>/dev/null || tar -xzf "$file" -C "$tmp"
  local d=$tmp/rig
  [[ -f $d/selection ]] || die "$file isn't a rig export"
  say "$(cat "$d/about" 2>/dev/null)"
  export_summary "$d" | sed 's/^/  /'
  if ((yes == 0)); then tty_in; ask_yn "Set this machine up from it?" y || return 0; fi

  # the selection first, so the items (host CLIs, srv, ...) are installed
  local cur new; cur=$(state_get selected); new=$(sel_get "$d" selected)
  local extras; extras=$(list_union "$(state_get extra_packages)" "$(sel_get "$d" extra_packages)")
  local merged; merged=$(list_union "$cur" "$new")
  if [[ $merged != "$cur" || $extras != "$(state_get extra_packages)" ]]; then
    review "$cur" "$merged"
    if ((yes == 1)) || ask_yn "Add these?" y; then
      local agent; agent=$(pick_agent_default "$merged" "$(sel_get "$d" agent_default)")
      local prof; prof=$(state_get profile); prof=${prof:-$(sel_get "$d" profile)}
      apply_state "$prof" "$merged" "$extras" "$agent" || warn "applying didn't finish; the rest still imports (rig sync later)"
    fi
  else
    say "  selection: nothing new"
  fi
  load_machine

  local m
  while IFS= read -r m; do
    [[ -d $d/modules/$m ]] && module_has "$m" import || continue
    "$(module_fn "$m" import)" "$d/modules/$m"
  done < <(modules_all)
  ok "imported"
}

# a b -> a, then what b adds (order kept)
list_union() { local out=$1 x; for x in $2; do out=$(list_add "$x" "$out"); done; printf '%s' "$out"; }

# RIG_XFER_TMP: a temporary folder, removed when rig exits (call it directly,
# not in $(...): the trap belongs to this shell)
xfer_tmp() {
  if [[ -z ${RIG_XFER_TMP:-} ]]; then RIG_XFER_TMP=$(mktemp -d); trap 'rm -rf "$RIG_XFER_TMP"' EXIT; fi
}
