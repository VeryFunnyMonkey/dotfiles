# shellcheck shell=bash
# commands/setup.sh: rig setup, the installer: a gum menu of the catalog by
# category, profiles, the Git section, the review, then apply.

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
  local -a agents; read -ra agents <<<"$1"; local n=${#agents[@]}
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
  local pick=''
  while :; do
    local rows=() def clis
    clis=$(git_clis "$sel")
    if ((accounts)); then
      def=$(default_identity); def=${def:-none}
      rows+=("Add an account" "Remove an account" "Default account: $def" "Test accounts")
    fi
    rows+=("Host CLIs: $clis" "Back")
    local head="Git: accounts (set up after the first install: rig git add)"
    if ((accounts)); then head="Git: accounts $(identities | tr '\n' ' ')"; fi
    mapfile -t rows < <(menu_rows "${rows[@]}")
    local at; at=$(cursor_on "$pick" "${rows[@]}")
    pick=$(gum_choose --header "$head" ${at:+"$at"} "${rows[@]}" </dev/tty) || return
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
      "Test accounts") git_test || true; gum input --placeholder "enter to continue" </dev/tty >/dev/null || true ;;
      Host*) sel=$(menu_category git "Git host CLIs (adding an account on a host selects its CLI)" "$sel") ;;
      *) return ;;
    esac
  done
}

git_clis() { # selected -> names of the selected host CLIs
  local in='' y
  for y in $1; do [[ $(item_field "$y" 1) == git && $(item_status "$y") == ok ]] && in+=" $y"; done
  names_of "$in" " · "
}

git_row() {
  if [[ ! -r $MACHINE_ENV ]] || ! declare -F identities >/dev/null; then echo "set up after the first install"; return; fi
  local ids def; ids=$(identities | tr '\n' ' '); def=$(default_identity || true)
  if [[ -z $ids ]]; then echo "no accounts yet"; else echo "${ids}(default: ${def:-none})"; fi
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
  local choice=''
  while :; do
    catalog_refresh "$sel"   # what's available follows the choices so far (a desktop brings a display)
    local rows=() cid cname mod=''
    [[ -n $profile && $sel != "$(profile_ids "$profile")" ]] && mod=' (modified)'
    rows+=("$(printf '%-20s %s' Profile "${profile:-none}$mod")")
    while IFS=$'\t' read -r cid cname; do
      [[ $cid == git ]] && continue  # shown in the Git row
      local in='' y
      for y in $sel; do [[ $(item_field "$y" 1) == "$cid" && $(item_status "$y") == ok ]] && in+=" $y"; done
      rows+=("$(printf '%-20s %s' "$cname" "$(names_of "$in" " · ")")")
    done < <(categories)
    rows+=("$(printf '%-20s %s' Git "$(git_row) · CLIs: $(git_clis "$sel")")")
    rows+=("Save as profile…" "Review & install" "Quit")
    mapfile -t rows < <(menu_rows "${rows[@]}")
    local at; at=$(cursor_on "$choice" "${rows[@]}")
    choice=$(gum_choose --height 20 --header "rig setup · $detected" ${at:+"$at"} "${rows[@]}" </dev/tty) || choice=Quit
    case $choice in
      Profile*) local p; p=$(menu_profile); if [[ -n $p ]]; then profile=$p; sel=$(profile_ids "$p"); fi ;;
      Git*) menu_git ;;
      "Save as profile…") save_profile "$sel" ;;
      "Review & install")
        agent_def=$(pick_agent_default "$sel" "$agent_def" menu)
        review "$cur" "$sel"
        if gum confirm "Install?" </dev/tty; then
          if apply_state "$profile" "$sel" "$extras" "$agent_def"; then return; fi
          cur=$sel   # saved, partly applied: back to the menu to change it or try again
          gum input --placeholder "enter to go back to the menu" </dev/tty >/dev/null || true
        fi ;;
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
