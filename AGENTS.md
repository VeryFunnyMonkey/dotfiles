# Agent instructions for this repo

Personal dotfiles for **client machines** (Arch, macOS, Debian/Ubuntu incl. WSL, Fedora). Servers are managed by a separate Ansible repo; don't add server concerns here.

## Layout
- `home/` is the chezmoi source (`.chezmoiroot`); chezmoi runs in **symlink mode**, so plain files in `~` are symlinks into the repo. Templates (`*.tmpl`) and executables are copies: after editing them, `chezmoi apply`.
- `home/.chezmoi.toml.tmpl`: the machine profile (preset, work, session, WSL, modules).
- `home/.chezmoidata/`: `packages.yaml` (the declared packages), `theme.yaml` (gruvbox).
- `home/.chezmoiscripts/`: setup steps (bootstrap, backup ledger, packages, shell, ssh agent, nvim).
- `home/dot_local/bin/executable_rig`: the `rig` command.
- `home/dot_config/`: zsh, tmux, nvim, git, lazygit, rig's rendered data.

## Rules
- **Every package earns its place.** Prefer what's already chosen; don't add tools that duplicate one.
- **Everything rig changes must be undoable.** New system changes get a ledger entry in `~/.local/state/rig/system.log` (kind, key, previous value) and a matching revert in `system_revert_all` in `rig`. New files chezmoi takes over are backed up by `run_before_05-backup.sh`.
- Templates only in small fragments (theme, machine data); main configs stay plain so symlink mode keeps them live.
- No emails, hostnames, IPs or anything private in the repo; identities and server lists are machine-local.
- Check with `chezmoi diff` before `chezmoi apply`. Test risky changes in a container, not on the owner's machine.
- Keymap changes update the README cheatsheet (and later the tutor and mini.clue descriptions) in the same commit.

## Commits
- No `Co-Authored-By` or any other attribution lines. Never push: the owner reviews and pushes.
