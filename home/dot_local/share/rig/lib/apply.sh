# shellcheck shell=bash
# lib/apply.sh: change the selection and make the machine match it. chezmoi
# apply runs the setup scripts; each module's sync then sets up what's
# selected and undoes what isn't, so this only handles the packages.

# Write the new state, apply, then offer to remove packages nothing needs.
apply_state() { # profile "selected" "extras" agent_default
  if [[ -r $MACHINE_ENV ]]; then load_machine; fi
  local old_tsv=''
  [[ -f $PACKAGES_TSV ]] && old_tsv=$(cat "$PACKAGES_TSV")
  state_write "$@"
  info "applying"
  chezmoi apply || { bad "applying didn't finish (the output above says why); fix it and run: rig sync"; return 1; }
  load_machine
  ledger_init
  pkg_cleanup "$old_tsv"
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

# Pick dev's default agent from the selected agents (keep the current one if still selected).
pick_agent_default() { # selected current [menu]
  local agents='' x
  for x in $1; do [[ $(item_field "$x" 1) == agents && $(item_status "$x") == ok ]] && agents+="${agents:+ }$x"; done
  if in_list "$2" "$agents"; then printf '%s' "$2"; return; fi
  if [[ ${3:-} == menu ]]; then menu_agent_default "$agents"; else printf '%s' "${agents%% *}"; fi
}
