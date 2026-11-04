# shellcheck shell=bash
# share/srv/status.sh: srv ls, and the status for the prompt and tmux

cmd_ls() {
  hosts_init
  local mounted; mounted=$(mounted_hosts)
  local n t p s any=0
  while IFS=$'\t' read -r n t p s; do
    [[ -z $n || $n == \#* ]] && continue
    any=1
    if grep -qxF "$n" <<<"$mounted"; then printf '  %s●%s %-18s %-32s %s%s\n' "$G" "$N" "$n" "$t" "${p:-~}" "$([[ $s == import || $s == homelab ]] && echo "  ${DIM}imported${N}")"
    else printf '  ○ %-18s %-32s %s%s\n' "$n" "$t" "${p:-~}" "$([[ $s == import || $s == homelab ]] && echo "  ${DIM}imported${N}")"; fi
  done <"$HOSTS"
  ((any)) || echo "  no hosts yet: srv add, or srv import <hosts file>"
}
# For the prompt and tmux: mounted host names, or nothing.
cmd_status() {
  local m; m=$(mounted_hosts | tr '\n' ' '); m=${m% }
  [[ -n $m ]] || return 0
  case ${1:-} in
    --tmux) printf '#[fg=yellow]⇅ %s ' "$m" ;;
    *) printf '%s\n' "$m" ;;
  esac
}
