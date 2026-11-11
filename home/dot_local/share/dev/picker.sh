# shellcheck shell=bash
# share/dev/picker.sh: the project picker (dev ls, prefix f, Alt-p)

# One line per project: what fzf shows, then (hidden) kind, session name, path.
#   kind: run = a tmux session is running, ws = has a workspace file, dir = a repo
# Projects are git repos: the ones zoxide knows (folders you've been in) and
# the ones under ~/Projects, plus anything with a running session or workspace.
# a repo inside another repo (a vendored library, a reference copy) isn't a project
nested_repo() { local d=${1%/*}; while [[ $d == "$HOME"/* ]]; do [[ -e $d/.git ]] && return 0; d=${d%/*}; done; return 1; }
picker_entries() { # kind \t name \t path \t tabs
  prune_registry
  local s p w n seen=$'\n'
  # open sessions, not the throwaway ones each Ghostty window opens
  # (\x1f between fields: with tabs, read would merge the empty @rig_window field away)
  while IFS=$'\x1f' read -r s p w n; do
    if [[ $w == 1 ]]; then continue; fi
    printf 'run\t%s\t%s\t%s\n' "$s" "$p" "$n"; seen+="$p"$'\n'
  done < <(tmux list-sessions -F $'#{session_name}\x1f#{session_path}\x1f#{@rig_window}\x1f#{session_windows}' 2>/dev/null || true)
  if [[ -f $REGISTRY ]]; then
    while IFS= read -r p; do
      if [[ $seen == *$'\n'"$p"$'\n'* ]]; then continue; fi
      printf 'ws\t%s\t%s\t\n' "$(session_name "$p")" "$p"; seen+="$p"$'\n'
    done <"$REGISTRY"
  fi
  # other git repos: most used first (zoxide), then the rest of ~/Projects
  {
    if have zoxide; then zoxide query -l 2>/dev/null | head -n 200; fi
    find "$HOME/Projects" -mindepth 2 -maxdepth 4 -name .git -prune 2>/dev/null | sed 's#/\.git$##' | sort
  } | while IFS= read -r p; do
    [[ -e $p/.git && $seen != *$'\n'"$p"$'\n'* ]] || continue
    if nested_repo "$p"; then continue; fi
    case $p in *.wt/*) continue ;; esac   # dev wt worktrees show under their repo
    printf 'dir\t%s\t%s\t\n' "$(session_name "$p")" "$p"; seen+="$p"$'\n'
  done
}
# Rows: name (as wide as the longest), status, the folder it's in (dim).
# --all adds every other folder under your home, for searching.
picker_items() {
  local entries kind name path tabs label width=8 scol=0
  entries=$(picker_entries)
  while IFS=$'\t' read -r kind name path tabs; do
    [[ -n $kind ]] || continue
    if [[ $kind != dir ]]; then scol=15; fi   # a status column only if something has one
    label=${path##*/}; [[ $kind == run ]] && label=$name
    if ((${#label} > width)); then width=${#label}; fi
  done <<<"$entries"
  if ((width > 22)); then width=22; fi
  while IFS=$'\t' read -r kind name path tabs; do
    [[ -n $kind ]] || continue
    label=${path##*/}; [[ $kind == run ]] && label=$name
    if ((${#label} > width)); then label="${label:0:width-1}…"; fi
    # the name in its kind's colour: open green, workspace blue, project plain
    local state='' text='' where=${path%/*} c=''
    case $kind in
      run) c='1;32'; text="open, $tabs tab$([[ $tabs == 1 ]] || echo s)"; state=$'\033[32m● '"$text"$'\033[0m' ;;
      ws)  c='34'; text="workspace"; state=$'\033[34m★ '"$text"$'\033[0m' ;;
    esac
    # padded by hand: printf counts bytes, and … ● ★ are 3 bytes each
    local name_pad; name_pad=$(printf '%*s' $((width - ${#label})) '')
    if [[ -n $c ]]; then label=$'\033['"${c}m${label}"$'\033[0m'; fi
    local pad=$((scol - (${#text} ? ${#text} + 2 : 0)))
    if ((scol)); then pad=$((pad + 2)); fi
    printf '%s%s  %s%*s\033[2m%s\033[0m\t%s\t%s\t%s\n' "$label" "$name_pad" "$state" "$pad" '' \
      "${where/#"$HOME"/\~}" "$kind" "$name" "$path"
  done <<<"$entries"
  if [[ ${1:-} != --all ]]; then return 0; fi
  # then every other folder under your home, so fuzzy search finds any path
  local projects; projects=$(cut -f3 <<<"$entries")
  all_dirs | awk -v home="$HOME" -v seen="$projects" '
    BEGIN { n = split(seen, a, "\n"); for (i = 1; i <= n; i++) skip[a[i]] = 1 }
    { p = home "/" $0; sub(/\/$/, "", p); if (p in skip) next
      n = p; sub(/.*\//, "", n); gsub(/[.:]/, "_", n)
      printf "\033[2m~/%s\033[0m\tfolder\t%s\t%s\n", substr(p, length(home) + 2), n, p; fflush() }'
}
# Folders under your home, shallow ones first (fd in depth bands, so the list
# still streams). fd's defaults skip what .gitignore ignores (node_modules,
# build output); caches and the trash are left out too.
all_dirs() {
  local fd; if have fd; then fd=fd; elif have fdfind; then fd=fdfind; else fd=''; fi
  if [[ -z $fd ]]; then
    (cd "$HOME" && find . -mindepth 1 -maxdepth 6 -type d -not -path '*/.git*' -not -path './.cache*' -printf '%P\n' 2>/dev/null) || true
    return 0
  fi
  # also left out: dependency and tool folders nobody opens a workspace in
  local x=(--type d --hidden --base-directory "$HOME"
           --exclude .git --exclude .cache --exclude Trash --exclude node_modules --exclude __pycache__
           --exclude .venv --exclude venv --exclude site-packages --exclude .npm --exclude .cargo
           --exclude .rustup --exclude .local/lib --exclude .local/share/nvim --exclude .local/share/fnm
           --exclude go/pkg --exclude .wine --exclude .steam --exclude .local/share/Steam .)
  "$fd" --max-depth 2 "${x[@]}" 2>/dev/null || true
  "$fd" --min-depth 3 --max-depth 3 "${x[@]}" 2>/dev/null || true
  "$fd" --min-depth 4 --max-depth 4 "${x[@]}" 2>/dev/null || true
  "$fd" --min-depth 5 "${x[@]}" 2>/dev/null || true
}
cmd_preview() { # kind name path
  local kind=$1 name=$2 path=$3 ws
  printf '\033[1m%s\033[0m  %s\n\n' "${path##*/}" "${path/#"$HOME"/\~}"
  if [[ $kind == folder ]]; then
    printf 'A folder. Enter opens it in tmux:\n  left:  %s\n  right: nvim\n\n' "$(left_pane)"
    ls -A --color=always "$path" 2>/dev/null | head -n 40
    return 0
  elif [[ $kind == run ]]; then
    printf 'Open now. Enter switches to it. Its tabs:\n\n'
    tmux list-windows -t "=$name" -F '  #{window_index}: #{window_name}  (#{window_panes} panes)' 2>/dev/null
    printf '\nctrl-x closes it.\n'
  elif ws=$(workspace_file "$path"); then
    printf 'Enter opens it with its workspace file (%s):\n\n' "${ws/#"$HOME"/\~}"
    if have bat; then bat --style=plain --color=always --language=ini "$ws"; else cat "$ws"; fi
    printf '\nctrl-e edits that file.\n'
  else
    printf 'Not open. Enter opens it in tmux:\n  left:  %s\n  right: nvim\n\n' "$(left_pane)"
    printf 'ctrl-n sets up a workspace file instead: your own tabs and panes\nfor this project (dev init).\n'
  fi
  if [[ -d $path/.git || -f $path/.git ]]; then
    printf '\n\033[2m%s\033[0m\n' "$(git -C "$path" log -1 --format='last commit %cr: %s' 2>/dev/null)"
  fi
}
left_pane() { local a; a=$(agent_cmd 2>/dev/null || true); if [[ -n $a ]]; then printf 'your agent (%s)' "$a"; else printf 'a shell (no agent set: dev agent set <cmd>)'; fi; }

# A typed path (~/x, /x, ./x) that's a folder: open exactly that folder.
typed_dir() { # query -> absolute folder, or nothing
  local q=$1
  # shellcheck disable=SC2088  # a literal ~ the user typed, expanded by hand
  case $q in "~"|"~/"*) q=$HOME${q#\~} ;; /*|./*|../*) ;; *) return 1 ;; esac
  [[ -d $q ]] && (cd "$q" && pwd -P)
}

cmd_ls() {
  have fzf || die "fzf isn't installed"
  local out query key line kind name path dir mark
  # marks whether the folders are loaded, so typing reloads only once
  mark=$(mktemp "${TMPDIR:-/tmp}/dev-pick.XXXXXX"); rm -f "$mark"
  trap 'rm -f "$mark"' RETURN
  local self; self="bash $(printf %q "$0")"
  local on_change="if [ -n \"\$FZF_QUERY\" ]; then [ -e $mark ] || { : > $mark; echo \"reload($self _items --all)\"; }; else rm -f $mark; echo \"reload($self _items)\"; fi"
  while :; do
    # enter with nothing matching still returns what was typed (a path, maybe)
    # ranked by match; equal matches keep list order (projects, then shallow folders)
    out=$(picker_items | pick --ansi --delimiter='\t' --with-nth=1 --tiebreak=index \
          --prompt='project> ' --print-query --bind 'enter:accept-or-print-query' \
          --header=$'\033[32m● open\033[0m · \033[34m★ workspace\033[0m · project · type to search all of ~\nenter open · ^x close · ^e/^n workspace · ^/ preview' \
          --bind "change:transform:$on_change" \
          --header-first \
          --preview="bash $(printf %q "$0") _preview {2} {3} {4}" --preview-window='right,45%,border-left,wrap,noinfo' \
          --bind "start,resize:transform:$PREVIEW_FIT" --bind 'ctrl-/:toggle-preview' \
          --expect=ctrl-e,ctrl-x,ctrl-n) || return 0
    query=$(sed -n 1p <<<"$out"); key=$(sed -n 2p <<<"$out"); line=$(sed -n 3p <<<"$out")
    # a typed path wins over whatever it happened to match
    if [[ -z $key ]] && dir=$(typed_dir "$query"); then open_project "$dir"; return; fi
    [[ -n $line ]] || return 0
    IFS=$'\t' read -r _ kind name path <<<"$line"
    case $key in
      ctrl-e) (cd "$path" && cmd_edit) ;;
      ctrl-x) if [[ $kind == run ]]; then tmux kill-session -t "=$name" 2>/dev/null && ok "closed $name"; fi ;;
      ctrl-n) (cd "$path" && cmd_init) ;;
      *) [[ -d $path ]] || die "$path doesn't exist"
         # a plain folder opens as itself, a project at its repo's root
         if [[ $kind == folder ]]; then open_project "$path"; else open_project "$(project_root "$path")"; fi ;;
    esac
    return
  done
}
