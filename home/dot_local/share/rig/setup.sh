# shellcheck shell=bash
# rig setup: the installer. Also rig add/remove (one item or package) and
# rig profile. Sourced by rig.
#
# A machine's software state is: the profile it started from, the selected
# catalog items, and its extra packages. They live in chezmoi's config
# ([data] profile/selected/extra_packages/agent_default); this file reads and
# writes them, then runs chezmoi. Catalog: .chezmoidata/catalog/; profiles:
# .chezmoidata/profiles/.

CZ_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"

# Source dir: the applied one, else chezmoi's (fresh machine, before apply).
src_dir() {
  if [[ -n ${RIG_SOURCE_DIR:-} ]]; then printf '%s' "$RIG_SOURCE_DIR"
  else chezmoi source-path 2>/dev/null; fi
}
cz_tmpl() { chezmoi execute-template --source "$(src_dir)" "$1"; }

# ------------------------------------------------------------- state ----------
state_get() { # key -> space-separated (lists) or the value
  case $1 in
    selected|extra_packages) cz_tmpl "{{ dig \"$1\" list . | join \" \" }}" ;;
    *) cz_tmpl "{{ dig \"$1\" \"\" . }}" ;;
  esac
}
toml_list() { local out='' x; for x in $1; do out+="${out:+, }\"$x\""; done; printf '[%s]' "$out"; }

# Write profile/selected/extra_packages/agent_default into chezmoi's config,
# then let chezmoi re-render it (detection, everything else kept).
state_write() { # profile "selected" "extras" agent_default
  mkdir -p "$(dirname "$CZ_CFG")"
  local tmp; tmp=$(mktemp)
  if [[ -f $CZ_CFG ]]; then
    awk -v prof="$1" -v sel="$(toml_list "$2")" -v ext="$(toml_list "$3")" -v def="$4" '
      /^[[:space:]]*profile = /        { print "    profile = \"" prof "\""; next }
      /^[[:space:]]*selected = /       { print "    selected = " sel; next }
      /^[[:space:]]*extra_packages = / { print "    extra_packages = " ext; next }
      /^[[:space:]]*agent_default = /  { print "    agent_default = \"" def "\""; next }
      { print }' "$CZ_CFG" >"$tmp"
    grep -q '^[[:space:]]*selected = ' "$tmp" || printf '[data]\n    profile = "%s"\n    selected = %s\n    extra_packages = %s\n    agent_default = "%s"\n' \
      "$1" "$(toml_list "$2")" "$(toml_list "$3")" "$4" >"$tmp"
  else
    printf '[data]\n    profile = "%s"\n    selected = %s\n    extra_packages = %s\n    agent_default = "%s"\n' \
      "$1" "$(toml_list "$2")" "$(toml_list "$3")" "$4" >"$tmp"
  fi
  mv "$tmp" "$CZ_CFG"
  chezmoi init --source "$(src_dir)" >/dev/null
}

# ------------------------------------------------------------- catalog --------
CATALOG=''   # category \t id \t name \t description \t status
PROFILES=''  # name \t description \t ids
load_catalog() {
  [[ -n $CATALOG ]] || CATALOG=$(cz_tmpl '{{ includeTemplate "catalog-tsv" . }}' | sed '/^$/d')
  [[ -n $PROFILES ]] || PROFILES=$(cz_tmpl '{{ includeTemplate "profiles-tsv" . }}' | sed '/^$/d')
}
categories() { cz_tmpl '{{ range .categories }}{{ .id }}	{{ .name }}{{ "\n" }}{{ end }}' | sed '/^$/d'; }
item_field() { awk -F'\t' -v id="$1" -v f="$2" '$2==id {print $f; exit}' <<<"$CATALOG"; }
item_name() { item_field "$1" 3; }
item_status() { item_field "$1" 5; }
is_item() { [[ -n $(item_field "$1" 2) ]]; }
profile_ids() { awk -F'\t' -v n="$1" '$1==n {print $3; exit}' <<<"$PROFILES"; }
profile_exists() { [[ -n $(awk -F'\t' -v n="$1" '$1==n {print 1}' <<<"$PROFILES") ]]; }

in_list() { [[ " $2 " == *" $1 "* ]]; }
list_add() { if in_list "$1" "$2"; then printf '%s' "$2"; else printf '%s' "${2:+$2 }$1"; fi; }
list_del() { local out='' x; for x in $2; do [[ $x == "$1" ]] || out+="${out:+ }$x"; done; printf '%s' "$out"; }
names_of() { local x out=''; for x in $1; do out+="${out:+, }$(item_name "$x")"; done; printf '%s' "${out:-none}"; }

# ------------------------------------------------------------- apply ----------
# Write the new state, apply, then clean up what was deselected.
apply_state() { # profile "selected" "extras" agent_default
  # what's applied now (agents, runtimes), to clean up after the change
  if [[ -r $MACHINE_ENV ]]; then load_machine; fi
  local old_tsv=''
  [[ -f $PACKAGES_TSV ]] && old_tsv=$(cat "$PACKAGES_TSV")
  local old_agents=${RIG_AGENTS:-} old_runtimes=${RIG_RUNTIMES:-}

  state_write "$@"
  info "applying"
  chezmoi apply
  load_machine
  ledger_init

  # agents that were deselected: uninstall the ones rig installed
  local a
  for a in $old_agents; do
    in_list "$a" "$RIG_AGENTS" && continue
    if [[ $(agent_status "$a") == installed ]] && agent_present "$a"; then
      info "uninstalling $(agent_label "$a") (deselected)"
      agent_remove "$a" || warn "couldn't uninstall $a"
      printf '%s\t%s\t%s\t%s\n' agent "$a" removed "$(now)" >>"$RIG_STATE/system.log"
    fi
  done

  # runtimes nothing needs any more: offer to delete what rig created
  runtimes_cleanup "$old_runtimes"

  # packages no longer needed: offer to remove the ones rig installed
  if [[ -n $old_tsv ]]; then
    local gone=() m n
    while IFS=$'\t' read -r m n _ _; do
      [[ -z $m ]] && continue
      awk -F'\t' -v m="$m" -v n="$n" '$1==m && $2==n {f=1} END {exit !f}' "$PACKAGES_TSV" && continue
      [[ $(ledger_pkg_status "$m" "$n") == installed ]] && pkg_present "$m" "$n" && gone+=("$m"$'\t'"$n")
    done <<<"$old_tsv"
    if ((${#gone[@]})); then
      say "  no longer needed (rig installed these):"
      printf '    %s\n' "${gone[@]//$'\t'/: }"
      if confirm "Uninstall them?"; then
        local g
        for g in "${gone[@]}"; do
          pkg_remove_cmd "${g%%$'\t'*}" "${g#*$'\t'}" && ledger_pkg_forget "${g%%$'\t'*}" "${g#*$'\t'}"
        done
      else say "  ${DIM}kept; rig drift lists them${N}"; fi
    fi
  fi
  ok "done"
}

# ------------------------------------------------------------- review ---------
review() { # old new -> prints the change; returns 1 if nothing changed
  local old=$1 new=$2 x add='' del='' skip=''
  for x in $new; do in_list "$x" "$old" || add+=" $x"; done
  for x in $old; do in_list "$x" "$new" || del+=" $x"; done
  for x in $new; do [[ $(item_status "$x") == ok ]] || skip+=" $x"; done
  say "${B}Review${N}"
  if [[ -n $add ]]; then say "  ${G}+ add:${N}    $(names_of "$add")"; fi
  if [[ -n $del ]]; then say "  ${R}- remove:${N} $(names_of "$del")"; fi
  if [[ -z $add && -z $del ]]; then say "  no item changes"; fi
  for x in $skip; do say "  ${DIM}skipped here: $(item_name "$x"): $(item_status "$x")${N}"; done
  say "  ${DIM}core (always): zsh, tmux, neovim, git, fzf, ripgrep, fd, gum, build tools${N}"
}

# ------------------------------------------------------------- menus ----------
# gum draws the menus. On a fresh machine it isn't there yet: install it (and
# record it in the ledger like any other package).
need_gum() {
  have gum && return 0
  local plat mgr=brew
  plat=$(cz_tmpl '{{ (includeTemplate "detect" . | fromJson).platform }}')
  [[ $plat == arch ]] && mgr=pacman
  ledger_init
  info "installing gum (draws the installer menus)"
  ledger_pkg_record "$mgr" gum gum installed
  pkg_install_cmd "$mgr" gum || die "couldn't install gum"
  hash -r
}
# gum choose prints "nothing selected" when a menu is left with Esc; that's how
# you go back here, so erase the line instead of leaving it over the next menu.
gum_choose() {
  local rc=0
  gum choose "$@" || rc=$?
  if ((rc)); then printf '\033[1A\033[2K' >/dev/tty; fi
  return $rc
}
G_HEAD() { gum style --foreground 109 --bold "$@"; }

menu_category() { # category-id category-name selected -> prints new selection
  local cat=$1 cname=$2 sel=$3 labels=() pre=() id name desc st line
  while IFS=$'\t' read -r c id name desc st; do
    [[ $c == "$cat" && $st == ok ]] || continue
    line="$id  ·  $name  ·  ${desc//,/;}"
    labels+=("$line")
    in_list "$id" "$sel" && pre+=("$line")
  done <<<"$CATALOG"
  local notes; notes=$(awk -F'\t' -v c="$cat" '$1==c && $5!="ok" {print "not here: " $3 " (" $5 ")"}' <<<"$CATALOG")
  local picked
  picked=$(gum_choose --no-limit --height 20 \
    --header "$cname: space to tick, enter when done${notes:+$'\n'$notes}" \
    "${pre[@]/#/--selected=}" -- "${labels[@]}" </dev/tty) || { printf '%s' "$sel"; return; }
  # keep selections from other categories (and items not available here)
  local out='' x
  for x in $sel; do [[ $(item_field "$x" 1) == "$cat" && $(item_status "$x") == ok ]] || out+="${out:+ }$x"; done
  while IFS= read -r line; do [[ -n $line ]] && out+="${out:+ }${line%%  ·  *}"; done <<<"$picked"
  printf '%s' "$out"
}

menu_profile() { # current -> prints chosen profile name (or empty)
  local opts=() n d ids
  while IFS=$'\t' read -r n d ids; do opts+=("$n  ·  $d"); done <<<"$PROFILES"
  local pick; pick=$(gum_choose --header "Start from a profile (replaces the current selection)" "${opts[@]}" </dev/tty) || return 0
  printf '%s' "${pick%%  ·  *}"
}

menu_agent_default() { # agents -> prints the one dev starts
  local n=0 a; for a in $1; do ((n++)); done
  if ((n == 0)); then return; fi
  if ((n == 1)); then printf '%s' "$1"; return; fi
  # shellcheck disable=SC2086
  gum_choose --header "Which agent should dev start?" $1 </dev/tty || printf '%s' "${1%% *}"
}

save_profile() { # selected
  local name desc file
  name=$(gum input --placeholder "profile name (e.g. laptop)" </dev/tty) || return 0
  name=$(printf '%s' "$name" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9_-')
  [[ -n $name ]] || return 0
  desc=$(gum input --placeholder "one-line description" </dev/tty) || desc=''
  file="$(src_dir)/.chezmoidata/profiles/$name.yaml"
  if [[ -f $file ]] && ! gum confirm "Profile '$name' exists. Replace it?" </dev/tty; then return 0; fi
  write_profile "$name" "$desc" "$1" "$file"
  PROFILES=''; load_catalog
  ok "saved profile '$name' (${file/#$HOME/~}); commit it to use it on other machines"
}
write_profile() { # name desc selected file
  local list='' x; for x in $3; do list+="${list:+, }$x"; done
  printf 'profiles:\n  %s:\n    description: "%s"\n    select: [%s]\n' "$1" "${2//\"/\'}" "$list" >"$4"
}

# The Git section: accounts, the default account, and the host CLIs (gh,
# glab, tea). Adding an account selects its host's CLI by itself.
menu_git() {
  local accounts=1
  if ! declare -F identities >/dev/null || [[ ! -r $MACHINE_ENV ]]; then accounts=0; fi
  while :; do
    local rows=() pick def clis
    clis=$(git_clis "$sel")
    if ((accounts)); then
      def=$(default_identity); def=${def:-none}
      rows+=("Add an account" "Remove an account" "Default account: $def" "Test accounts")
    fi
    rows+=("Host CLIs: $clis" "Back")
    local head="Git: accounts (set up after the first install: rig git add)"
    if ((accounts)); then head="Git: accounts $(identities | tr '\n' ' ')"; fi
    pick=$(gum_choose --header "$head" "${rows[@]}" </dev/tty) || return
    case $pick in
      "Add an account") RIG_SETUP_MENU=1 git_add || true ;;
      "Remove an account")
        local n ids; mapfile -t ids < <(identities)
        ((${#ids[@]})) || continue
        n=$(gum_choose --header "Remove which account?" "${ids[@]}" </dev/tty) || continue
        RIG_YES=1 git_remove "$n" || true ;;
      Default*)
        local n ids; mapfile -t ids < <(identities)
        n=$(gum_choose --header "Default account (none: commits need a matching account)" "${ids[@]}" none </dev/tty) || continue
        git_set_default "$n" ;;
      "Test accounts") git_doctor || true; gum input --placeholder "enter to continue" </dev/tty >/dev/null || true ;;
      Host*) sel=$(menu_category git "Git host CLIs (adding an account on a host selects its CLI)" "$sel") ;;
      *) return ;;
    esac
  done
}
git_clis() { # selected -> names of the selected host CLIs
  local in='' y
  for y in $1; do [[ $(item_field "$y" 1) == git && $(item_status "$y") == ok ]] && in+=" $y"; done
  names_of "$in"
}

cmd_setup() {
  local profile='' sel='' extras='' agent_def='' yes=0 pick_profile='' add=() del=()
  while (($#)); do
    case $1 in
      --profile) pick_profile=$2; shift ;;
      --select) IFS=, read -ra add <<<"$2"; shift ;;
      --deselect) IFS=, read -ra del <<<"$2"; shift ;;
      --agent-default) agent_def=$2; shift ;;
      --yes|-y) yes=1 ;;
      *) die "usage: rig setup [--profile <name>] [--select a,b] [--deselect c] [--agent-default <agent>] [--yes]" ;;
    esac
    shift
  done
  load_catalog
  local cur; cur=$(state_get selected 2>/dev/null || true)
  profile=$(state_get profile 2>/dev/null || true)
  extras=$(state_get extra_packages 2>/dev/null || true)
  [[ -n $agent_def ]] || agent_def=$(state_get agent_default 2>/dev/null || true)
  sel=$cur
  if [[ -n $pick_profile ]]; then
    profile_exists "$pick_profile" || die "no profile '$pick_profile' (rig profile list)"
    profile=$pick_profile; sel=$(profile_ids "$pick_profile")
  fi
  local x
  for x in "${add[@]}"; do is_item "$x" || die "unknown item '$x' (rig setup shows the catalog)"; sel=$(list_add "$x" "$sel"); done
  for x in "${del[@]}"; do sel=$(list_del "$x" "$sel"); done

  if ((yes)); then
    export RIG_NONINTERACTIVE=1
    agent_def=$(pick_agent_default "$sel" "$agent_def")
    review "$cur" "$sel"
    apply_state "$profile" "$sel" "$extras" "$agent_def"
    return
  fi

  need_gum
  if [[ -z $cur && -z $pick_profile ]]; then
    local p; p=$(menu_profile)
    if [[ -n $p ]]; then profile=$p; sel=$(profile_ids "$p"); fi
  fi
  local detected; detected=$(cz_tmpl '{{ $d := includeTemplate "detect" . | fromJson }}{{ $d.platform }}{{ if $d.wsl }} (WSL){{ end }} · {{ $d.desktop | default "no desktop" }} · display: {{ $d.display }}')
  while :; do
    local rows=() cid cname mod=''
    [[ -n $profile && $sel != "$(profile_ids "$profile")" ]] && mod=' (modified)'
    rows+=("$(printf '%-20s %s' Profile "${profile:-none}$mod")")
    while IFS=$'\t' read -r cid cname; do
      [[ $cid == git ]] && continue  # shown in the Git row
      local in='' y
      for y in $sel; do [[ $(item_field "$y" 1) == "$cid" && $(item_status "$y") == ok ]] && in+=" $y"; done
      rows+=("$(printf '%-20s %s' "$cname" "$(names_of "$in")")")
    done < <(categories)
    rows+=("$(printf '%-20s %s' Git "$(git_row) · CLIs: $(git_clis "$sel")")")
    rows+=("Save as profile…" "Review & install" "Quit")
    local choice
    choice=$(gum_choose --height 20 --header "rig setup · $detected" "${rows[@]}" </dev/tty) || choice=Quit
    case $choice in
      Profile*) local p; p=$(menu_profile); if [[ -n $p ]]; then profile=$p; sel=$(profile_ids "$p"); fi ;;
      Git*) menu_git ;;
      "Save as profile…") save_profile "$sel" ;;
      "Review & install")
        agent_def=$(pick_agent_default "$sel" "$agent_def" menu)
        review "$cur" "$sel"
        if gum confirm "Install?" </dev/tty; then apply_state "$profile" "$sel" "$extras" "$agent_def"; return; fi ;;
      Quit)
        if [[ $sel != "$cur" ]] && ! gum confirm "Quit without installing your changes?" </dev/tty; then continue; fi
        return 0 ;;
      *)
        while IFS=$'\t' read -r cid cname; do
          [[ $cid == git ]] && continue
          if [[ $choice == "$cname "* ]]; then sel=$(menu_category "$cid" "$cname" "$sel"); fi
        done < <(categories) ;;
    esac
  done
}

git_row() {
  if [[ ! -r $MACHINE_ENV ]] || ! declare -F identities >/dev/null; then echo "set up after the first install"; return; fi
  local ids def; ids=$(identities | tr '\n' ' '); def=$(default_identity || true)
  if [[ -z $ids ]]; then echo "no accounts yet"; else echo "${ids}(default: ${def:-none})"; fi
}

# Pick dev's default agent from the selected agents (keep the current one if still selected).
pick_agent_default() { # selected current [menu]
  local agents='' x
  for x in $1; do [[ $(item_field "$x" 1) == agents && $(item_status "$x") == ok ]] && agents+="${agents:+ }$x"; done
  if in_list "$2" "$agents"; then printf '%s' "$2"; return; fi
  if [[ ${3:-} == menu ]]; then menu_agent_default "$agents"; else printf '%s' "${agents%% *}"; fi
}

# ------------------------------------------------------------- add/remove -----
# rig add <item|package>...: a catalog item is selected; anything else becomes an
# extra package for this machine. rig remove undoes either.
cmd_add() {
  load_machine; load_catalog
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
      local n d ids cur; cur=$(state_get profile 2>/dev/null || true)
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
