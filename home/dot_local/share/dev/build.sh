# shellcheck shell=bash
# share/dev/build.sh: building a tmux session from a workspace, and attaching

# Type a command into a pane's shell, so you're back at a prompt when it ends.
pane_run() { # target command
  local target=$1 cmd=$2
  if [[ -z $cmd || $cmd == shell ]]; then return 0; fi
  if [[ $cmd == agent ]]; then
    cmd=$(agent_cmd)
    if [[ -z $cmd ]]; then return 0; fi
    if ! have "${cmd%% *}"; then
      tmux send-keys -t "$target" "printf 'dev: %s not found. Set one with: dev agent set <command>\\n' '${cmd%% *}'" Enter
      return 0
    fi
  fi
  tmux send-keys -t "$target" "$cmd" Enter
}

default_workspace() { printf '[code]\nagent\nnvim\n'; }

# Build session $1 in $2 from a workspace (on stdin).
build_session() {
  local name=$1 root=$2 win='' layout='' first=1 panes=0 line cmds=()
  flush_window() {
    [[ -n $win ]] || return 0
    local target="$name:$win" i
    ((${#cmds[@]})) || cmds=(shell)
    if ((first)); then tmux new-session -d -s "$name" -n "$win" -c "$root"; first=0
    else tmux new-window -d -t "$name:" -n "$win" -c "$root"; fi
    for ((i = 1; i < ${#cmds[@]}; i++)); do tmux split-window -d -t "$target" -c "$root"; done
    # agent on the left (40%), the rest on the right
    tmux set-window-option -t "$target" main-pane-width '40%' >/dev/null 2>&1 || true
    tmux select-layout -t "$target" "${layout:-main-vertical}" >/dev/null
    local idx=0 pane
    while IFS= read -r pane; do
      pane_run "$pane" "${cmds[$idx]:-shell}"; ((idx++)) || true
    done < <(tmux list-panes -t "$target" -F '#{pane_id}')
    tmux select-pane -t "$target.{last}" 2>/dev/null || true
    cmds=(); panes=$((panes + 1))
  }
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    if [[ $line =~ ^[[:space:]]*# || -z ${line//[[:space:]]/} ]]; then continue; fi
    if [[ $line =~ ^\[([^]]+)\][[:space:]]*([a-z-]*) ]]; then
      flush_window
      win=${BASH_REMATCH[1]}; layout=${BASH_REMATCH[2]}
    else
      [[ -n $win ]] || { win=code; layout=''; }
      cmds+=("${line#"${line%%[![:space:]]*}"}")
    fi
  done
  flush_window
  ((first == 0)) || tmux new-session -d -s "$name" -c "$root"
  tmux select-window -t "$name:^" 2>/dev/null || true
}

attach() {
  if [[ ${DEV_NO_ATTACH:-0} == 1 ]]; then return 0; fi  # tests / scripts
  if [[ -n ${TMUX:-} ]]; then tmux switch-client -t "$1"; else tmux attach-session -t "$1"; fi
}

open_project() { # root
  local root=$1 name ws
  name=$(session_name "$root")
  if tmux has-session -t "=$name" 2>/dev/null; then attach "$name"; return; fi
  if ws=$(workspace_file "$root"); then
    register "$root"
    build_session "$name" "$root" <"$ws"
  else
    default_workspace | build_session "$name" "$root"
  fi
  attach "$name"
}
