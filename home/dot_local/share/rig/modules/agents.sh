# shellcheck shell=bash
# modules/agents.sh: the coding agents selected in rig setup (catalog items
# with `agent: true`). Install methods follow each vendor's docs; check them
# at every stack review. Logins, API keys and agent settings are never touched.

AGENT_NAMES="claude copilot codex gemini opencode"

agent_cmd_name() { case $1 in claude) echo claude ;; copilot) echo copilot ;; codex) echo codex ;; gemini) echo gemini ;; opencode) echo opencode ;; esac; }

agent_label() { case $1 in claude) echo "Claude Code" ;; copilot) echo "GitHub Copilot CLI" ;; codex) echo "OpenAI Codex CLI" ;; gemini) echo "Gemini CLI" ;; opencode) echo "OpenCode" ;; esac; }

agent_npm_pkg() { case $1 in copilot) echo @github/copilot ;; codex) echo @openai/codex ;; gemini) echo @google/gemini-cli ;; esac; }

# How each agent is installed on this machine
agent_method() {
  local darwin=0; if is_darwin; then darwin=1; fi
  case $1 in
    claude) echo script ;;                        # native installer; updates itself
    copilot) ((darwin)) && echo "brew copilot-cli" || echo npm ;;
    codex) ((darwin)) && echo "brew --cask codex" || echo npm ;;
    gemini) ((darwin)) && echo "brew gemini-cli" || echo npm ;;
    opencode)
      if ((darwin)); then echo "brew anomalyco/tap/opencode"
      elif [[ $RIG_NATIVE == pacman ]]; then echo "pacman opencode"
      else echo script; fi ;;
  esac
}

agent_install() {
  local a=$1 m; m=$(agent_method "$a")
  case $m in
    script)
      case $a in
        claude) curl -fsSL https://claude.ai/install.sh | bash ;;
        opencode) curl -fsSL https://opencode.ai/install | OPENCODE_INSTALL_DIR="$HOME/.local/bin" bash ;;
      esac ;;
    npm) with_node; have npm || die "npm missing (the node runtime should have installed it)"; npm install -g "$(agent_npm_pkg "$a")" ;;
    brew\ *) brew install ${m#brew } ;;
    pacman\ *) pkg_install_cmd pacman "${m#pacman }" ;;
  esac
}

agent_remove() {
  local a=$1 m; m=$(agent_method "$a")
  case $m in
    script)
      case $a in
        claude) rm -f "$HOME/.local/bin/claude"; rm -rf "$HOME/.local/share/claude" ;;
        opencode) rm -f "$HOME/.local/bin/opencode" ;;
      esac ;;
    npm) with_node; npm uninstall -g "$(agent_npm_pkg "$a")" ;;
    brew\ *) brew uninstall ${m#brew } ;;
    pacman\ *) pkg_remove_cmd pacman "${m#pacman }" ;;
  esac
}

agent_update() {
  local a=$1 m; m=$(agent_method "$a")
  case $m in
    script) [[ $a == opencode ]] && opencode upgrade >/dev/null 2>&1 || true ;;  # claude updates itself
    npm) with_node; npm install -g "$(agent_npm_pkg "$a")@latest" >/dev/null ;;
    brew\ *) brew upgrade ${m#brew } >/dev/null 2>&1 || true ;;
    pacman\ *) : ;;  # system update covers it
  esac
}

agent_present() { with_node; have "$(agent_cmd_name "$1")"; }

# ledger: agent <name> installed|preexisting|removed
agent_status() { ledger_last agent "$1"; }

agents_sync() {
  local a
  for a in $RIG_AGENTS; do
    if agent_present "$a"; then
      [[ -n $(agent_status "$a") ]] || ledger_record agent "$a" preexisting
      ok "$(agent_label "$a") installed"
    else
      info "installing $(agent_label "$a")"
      if agent_install "$a"; then
        ledger_record agent "$a" installed
        ok "$(agent_label "$a") installed (sign in on first run)"
      else warn "couldn't install $a"; fi
    fi
  done
  # deselected: uninstall the ones rig installed
  for a in $AGENT_NAMES; do
    in_list "$a" "$RIG_AGENTS" && continue
    if [[ $(agent_status "$a") == installed ]] && agent_present "$a"; then
      info "uninstalling $(agent_label "$a") (deselected)"
      if agent_remove "$a"; then ledger_record agent "$a" removed; else warn "couldn't uninstall $a"; fi
    fi
  done
  [[ -n $RIG_AGENTS ]] || ok "no agents selected"
}

agents_update() {
  [[ -n $RIG_AGENTS ]] || return 0
  info "agents"
  local a
  for a in $RIG_AGENTS; do if [[ $(agent_status "$a") == installed ]]; then agent_update "$a"; fi; done
}

agents_doctor() {
  info "agents"
  if [[ -z $RIG_AGENTS ]]; then say "  none selected (rig setup, or rig add <agent>)"; return 0; fi
  local a
  for a in $RIG_AGENTS; do
    if agent_present "$a"; then check_ok "$(agent_label "$a")$( [[ $a == "$RIG_AGENT_DEFAULT" ]] && printf ' (dev default)')"
    else check_bad "$(agent_label "$a") missing (rig agents sync)"; fi
  done
}

# rig uninstall --agents: only the ones rig installed
agents_uninstall() {
  [[ ${UNINSTALL_AGENTS:-0} == 1 ]] || return 0
  info "uninstalling agents rig installed"
  local a
  for a in $AGENT_NAMES; do
    if [[ $(agent_status "$a") == installed ]] && agent_present "$a"; then
      if agent_remove "$a"; then ok "uninstalled $(agent_label "$a")"; else warn "couldn't uninstall $a"; fi
    fi
  done
}
revert_agent() { :; }   # agents are removed by --agents (above)

agents_cmd() {
  load_machine; ledger_init
  local sub=${1:-list}; (($#)) && shift
  case $sub in
    list|ls)
      local a
      for a in $AGENT_NAMES; do
        local mark="○" note=''
        in_list "$a" "$RIG_AGENTS" && mark="${G}●${N}"
        [[ $a == "$RIG_AGENT_DEFAULT" ]] && note=" (dev default)"
        if agent_present "$a"; then note+=" installed"; elif in_list "$a" "$RIG_AGENTS"; then note+=" ${Y}missing${N}"; fi
        printf '  %s %-9s %s%s\n' "$mark" "$a" "$(agent_label "$a")" "$note"
      done
      say "  ${DIM}select agents in rig setup (or rig add <name>) · rig agents default <name>${N}" ;;
    default)
      local a=${1:-}; in_list "$a" "$RIG_AGENTS" || die "'$a' isn't one of this machine's agents ($RIG_AGENTS)"
      state_write "$RIG_PROFILE" "$(state_get selected)" "$(state_get extra_packages)" "$a"
      chezmoi apply --exclude=scripts >/dev/null; ok "dev starts $a" ;;
    sync) agents_sync ;;
    update) agents_update ;;
    *) die "usage: rig agents list|default <name>|sync" ;;
  esac
}
