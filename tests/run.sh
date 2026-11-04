#!/usr/bin/env bash
# Run a test in a throwaway container:  tests/run.sh <test> [image]
#   image: archlinux (default) or ubuntu:24.04
# A test's header can ask for extras:
#   # packages: <distro packages>   installed before the test (as root)
#   # needs: fuse                    the container gets /dev/fuse
#   # needs: server                  a second container "srvbox" running sshd
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); repo=$(dirname "$here")
name=${1:?usage: tests/run.sh <test> [image]}; image=${2:-archlinux:latest}
test="$here/$name.sh"; [[ -f $test ]] || { echo "no test $test" >&2; exit 2; }
extra=$(sed -n 's/^# packages: //p' "$test")
needs=$(sed -n 's/^# needs: //p' "$test" | tr '\n' ' ')
c="rigtest-$name-$$"; net="rignet-$$"
cleanup() { docker rm -f "$c" srvbox-$$ >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker network create "$net" >/dev/null
args=(--network "$net")
[[ $needs == *fuse* ]] && args+=(--device /dev/fuse --cap-add SYS_ADMIN)
docker run -d --name "$c" "${args[@]}" "$image" sleep infinity >/dev/null
case $image in
  archlinux*) docker exec "$c" bash -c "pacman -Syu --noconfirm --needed sudo git curl util-linux openssh $extra >/tmp/pkg.log 2>&1" ;;
  ubuntu*|debian*) docker exec "$c" bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq sudo curl ca-certificates git openssh-client $extra >/tmp/pkg.log 2>&1" ;;
esac
docker exec "$c" bash -c 'useradd -m -s /bin/bash tester && echo "tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tester'

if [[ $needs == *server* ]]; then
  docker run -d --name "srvbox-$$" --hostname srvbox --network-alias srvbox --network "$net" archlinux:latest sleep infinity >/dev/null
  docker exec "srvbox-$$" bash -c 'pacman -Sy --noconfirm --needed openssh >/dev/null 2>&1 && ssh-keygen -A >/dev/null && useradd -m -s /bin/bash debian && mkdir -p /home/debian/.ssh && /usr/bin/sshd'
  docker exec -u tester "$c" bash -c 'mkdir -p ~/.ssh && ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519'
  docker exec -u tester "$c" cat /home/tester/.ssh/id_ed25519.pub | docker exec -i "srvbox-$$" bash -c 'cat >> /home/debian/.ssh/authorized_keys && chown -R debian /home/debian/.ssh && chmod 600 /home/debian/.ssh/authorized_keys'
fi

docker cp "$repo" "$c:/home/tester/dotfiles"
docker exec "$c" chown -R tester:tester /home/tester/dotfiles
log=$(mktemp)
docker exec -u tester "$c" bash -c "source ~/dotfiles/tests/lib.sh; source ~/dotfiles/tests/$name.sh" >"$log" 2>&1 || true
grep -E '^(PASS|FAIL|===)' "$log"
if grep -q '^FAIL' "$log" || ! grep -q '^===' "$log"; then
  echo "--- last lines of the log:"; tail -n 40 "$log"
  exit 1
fi
