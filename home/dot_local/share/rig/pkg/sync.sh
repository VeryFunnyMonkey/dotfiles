# shellcheck shell=bash
# pkg/sync.sh: what the package list (packages.tsv, rendered by chezmoi from
# packages.yaml and the selected items) means for this machine: install what's
# missing, report drift, search, update, and clean up after a deselect.

# packages.tsv: manager \t name(s) \t logical \t source \t blocked by
pkg_declared() { awk -F'\t' 'NF>=2 && $1 !~ /^#/' "$PACKAGES_TSV"; }

# The installed package (of the same manager) that keeps this one out, if any
# (packages.yaml conflicts: rig doesn't replace what you already have).
pkg_blocker() { # manager "blockers..."
  local b; for b in $2; do if pkg_present "$1" "$b"; then printf '%s' "$b"; return 0; fi; done
  return 1
}

# Install everything declared for this machine that's missing.
cmd_sync() {
  load_machine; ledger_init
  [[ -r $PACKAGES_TSV ]] || die "no package list ($PACKAGES_TSV); run chezmoi apply"
  baseline_record
  local -A todo=()
  local m n logical blk by
  while IFS=$'\t' read -r m n logical _ blk; do
    if pkg_present "$m" "$n"; then
      ledger_pkg_record "$m" "$n" "$logical" preexisting
    elif by=$(pkg_blocker "$m" "${blk:-}"); then
      say "  ${DIM}left out $n: your $by is installed, and $n would replace it (rig leaves it as it is)${N}"
    else
      todo[$m]+="$n"$'\n'
      ledger_pkg_record "$m" "$n" "$logical" installed
    fi
  done < <(pkg_declared)
  if ((${#todo[@]} == 0)); then ok "all declared packages are installed"; return 0; fi
  local mgr names failed=()
  for mgr in pacman aur apt dnf brew winget download; do
    [[ -n ${todo[$mgr]:-} ]] || continue
    names=$(printf '%s' "${todo[$mgr]}" | tr '\n' ' ')
    info "installing with $mgr: $names"
    # casks and downloads one at a time; the rest in one go, and if that
    # fails, one at a time: one bad package doesn't keep out the others
    # (or the managers after this one)
    # shellcheck disable=SC2086
    if [[ $mgr == download || $mgr == brew && $names == *--cask* ]] || ! pkg_install_cmd "$mgr" $names; then
      while IFS= read -r n; do
        [[ -n $n ]] || continue
        if pkg_present "$mgr" "$n" || pkg_install_cmd "$mgr" "$n"; then continue; fi
        failed+=("$n ($mgr)")
      done <<<"${todo[$mgr]}"
    fi
  done
  if ((${#failed[@]})); then
    bad "not installed: ${failed[*]} (the output above says why; then: rig sync)"
    return 1
  fi
  ok "packages in sync"
}

# The explicitly-installed packages before rig touched this machine, so
# `rig drift` only reports what changed since.
baseline_record() {
  if [[ -f $RIG_STATE/baseline ]]; then return 0; fi
  pkg_explicit >"$RIG_STATE/baseline" 2>/dev/null || true
}
pkg_declared_names() { pkg_declared | awk -F'\t' '{n=split($2,a," "); if ($2 ~ /^--cask /) print $1"\t"$2; else for (i=1;i<=n;i++) print $1"\t"a[i]}'; }
pkg_missing() { # "manager\tname (logical)" for each declared package that isn't installed
  local m n logical blk
  while IFS=$'\t' read -r m n logical _ blk; do
    pkg_present "$m" "$n" || pkg_blocker "$m" "${blk:-}" >/dev/null || printf '%s\t%s (%s)\n' "$m" "$n" "$logical"
  done < <(pkg_declared)
}

cmd_drift() {
  load_machine; ledger_init
  local all=0; [[ ${1:-} == --all ]] && all=1
  local tmp; tmp=$(mktemp -d)
  pkg_explicit | sort -u >"$tmp/now"
  pkg_declared_names | sort -u >"$tmp/declared"
  if ((all)) || [[ ! -f $RIG_STATE/baseline ]]; then : >"$tmp/base"; else sort -u "$RIG_STATE/baseline" >"$tmp/base"; fi
  # rig's own installs (an AUR helper, say) aren't drift either
  awk -F'\t' '$4=="installed" {print $1 "\t" $2}' "$RIG_STATE/packages.log" | sed 's/^aur\t/pacman\t/' | sort -u >"$tmp/rigs"
  sed 's/^aur\t/pacman\t/' "$tmp/now" | sort -u >"$tmp/now.n"; mv "$tmp/now.n" "$tmp/now"
  sed 's/^aur\t/pacman\t/' "$tmp/declared" | sort -u >"$tmp/declared.n"; mv "$tmp/declared.n" "$tmp/declared"
  comm -23 "$tmp/now" "$tmp/declared" | comm -23 - "$tmp/base" | comm -23 - "$tmp/rigs" >"$tmp/extra"
  pkg_missing >"$tmp/missing"
  if [[ -s $tmp/extra ]]; then
    info "installed but not declared$( ((all)) || printf ' (since rig was set up; --all for everything)')"
    sed 's/^/  /' "$tmp/extra"
    say "  ${DIM}keep one: rig install <name>  ·  remove one: rig remove <name>${N}"
  else ok "nothing installed outside the declaration"; fi
  if [[ -s $tmp/missing ]]; then
    info "declared but missing (rig sync installs them)"; sed 's/^/  /' "$tmp/missing"
  fi
  rm -rf "$tmp"
}

cmd_search() {
  load_machine
  (($#)) || die "usage: rig search <query>"
  "pm_${RIG_NATIVE}_search" "$@"
  if [[ $RIG_NATIVE != brew ]] && have brew; then info "brew"; pm_brew_search "$@" || true; fi
}

# rig update: the system's own packages, then whatever is declared but missing
pkg_update() {
  info "system packages"
  if declare -F "pm_${RIG_NATIVE}_upgrade" >/dev/null && [[ $RIG_NATIVE != brew ]]; then "pm_${RIG_NATIVE}_upgrade"; fi
  if have brew; then info "brew"; pm_brew_upgrade; fi
  if have flatpak; then info "flatpak"; flatpak update -y; fi
  cmd_sync
}

# A command rig installed that another copy earlier on PATH hides (an install
# from before rig, say): the other copy is what runs. Name it, so it can go.
pkg_shadowed() {
  local m n p b c first
  while IFS=$'\t' read -r m n _; do
    declare -F "pm_${m}_bins" >/dev/null || continue
    [[ $n == --cask\ * ]] && continue
    for p in $n; do
      pkg_present "$m" "$p" || continue
      while IFS= read -r b; do
        [[ -f $b && -x $b ]] || continue
        c=${b##*/}
        first=$(type -P "$c" 2>/dev/null) || continue
        [[ $(realpath "$first" 2>/dev/null) == "$(realpath "$b" 2>/dev/null)" ]] && continue
        check_bad "$c: ${first/#$HOME/\~} runs, not rig's (${b/#$HOME/\~}); an older install? remove it"
      done < <("pm_${m}_bins" "$p")
    done
  done < <(pkg_declared)
}

pkg_doctor() {
  info "packages"
  if [[ ${RIG_NATIVE:-} == pacman ]]; then
    if [[ $(pacman_helper) != pacman ]]; then check_ok "AUR helper: $(pacman_helper)"; else check_bad "no AUR helper (yay); the bootstrap installs it"; fi
  fi
  local missing; missing=$(pkg_missing)
  if [[ -z $missing ]]; then check_ok "all declared packages installed"
  else while IFS=$'\t' read -r m rest; do check_bad "missing: $rest ($m)"; done <<<"$missing"; fi
  pkg_shadowed
}

# After a change of selection: packages rig installed that nothing needs now.
pkg_cleanup() { # the package list from before
  [[ -n $1 ]] || return 0
  local gone=() m n
  while IFS=$'\t' read -r m n _ _; do
    [[ -z $m ]] && continue
    awk -F'\t' -v m="$m" -v n="$n" '$1==m && $2==n {f=1} END {exit !f}' "$PACKAGES_TSV" && continue
    [[ $(ledger_pkg_status "$m" "$n") == installed ]] && pkg_present "$m" "$n" && gone+=("$m"$'\t'"$n")
  done <<<"$1"
  ((${#gone[@]})) || return 0
  say "  no longer needed (rig installed these):"
  printf '    %s\n' "${gone[@]//$'\t'/: }"
  if confirm "Uninstall them?"; then
    local g
    pkg_remove_set < <(printf '%s\n' "${gone[@]}")
    for g in "${gone[@]}"; do
      pkg_present "${g%%$'\t'*}" "${g#*$'\t'}" || ledger_pkg_forget "${g%%$'\t'*}" "${g#*$'\t'}"
    done
  else say "  ${DIM}kept; rig drift lists them${N}"; fi
}

# rig uninstall --packages: the ones rig installed (never ones already there)
pkg_uninstall_all() {
  awk -F'\t' '$4=="installed" {print $1 "\t" $2}' "$RIG_STATE/packages.log" | pkg_remove_set
  # the AUR helper's cache and settings, when rig installed the helper
  if [[ $(ledger_pkg_status pacman yay-bin) == installed ]]; then rm -rf "$CACHE_HOME/yay" "$CONFIG_HOME/yay"; fi
}

# Remove "manager<TAB>name" lines. Each manager's packages go in one
# transaction, so it works out the order between packages that depend on each
# other. If that fails (one is needed by something rig didn't install), it
# goes one at a time, in passes, until a pass removes nothing.
pkg_remove_set() {
  local -A by=()
  local m n
  while IFS=$'\t' read -r m n; do
    [[ -n $m ]] || continue
    if pkg_present "$m" "$n"; then by[$m]+="$n"$'\n'; fi
  done
  for m in "${!by[@]}"; do
    local -a names=() left=()
    mapfile -t names < <(printf '%s' "${by[$m]}")
    # shellcheck disable=SC2068  # each name may hold several packages (split on purpose)
    if [[ $m != download ]] && pkg_remove_cmd "$m" ${names[@]} >/dev/null 2>&1; then continue; fi
    local progress=1
    while ((progress)); do
      progress=0; left=()
      for n in "${names[@]}"; do
        pkg_present "$m" "$n" || continue
        if pkg_remove_cmd "$m" "$n" >/dev/null 2>&1; then progress=1; else left+=("$n"); fi
      done
      names=("${left[@]+"${left[@]}"}")
    done
    for n in "${names[@]+"${names[@]}"}"; do warn "kept $n ($m): something else still needs it"; done
  done
}

# gum draws the installer's menus. On a fresh machine it isn't there yet:
# install it (recorded like any other package).
need_gum() {
  have gum && return 0
  local mgr=brew
  [[ $(cz_tmpl '{{ (includeTemplate "detect" . | fromJson).platform }}') == arch ]] && mgr=pacman
  ledger_init
  info "installing gum (draws the installer menus)"
  ledger_pkg_record "$mgr" gum gum installed
  pkg_install_cmd "$mgr" gum || die "couldn't install gum"
  hash -r
}
