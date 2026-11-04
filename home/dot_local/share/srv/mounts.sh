# shellcheck shell=bash
# share/srv/mounts.sh: mounting and unmounting (rclone: FUSE on Linux, NFS on macOS)

mount_point() { printf '%s/%s' "$MNT_ROOT" "$1"; }
is_mounted() { # path
  if darwin; then mount | grep -q " on $1 ("
  else grep -q " $1 fuse" /proc/mounts 2>/dev/null; fi
}
state_add() { mkdir -p "$RUNTIME"; touch "$MOUNTED"; grep -qxF "$1" "$MOUNTED" || printf '%s\n' "$1" >>"$MOUNTED"; }
state_del() { [[ -f $MOUNTED ]] || return 0; grep -vxF "$1" "$MOUNTED" >"$MOUNTED.new" || true; mv "$MOUNTED.new" "$MOUNTED"; }
# Mounted hosts, checked against the real mount table (stale entries dropped).
mounted_hosts() {
  [[ -f $MOUNTED ]] || return 0
  local n
  while IFS= read -r n; do
    [[ -n $n ]] || continue
    if is_mounted "$(mount_point "$n")"; then printf '%s\n' "$n"; else state_del "$n"; fi
  done < <(cat "$MOUNTED")
}
rclone_pid() { pgrep -f "rclone (nfs)?mount .* $1( |$)" 2>/dev/null | head -n1 || true; }

# Make sure ssh can log in without a prompt (rclone runs in the background).
# If the key needs its passphrase, ask once; the agent keeps it (AddKeysToAgent).
ssh_ready() { # name
  local -a a; mapfile -t a < <(ssh_args "$(host_target "$1")")
  ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new "${a[@]}" true 2>/dev/null && return 0
  { : </dev/tty; } 2>/dev/null || return 1   # no terminal to ask in
  printf '  %s: unlocking your key / accepting the host key (once)\n' "$1"
  ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new "${a[@]}" true </dev/tty || return 1
}

cmd_mount() {
  local n=${1:-} path=${2:-}
  need_host "$n"
  have rclone || die "rclone isn't installed (rig sync)"
  local mp; mp=$(mount_point "$n")
  if is_mounted "$mp"; then state_add "$n"; status_push; ok "$n is already mounted at ${mp/#$HOME/~}"; return 0; fi
  # rclone: a relative path is relative to the login's home; blank is the home itself
  [[ -n $path ]] || path=$(host_path "$n")
  # shellcheck disable=SC2088  # the server's ~, not ours
  case $path in
    '~' | '~/') path='' ;;
    '~/'*) path=${path#\~/} ;;
  esac
  ssh_ready "$n" || die "can't log in to $n over ssh (srv ssh $n to check)"
  mkdir -p "$mp" "$CACHE/$n" "$LOGS"
  local -a a; mapfile -t a < <(ssh_args "$(host_target "$n")")
  local sshcmd="ssh -o BatchMode=yes ${a[*]}"
  local -a common=(
    ":sftp:$path" "$mp"
    --sftp-ssh "$sshcmd" --sftp-shell-type unix
    --vfs-cache-mode writes --vfs-write-back 1s --dir-cache-time 5s --attr-timeout 1s
    --cache-dir "$CACHE/$n" --log-file "$LOGS/$n.log" --log-level NOTICE
    --daemon
  )
  if darwin; then
    rclone nfsmount "${common[@]}" || die "mount failed (see ${LOGS/#$HOME/~}/$n.log)"
  else
    rclone mount "${common[@]}" --volname "$n" || die "mount failed (see ${LOGS/#$HOME/~}/$n.log)"
  fi
  local _; for _ in $(seq 1 20); do is_mounted "$mp" && break; sleep 0.25; done
  is_mounted "$mp" || die "rclone started but nothing is mounted (see ${LOGS/#$HOME/~}/$n.log)"
  state_add "$n"; status_push
  ok "mounted $n at ${mp/#$HOME/~}"
}

unmount_once() {
  if darwin; then umount "$1" 2>/dev/null
  else fusermount3 -u "$1" 2>/dev/null || fusermount -u "$1" 2>/dev/null; fi
}
unmount_force() {
  if darwin; then umount -f "$1" 2>/dev/null || diskutil unmount force "$1" >/dev/null 2>&1 || true
  else fusermount3 -uz "$1" 2>/dev/null || fusermount -uz "$1" 2>/dev/null || true; fi
}
users_of() { # what has the mount open
  if have lsof; then lsof +D "$1" 2>/dev/null | awk 'NR>1 {print "    " $1 " (pid " $2 ")"}' | sort -u | head -n 8
  elif have fuser; then fuser -vm "$1" 2>&1 | sed 's/^/    /' | head -n 8; fi
}
say_hint() { printf '    %s%s%s\n' "$DIM" "$*" "$N"; }

cmd_umount() {
  local force=0 all=0 names=()
  while (($#)); do case $1 in --force|-f) force=1 ;; --all|-a) all=1 ;; *) names+=("$1") ;; esac; shift; done
  if ((all)); then mapfile -t names < <( { mounted_hosts; [[ -f $MOUNTED ]] && cat "$MOUNTED"; } | sort -u); fi
  ((${#names[@]})) || die "usage: srv umount <host>... | --all [--force]"
  local n mp pid
  for n in "${names[@]}"; do
    [[ -n $n ]] || continue
    mp=$(mount_point "$n")
    if is_mounted "$mp"; then
      # programs that just closed (an editor's language server, say) can take
      # a moment to let go, so try a few times before calling it busy

      local _; for _ in 1 2 3 4 5 6; do
        unmount_once "$mp" && break
        if ((force)); then unmount_force "$mp"; break; fi
        sleep 0.5
      done
      pid=$(rclone_pid "$mp")
      if [[ -n $pid ]] && ((force)); then kill "$pid" 2>/dev/null || true; fi
    fi
    if is_mounted "$mp"; then
      bad "$n is busy: something still has files open in ${mp/#$HOME/~}"
      users_of "$mp"
      say_hint "close them, or: srv umount --force $n"
      continue
    fi
    state_del "$n"; status_push
    rmdir "$mp" 2>/dev/null || true
    ok "unmounted $n"
  done
  rmdir "$MNT_ROOT" 2>/dev/null || true
}
