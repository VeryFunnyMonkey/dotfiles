# shellcheck shell=bash
# share/dev/help.sh: dev help

cmd_help() {
  cat <<EOF
${B}dev${N}: tmux workspaces

  ${B}dev${N} [dir]               open this project's workspace (or the picker, outside a project)
  ${B}dev ls${N}                  pick a project or open session (also: prefix f, Alt-p);
                          every folder under ~ is in it too, or type a path
  ${B}dev init${N} [template] [--local|--repo]   create a workspace (.dev) here; templates: $(ls "$TEMPLATES" 2>/dev/null | tr '\n' ' ')
  ${B}dev edit${N}                edit this project's workspace
  ${B}dev agent${N} [set <cmd> | unset]   the agent the 'agent' pane runs
  ${B}dev wt${N} <branch>         a worktree + window for parallel work; ${B}dev wt ls${N}, ${B}dev wt rm${N} <branch>
  ${B}dev forget${N} [dir]        drop a project from the picker
  options: --agent <cmd> (this time only), --no-agent

  A workspace file: each [name] is a window (optional tmux layout after it:
  main-vertical, main-horizontal, even-horizontal, even-vertical, tiled);
  each line under it is a pane's command. 'agent' = your agent, 'shell' = a plain shell.
EOF
}
