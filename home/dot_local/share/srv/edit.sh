# shellcheck shell=bash
# share/srv/edit.sh: srv add / rm

ask() { # prompt [default]
  local r
  if have gum; then gum input --prompt "$1: " --value "${2:-}" </dev/tty
  else printf '  %s%s: ' "$1" "${2:+ [$2]}" >/dev/tty; IFS= read -r r </dev/tty; printf '%s' "${r:-${2:-}}"; fi
}
cmd_add() {
  hosts_init
  local n=${1:-} t=${2:-} p=${3:-}
  [[ -n $n ]] || n=$(ask "Name (used for ~/Servers/<name>)")
  n=$(printf '%s' "$n" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9._-')
  [[ -n $n ]] || die "need a name"
  [[ -z $(host_line "$n") ]] || die "'$n' already exists (srv edit to change it)"
  [[ -n $t ]] || t=$(ask "Login (user@host, or user@host:port)" "$(id -un)@$n")
  [[ $t == *@* ]] || die "the login is user@host"
  [[ $# -ge 3 ]] || p=$(ask "Folder to mount (blank = the home folder)" "")
  printf '%s\t%s\t%s\t%s\n' "$n" "$t" "${p:-~}" manual >>"$HOSTS"
  ok "added $n ($t${p:+, $p})"
  if ssh_ready "$n"; then ok "ssh login works"; else warn "couldn't log in yet; check with: srv ssh $n"; fi
}
cmd_rm() {
  local n=${1:-}; need_host "$n"
  if is_mounted "$(mount_point "$n")"; then cmd_umount "$n"; fi
  awk -F'\t' -v n="$n" '$1!=n' "$HOSTS" >"$HOSTS.new" && mv "$HOSTS.new" "$HOSTS"
  ok "removed $n"
}
