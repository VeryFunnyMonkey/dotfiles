#!/usr/bin/env bash
# Every shell file that shellcheck should check: the installer, the test
# runners, the commands, and all their libraries. Used by .githooks/pre-commit
# and CI, so a new file is checked without editing either.
set -euo pipefail
cd "$(dirname "$0")/.."
printf '%s\n' install.sh tests/run.sh tests/here.sh \
  home/dot_local/bin/executable_rig home/dot_local/bin/executable_dev home/dot_local/bin/executable_srv
find home/dot_local/share -name '*.sh' | sort
