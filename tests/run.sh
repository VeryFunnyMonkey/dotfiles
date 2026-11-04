#!/usr/bin/env bash
# Run a test in a throwaway container (Docker or Podman):  tests/run.sh <test> [image]
#   image: archlinux (default) or ubuntu:24.04
# A test's header can ask for extras:
#   # packages: <distro packages>   installed before the test (as root)
#   # needs: fuse                    the container gets /dev/fuse
#   # needs: server                  a second container "srvbox" running sshd
#   # needs: privileged              a privileged container (containers inside it)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); repo=$(dirname "$here")
# Docker or Podman, whichever is here (CTR=podman to choose)
ctr=${CTR:-$(command -v docker >/dev/null && echo docker || echo podman)}
name=${1:?usage: tests/run.sh <test> [image]}; image=${2:-archlinux:latest}
test="$here/$name.sh"; [[ -f $test ]] || { echo "no test $test" >&2; exit 2; }
extra=$(sed -n 's/^# packages: //p' "$test")
needs=$(sed -n 's/^# needs: //p' "$test" | tr '\n' ' ')
c="rigtest-$name-$$"; net="rignet-$$"
cleanup() {
  if [[ ${KEEP:-0} == 1 ]]; then echo "(KEEP=1: container $c left running)"; return; fi
  "$ctr" rm -f "$c" srvbox-$$ >/dev/null 2>&1 || true; "$ctr" network rm "$net" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$ctr" network create "$net" >/dev/null
args=(--network "$net")
[[ $needs == *fuse* ]] && args+=(--device /dev/fuse --cap-add SYS_ADMIN --security-opt apparmor=unconfined)
[[ $needs == *privileged* ]] && args+=(--privileged)
fq() { if [[ $1 == */* ]]; then echo "$1"; else echo "docker.io/library/$1"; fi; }  # Podman wants full names
"$ctr" run -d --name "$c" "${args[@]}" "$(fq "$image")" sleep infinity >/dev/null
case $image in
  archlinux*) "$ctr" exec "$c" bash -c "pacman -Syu --noconfirm --needed sudo git curl util-linux openssh $extra >/tmp/pkg.log 2>&1" ;;
  ubuntu*|debian*) "$ctr" exec "$c" bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq sudo curl ca-certificates git openssh-client $extra >/tmp/pkg.log 2>&1" ;;
esac
"$ctr" exec "$c" bash -c 'useradd -m -s /bin/bash tester && echo "tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tester'

if [[ $needs == *server* ]]; then
  "$ctr" run -d --name "srvbox-$$" --hostname srvbox --network-alias srvbox --network "$net" "$(fq archlinux:latest)" sleep infinity >/dev/null
  "$ctr" exec "srvbox-$$" bash -c 'pacman -Sy --noconfirm --needed openssh >/dev/null 2>&1 && ssh-keygen -A >/dev/null && useradd -m -s /bin/bash debian && mkdir -p /home/debian/.ssh && /usr/bin/sshd'
  "$ctr" exec -u tester "$c" bash -c 'mkdir -p ~/.ssh && ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519'
  "$ctr" exec -u tester "$c" cat /home/tester/.ssh/id_ed25519.pub | "$ctr" exec -i "srvbox-$$" bash -c 'cat >> /home/debian/.ssh/authorized_keys && chown -R debian /home/debian/.ssh && chmod 600 /home/debian/.ssh/authorized_keys'
fi

"$ctr" cp "$repo" "$c:/home/tester/dotfiles"
"$ctr" exec "$c" chown -R tester:tester /home/tester/dotfiles
log=$(mktemp)
"$ctr" exec -u tester "$c" bash -c "source ~/dotfiles/tests/lib.sh; source ~/dotfiles/tests/$name.sh" >"$log" 2>&1 || true
grep -E '^(PASS|FAIL|===)' "$log"
if grep -q '^FAIL' "$log" || ! grep -q '^===' "$log"; then
  echo "--- last lines of the log:"; tail -n 40 "$log"
  exit 1
fi
