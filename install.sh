#!/bin/sh
# Set up a new machine:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/VeryFunnyMonkey/dotfiles/main/install.sh)"
# Non-interactive (scripts, CI):
#   sh -c "$(curl -fsSL .../install.sh)" -- --profile desktop --yes
#
# Installs chezmoi, prepares the package manager (the repo's bootstrap step,
# recorded so rig uninstall can undo it), clones the dotfiles, then starts the
# installer: rig setup.
set -eu

REPO=${RIG_REPO:-VeryFunnyMonkey}
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
PATH="$BIN:$PATH"

say() { printf '\033[34m==>\033[0m %s\n' "$*"; }

if ! command -v chezmoi >/dev/null 2>&1; then
  say "installing chezmoi"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$BIN" >/dev/null
  # recorded, so rig uninstall can remove it too
  STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rig"
  mkdir -p "$STATE"
  printf 'chezmoi-installed\t%s\t-\t%s\n' "$BIN/chezmoi" "$(date +%Y-%m-%dT%H:%M:%S)" >>"$STATE/system.log"
fi

if [ -n "${RIG_SOURCE:-}" ]; then
  say "using the dotfiles at $RIG_SOURCE"
  chezmoi init --source "$RIG_SOURCE"
else
  say "cloning the dotfiles ($REPO)"
  chezmoi init "$REPO"
fi
SRC=$(chezmoi source-path)

say "preparing the package manager"
chezmoi execute-template --source "$SRC" < "$SRC/.chezmoiscripts/run_once_before_00-bootstrap.sh.tmpl" | bash

# Homebrew (macOS, Debian/Ubuntu, Fedora) on PATH for the rest
for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -x "$b" ]; then eval "$("$b" shellenv)"; break; fi
done

# Give the installer the terminal (stdin may be the curl pipe); without one
# (CI, containers) it runs as is, which needs --yes.
if (: </dev/tty) 2>/dev/null; then
  exec bash "$SRC/dot_local/bin/executable_rig" setup "$@" </dev/tty
else
  exec bash "$SRC/dot_local/bin/executable_rig" setup "$@"
fi
