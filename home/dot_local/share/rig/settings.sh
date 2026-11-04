# shellcheck shell=bash
# rig settings: OS settings from the selected "OS settings" catalog items.
# Before changing a setting rig records its previous value in the ledger
# (~/.local/state/rig/applied-settings); deselecting the item, or uninstalling,
# puts that value back (or removes the setting if it wasn't set).
#
# ledger: kind TAB id TAB previous TAB type TAB item     (previous "<unset>" = not set before)

APPLIED() { printf '%s/applied-settings' "$RIG_STATE"; }
UNSET='<unset>'

# Values can contain tabs (KDE separates two shortcuts with one), but rig's
# lists are tab-separated: inside rig a tab is written as a literal \t.
tab_enc() { printf '%s' "${1//$'\t'/\\t}"; }
tab_dec() { printf '%s' "${1//\\t/$'\t'}"; }

kde_groups() { local g; IFS='/' read -ra g <<<"$1"; local x; for x in "${g[@]}"; do printf -- '--group\n%s\n' "$x"; done; }

setting_read() { # kind id type
  local kind=$1 id=$2 v='' f g k d
  case $kind in
    kde) IFS='|' read -r f g k <<<"$id"; local -a ga; mapfile -t ga < <(kde_groups "$g")
         v=$(tab_enc "$(kreadconfig6 --file "$f" "${ga[@]}" --key "$k" 2>/dev/null || true)") ;;
    defaults) IFS='|' read -r d k <<<"$id"; v=$(defaults read "$d" "$k" 2>/dev/null || true) ;;
    # the explicit default in mimeapps.list (what xdg-mime default writes), not
    # xdg-mime's resolved answer, which falls back to any app that can open it
    mime) v=$(awk -F= -v t="$id" '/^\[/ {sec=$0} sec=="[Default Applications]" && $1==t {print $2; exit}' \
            "${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list" 2>/dev/null || true) ;;
    line) if grep -qxF "$4" "$HOME/$id" 2>/dev/null; then v=present; fi ;;
  esac
  printf '%s' "${v:-$UNSET}"
}

setting_write() { # kind id value type
  local kind=$1 id=$2 val=$3 type=${4:-} f g k d
  case $kind in
    kde) IFS='|' read -r f g k <<<"$id"; local -a ga; mapfile -t ga < <(kde_groups "$g")
         if [[ $val == "$UNSET" ]]; then kwriteconfig6 --file "$f" "${ga[@]}" --key "$k" --delete
         else kwriteconfig6 --file "$f" "${ga[@]}" --key "$k" "$(tab_dec "$val")"; fi ;;
    defaults) IFS='|' read -r d k <<<"$id"
         if [[ $val == "$UNSET" ]]; then defaults delete "$d" "$k" 2>/dev/null || true
         else defaults write "$d" "$k" "-$type" "$val"; fi ;;
    mime)
         if [[ $val == "$UNSET" ]]; then mime_unset "$id"
         else xdg-mime default "$val" "$id"; fi ;;
  esac
}
mime_unset() { # drop our default for a type from mimeapps.list
  local f="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
  [[ -f $f ]] || return 0
  awk -v t="$1" '/^\[/ {sec=$0} !(sec=="[Default Applications]" && index($0, t "=")==1) {print}' "$f" >"$f.new" && mv "$f.new" "$f"
}
line_add() { mkdir -p "$(dirname "$HOME/$1")"; grep -qxF "$2" "$HOME/$1" 2>/dev/null || printf '%s\n' "$2" >>"$HOME/$1"; }
line_del() {
  [[ -f $HOME/$1 ]] || return 0
  grep -vxF "$2" "$HOME/$1" >"$HOME/$1.new" || true; mv "$HOME/$1.new" "$HOME/$1"
  [[ -s $HOME/$1 ]] || rm -f "$HOME/$1"
}

applied_get() { awk -F'\t' -v k="$1" -v i="$2" '$1==k && $2==i {print; exit}' "$(APPLIED)" 2>/dev/null; }
applied_del() { awk -F'\t' -v k="$1" -v i="$2" '!($1==k && $2==i)' "$(APPLIED)" >"$(APPLIED).new" && mv "$(APPLIED).new" "$(APPLIED)"; }

settings_desired() { cz_tmpl '{{ includeTemplate "settings-tsv" . }}' | sed '/^$/d'; }

# Revert one ledger line: kind id previous type item (line kind: previous is
# "present"/<unset>, and the id field holds path, the type field holds the line)
setting_revert() {
  local kind=$1 id=$2 prev=$3 type=$4
  case $kind in
    line) if [[ $prev == "$UNSET" ]]; then line_del "$id" "$type"; fi ;;
    *) setting_write "$kind" "$id" "$prev" "$type" ;;
  esac
}

cmd_settings() {
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
    local cur key_id=$id type=$extra
    if [[ $kind == line ]]; then type=$val; fi
    cur=$(setting_read "$kind" "$id" "$extra" "$val")
    local want=$val; [[ $kind == line ]] && want=present
    [[ $cur == "$want" ]] && { [[ -n $(applied_get "$kind" "$key_id") ]] || true; continue; }
    if ((dry)); then say "  would set $item: $kind $id -> $val (now: $cur)"; continue; fi
    if [[ -z $(applied_get "$kind" "$key_id") ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$key_id" "$cur" "$type" "$item" >>"$(APPLIED)"
    fi
    if [[ $kind == line ]]; then line_add "$id" "$val"; else setting_write "$kind" "$id" "$val" "$extra"; fi
    changed=1
  done <<<"$desired"

  # settings that are no longer wanted: put the originals back
  local k i p t it
  while IFS=$'\t' read -r k i p t it; do
    [[ -n $k ]] || continue
    if ! awk -F'\t' -v k="$k" -v i="$i" '$2==k && $3==i {f=1} END {exit !f}' <<<"$desired"; then
      if ((dry)); then say "  would restore $it: $k $i -> $p"; continue; fi
      setting_revert "$k" "$i" "$p" "$t"
      applied_del "$k" "$i"
      changed=1
      [[ $k == defaults ]] && restarts+=" $(restart_for "$it")"
    fi
  done < <(cat "$(APPLIED)")

  if ((changed)) && ((dry == 0)); then
    local app; for app in $restarts; do [[ -n $app ]] && killall "$app" 2>/dev/null || true; done
    if [[ ${RIG_DESKTOP:-} == kde ]] && have qdbus6; then qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true; fi
    ok "OS settings applied"
  elif ((dry == 0)); then ok "OS settings already in place"; fi
}
restart_for() { cz_tmpl "{{ join \" \" (dig \"restart\" list (index .catalog \"$1\")) }}" 2>/dev/null || true; }

# rig uninstall: put every recorded setting back
settings_revert_all() {
  [[ -f $(APPLIED) ]] || return 0
  local k i p t it
  while IFS=$'\t' read -r k i p t it; do
    [[ -n $k ]] || continue
    setting_revert "$k" "$i" "$p" "$t" && ok "restored $k $i"
  done < <(tac_ "$(APPLIED)")
  : >"$(APPLIED)"
}
