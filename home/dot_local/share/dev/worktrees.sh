# shellcheck shell=bash
# share/dev/worktrees.sh: dev wt: a worktree and window for parallel work

cmd_wt() {
  local sub=${1:-}; (($#)) && shift
  local root; root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not in a git repo"
  # worktrees live next to the main checkout
  local main; main=$(git -C "$root" worktree list --porcelain | awk '/^worktree /{print $2; exit}')
  local base; base="$(dirname "$main")/$(basename "$main").wt"
  case $sub in
    ls) git -C "$main" worktree list ;;
    rm)
      local br=${1:-}; [[ -n $br ]] || die "usage: dev wt rm <branch>"
      local path="$base/$br"
      [[ -d $path ]] || die "no worktree at $path"
      [[ -z $(git -C "$path" status --porcelain) ]] || die "$br has uncommitted changes; commit or stash first"
      local w; w=$(tmux list-windows -a -F '#{session_name}:#{window_index} #{pane_current_path}' 2>/dev/null | awk -v p="$path" '$2==p || index($2, p "/")==1 {print $1}' | sort -u)
      git -C "$main" worktree remove "$path"
      [[ -n $w ]] && while IFS= read -r t; do tmux kill-window -t "$t" 2>/dev/null || true; done <<<"$w"
      ok "removed worktree $br" ;;
    ''|-*) die "usage: dev wt <branch> | dev wt ls | dev wt rm <branch>" ;;
    *)
      local br=$sub path="$base/$sub"
      if [[ ! -d $path ]]; then
        mkdir -p "$base"
        if git -C "$main" show-ref --verify --quiet "refs/heads/$br"; then git -C "$main" worktree add "$path" "$br"
        else git -C "$main" worktree add -b "$br" "$path"; fi
      fi
      local session; session=$(session_name "$main")
      tmux has-session -t "=$session" 2>/dev/null || default_workspace | build_session "$session" "$main"
      local win="wt:${br//[.:]/_}"
      if ! tmux list-windows -t "=$session" -F '#{window_name}' | grep -qxF "$win"; then
        tmux new-window -d -t "$session:" -n "$win" -c "$path"
        tmux split-window -d -h -t "$session:$win" -c "$path"
        tmux set-window-option -t "$session:$win" main-pane-width '40%' >/dev/null 2>&1
        tmux select-layout -t "$session:$win" main-vertical >/dev/null
        local panes; mapfile -t panes < <(tmux list-panes -t "$session:$win" -F '#{pane_id}')
        pane_run "${panes[0]}" agent
        pane_run "${panes[1]}" nvim
      fi
      tmux select-window -t "$session:$win"
      attach "$session" ;;
  esac
}
