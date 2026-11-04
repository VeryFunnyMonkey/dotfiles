# shellcheck shell=bash
# share/srv/connect.sh: srv ssh / dev

cmd_ssh() {
  local n=${1:-}; need_host "$n"; shift
  [[ ${1:-} == -- ]] && shift
  local -a a; mapfile -t a < <(ssh_args "$(host_target "$n")")
  exec ssh "${a[@]}" "$@"
}
cmd_dev() {
  local n=${1:-}; need_host "$n"
  is_mounted "$(mount_point "$n")" || cmd_mount "$n"
  exec dev "$(mount_point "$n")"
}
