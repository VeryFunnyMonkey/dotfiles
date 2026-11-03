# dotfiles

My setup for client machines (Arch, macOS, Debian/Ubuntu including WSL, Fedora): zsh, tmux, Neovim, git, plus `rig`, a small command that installs, updates, checks and, if needed, cleanly uninstalls all of it. Servers are managed separately, by Ansible.

Managed with [chezmoi](https://chezmoi.io) in **symlink mode**: most files in `~` are symlinks into this repo, so edits take effect immediately. The source lives in `home/` (`.chezmoiroot`).

> **Status:** Phases 1–3 (core, git accounts, `dev` workspaces, modules, agents). Ghostty, OS settings, the tutor, the `wm` module and CI come next.

## Set up a new machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply VeryFunnyMonkey
```

The first question is a **preset**:

| Preset | For |
|---|---|
| `personal-desktop` | a desktop/laptop with a GUI (this Arch/KDE PC) |
| `work` | a work laptop (on WSL this is detected automatically) |
| `tui` | a keyboard-driven Hyprland box |
| `headless` | no display: a VM or a box you SSH into |
| `custom` | asks each question |

Then it installs packages, sets zsh as your login shell, enables the SSH agent, sets up Neovim (plugins, parsers, language tools) and offers to set up your git accounts. It also asks whether you use GitHub on this machine (personal presets say yes), which decides whether `gh` is installed. Anything it's about to replace (an old `~/.zshrc`, `~/.gitconfig` etc.) is backed up first.

Already have the repo checked out? `chezmoi init --source ~/Projects/dotfiles --apply`.

## rig

| Command | What it does |
|---|---|
| `rig doctor` | check this machine: dotfiles applied, packages, shell, SSH agent, Neovim |
| `rig update` | update everything: dotfiles, system packages, brew, flatpak, Neovim plugins and tools |
| `rig install <pkg> [--group g]` | install a package **and** declare it in `packages.yaml` |
| `rig remove <pkg>` | undeclare it, and uninstall it if rig installed it |
| `rig search <query>` | search the package managers |
| `rig drift [--all]` | installed-but-undeclared, and declared-but-missing |
| `rig sync` | install whatever is declared but missing |
| `rig git add\|list\|which\|remove\|clone\|doctor` | git accounts (below) |
| `rig module list\|info\|enable\|disable [--purge]` | opt-in modules (below) |
| `rig agents list\|add\|remove\|default` | coding agents (below) |
| `rig edit [file]` | edit the dotfiles, then apply |
| `rig diff` / `rig apply` | `chezmoi diff` / `chezmoi apply` |
| `rig profile` | re-answer the machine questions |
| `rig reset nvim\|mason\|zsh\|chezmoi\|all` | rebuild a part that misbehaves (your files and history stay) |
| `rig uninstall [flags] [--run]` | put the machine back as it was; a dry run unless `--run` |

### Undo everything

rig records what it changes as it goes (`~/.local/state/rig`): files it replaced, packages it installed (and which were already there), and system changes like your login shell. `rig uninstall` replays that backwards:

```sh
rig uninstall                 # see what it would do
rig uninstall --run           # remove managed files, restore originals, revert system changes
rig uninstall --everything --run   # also packages rig added, runtimes, identities, agents
rig uninstall --restore ~/rig-uninstall-<date>.tar.gz   # undo an uninstall
```

Packages that were installed before rig are never removed. SSH keys are never deleted.

## Git accounts

Each account (personal, a client, ...) has its own name, email and SSH key, also used to **sign commits**. Nothing personal is in the repo: accounts live in `~/.config/git/identities/` and `~/.ssh/`.

```sh
rig git add            # walkthrough: name, email, where it's hosted, folder, key
rig git list           # accounts and their folders
rig git which          # which account this repo uses
rig git clone clienta git@github.com:org/repo   # clone through that account, into its folder
rig git doctor         # test each account's connection
rig git remove clienta
```

- **Hosts:** GitHub is automatic: `gh` logs you in through the browser and uploads the key for login and signing. GitLab, Azure DevOps, Bitbucket and other servers: the key is copied to your clipboard and the settings page opens. "No hosting" gives a local identity only.
- **Which account a repo uses:** repos inside an account's folder (`~/Projects` for personal, `~/Work/<name>` for others), or cloned through its alias (`git@github.com-<name>:...`). On personal machines the default account covers everything else; on work machines there is no default, so git refuses to commit until a repo matches an account. Wrong-client commits can't happen.
- **GitHub on this machine:** adding a GitHub account installs `gh` if needed; removing the last one offers to remove it.

## Modules

Opt-in pieces a machine may or may not want. The preset picks them at setup; change them any time:

| Module | What it brings | Default |
|---|---|---|
| `lang-python` | pyright, ruff (lint/format/imports), uv | personal, work, tui |
| `lang-web` | ts_ls, prettierd (TS/JS/JSON/CSS/HTML/Markdown) | personal, work, tui |
| `lang-ops` | Ansible, YAML with Compose/Actions schemas, OpenTofu, Docker, shell (shellcheck, shfmt) | personal, work, tui |
| `lang-go` | gopls, goimports, gofumpt; Go toolchain | off |
| `lang-rust` | rust-analyzer (clippy), rustfmt; rustup | off |
| `homelab` | Tailscale (joins the tailnet) | personal, tui, headless |
| `wm` | keyboard-driven desktop (coming) | off |

```sh
rig module list
rig module enable lang-go
rig module disable lang-rust --purge   # --purge also deletes toolchains rig installed
rig module info lang-ops
```

Neovim picks up the language servers, formatters and parsers of whatever is enabled. Modules that need Node, Go or Rust pull in that **runtime** (fnm + Node LTS, Go, rustup); it's removed with `--purge` once nothing needs it. Guides: [docs/modules](docs/modules).

## Coding agents

Setup asks which to install (none, one or several): **Claude Code**, **GitHub Copilot CLI**, **OpenAI Codex CLI**, **Gemini CLI**, **OpenCode**. The first one (or the one you pick) is what `dev` starts.

```sh
rig agents list
rig agents add codex
rig agents remove gemini
rig agents default claude
```

rig installs them through each vendor's official route and updates them with `rig update`. Logins, API keys and agent settings are yours: sign in on first run (e.g. Copilot with a work account).

## dev: workspaces

`dev` builds tmux sessions for projects. Run it in a repo: your agent on the left, nvim on the right. Run it anywhere else (or press `Alt-p`, or `prefix f` in tmux) for a picker of running sessions, workspaces and frequent folders.

```sh
dev agent set claude    # once per machine: what the agent pane runs (dev agent unset: plain shell)
dev                     # open this project's workspace
dev init web            # create a workspace (.dev) from a template: default, web, py
dev edit                # change it
dev --agent codex       # a different agent this time; --no-agent for a plain shell
dev wt feature-x        # a worktree + window for parallel work; dev wt ls, dev wt rm feature-x
```

A workspace file (`.dev`, or kept on the machine with `dev init --local`, the default on work machines so client repos never get one):

```ini
[code] main-vertical
agent
nvim

[run] even-horizontal
npm run dev
shell
```

Each `[name]` is a window, with an optional tmux layout after it. Each line is a pane's command: `agent` is your agent, `shell` a plain shell, anything else is typed into the pane (you're back at a prompt when it stops).

## Packages

`home/.chezmoidata/packages.yaml` declares everything. Where packages come from:

- **Arch:** pacman (yay/paru when present)
- **macOS:** Homebrew
- **Debian/Ubuntu, Fedora:** the distro for the base system only; **Homebrew on Linux** for developer tools, which the distros ship too old or not at all

`rig install` / `rig remove` edit the file for you; commit it afterwards.

## What's in it

- **zsh** (`~/.config/zsh`, via `ZDOTDIR`): emacs keys, shared history in `~/.local/state/zsh`, fzf (Ctrl-R / Ctrl-T / Alt-C), zoxide (`z`), autosuggestions, syntax highlighting, a git-aware prompt. Machine-local additions: `~/.config/zsh/local.zsh`.
- **tmux** (`C-Space` prefix): `\` / `-` split, `C-h/j/k/l` moves across tmux panes *and* nvim splits, `prefix f` workspace picker, `prefix g` lazygit, `prefix r` reload, `v`/`y` copy (OSC52, works over SSH).
- **Neovim** 0.12 with `vim.pack`: gruvbox, mini.nvim, fzf-lua, treesitter, blink.cmp, Mason + LSP, conform (format on save), grug-far. Press `<leader>` (Space) and wait for a menu; `<leader>fk` searches every key by description.
- **git**: delta for diffs, sensible defaults. No identity in the repo: it's machine-local (`~/.config/git/identities.gitconfig`).
- **Theme:** gruvbox dark everywhere; colours in `home/.chezmoidata/theme.yaml`.

## Neovim keys

| Keys | Group |
|---|---|
| `<leader>ff` `fg` `fw` `fb` `fr` `fh` `fk` `f/` `f.` | **find**: files, grep, word, buffers, recent, help, keymaps, lines, resume |
| `<leader>cd` `cr` `ci` `ct` `cs` `cS` `ca` `cn` `cf` `cx` `cX` `cl` | **code**: definition, references, implementations, type, symbols, action, rename, format, diagnostics |
| `<leader>gg` `gs` `go`, `[h` `]h`, `gh` `gH` | **git**: lazygit, changed files, diff overlay, next/prev hunk, apply/reset hunk |
| `<leader>sr` `sw` | **search/replace** across the project |
| `<leader>uw` `ud` `un` `uf` | **UI**: wrap, inline diagnostics, relative numbers, format on save |
| `<leader>e` `E`, `<leader><space>` | explorer (file / cwd), recent & open files |

Neovim's built-ins work too: `grn` rename, `gra` action, `grr` references, `gri` implementation, `K` hover, `[d` `]d` diagnostics, `gc` comment. Completion: `C-n`/`C-p` move, `C-y` or Enter accept, `C-e` dismiss.

## Notes

- **WSL:** install JetBrainsMono Nerd Font on Windows and pick it in Windows Terminal. Not yet verified on a real WSL machine.
- **macOS:** the path exists but isn't verified on a real Mac yet.
