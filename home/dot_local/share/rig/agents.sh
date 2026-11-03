# shellcheck shell=bash
# rig agents: coding agents chosen at setup (none, one or several). Sourced by rig.
# Install methods follow each vendor's docs; check them at every stack review.
# Logins, API keys and agent settings are never touched.

AGENT_NAMES="claude copilot codex gemini opencode"

agent_cmd_name() { case $1 in claude) echo claude ;; copilot) echo copilot ;; codex) echo codex ;; gemini) echo gemini ;; opencode) echo opencode ;; esac; }
agent_label() { case $1 in claude) echo "Claude Code" ;; copilot) echo "GitHub Copilot CLI" ;; codex) echo "OpenAI Codex CLI" ;; gemini) echo "Gemini CLI" ;; opencode) echo "OpenCode" ;; esac; }
agent_known() { [[ " $AGENT_NAMES " == *" $1 "* ]]; }
agent_npm_pkg() { case $1 in copilot) echo @github/copilot ;; codex) echo @openai/codex ;; gemini) echo @google/gemini-cli ;; esac; }

# How each agent is installed on this machine
agent_method() {
  local darwin=0; [[ $(uname) == Darwin ]] && darwin=1
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

# ledger: agent <name> <installed|preexisting>
agent_status() { awk -F'\t' -v n="$1" '$1=="agent" && $2==n {s=$3} END {print s}' "$RIG_STATE/system.log"; }

# chezmoi data: agents = [...], agent_default = "..."
set_agents_data() { # "a b c" default
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml" list='' a
  for a in $1; do list+="${list:+, }\"$a\""; done
  sed -i.bak -E "s/^([[:space:]]*)agents = .*/\1agents = [$list]/; s/^([[:space:]]*)agent_default = .*/\1agent_default = \"$2\"/" "$cfg"
  rm -f "$cfg.bak"
}

cmd_agents() {
  load_machine; ledger_init
  local sub=${1:-list}; (($#)) && shift
  case $sub in
    list|ls)
      local a
      for a in $AGENT_NAMES; do
        local mark="○" note=''
        [[ " $RIG_AGENTS " == *" $a "* ]] && mark="${G}●${N}"
        [[ $a == "$RIG_AGENT_DEFAULT" ]] && note=" (dev default)"
        agent_present "$a" && note+=" installed" || { [[ " $RIG_AGENTS " == *" $a "* ]] && note+=" ${Y}missing${N}"; }
        printf '  %s %-9s %s%s\n' "$mark" "$a" "$(agent_label "$a")" "$note"
      done
      say "  ${DIM}rig agents add|remove <name> · rig agents default <name>${N}" ;;
    add)
      (($#)) || die "usage: rig agents add <name>... ($AGENT_NAMES)"
      local list=$RIG_AGENTS a def=$RIG_AGENT_DEFAULT
      for a in "$@"; do agent_known "$a" || die "unknown agent '$a' ($AGENT_NAMES)"; [[ " $list " == *" $a "* ]] || list+=" $a"; done
      [[ -n $def ]] || def=$1
      set_agents_data "$list" "$def"; chezmoi apply ;;
    remove|rm)
      (($#)) || die "usage: rig agents remove <name>..."
      local list='' a def=$RIG_AGENT_DEFAULT
      for a in $RIG_AGENTS; do [[ " $* " == *" $a "* ]] || list+="${list:+ }$a"; done
      for a in "$@"; do
        if [[ $(agent_status "$a") == installed ]] && agent_present "$a"; then
          info "uninstalling $(agent_label "$a")"; agent_remove "$a" || warn "couldn't uninstall $a"
          printf '%s\t%s\t%s\t%s\n' agent "$a" removed "$(now)" >>"$RIG_STATE/system.log"
        elif agent_present "$a"; then warn "$a was installed before rig; leaving it"; fi
      done
      [[ " $list " == *" $def "* ]] || def=${list%% *}
      set_agents_data "$list" "$def"; chezmoi apply
      [[ -n $def ]] && ok "dev now starts $def" ;;
    default)
      local a=${1:-}; [[ " $RIG_AGENTS " == *" $a "* ]] || die "'$a' isn't one of this machine's agents ($RIG_AGENTS)"
      set_agents_data "$RIG_AGENTS" "$a"; chezmoi apply --exclude=scripts >/dev/null; ok "dev starts $a" ;;
    sync)
      local a
      for a in $RIG_AGENTS; do
        if agent_present "$a"; then
          [[ -n $(agent_status "$a") ]] || printf '%s\t%s\t%s\t%s\n' agent "$a" preexisting "$(now)" >>"$RIG_STATE/system.log"
          ok "$(agent_label "$a") installed"
        else
          info "installing $(agent_label "$a")"
          if agent_install "$a"; then
            printf '%s\t%s\t%s\t%s\n' agent "$a" installed "$(now)" >>"$RIG_STATE/system.log"
            ok "$(agent_label "$a") installed (sign in on first run)"
          else warn "couldn't install $a"; fi
        fi
      done
      [[ -n $RIG_AGENTS ]] || ok "no agents chosen (rig agents add <name>)" ;;
    update)
      local a
      for a in $RIG_AGENTS; do [[ $(agent_status "$a") == installed ]] && agent_update "$a"; done; true ;;
    *) die "usage: rig agents list|add|remove|default|sync" ;;
  esac
}

agents_uninstall_all() { # rig uninstall --agents: only the ones rig installed
  local a
  for a in $AGENT_NAMES; do
    if [[ $(agent_status "$a") == installed ]] && agent_present "$a"; then
      agent_remove "$a" && ok "uninstalled $(agent_label "$a")" || warn "couldn't uninstall $a"
    fi
  done
}
