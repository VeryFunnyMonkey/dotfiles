# Agent instructions for this repo

Personal dotfiles for **client machines** (Arch, macOS, Debian/Ubuntu incl. WSL, Fedora). Servers are managed by a separate Ansible repo; don't add server concerns here.

## Layout
- `home/` is the chezmoi source (`.chezmoiroot`); chezmoi runs in **symlink mode**, so plain files in `~` are symlinks into the repo. Templates (`*.tmpl`) and executables are copies: after editing them, `chezmoi apply`.
- `home/.chezmoi.toml.tmpl`: chezmoi's config for the machine. It asks nothing: `rig setup` writes profile/selected/extra_packages/agent_default; detection (`.chezmoitemplates/detect`) adds wsl/display/desktop.
- `home/.chezmoidata/`: `catalog/*.yaml` (every selectable item, by category: packages, platforms, needs, nvim), `profiles/*.yaml` (saved selections), `packages.yaml` (core + per-OS names), `runtimes.yaml`, `theme.yaml`. `.chezmoitemplates/enabled` works out what applies on this machine (selected, skipped, runtimes, agents).
- `home/.chezmoiscripts/`: setup steps (bootstrap, backup ledger, packages, shell, ssh agent, nvim).
- `home/dot_local/bin/executable_rig`: the `rig` command; its libraries in `home/dot_local/share/rig/` (found next to rig, so it runs from the repo too): `setup.sh` (installer, add/remove, profiles), `git.sh` (git accounts), `runtimes.sh` (runtimes, Tailscale), `agents.sh` (coding agents).
- `install.sh`: the bootstrap one-liner for a new machine.
- `docs/catalog/`: guides for catalog items (`rig info <item>`).
- `home/dot_local/bin/executable_dev`: `dev` (tmux workspaces); templates in `home/dot_config/dev/templates/`.
- `home/dot_local/bin/executable_srv`: `srv` (mount servers over SSH with rclone: nfsmount on macOS, FUSE mount on Linux). Hosts are machine-local (`~/.config/srv/hosts`); mount state lives in a runtime folder so it disappears with the mounts.
- `home/dot_config/`: zsh, tmux, nvim, git, lazygit, rig's rendered data.

## Rules
- **New software is a catalog item** (category, description, platforms), not a hard-coded package. Only rig's own dependencies go in core.
- **Every package earns its place.** Prefer what's already chosen; don't add tools that duplicate one.
- **Everything rig changes must be undoable.** New system changes get a ledger entry in `~/.local/state/rig/system.log` (kind, key, previous value) and a matching revert in `system_revert_all` in `rig`. New files chezmoi takes over are backed up by `run_before_05-backup.sh`.
- Symlink mode makes edits live on the owner's machine: a plain file that starts using a *new* file breaks until `chezmoi apply` creates it. Add the new file and apply in the same step (or `chezmoi apply --exclude=scripts`).
- Templates only in small fragments (theme, machine data); main configs stay plain so symlink mode keeps them live.
- No emails, hostnames, IPs or anything private in the repo; identities and server lists are machine-local.
- Scripts run with `set -euo pipefail`: write `if [[ ... ]]; then ...; fi`, not `[[ ... ]] && ...`, at the end of functions and loops (a false condition there makes the function fail).
- Check with `chezmoi diff` before `chezmoi apply`. Test risky changes in a container, not on the owner's machine.
- Keymap changes update the README cheatsheet, the tutor (`home/dot_config/nvim/tutor/dotfiles.tutor`) and the keymap's `desc` in the same commit. `scripts/check-keys.sh` fails if the tutor or README mention a key that doesn't exist. After editing the tutor's text, run `scripts/build-tutor-json.py` (exercise line numbers).
- OS settings are catalog items with `settings:`; `rig settings` records each previous value before changing it, so they stay undoable.

## Commits
- No `Co-Authored-By` or any other attribution lines. Never push: the owner reviews and pushes.
