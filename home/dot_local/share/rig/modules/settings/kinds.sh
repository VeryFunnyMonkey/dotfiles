# shellcheck shell=bash
# modules/settings/kinds.sh: one block per kind of OS setting. The catalog's
# settings (and which machines each kind applies to) are described in
# .chezmoidata/catalog/settings.yaml; .chezmoitemplates/settings-tsv turns
# them into "item kind id value extra" lines for this machine.

# Values can contain tabs (KDE separates two shortcuts with one), but rig's
# lists are tab-separated: inside rig a tab is written as a literal \t.

# Values can contain tabs (KDE separates two shortcuts with one), but rig's
# lists are tab-separated: inside rig a tab is written as a literal \t.
tab_enc() { printf '%s' "${1//$'\t'/\\t}"; }

tab_dec() { printf '%s' "${1//\\t/$'\t'}"; }

kde_groups() { local g; IFS='/' read -ra g <<<"$1"; local x; for x in "${g[@]}"; do printf -- '--group\n%s\n' "$x"; done; }

# ------------------------------------------------------------- kde ----------
# id = file|group|key (group nested with "/")
setting_kde_read() {
  local f g k v; IFS='|' read -r f g k <<<"$1"; local -a ga; mapfile -t ga < <(kde_groups "$g")
  v=$(tab_enc "$(kreadconfig6 --file "$f" "${ga[@]}" --key "$k" 2>/dev/null || true)")
  printf '%s' "${v:-$UNSET}"
}
setting_kde_write() {
  local f g k; IFS='|' read -r f g k <<<"$1"; local -a ga; mapfile -t ga < <(kde_groups "$g")
  if [[ $2 == "$UNSET" ]]; then kwriteconfig6 --file "$f" "${ga[@]}" --key "$k" --delete
  else kwriteconfig6 --file "$f" "${ga[@]}" --key "$k" "$(tab_dec "$2")"; fi
}
setting_kde_done() {
  if [[ ${RIG_DESKTOP:-} == kde ]] && have qdbus6; then qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true; fi
}

# ------------------------------------------------------------- defaults -----
# macOS. id = domain|key, extra = the type (bool, int, float, string)
setting_defaults_read() {
  local d k v; IFS='|' read -r d k <<<"$1"; v=$(defaults read "$d" "$k" 2>/dev/null || true)
  printf '%s' "${v:-$UNSET}"
}
setting_defaults_write() {
  local d k; IFS='|' read -r d k <<<"$1"
  if [[ $2 == "$UNSET" ]]; then defaults delete "$d" "$k" 2>/dev/null || true
  else defaults write "$d" "$k" "-$3" "$2"; fi
}

# ------------------------------------------------------------- mime ---------
# id = mime type, value = desktop file. Read from mimeapps.list's explicit
# default (what xdg-mime default writes), not xdg-mime's resolved answer,
# which falls back to any app that can open it.
setting_mime_read() {
  local v; v=$(awk -F= -v t="$1" '/^\[/ {sec=$0} sec=="[Default Applications]" && $1==t {print $2; exit}' \
    "$CONFIG_HOME/mimeapps.list" 2>/dev/null || true)
  printf '%s' "${v:-$UNSET}"
}
setting_mime_write() {
  if [[ $2 == "$UNSET" ]]; then
    local f="$CONFIG_HOME/mimeapps.list"
    [[ -f $f ]] || return 0
    awk -v t="$1" '/^\[/ {sec=$0} !(sec=="[Default Applications]" && index($0, t "=")==1) {print}' "$f" >"$f.new" && mv "$f.new" "$f"
  else xdg-mime default "$2" "$1"; fi
}

# ------------------------------------------------------------- line ---------
# A line in a file. id = path (relative to ~); the ledger's "type" column
# holds the line, and "previous" is "present" or <unset>.

line_add() { mkdir -p "$(dirname "$HOME/$1")"; grep -qxF "$2" "$HOME/$1" 2>/dev/null || printf '%s\n' "$2" >>"$HOME/$1"; }

line_del() {
  [[ -f $HOME/$1 ]] || return 0
  grep -vxF "$2" "$HOME/$1" >"$HOME/$1.new" || true; mv "$HOME/$1.new" "$HOME/$1"
  [[ -s $HOME/$1 ]] || rm -f "$HOME/$1"
}

setting_line_read() { if grep -qxF "$3" "$HOME/$1" 2>/dev/null; then printf present; else printf '%s' "$UNSET"; fi; }
setting_line_write() { line_add "$1" "$2"; }
setting_line_restore() { if [[ $2 == "$UNSET" ]]; then line_del "$1" "$3"; fi; }
setting_line_type() { printf '%s' "$1"; }
setting_line_wanted() { printf present; }
