#!/usr/bin/env bash
# scripts/check-packages.sh: does every package rig could install on this OS
# still exist under that name? Catches upstream renames and removals (tea ->
# gitea-cli, a cask renamed, a download moved) before a new machine hits them.
#
# Renders this OS's package list with every catalog item selected (the same
# template a machine uses, so no resolving logic is repeated here), then asks
# each manager's pm_<manager>_exists. Installs nothing. Refresh the package
# database first (pacman -Sy, apt-get update); CI runs it weekly on each OS.
#
#   scripts/check-packages.sh      exit 1 if anything is missing
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
rig="$repo/home/dot_local/share/rig"
# shellcheck source=/dev/null
for f in lib/sys.sh lib/ui.sh pkg/managers.sh pkg/downloads.sh; do source "$rig/$f"; done
have chezmoi || die "needs chezmoi"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cz() { chezmoi --source "$repo" --config "$tmp/c.toml" "$@"; }
printf '[data]\n' >"$tmp/c.toml"
all=$(cz execute-template '{{ keys .catalog | sortAlpha | join "\",\"" }}')

# Every display variant (the clipboard differs per display; "windows" is WSL's).
for display in wayland x11 windows; do
  printf '[data]\n  display = "%s"\n  desktop = "kde"\n  selected = ["%s"]\n' "$display" "$all" >"$tmp/c.toml"
  cz execute-template <"$repo/home/dot_config/rig/packages.tsv.tmpl"
done | awk -F'\t' 'NF>=2 && $1 !~ /^#/ && !seen[$1"\t"$2]++' >"$tmp/list"

checked=0 missing=0 unsure=0
while IFS=$'\t' read -r mgr names logical src; do
  # one entry can be several packages ("gcc make"), or a cask ("--cask x")
  if [[ $names == --cask\ * ]]; then set -- "$names"; else read -ra parts <<<"$names"; set -- "${parts[@]}"; fi
  for n in "$@"; do
    checked=$((checked + 1))
    rc=0; "pm_${mgr}_exists" "$n" || rc=$?
    if ((rc == 1)); then
      missing=$((missing + 1))
      printf 'MISSING %s: %s  (%s, from %s)\n' "$mgr" "$n" "$logical" "$src"
    elif ((rc != 0)); then
      unsure=$((unsure + 1))
      printf "UNSURE  %s: %s  (no answer; it's checked again next run)\n" "$mgr" "$n"
    fi
  done
done <"$tmp/list"

platform=$(cz execute-template '{{ includeTemplate "platform" . }}')
if ((missing)); then
  printf '%d of %d packages missing on %s: renamed or removed upstream? Fix the name in packages.yaml (names:) or the item.\n' "$missing" "$checked" "$platform"
  exit 1
fi
printf 'all %d packages exist on %s\n' "$checked" "$platform"
if ((unsure)); then printf '(%d could not be checked: no answer)\n' "$unsure"; fi
