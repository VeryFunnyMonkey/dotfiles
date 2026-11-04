# shellcheck shell=bash
# share/dev/agent.sh: the agent the 'agent' pane runs (dev agent ...)

agent_cmd() { # honours --agent / --no-agent (DEV_AGENT_OVERRIDE), $DEV_AGENT, the saved file
  if [[ ${DEV_NO_AGENT:-0} == 1 ]]; then return 0; fi
  if [[ -n ${DEV_AGENT_OVERRIDE:-} ]]; then printf '%s' "$DEV_AGENT_OVERRIDE"
  elif [[ -n ${DEV_AGENT:-} ]]; then printf '%s' "$DEV_AGENT"
  elif [[ -s $AGENT_FILE ]]; then head -n1 "$AGENT_FILE"
  else
    # the machine's default agent from setup (rig agents default <name>)
    local d; d=$(sed -n 's/^RIG_AGENT_DEFAULT="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "${XDG_CONFIG_HOME:-$HOME/.config}/rig/machine.env" 2>/dev/null)
    if [[ -n $d ]]; then printf '%s' "$d"; fi
  fi
}
cmd_agent() {
  case ${1:-} in
    set) shift; (($#)) || die "usage: dev agent set <command>"; mkdir -p "$DEV_CFG"; printf '%s\n' "$*" >"$AGENT_FILE"
         ok "dev starts '$*' in the left pane"; have "${1%% *}" || warn "'${1%% *}' isn't installed yet" ;;
    unset) rm -f "$AGENT_FILE"; ok "no agent: the left pane is a plain shell" ;;
    '') local c; c=$(agent_cmd); echo "${c:-(none: dev agent set <command>, or rig agents add <name>)}" ;;
    *) die "usage: dev agent [set <command> | unset]" ;;
  esac
}
