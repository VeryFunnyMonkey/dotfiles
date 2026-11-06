# Podman on a machine that already has Docker: rig leaves Docker as it is
# (no podman-docker in its place, no DOCKER_HOST pointing at Podman), says
# so, and Docker is still there after rig uninstall.
sudo pacman -S --noconfirm --needed docker >/dev/null 2>&1
pkgs | sort > /tmp/pkgs-before.txt
install_rig --profile minimal --select podman --yes
check "install ok" '[[ $? -eq 0 ]]' || tail -20 /tmp/install.log
check "podman installed next to Docker" 'command -v podman >/dev/null && pacman -Q docker >/dev/null 2>&1'
check "podman-docker left out, and the log says why" '! pacman -Q podman-docker >/dev/null 2>&1 && grep -q "left out podman-docker: your docker is installed" /tmp/install.log' || grep -i "docker" /tmp/install.log
check "docker is still Docker's" '[[ $(docker --version 2>/dev/null) == Docker* ]]'
check "no DOCKER_HOST pointing at Podman" '[[ ! -e ~/.local/state/rig/docker-host ]]'
doc=$(rig doctor 2>&1)
check "doctor: packages complete, docker is yours" '[[ $doc == *"all declared packages installed"* && $doc == *"docker is your own Docker"* ]]' || echo "$doc"
~/.local/bin/rig uninstall --everything --yes > /tmp/un.log 2>&1
check "uninstall ok" '[[ $? -eq 0 ]]' || tail -20 /tmp/un.log
pkgs | sort > /tmp/pkgs-after.txt
check "packages back to before (Docker kept)" '[[ "$(cat /tmp/pkgs-before.txt)" == "$(cat /tmp/pkgs-after.txt)" ]]' || comm -3 /tmp/pkgs-before.txt /tmp/pkgs-after.txt | head
done_tests
