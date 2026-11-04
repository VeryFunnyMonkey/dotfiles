# shellcheck shell=bash
# share/srv/doctor.sh: srv doctor, srv help

cmd_doctor() {
  local fails=0
  if have rclone; then ok "rclone $(rclone version 2>/dev/null | head -n1 | awk '{print $2}')"; else bad "rclone missing (rig sync)"; fails=1; fi
  if ! darwin; then
    if have fusermount3 || have fusermount; then ok "FUSE"; else bad "fuse3 missing (rig sync)"; fails=1; fi
  fi
  local m; m=$(mounted_hosts | tr '\n' ' ')
  ok "mounted: ${m:-none}"
  local n
  for n in $(host_names); do
    local mp; mp=$(mount_point "$n")
    # stale: still in the mount table, but its rclone is gone (e.g. killed, or the
    # machine slept through a network change)
    if is_mounted "$mp" && [[ -z $(rclone_pid "$mp") ]]; then
      bad "$n: stale mount (srv umount --force $n)"; fails=1
    fi
  done
  ((fails == 0))
}

cmd_help() {
  cat <<EOF
${B}srv${N}: mount your servers at ~/Servers/<host>, over SSH

  ${B}srv${N}                        pick a host (also: prefix m in tmux, Alt-m)
  ${B}srv mount${N} <host> [path]    mount its home folder (or a path)
  ${B}srv umount${N} <host> | --all  unmount (--force for a stuck mount)
  ${B}srv dev${N} <host>             mount it and open a dev workspace there (agent + nvim)
  ${B}srv ssh${N} <host> [-- cmd]    a shell (or a command) on the server
  ${B}srv add${N} [name user@host[:port] [path]]   add a host
  ${B}srv rm${N} <host> · ${B}srv edit${N} · ${B}srv ls${N}
  ${B}srv import${N} [file]          add hosts from a hosts file or an Ansible inventory (re-reads the last one)
  ${B}srv export${N}                 print the hosts; srv import --merge <file> adds them elsewhere (rig export does both)
  ${B}srv doctor${N}                 check rclone/FUSE and stale mounts
EOF
}
