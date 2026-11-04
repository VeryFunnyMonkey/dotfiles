# shellcheck shell=bash
# share/srv/hosts.sh: the hosts file and ssh targets

# hosts file: name TAB user@host[:port] TAB path (~ = home) TAB source (manual|import)
hosts_init() { mkdir -p "$SRV_CFG"; [[ -f $HOSTS ]] || printf '# srv hosts: name<TAB>user@host[:port]<TAB>path (~ = home)<TAB>source\n' >"$HOSTS"; }
host_line() { awk -F'\t' -v n="$1" '$1==n && $1 !~ /^#/ {print; exit}' "$HOSTS" 2>/dev/null; }
host_names() { awk -F'\t' '$1 !~ /^#/ && NF>=2 {print $1}' "$HOSTS" 2>/dev/null; }
host_target() { host_line "$1" | cut -f2; }
host_path() { host_line "$1" | cut -f3; }
need_host() { [[ -n $(host_line "${1:-}") ]] || die "no host '${1:-}' (srv ls, srv add)"; }

# user@host[:port] -> ssh arguments
ssh_args() {
  local t=$1 port=''
  if [[ $t == *:* ]]; then port=${t##*:}; t=${t%:*}; fi
  printf '%s\n' -o ServerAliveInterval=15 -o ServerAliveCountMax=3
  if [[ -n $port ]]; then printf '%s\n' -p "$port"; fi
  printf '%s\n' "$t"
}
