# shellcheck shell=bash
# rig containers: Podman set up rootless and Docker-compatible. Sourced by rig.
#   Linux/WSL: sub-ID ranges for rootless containers (added if missing),
#              the per-user podman.socket (Docker API) and DOCKER_HOST.
#   macOS:     a podman machine (the VM), created once and started, its socket
#              in DOCKER_HOST, and `docker` running podman.
# Every change goes in the ledger; deselecting/uninstalling undoes it.

podman_selected() { [[ " ${RIG_SELECTED:-} " == *" podman "* ]]; }
DOCKER_HOST_FILE() { printf '%s/docker-host' "$RIG_STATE"; }

subids_ok() { grep -q "^$(id -un):" /etc/subuid 2>/dev/null && grep -q "^$(id -un):" /etc/subgid 2>/dev/null; }

cmd_containers() {
  load_machine; ledger_init
  local sub=${1:-sync}
  case $sub in
    sync) if podman_selected; then containers_setup; else containers_teardown; fi ;;
    *) die "usage: rig containers sync" ;;
  esac
}

containers_setup() {
  have podman || { warn "podman isn't installed yet (rig sync)"; return 0; }
  if [[ $(uname) == Darwin ]]; then
    if ! podman machine inspect >/dev/null 2>&1; then
      info "creating the podman machine (the small Linux VM containers run in on macOS)"
      podman machine init
      printf '%s\t%s\t%s\t%s\n' podman-machine default created "$(now)" >>"$RIG_STATE/system.log"
    fi
    if [[ $(podman machine inspect --format '{{.State}}' 2>/dev/null) != running ]]; then
      podman machine start >/dev/null && ok "podman machine started"
    fi
    local sock; sock=$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || true)
    if [[ -n $sock ]]; then printf 'unix://%s\n' "$sock" >"$(DOCKER_HOST_FILE)"; fi
  else
    if ! subids_ok; then
      info "adding sub-ID ranges for rootless containers ($(id -un))"
      sudo_ usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$(id -un)"
      printf '%s\t%s\t%s\t%s\n' subids "$(id -un)" added "$(now)" >>"$RIG_STATE/system.log"
      podman system migrate >/dev/null 2>&1 || true
    fi
    if have systemctl && systemctl --user show-environment >/dev/null 2>&1; then
      local prev; prev=$(systemctl --user is-enabled podman.socket 2>/dev/null || true)
      if [[ $prev != enabled ]]; then
        systemctl --user enable --now podman.socket
        printf '%s\t%s\t%s\t%s\n' user-unit podman.socket "${prev:-disabled}" "$(now)" >>"$RIG_STATE/system.log"
      fi
    else
      warn "no systemd user session: start the Docker-compatible socket by hand when needed (podman system service)"
    fi
    printf 'unix://%s/podman/podman.sock\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" >"$(DOCKER_HOST_FILE)"
  fi
  ok "podman ready ($(podman --version 2>/dev/null | awk '{print $3}')); docker, docker compose and DOCKER_HOST use it"
}

# Deselected: stop what rig started; ask before deleting the VM (images and
# volumes live in it). Packages are handled like any other deselected item.
containers_teardown() {
  [[ -f $(DOCKER_HOST_FILE) ]] || return 0
  rm -f "$(DOCKER_HOST_FILE)"
  if [[ $(uname) == Darwin ]] && have podman; then
    podman machine stop >/dev/null 2>&1 || true
    if grep -q $'^podman-machine\tdefault\tcreated' "$RIG_STATE/system.log" && confirm "Delete the podman machine too (its images and volumes go with it)?"; then
      podman machine rm -f >/dev/null 2>&1 && ok "podman machine deleted"
    fi
  elif have systemctl && [[ $(awk -F'\t' '$1=="user-unit" && $2=="podman.socket" {print $3}' "$RIG_STATE/system.log" | tail -n1) == disabled ]]; then
    systemctl --user disable --now podman.socket 2>/dev/null || true
  fi
  ok "podman stopped"
}
