# Agent instructions for this repo

Personal dotfiles for **client machines** (Arch, macOS, Windows through WSL, Debian/Ubuntu, Fedora). Servers are managed by a separate Ansible repo; don't add server concerns here.

## Layout
- `home/` is the chezmoi source (`.chezmoiroot`); chezmoi runs in **symlink mode**, so plain files in `~` are symlinks into the repo. Templates (`*.tmpl`) and executables are copies: after editing them, `chezmoi apply`.
- `home/.chezmoi.toml.tmpl`: chezmoi's config for the machine. It asks nothing: `rig setup` writes profile/selected/extra_packages/agent_default; detection (`.chezmoitemplates/detect`) adds wsl/display/desktop (the platform "windows" is WSL).
- `home/.chezmoidata/`: all the data, no logic.
  - `catalog/*.yaml`: every selectable item, by category. Fields: packages, platforms, needs, nvim, settings, `module` (the rig module behind it), `files` (paths only it brings). The meaning of each field is in `catalog/_categories.yaml`; the OS setting kinds are in `catalog/_setting-kinds.yaml`.
  - `profiles/*.yaml` (saved selections), `packages.yaml` (core, per-manager names, virtual packages, downloads), `runtimes.yaml`, `theme.yaml`.
  - `.chezmoitemplates/enabled` works out what applies on this machine: selected, skipped, runtimes, agents, modules.
- `home/.chezmoiscripts/`: the setup steps. The bootstrap and the backup run on their own; every other step is one line, `rig sync` or `rig modules sync <module>`, plus the template values that make it re-run.
- `home/dot_local/bin/executable_rig`: the `rig` entry point. It only loads the parts in `home/dot_local/share/rig/` (found next to rig, so it runs from the repo too) and dispatches. The parts, each depending only on the layers above it:
  - `lib/`: the building blocks. `sys` (helpers), `ui` (output, prompts, gum menus, doctor checks), `machine` (paths and this machine's selection), `ledger` (the undo record and its revert dispatcher), `units` (systemd units), `windows` (the Windows side, from WSL), `catalog`, `apply` (change the selection and apply), `modules` (the module registry and contract).
  - `pkg/`: packages. `managers.sh` has one `pm_<manager>_*` set per package manager; `downloads.sh` one `dl_<name>_*` set per download; `sync.sh` holds sync, drift, search, update and cleanup.
  - `modules/`: one feature each, with helpers in `modules/<name>/`. Core: srv, shell, ssh-agent, git (with the host table in `git/hosts.sh`), agents, runtimes, nvim, settings (kinds in `settings/kinds.sh`). Item modules, active while their item is selected: containers (Podman), tailscale, desktop (Hyprland), and on Windows winterm, powertoys, glazewm (the wm item) and gcm (Git Credential Manager).
  - `commands/`: what you type. setup (the installer), items (add/remove/profile/info), doctor, update, reset, uninstall, transfer (export/import), misc. Commands loop over modules; they don't know any feature.
- **The module contract** (`lib/modules.sh`). A module `<m>` may define `<m>_sync`, `<m>_doctor`, `<m>_update`, `<m>_reset`, `<m>_uninstall` and `<m>_cmd` (for `rig <m> ...`), `<m>_export`/`<m>_exported`/`<m>_import` (its machine-local part, for `rig export`/`rig import`; never keys or tokens), plus `revert_<kind>` for each ledger kind it records. To add a feature:
  1. write `modules/<name>.sh`;
  2. give its catalog item `module: <name>` (or add it to `RIG_CORE_MODULES` if every machine needs it);
  3. declare its files in the item (`files:`).

  Nothing else changes: the setup script for item modules, doctor, update and uninstall all pick it up.
- `install.sh`: the bootstrap one-liner for a new machine; `install.ps1` the one for Windows (WSL, the distro and your user, then install.sh inside it).
- `docs/catalog/`: guides for catalog items (`rig info <item>`).
- `home/dot_local/bin/executable_dev`: `dev` (tmux workspaces): settings and `main`; its parts in `home/dot_local/share/dev/` (projects, agent, build, workspace, picker, worktrees, help). Workspace templates in `home/dot_config/dev/templates/`.
- `home/dot_local/bin/executable_srv`: `srv` (mount servers over SSH with rclone: nfsmount on macOS, FUSE mount on Linux): settings and `main`; its parts in `home/dot_local/share/srv/` (hosts, mounts, edit, status, picker, connect, import, doctor). Hosts are machine-local (`~/.config/srv/hosts`), added by hand or imported from a hosts file (simple list or Ansible inventory); mount state lives in a runtime folder so it disappears with the mounts.
- `home/dot_config/`: zsh, tmux, nvim, git, lazygit, rig's rendered data.

## Rules
- **New software is a catalog item** (category, description, platforms), not a hard-coded package. Only rig's own dependencies go in core.
- **Every package earns its place.** Prefer what's already chosen; don't add tools that duplicate one.
- **Everything rig changes must be undoable.** A system change is recorded first with `ledger_record kind key previous` (in `~/.local/state/rig/system.log`), and the module that makes it defines `revert_<kind>`, which `rig uninstall` calls. systemd units go through `unit_enable_user`/`unit_enable_system` (`lib/units.sh`), which record themselves. New files chezmoi takes over are backed up by `run_before_05-backup.sh`.
- **Logic in code, choices in data.** A new package manager, download, setting kind or git host is functions (and a data entry), never another `case` in shared code.
- Symlink mode makes edits live on the owner's machine: a plain file that starts using a *new* file breaks until `chezmoi apply` creates it. Add the new file and apply in the same step (or `chezmoi apply --exclude=scripts`).
- Templates only in small fragments (theme, machine data); main configs stay plain so symlink mode keeps them live.
- No emails, hostnames, IPs or anything private in the repo; identities and server lists are machine-local.
- **Say what rig moved or changed, and where it went.** rig may take over settings, but never silently: moving a file aside names the file, where it went and where the owner's own additions go now (`.chezmoidata/local.yaml`); replacing or changing something (a Windows file, a setting, a line in `~/.ssh/config`) says what it was and that undo puts it back. A package that would replace one already installed is left out, saying why (`conflicts:` in packages.yaml).
- **No migrations or one-off fixes in the code.** The code describes how things are now, not how to repair a machine set up by an earlier version or left wrong by a bad run (renamed values, moved files, leftovers). Fix those with a one-off command given to the owner. Handling *your* setup from before rig (backing up and carrying over files) isn't a migration; neither is coping with something that can happen on any run (an interrupted install).
- Scripts run with `set -euo pipefail`: write `if [[ ... ]]; then ...; fi`, not `[[ ... ]] && ...`, at the end of functions and loops (a false condition there makes the function fail).
- Check with `chezmoi diff` before `chezmoi apply`. Test risky changes in a container, not on the owner's machine.
- Keymap changes update the README cheatsheet, the tutor (`home/dot_config/nvim/tutor/dotfiles.tutor`) and the keymap's `desc` in the same commit. `scripts/check-keys.sh` fails if the tutor or README mention a key that doesn't exist. After editing the tutor's text, run `scripts/build-tutor-json.py` (exercise line numbers).
- OS settings are catalog items with `settings:`; `rig settings` records each previous value before changing it, so they stay undoable.

## Commits
- No `Co-Authored-By` or any other attribution lines. Never push: the owner reviews and pushes.

## Stack review
`docs/stack.yaml` records every chosen component: why it was chosen, what lost, and `revisit_if` triggers. A review checks that the choices still hold. Do one when the owner asks, or offer one (once, at the start of a session) when `last_reviewed` is more than 90 days old; `rig doctor` also says when one is due.

1. **Research, don't recall.** For each component, check current upstream sources: release notes, changelogs, deprecation notices, the project's README and status, `:help news` for the installed Neovim. Training data goes stale; that's what the review is for. Agent install methods (`dot_local/share/rig/agents.sh`) are checked every time.
2. **Look for:** breaking changes or deprecations affecting this config; a `revisit_if` trigger that has fired; projects archived, unmaintained or relicensed; notable new alternatives that fit the principles (open source, few packages, keyboard-first, works on Arch, macOS and Windows).
3. **Run the local checks:** `rig doctor`, `rig drift`, `nvim --headless "+checkhealth" +qa` (deprecation warnings), `chezmoi doctor`, the tests (`tests/run.sh <test>`; CI runs them monthly too).
4. **Report before changing anything:** write `docs/reviews/<date>.md` with *Must fix* (breaking/deprecated), *Should consider* (each with a source link), *No change*. Wait for the owner to choose.
5. **Apply only what the owner approves.** Each change updates its `stack.yaml` entry (why, alternatives, revisit_if) and, for keymaps, the tutor and README (the existing rule).
6. **Bump `last_reviewed`** even when nothing changes.

**Guard rails:** don't reopen settled decisions without a fired `revisit_if` trigger or new evidence; don't add packages that only duplicate a chosen one; prefer the smallest change that keeps things current.

## Checks
`scripts/shell-files.sh` lists every shell file; the hook and CI shellcheck exactly that list.

`scripts/check-packages.sh` asks each package manager (`pm_<manager>_exists`) whether every package rig could install on this OS still exists under its name. The `packages` workflow runs it weekly on Arch, Ubuntu, Fedora and macOS, and on pushes that change a package name. A new manager or download needs its `pm_<m>_exists` (or `dl_<d>_url`) for it.

`.githooks/pre-commit` (enable once per clone: `git config core.hooksPath .githooks`) runs shellcheck, zsh syntax, `scripts/check-keys.sh`, `scripts/build-tutor-json.py --check`, `scripts/check-stack.py` and a scan for private data, skipping a check when its tool isn't installed.
