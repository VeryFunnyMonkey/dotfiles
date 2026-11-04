# shellcheck shell=bash
# commands/items.sh: one item (or package) at a time, and profiles:
# rig add / remove / profile / info.

# ------------------------------------------------------------- add/remove -----
# rig add <item|package>...: a catalog item is selected; anything else becomes an
# extra package for this machine. rig remove undoes either.
cmd_add() {
  load_machine; repo_pull; load_catalog
  (($#)) || die "usage: rig add <item|package>... (rig setup lists the items)"
  local sel extras x
  sel=$(state_get selected); extras=$(state_get extra_packages)
  for x in "$@"; do
    if is_item "$x"; then sel=$(list_add "$x" "$sel"); ok "selected $(item_name "$x")"
    else extras=$(list_add "$x" "$extras"); ok "added $x (extra package on this machine)"; fi
  done
  apply_state "$RIG_PROFILE" "$sel" "$extras" "$(pick_agent_default "$sel" "$RIG_AGENT_DEFAULT")"
}

cmd_del() {
  load_machine; load_catalog
  (($#)) || die "usage: rig remove <item|package>..."
  local sel extras x
  sel=$(state_get selected); extras=$(state_get extra_packages)
  for x in "$@"; do
    if in_list "$x" "$sel"; then sel=$(list_del "$x" "$sel"); ok "deselected $(item_name "$x")"
    elif in_list "$x" "$extras"; then extras=$(list_del "$x" "$extras"); ok "removed extra package $x"
    else warn "$x isn't selected or an extra package here"; fi
  done
  apply_state "$RIG_PROFILE" "$sel" "$extras" "$(pick_agent_default "$sel" "$RIG_AGENT_DEFAULT")"
}

# ------------------------------------------------------------- profiles -------
cmd_profile_cmd() {
  load_catalog
  local sub=${1:-list}; (($#)) && shift
  case $sub in
    list|ls)
      local n d cur; cur=$(state_get profile 2>/dev/null || true)
      while IFS=$'\t' read -r n d _; do
        printf '  %s %-12s %s\n' "$([[ $n == "$cur" ]] && echo "${G}●${N}" || echo "○")" "$n" "$d"
      done <<<"$PROFILES" ;;
    show)
      local n=${1:-$(state_get profile)}; profile_exists "$n" || die "no profile '$n'"
      say "$n: $(awk -F'\t' -v n="$n" '$1==n {print $2}' <<<"$PROFILES")"
      say "  $(names_of "$(profile_ids "$n")")" ;;
    use)
      local n=${1:-}; profile_exists "$n" || die "usage: rig profile use <name> (rig profile list)"
      cmd_setup --profile "$n" "${@:2}" ;;
    save)
      local n=${1:-}; [[ -n $n ]] || die "usage: rig profile save <name> [description]"
      n=$(printf '%s' "$n" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9_-')
      local file; file="$(src_dir)/.chezmoidata/profiles/$n.yaml"
      write_profile "$n" "${2:-}" "$(state_get selected)" "$file"
      ok "saved profile '$n' (${file/#$HOME/~}); commit it to use it on other machines" ;;
    *) die "usage: rig profile list|show [name]|use <name>|save <name> [description]" ;;
  esac
}

# rig info <item>: the item's guide (docs/catalog/<item>.md) or its description
cmd_info() {
  load_catalog
  local id=${1:-}; is_item "$id" || die "usage: rig info <item> (rig setup shows the catalog)"
  local doc; doc="$(dirname "$(src_dir)")/docs/catalog/$id.md"
  if [[ -f $doc ]]; then if have bat; then bat --style=plain --language=markdown "$doc"; else cat "$doc"; fi
  else say "$(item_name "$id"): $(item_field "$id" 4)"; local st; st=$(item_status "$id"); if [[ $st != ok ]]; then say "  here: $st"; fi; fi
}
