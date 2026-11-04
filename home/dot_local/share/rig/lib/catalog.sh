# shellcheck shell=bash
# lib/catalog.sh: the catalog (.chezmoidata/catalog/) and profiles, as this
# machine sees them (each item's status: "ok" or why it's skipped here).

CATALOG=''   # category \t id \t name \t description \t status
PROFILES=''  # name \t description \t ids

# Render a template as if the selection were already this (the installer's
# choices before they're saved): availability and includes follow it.
selection_json() { local x out=''; for x in $1; do out+="${out:+,}\"$x\""; done; printf '{"selected":[%s]}' "$out"; }
cz_tmpl_with() { chezmoi execute-template --source "$(src_dir)" --override-data "$(selection_json "$1")" "$2"; }
catalog_refresh() { CATALOG=$(cz_tmpl_with "$1" '{{ includeTemplate "catalog-tsv" . }}' | sed '/^$/d'); }
# Items a selection brings in through includes: (not chosen themselves).
included_by() { # selection -> ids
  local all x out=''
  all=$(cz_tmpl_with "$1" '{{ (includeTemplate "enabled" . | fromJson).selected | join " " }}')
  for x in $all; do in_list "$x" "$1" || out+="${out:+ }$x"; done
  printf '%s' "$out"
}

load_catalog() {
  [[ -n $CATALOG ]] || CATALOG=$(cz_tmpl '{{ includeTemplate "catalog-tsv" . }}' | sed '/^$/d')
  [[ -n $PROFILES ]] || PROFILES=$(cz_tmpl '{{ includeTemplate "profiles-tsv" . }}' | sed '/^$/d')
}

categories() { cz_tmpl '{{ range .categories }}{{ .id }}	{{ .name }}{{ "\n" }}{{ end }}' | sed '/^$/d'; }

item_field() { awk -F'\t' -v id="$1" -v f="$2" '$2==id {print $f; exit}' <<<"$CATALOG"; }

item_name() { item_field "$1" 3; }

item_status() { item_field "$1" 5; }

is_item() { [[ -n $(item_field "$1" 2) ]]; }

item_label() { cz_tmpl "{{ (index .catalog \"$1\").name }}" 2>/dev/null || printf '%s' "$1"; }

item_selected() { in_list "$1" "${RIG_SELECTED:-}"; }

names_of() { # ids [separator]
  local x out='' sep=${2:-, }; for x in $1; do out+="${out:+$sep}$(item_name "$x")"; done; printf '%s' "${out:-none}"; }

profile_ids() { awk -F'\t' -v n="$1" '$1==n {print $3; exit}' <<<"$PROFILES"; }

profile_exists() { [[ -n $(awk -F'\t' -v n="$1" '$1==n {print 1}' <<<"$PROFILES") ]]; }
