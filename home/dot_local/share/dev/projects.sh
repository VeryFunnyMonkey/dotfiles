# shellcheck shell=bash
# share/dev/projects.sh: projects: their root, session name, workspace file, the registry

project_root() { # dir -> git toplevel (or the dir itself)
  local d; d=$(cd "$1" 2>/dev/null && pwd -P) || return 1
  git -C "$d" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$d"
}
session_name() { local n; n=$(basename "$1"); printf '%s' "${n//[.:]/_}"; }
workspace_file() { # root -> the .dev file in use, if any
  if [[ -f $1/.dev ]]; then printf '%s\n' "$1/.dev"
  elif [[ -f $LOCAL_STORE/$(session_name "$1") ]]; then printf '%s\n' "$LOCAL_STORE/$(session_name "$1")"
  else return 1; fi
}
register() { mkdir -p "$DEV_CFG"; touch "$REGISTRY"; grep -qxF "$1" "$REGISTRY" || printf '%s\n' "$1" >>"$REGISTRY"; }
prune_registry() {
  [[ -f $REGISTRY ]] || return 0
  local tmp; tmp=$(mktemp)
  while IFS= read -r p; do [[ -d $p ]] && workspace_file "$p" >/dev/null && printf '%s\n' "$p"; done <"$REGISTRY" | sort -u >"$tmp"
  mv "$tmp" "$REGISTRY"
}
