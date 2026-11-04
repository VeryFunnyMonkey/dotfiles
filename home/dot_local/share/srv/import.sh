# shellcheck shell=bash
# share/srv/import.sh: srv import: hosts from a simple list or an Ansible inventory

# Import hosts from a file: srv's simple list (name user@host[:port] [path] per
# line; see extras/srv-hosts.example) or an Ansible inventory (hosts.yml, with
# group_vars/host_vars next to it for ansible_user / ansible_host). Imported
# hosts are marked source=import; re-importing replaces only those.
IMPORT_SRC() { printf '%s/import-source' "$SRV_CFG"; }

inventory_hosts() { # inventory.yml
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      match($0, /^ */); ind = RLENGTH
      line = $0; sub(/^ */, "", line); sub(/[[:space:]]*#.*/, "", line)
      if (in_hosts && ind <= hosts_ind) in_hosts = 0
      if (line == "hosts:") { in_hosts = 1; hosts_ind = ind; next }
      if (in_hosts && line ~ /^[A-Za-z0-9._-]+:$/ && ind == hosts_ind + 2) { sub(/:$/, "", line); print line }
    }' "$1" | sort -u
}
yaml_value() { # file key
  [[ -f $1 ]] || return 0
  awk -v k="$2" '$1==k":" {sub(/^[^:]*:[[:space:]]*/,""); gsub(/["'"'"']/,""); print; exit}' "$1"
}
host_vars_file() { # inventory-dir host
  local f
  for f in "$1/host_vars/$2.yml" "$1/host_vars/$2.yaml" "$1/host_vars/$2/main.yml" "$1/host_vars/$2/main.yaml"; do
    if [[ -f $f ]]; then printf '%s' "$f"; return; fi
  done
}
group_all_file() {
  local f
  for f in "$1/group_vars/all.yml" "$1/group_vars/all.yaml" "$1/group_vars/all/main.yml" "$1/group_vars/all/main.yaml"; do
    if [[ -f $f ]]; then printf '%s' "$f"; return; fi
  done
}

# file or folder -> the file to read (an inventory folder holds hosts.yml / inventory.yml)
import_file() {
  local p=${1/#\~/$HOME}
  if [[ -d $p ]]; then
    local f
    for f in "$p/hosts.yml" "$p/hosts.yaml" "$p/inventory.yml" "$p/inventory/hosts.yml" "$p/inventory/hosts.yaml"; do
      if [[ -f $f ]]; then printf '%s' "$f"; return; fi
    done
    return 1
  fi
  [[ -f $p ]] && printf '%s' "$p"
}

cmd_import() {
  if [[ ${1:-} == --merge ]]; then shift; import_merge "$@"; return; fi
  local arg=${1:-}
  if [[ -z $arg ]]; then
    [[ -f $(IMPORT_SRC) ]] || die "usage: srv import <hosts file | Ansible inventory> (example: extras/srv-hosts.example in the dotfiles)"
    arg=$(cat "$(IMPORT_SRC)")
  fi
  local file; file=$(import_file "$arg") || die "no hosts file at $arg"
  [[ -n $file ]] || die "no hosts file at $arg"
  hosts_init
  local tmp n=0 name target path
  tmp=$(mktemp)
  awk -F'\t' '$4!="import" && $4!="homelab"' "$HOSTS" >"$tmp"
  add_host() { # name target path
    if [[ -n $(awk -F'\t' -v n="$1" '$1==n' "$tmp") ]]; then warn "$1: you already have your own entry; kept yours"; return; fi
    printf '%s\t%s\t%s\timport\n' "$1" "$2" "${3:-~}" >>"$tmp"; n=$((n + 1))
  }
  if grep -qE '^[[:space:]]*hosts:[[:space:]]*$' "$file"; then
    # Ansible inventory
    local dir def_user user addr h hv
    dir=$(dirname "$file")
    def_user=$(yaml_value "$(group_all_file "$dir")" ansible_user); def_user=${def_user:-$(id -un)}
    while IFS= read -r h; do
      [[ -n $h ]] || continue
      hv=$(host_vars_file "$dir" "$h")
      user=$(yaml_value "$hv" ansible_user); user=${user:-$def_user}
      addr=$(yaml_value "$hv" ansible_host); addr=${addr:-$h}
      add_host "$h" "$user@$addr" "~"
    done < <(inventory_hosts "$file")
  else
    # simple list: name user@host[:port] [path]
    while read -r name target path _; do
      [[ -z $name || $name == \#* ]] && continue
      [[ $target == *@* ]] || { warn "skipped '$name': the login must be user@host"; continue; }
      add_host "$name" "$target" "$path"
    done <"$file"
  fi
  mv "$tmp" "$HOSTS"
  printf '%s\n' "$file" >"$(IMPORT_SRC)"
  ok "imported $n hosts from ${file/#$HOME/~} (srv ls; srv import again re-reads it)"
}

# srv export: the hosts, in srv's own format (moving them to another machine:
# rig export). srv import --merge <file> adds the ones that aren't here yet,
# each keeping its source, and leaves everything else alone.
cmd_export() { [[ -f $HOSTS ]] || return 0; awk -F'\t' '$1 !~ /^#/ && NF>=2' "$HOSTS"; }
import_merge() { # file
  local file=${1:?usage: srv import --merge <file from srv export>} name target path src n=0
  [[ -f $file ]] || die "no file at $file"
  hosts_init
  while IFS=$'\t' read -r name target path src; do
    [[ -n $name && $name != \#* && $target == *@* ]] || continue
    if [[ -n $(host_line "$name") ]]; then continue; fi
    printf '%s\t%s\t%s\t%s\n' "$name" "$target" "${path:-~}" "${src:-manual}" >>"$HOSTS"; n=$((n + 1))
  done <"$file"
  ok "added $n hosts (srv ls)"
}
