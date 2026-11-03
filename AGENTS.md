# Agent instructions for this repo

Personal dotfiles for **client machines** (Arch, macOS, Debian/Ubuntu incl. WSL, Fedora). Servers are managed by a separate Ansible repo; don't add server concerns here.

## Layout
- `home/` is the chezmoi source (`.chezmoiroot`); chezmoi runs in **symlink mode**, so plain files in `~` are symlinks into the repo. Templates (`*.tmpl`) and executables are copies: after editing them, `chezmoi apply`.
- `home/.chezmoi.toml.tmpl`: the machine profile (preset, work, session, WSL, modules).
- `home/.chezmoidata/`: `packages.yaml` (the declared packages), `theme.yaml` (gruvbox), `modules/*.yaml` (module manifests: packages, needs, nvim servers/formatters/parsers), `runtimes.yaml`, `agents.yaml`. `home/.chezmoitemplates/enabled` works out a machine's modules, runtimes and agents.
- `home/.chezmoiscripts/`: setup steps (bootstrap, backup ledger, packages, shell, ssh agent, nvim).
- `home/dot_local/bin/executable_rig`: the `rig` command; its libraries in `home/dot_local/share/rig/`: `git.sh` (git accounts), `modules.sh` (modules, runtimes, homelab), `agents.sh` (coding agents).
- `docs/modules/`: one guide per module (`rig module info <name>`).
- `home/dot_local/bin/executable_dev`: `dev` (tmux workspaces); templates in `home/dot_config/dev/templates/`.
- `home/dot_config/`: zsh, tmux, nvim, git, lazygit, rig's rendered data.

## Rules
- **Every package earns its place.** Prefer what's already chosen; don't add tools that duplicate one.
- **Everything rig changes must be undoable.** New system changes get a ledger entry in `~/.local/state/rig/system.log` (kind, key, previous value) and a matching revert in `system_revert_all` in `rig`. New files chezmoi takes over are backed up by `run_before_05-backup.sh`.
- Symlink mode makes edits live on the owner's machine: a plain file that starts using a *new* file breaks until `chezmoi apply` creates it. Add the new file and apply in the same step (or `chezmoi apply --exclude=scripts`).
- Templates only in small fragments (theme, machine data); main configs stay plain so symlink mode keeps them live.
- No emails, hostnames, IPs or anything private in the repo; identities and server lists are machine-local.
- Scripts run with `set -euo pipefail`: write `if [[ ... ]]; then ...; fi`, not `[[ ... ]] && ...`, at the end of functions and loops (a false condition there makes the function fail).
- Check with `chezmoi diff` before `chezmoi apply`. Test risky changes in a container, not on the owner's machine.
- Keymap changes update the README cheatsheet (and later the tutor and mini.clue descriptions) in the same commit.

## Commits
- No `Co-Authored-By` or any other attribution lines. Never push: the owner reviews and pushes.
