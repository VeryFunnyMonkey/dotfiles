# shellcheck shell=bash
# modules/containers.sh: Podman, rootless and Docker-compatible (the podman
# item: `module: containers`).
#   Linux/WSL: sub-ID ranges for rootless containers (added if missing),
#              the per-user podman.socket (Docker API) and DOCKER_HOST.
#   macOS:     a podman machine (the VM), created once and started, its socket
#              in DOCKER_HOST, and `docker` running podman.
# Every change goes in the ledger; deselecting/uninstalling undoes it.

docker_host_file() { printf '%s/docker-host' "$RIG_STATE"; }

subids_ok() { grep -q "^$(id -un):" /etc/subuid 2>/dev/null && grep -q "^$(id -un):" /etc/subgid 2>/dev/null; }

containers_sync() {
  if module_active containers; then containers_setup; else containers_teardown; fi
}

containers_setup() {
  have podman || { warn "podman isn't installed yet (rig sync)"; return 0; }
  if is_darwin; then
    if ! podman machine inspect >/dev/null 2>&1; then
      info "creating the podman machine (the small Linux VM containers run in on macOS)"
      podman machine init
      ledger_record podman-machine default created
    fi
    if [[ $(podman machine inspect --format '{{.State}}' 2>/dev/null) != running ]]; then
      podman machine start >/dev/null && ok "podman machine started"
    fi
    local sock; sock=$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || true)
    if [[ -n $sock ]]; then printf 'unix://%s\n' "$sock" >"$(docker_host_file)"; fi
  else
    if ! subids_ok; then
      info "adding sub-ID ranges for rootless containers ($(id -un))"
      sudo_ usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$(id -un)"
      ledger_record subids "$(id -un)" added
      podman system migrate >/dev/null 2>&1 || true
    fi
    if have_user_systemd; then unit_enable_user podman.socket
    else warn "no systemd user session: start the Docker-compatible socket by hand when needed (podman system service)"; fi
    printf 'unix://%s/podman/podman.sock\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" >"$(docker_host_file)"
  fi
  ok "podman ready ($(podman --version 2>/dev/null | awk '{print $3}')); docker, docker compose and DOCKER_HOST use it"
}

# Deselected: stop what rig started; ask before deleting the VM (images and
# volumes live in it). Packages are handled like any other deselected item.
containers_teardown() {
  [[ -f $(docker_host_file) ]] || return 0
  rm -f "$(docker_host_file)"
  if is_darwin && have podman; then
    podman machine stop >/dev/null 2>&1 || true
    if ledger_has podman-machine default created && confirm "Delete the podman machine too (its images and volumes go with it)?"; then
      podman machine rm -f >/dev/null 2>&1 && ok "podman machine deleted"
    fi
  elif have systemctl; then
    unit_release_user podman.socket
  fi
  ok "podman stopped"
}

containers_doctor() {
  module_active containers || return 0
  info "containers"
  if have podman && podman info >/dev/null 2>&1; then check_ok "podman works ($(podman --version | awk '{print $3}'))"
  else check_bad "podman isn't working (podman info; on macOS: podman machine start)"; fi
  local dh; dh=$(cat "$(docker_host_file)" 2>/dev/null || true)
  if [[ -n $dh && -S ${dh#unix://} ]]; then check_ok "Docker-compatible socket: $dh"
  else check_bad "Docker-compatible socket missing (rig containers sync)"; fi
}

# usermod refuses while the user has processes (always, here), so remove
# exactly the line rig added
revert_subids() { sudo_ sed -i "/^$1:100000:65536\$/d" /etc/subuid /etc/subgid && ok "removed rootless sub-ID ranges for $1"; }
revert_podman_machine() {
  if have podman && podman machine inspect >/dev/null 2>&1 && confirm "Delete the podman machine (its images and volumes)?"; then
    podman machine rm -f >/dev/null 2>&1 && ok "deleted the podman machine"
  fi
}

containers_cmd() {
  load_machine; ledger_init
  case ${1:-sync} in
    sync) containers_sync ;;
    *) die "usage: rig containers sync" ;;
  esac
}
