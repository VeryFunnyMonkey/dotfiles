# dotfiles

My setup for client machines (Arch, macOS, Debian/Ubuntu including WSL, Fedora): zsh, tmux, Neovim, git, plus `rig`, a small command that installs, updates, checks and, if needed, cleanly uninstalls all of it. Servers are managed separately, by Ansible.

Managed with [chezmoi](https://chezmoi.io) in **symlink mode**: most files in `~` are symlinks into this repo, so edits take effect immediately. The source lives in `home/` (`.chezmoiroot`).

> **Status:** Phase 1 (core). Git accounts, `dev` workspaces, modules, Ghostty, the tutor and CI come in later phases.

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

Then it installs packages, sets zsh as your login shell, enables the SSH agent and sets up Neovim (plugins, parsers, language tools). Anything it's about to replace (an old `~/.zshrc`, `~/.gitconfig` etc.) is backed up first.

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

## Packages

`home/.chezmoidata/packages.yaml` declares everything. Where packages come from:

- **Arch:** pacman (yay/paru when present)
- **macOS:** Homebrew
- **Debian/Ubuntu, Fedora:** the distro for the base system only; **Homebrew on Linux** for developer tools, which the distros ship too old or not at all

`rig install` / `rig remove` edit the file for you; commit it afterwards.

## What's in it

- **zsh** (`~/.config/zsh`, via `ZDOTDIR`): emacs keys, shared history in `~/.local/state/zsh`, fzf (Ctrl-R / Ctrl-T / Alt-C), zoxide (`z`), autosuggestions, syntax highlighting, a git-aware prompt. Machine-local additions: `~/.config/zsh/local.zsh`.
- **tmux** (`C-Space` prefix): `\` / `-` split, `C-h/j/k/l` moves across tmux panes *and* nvim splits, `prefix g` lazygit, `prefix r` reload, `v`/`y` copy (OSC52, works over SSH).
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
