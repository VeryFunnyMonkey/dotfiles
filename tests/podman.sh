# needs: privileged
# Podman, rootless and Docker-compatible: docker run / docker compose through the
# shim and the socket; sub-ID ranges added and removed again; clean uninstall.
sudo sed -i "/^$(id -un):/d" /etc/subuid /etc/subgid      # start without sub-ID ranges
# the runtime folder where a real login puts it (the host's AppArmor profile for
# pasta, Podman's networking, only allows this one)
export XDG_RUNTIME_DIR=/run/user/$(id -u); sudo mkdir -p "$XDG_RUNTIME_DIR"; sudo chown "$(id -u):$(id -g)" "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
# no journald in a container: container logs and events go to files
mkdir -p ~/.config/containers
printf '[containers]\nlog_driver = "k8s-file"\n[engine]\nevents_logger = "file"\n' > ~/.config/containers/containers.conf
pkgs | sort > /tmp/pkgs-before.txt
install_rig --profile minimal --select podman,lazydocker --yes
check "install ok" '[[ $? -eq 0 ]]'
check "podman, the docker shim and compose installed" 'command -v podman >/dev/null && command -v docker >/dev/null && command -v docker-compose >/dev/null && command -v lazydocker >/dev/null'
check "sub-ID ranges added for rootless" 'grep -q "^$(id -un):" /etc/subuid && grep -q "^$(id -un):" /etc/subgid'
check "DOCKER_HOST recorded" '[[ $(cat ~/.local/state/rig/docker-host) == "unix://$XDG_RUNTIME_DIR/podman/podman.sock" ]]'
# test container only: Docker's image layers drop newuidmap's file capability
sudo chmod u+s "$(command -v newuidmap)" "$(command -v newgidmap)"
# ... and Podman's overlay storage can't sit on Docker's overlay: use vfs here
export STORAGE_DRIVER=vfs
podman system reset -f >/dev/null 2>&1
# no systemd in a container: run the Docker-compatible service by hand
mkdir -p "$XDG_RUNTIME_DIR/podman"
podman system service --time=0 "unix://$XDG_RUNTIME_DIR/podman/podman.sock" >/tmp/svc.log 2>&1 &
sleep 2
check "rootless podman runs a container" '[[ $(podman run --rm docker.io/library/alpine echo hi 2>/tmp/run.err) == hi ]]' || tail -n 15 /tmp/run.err
check "docker shim runs it too" '[[ $(docker run --rm docker.io/library/alpine echo via-docker 2>/dev/null) == via-docker ]]'
mkdir -p ~/c && printf 'services:\n  hello:\n    image: docker.io/library/alpine\n    command: echo from-compose\n' > ~/c/compose.yml
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
(cd ~/c && docker compose up > /tmp/compose.log 2>&1)
check "docker compose up works through the socket" 'grep -q from-compose /tmp/compose.log' || tail -n 15 /tmp/compose.log
check "containers run as this user, not root" '[[ $(podman info --format "{{.Host.Security.Rootless}}") == true ]]'
RIG_YES=1 rig remove podman lazydocker > /tmp/rm.log 2>&1
check "deselect: DOCKER_HOST file gone" '[[ ! -e ~/.local/state/rig/docker-host ]]'
kill %1 2>/dev/null || true
~/.local/bin/rig uninstall --everything --yes > /tmp/un.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]'
check "sub-ID ranges rig added are removed again" '! grep -q "^$(id -un):" /etc/subuid' || { grep -i "sub-id\|subid\|usermod" /tmp/un.log; grep subids ~/rig-uninstall-*/.local/state/rig/system.log 2>/dev/null; cat /etc/subuid; }
pkgs | sort > /tmp/pkgs-after.txt
check "packages back to before" '[[ "$(cat /tmp/pkgs-before.txt)" == "$(cat /tmp/pkgs-after.txt)" ]]' || comm -3 /tmp/pkgs-before.txt /tmp/pkgs-after.txt | head
done_tests
