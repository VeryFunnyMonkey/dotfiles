# shellcheck shell=bash
# share/dev/workspace.sh: dev init / edit / forget

cmd_init() {
  local tmpl=default where='' root
  while (($#)); do
    case $1 in
      --local) where=local ;;
      --repo) where=repo ;;
      -*) die "unknown option $1" ;;
      *) tmpl=$1 ;;
    esac
    shift
  done
  root=$(project_root "$PWD")
  [[ -f $TEMPLATES/$tmpl ]] || die "no template '$tmpl' (have: $(ls "$TEMPLATES" 2>/dev/null | tr '\n' ' '))"
  [[ -n $where ]] || where=repo
  local file
  if [[ $where == local ]]; then mkdir -p "$LOCAL_STORE"; file="$LOCAL_STORE/$(session_name "$root")"
  else file="$root/.dev"; fi
  if [[ -e $file ]]; then die "a workspace already exists: $file (dev edit)"; fi
  cp "$TEMPLATES/$tmpl" "$file"
  register "$root"
  ok "workspace ${file/#$HOME/~} (from template $tmpl)"
  if [[ $where == local ]]; then printf '  %skept on this machine, not in the repo%s\n' "$DIM" "$N"; fi
  "${EDITOR:-nvim}" "$file"
}
cmd_edit() {
  local root ws; root=$(project_root "${1:-$PWD}")
  ws=$(workspace_file "$root") || die "no workspace here (dev init)"
  "${EDITOR:-nvim}" "$ws"
}
cmd_forget() {
  local root; root=$(project_root "${1:-$PWD}") || root=${1:-$PWD}
  [[ -f $REGISTRY ]] && { grep -vxF "$root" "$REGISTRY" >"$REGISTRY.new" || true; mv "$REGISTRY.new" "$REGISTRY"; }
  ok "forgot $root"
}
