# dotfiles

My setup for client machines (Arch, macOS, Debian/Ubuntu including WSL, Fedora): zsh, tmux, Neovim, git, plus `rig`, a small command that installs, updates, checks and, if needed, cleanly uninstalls all of it. Servers are managed separately, by Ansible.

Managed with [chezmoi](https://chezmoi.io) in **symlink mode**: most files in `~` are symlinks into this repo, so edits take effect immediately. The source lives in `home/` (`.chezmoiroot`).

> **Status:** the installer, core, git accounts, `dev` workspaces, languages and agents are done. Ghostty's config, OS settings, the tutor, the keyboard-desktop item and CI come next.

## Set up a new machine

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/VeryFunnyMonkey/dotfiles/main/install.sh)"
```

It installs chezmoi, prepares the package manager, clones this repo and starts **the installer**, `rig setup`:

```
 rig setup · arch · kde · display: wayland
   Profile              desktop
   Machine              arch · kde · display: wayland
   CLI tools            zoxide, eza, bat, delta, lazygit
   Terminal & desktop   Ghostty, JetBrainsMono Nerd Font, Clipboard tools
   TUI apps             none
   Languages            Python, Web
   Homelab              Tailscale
   Git hosting          GitHub (gh)
   Coding agents        Claude Code
   Git                  personal (default: personal)
   Save as profile…
   Review & install
```

Start from a **profile**, tick software per category, check the review (what gets added and removed), install. Only items that make sense on this machine are shown (no Ghostty on WSL, no clipboard tools on macOS...), and a profile listing something that doesn't apply here just skips it with the reason.

**Profiles** are saved selections, in `home/.chezmoidata/profiles/`: `desktop`, `tui`, `headless`, `minimal`, plus any you save (**Save as profile…**, or `rig profile save <name>`); commit them to use them on other machines. None of the built-ins turn on languages or agents.

Run `rig setup` again any time to change things. Without menus: `rig setup --profile desktop --select python,web --yes`.

Always installed (core): zsh, tmux, Neovim, git, fzf, ripgrep, fd, gum and build tools. Then setup sets zsh as your login shell, enables the SSH agent, sets up Neovim and offers to set up your git accounts. Anything it's about to replace (an old `~/.zshrc`, `~/.gitconfig` etc.) is backed up first.

## rig

| Command | What it does |
|---|---|
| `rig doctor` | check this machine: dotfiles applied, packages, shell, SSH agent, Neovim |
| `rig update` | update everything: dotfiles, system packages, brew, flatpak, Neovim plugins and tools |
| `rig setup` | the installer (menus; `--profile`, `--select`, `--deselect`, `--yes` without them) |
| `rig add <item\|pkg>` | select a catalog item, or add an extra package for this machine |
| `rig remove <item\|pkg>` | deselect it; offers to uninstall what rig installed for it |
| `rig profile list\|show\|use\|save` | saved selections |
| `rig info <item>` | what an item brings |
| `rig search <query>` | search the package managers |
| `rig drift [--all]` | installed-but-undeclared, and declared-but-missing |
| `rig sync` | install whatever is declared but missing |
| `rig git add\|list\|which\|remove\|clone\|doctor` | git accounts (below) |
| `rig agents list\|default <name>` | coding agents, and which one `dev` starts |
| `rig edit [file]` | edit the dotfiles, then apply |
| `rig diff` / `rig apply` | `chezmoi diff` / `chezmoi apply` |
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
rig git default personal   # or none
rig git remove clienta
```

- **Hosts:** GitHub is automatic: `gh` logs you in through the browser and uploads the key for login and signing. GitLab, Azure DevOps, Bitbucket and other servers: the key is copied to your clipboard and the settings page opens. "No hosting" gives a local identity only.
- **Which account a repo uses:** repos inside an account's folder (`~/Projects` for the first, `~/Projects/<name>` for others), or cloned through its alias (`git@github.com-<name>:...`). Everything else uses the **default account**, picked in `rig setup` (Git) or with `rig git default <account|none>`. With **none**, git refuses to commit until a repo matches an account, so nothing goes out under the wrong one.
- **GitHub on this machine:** adding a GitHub account installs `gh` if needed; removing the last one offers to remove it.

## The catalog

| Category | Items |
|---|---|
| CLI tools | zoxide, eza, bat, delta, lazygit, jq, tealdeer |
| Terminal & desktop | Ghostty, JetBrainsMono Nerd Font, clipboard tools |
| TUI apps | yazi, btop, lazydocker |
| Languages | python (pyright, ruff, uv), web (ts_ls, prettierd), ops (Ansible, YAML schemas, OpenTofu, Docker, shell), go, rust |
| Homelab | Tailscale |
| Git hosting | GitHub (gh) |
| Coding agents | Claude Code, Copilot CLI, Codex CLI, Gemini CLI, OpenCode |

Neovim picks up the language servers, formatters and parsers of the selected languages. Items that need Node, Go or Rust pull in that **runtime** (fnm + Node LTS, Go, rustup), and deselecting the last item that needs it offers to delete it. Item guides: [docs/catalog](docs/catalog). The catalog itself: `home/.chezmoidata/catalog/`.

## Coding agents

Tick them in `rig setup` (Coding agents), or `rig add codex`. When several are selected, setup asks which one `dev` starts (`rig agents default <name>` changes it). rig installs them through each vendor's official route and updates them with `rig update`; deselecting one uninstalls it if rig installed it. Logins, API keys and agent settings are yours.

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

A workspace file (`.dev` in the repo, or kept on this machine with `dev init --local`, for repos you'd rather not add it to):

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

`home/.chezmoidata/packages.yaml` declares the core and the per-OS names. Where packages come from:

- **Arch:** pacman (yay/paru when present)
- **macOS:** Homebrew
- **Debian/Ubuntu, Fedora:** the distro for the base system only; **Homebrew on Linux** for developer tools, which the distros ship too old or not at all

`packages.yaml` holds the core list and how names map per OS; everything else comes from the catalog. A package just for this machine: `rig add <pkg>` (kept in this machine's config).

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
