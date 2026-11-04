#!/bin/sh
# Set up a new machine:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/VeryFunnyMonkey/dotfiles/main/install.sh)"
# Non-interactive (scripts, CI):
#   sh -c "$(curl -fsSL .../install.sh)" -- --profile desktop --yes
# Another branch (to try one out): RIG_BRANCH=<branch> in front, and the URL's
# "main" changed to it.
#
# Installs chezmoi, prepares the package manager (the repo's bootstrap step,
# recorded so rig uninstall can undo it), clones the dotfiles, then starts the
# installer: rig setup.
set -eu

REPO=${RIG_REPO:-VeryFunnyMonkey}
BRANCH=${RIG_BRANCH:-}
# ~/.config or ~/.local as a link to something that's gone (an old dotfiles
# setup, a sync folder) makes every step fail with "no such file or directory".
for d in "${XDG_CONFIG_HOME:-$HOME/.config}" "$HOME/.local"; do
  if [ -L "$d" ] && [ ! -e "$d" ]; then
    printf 'rig: %s is a link to %s, which no longer exists.\n' "$d" "$(readlink "$d")" >&2
    printf '     Point it somewhere that exists, or remove the link (rm %s), then run this again.\n' "$d" >&2
    exit 1
  fi
done
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
# A fresh macOS account has no ~/.config; chezmoi expects it there.
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
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
  if [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi/.git" ]; then say "using the dotfiles already here"
  else say "cloning the dotfiles ($REPO${BRANCH:+, branch $BRANCH})"; fi
  if [ -n "$BRANCH" ]; then chezmoi init --branch "$BRANCH" "$REPO"; else chezmoi init "$REPO"; fi
fi
SRC=$(chezmoi source-path)

# Already here (a re-run, or RIG_SOURCE): bring it up to date first, on the
# branch asked for. Local changes, or history that doesn't fast-forward, are
# left alone; offline, it carries on with what's there.
ROOT=$(git -C "$SRC" rev-parse --show-toplevel 2>/dev/null || true)
pull=no
if [ -n "$ROOT" ]; then
  if [ -n "$BRANCH" ] || git -C "$ROOT" rev-parse '@{u}' >/dev/null 2>&1; then pull=yes; fi
fi
if [ "$pull" = yes ]; then
  if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
    say "the dotfiles in $ROOT have local changes: not pulling"
  else
    if [ -n "$BRANCH" ] && [ "$(git -C "$ROOT" branch --show-current)" != "$BRANCH" ]; then
      git -C "$ROOT" fetch -q origin "$BRANCH" && git -C "$ROOT" checkout -q "$BRANCH" ||
        say "couldn't switch to branch $BRANCH; staying on $(git -C "$ROOT" branch --show-current)"
    fi
    if git -C "$ROOT" pull -q --ff-only 2>/dev/null; then say "dotfiles up to date ($(git -C "$ROOT" log -1 --format='%h %s'))"
    else say "couldn't pull the dotfiles (offline, or local commits); using what's here"; fi
  fi
fi

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
