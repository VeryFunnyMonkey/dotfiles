# shellcheck shell=bash
# share/srv/picker.sh: the picker (srv, prefix m, Alt-m)

cmd_pick() {
  have fzf || die "fzf isn't installed"
  hosts_init
  local mounted; mounted=$(mounted_hosts)
  local lines='' n t p
  while IFS=$'\t' read -r n t p _; do
    [[ -z $n || $n == \#* ]] && continue
    if grep -qxF "$n" <<<"$mounted"; then lines+="●"$'\t'"$n"$'\t'"$t"$'\t'"${p:-~}"$'\n'
    else lines+="○"$'\t'"$n"$'\t'"$t"$'\t'"${p:-~}"$'\n'; fi
  done <"$HOSTS"
  if [[ -z $lines ]]; then lines="+"$'\t'"(add a host)"$'\t'$'\t'$'\n'; fi
  local out key line mark
  out=$(printf '%s' "$lines" | fzf --ansi --delimiter='\t' --no-sort --prompt='server> ' \
        --header='enter mount/unmount · ctrl-d dev workspace · ctrl-s ssh · ctrl-a add · ctrl-e edit · ctrl-x unmount' \
        --preview="$0 _preview {2}" --preview-window=right,45% \
        --expect=ctrl-d,ctrl-s,ctrl-a,ctrl-e,ctrl-x) || return 0
  key=$(head -n1 <<<"$out"); line=$(sed -n 2p <<<"$out")
  IFS=$'\t' read -r mark n _ <<<"$line"
  case $key in
    ctrl-a) cmd_add ;;
    ctrl-e) "${EDITOR:-nvim}" "$HOSTS" ;;
    ctrl-d) [[ $mark == + ]] || cmd_dev "$n" ;;
    ctrl-s) [[ $mark == + ]] || cmd_ssh "$n" ;;
    ctrl-x) [[ $mark == ● ]] && cmd_umount "$n" ;;
    *)
      if [[ $mark == + ]]; then cmd_add
      elif [[ $mark == ● ]]; then cmd_umount "$n"
      else cmd_mount "$n"; fi ;;
  esac
}
cmd_preview() {
  local n=$1 mp; [[ -n $(host_line "$n") ]] || { echo "add a host: user@host, and a folder (blank = home)"; return; }
  mp=$(mount_point "$n")
  printf '%s\n\n  login   %s\n  folder  %s\n  mount   %s\n' "$n" "$(host_target "$n")" "$(host_path "$n" | sed 's/^~$/~ (home)/')" "${mp/#$HOME/~}"
  if is_mounted "$mp"; then
    printf '\n  ● mounted\n\n'; ls -1 "$mp" 2>/dev/null | head -n 20 | sed 's/^/    /'
  else printf '\n  ○ not mounted (enter mounts it)\n'; fi
}
