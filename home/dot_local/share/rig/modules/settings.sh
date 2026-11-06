# shellcheck shell=bash
# modules/settings.sh: OS settings from the selected "OS settings" catalog
# items. Before changing a setting rig records its previous value
# (~/.local/state/rig/applied-settings); deselecting the item, or
# uninstalling, puts that value back (or removes the setting if it wasn't set).
# Each kind of setting (kde, defaults, mime, line, ...) is in
# modules/settings/kinds.sh.
#
# ledger: kind TAB id TAB previous TAB type TAB item     (previous "<unset>" = not set before)

APPLIED() { printf '%s/applied-settings' "$RIG_STATE"; }

# shellcheck disable=SC2034  # used by the kinds (settings/kinds.sh)
UNSET='<unset>' 

# A kind provides setting_<kind>_read <id> <extra> <value> (prints the current
# value or $UNSET) and setting_<kind>_write <id> <value> <extra> ($UNSET:
# remove it). setting_<kind>_restore <id> <previous> <extra> is optional;
# without it, restoring writes the previous value back.
setting_read() { "setting_$1_read" "$2" "${3:-}" "${4:-}"; }
setting_write() { "setting_$1_write" "$2" "$3" "${4:-}"; }
setting_revert() { # kind id previous type
  if declare -F "setting_$1_restore" >/dev/null; then "setting_$1_restore" "$2" "$3" "${4:-}"
  else setting_write "$1" "$2" "$3" "${4:-}"; fi
}

applied_get() { awk -F'\t' -v k="$1" -v i="$2" '$1==k && $2==i {print; exit}' "$(APPLIED)" 2>/dev/null; }

applied_del() { awk -F'\t' -v k="$1" -v i="$2" '!($1==k && $2==i)' "$(APPLIED)" >"$(APPLIED).new" && mv "$(APPLIED).new" "$(APPLIED)"; }

settings_desired() { cz_tmpl '{{ includeTemplate "settings-tsv" . }}' | sed '/^$/d'; }

settings_cmd() {
  load_machine; ledger_init
  touch "$(APPLIED)"
  local sub=${1:-sync} dry=0; [[ ${2:-} == --dry-run || $sub == --dry-run ]] && dry=1
  [[ $sub == --dry-run ]] && sub=sync
  case $sub in
    list)
      local item kind id val extra
      while IFS=$'\t' read -r item kind id val extra; do
        [[ $kind == restart ]] && continue
        printf '  %-18s %-9s %-45s %s\n' "$item" "$kind" "$id" "$val"
      done < <(settings_desired)
      [[ -s $(APPLIED) ]] && say "  ${DIM}recorded originals: $(wc -l <"$(APPLIED)" | tr -d ' ') (restored when an item is deselected)${N}"
      return 0 ;;
    sync) ;;
    *) die "usage: rig settings [list | sync [--dry-run]]" ;;
  esac

  local desired; desired=$(settings_desired)
  local item kind id val extra changed=0 restarts=''
  while IFS=$'\t' read -r item kind id val extra; do
    [[ -n $item ]] || continue
    if [[ $kind == restart ]]; then restarts+=" $id"; continue; fi
    local cur key_id=$id type=$extra want=$val
    # a kind may keep something else in the ledger's type column, and compare
    # against something other than the value (line: the line, and "present")
    if declare -F "setting_${kind}_type" >/dev/null; then type=$("setting_${kind}_type" "$val" "$extra"); fi
    if declare -F "setting_${kind}_wanted" >/dev/null; then want=$("setting_${kind}_wanted" "$val"); fi
    cur=$(setting_read "$kind" "$id" "$extra" "$val")
    [[ $cur == "$want" ]] && { [[ -n $(applied_get "$kind" "$key_id") ]] || true; continue; }
    if ((dry)); then say "  would set $item: $kind $id -> $val (now: $cur)"; continue; fi
    if [[ -z $(applied_get "$kind" "$key_id") ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$key_id" "$cur" "$type" "$item" >>"$(APPLIED)"
    fi
    setting_write "$kind" "$id" "$val" "$extra"
    say "  ${DIM}$item: $id set to $val (it was ${cur:-unset}; deselecting $item puts that back)${N}"
    changed=1
  done <<<"$desired"

  # settings that are no longer wanted: put the originals back
  local k i p t it
  while IFS=$'\t' read -r k i p t it; do
    [[ -n $k ]] || continue
    if ! awk -F'\t' -v k="$k" -v i="$i" '$2==k && $3==i {f=1} END {exit !f}' <<<"$desired"; then
      if ((dry)); then say "  would restore $it: $k $i -> $p"; continue; fi
      setting_revert "$k" "$i" "$p" "$t"
      say "  ${DIM}$it: $i put back to ${p:-unset}${N}"
      applied_del "$k" "$i"
      changed=1
      [[ $k == defaults ]] && restarts+=" $(restart_for "$it")"
    fi
  done < <(cat "$(APPLIED)")

  if ((changed)) && ((dry == 0)); then
    local app; for app in $restarts; do [[ -n $app ]] && killall "$app" 2>/dev/null || true; done
    # kinds that need a nudge after changes (KDE reloads KWin)
    local done_fn; for done_fn in $(declare -F | awk '$3 ~ /^setting_.*_done$/ {print $3}'); do "$done_fn"; done
    ok "OS settings applied"
  elif ((dry == 0)); then ok "OS settings already in place"; fi
}

restart_for() { cz_tmpl "{{ join \" \" (dig \"restart\" list (index .catalog \"$1\")) }}" 2>/dev/null || true; }

settings_sync() { settings_cmd sync; }

# rig uninstall: put every recorded setting back
settings_uninstall() {
  [[ -f $(APPLIED) ]] || return 0
  info "restoring OS settings"
  local k i p t it
  while IFS=$'\t' read -r k i p t it; do
    [[ -n $k ]] || continue
    setting_revert "$k" "$i" "$p" "$t" && ok "restored $k $i"
  done < <(tac_ "$(APPLIED)")
  : >"$(APPLIED)"
}
