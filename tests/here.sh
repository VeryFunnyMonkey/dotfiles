#!/usr/bin/env bash
# Run a test on this machine, as the current user, from a copy of the repo at
# ~/dotfiles (CI's WSL job; containers use tests/run.sh). Not for your own machine:
# the tests install and uninstall rig.
set -uo pipefail
name=${1:?usage: tests/here.sh <test>}
[[ -d ~/dotfiles && -f ~/dotfiles/tests/$name.sh ]] || { echo "needs the repo at ~/dotfiles" >&2; exit 2; }
log=$(mktemp)
bash -c "source ~/dotfiles/tests/lib.sh; source ~/dotfiles/tests/$name.sh" >"$log" 2>&1 || true
grep -E '^(PASS|FAIL|===|note:)' "$log"
if grep -q '^FAIL' "$log" || ! grep -q '^===' "$log"; then
  echo "--- the whole log:"; cat "$log"
  exit 1
fi
