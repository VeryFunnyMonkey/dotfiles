# dotfiles

My setup for client machines (Arch, macOS, Debian/Ubuntu including WSL, Fedora): zsh, tmux, Neovim, git, plus `rig`, a small command that installs, updates, checks and, if needed, cleanly uninstalls all of it. Servers are managed separately, by Ansible.

Managed with [chezmoi](https://chezmoi.io) in **symlink mode**: most files in `~` are symlinks into this repo, so edits take effect immediately. The source lives in `home/` (`.chezmoiroot`).

> **Status:** everything planned is built: the installer, core, git accounts, `dev`, `srv`, languages, agents, Ghostty, OS settings, the keyboard-driven desktop, the tutor, tests and CI. macOS and WSL paths are tested in CI or by rendering only, not yet on a real Mac or WSL machine.

## Set up a new machine

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/VeryFunnyMonkey/dotfiles/main/install.sh)"
```

It installs chezmoi, prepares the package manager, clones this repo and starts **the installer**, `rig setup`:

```
 rig setup · arch · kde · display: wayland
   Profile              desktop
   CLI tools            zoxide · eza · bat · delta · lazygit
   Terminal & desktop   Ghostty · JetBrainsMono Nerd Font · Clipboard tools
   TUI apps             none
   Languages            Python · Web
   Homelab              Tailscale
   Coding agents        Claude Code
   Git                  personal (default: personal) · CLIs: GitHub CLI (gh)
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

- **Hosts:** GitHub, GitLab (gitlab.com or your own) and Gitea/Forgejo/Codeberg are automatic: rig logs in with the host's CLI (`gh` and `glab` through the browser, `tea` with an access token you paste) and uploads the key for login and signing. Bitbucket, Azure DevOps (RSA key, no signing) and other servers: the key is copied to your clipboard and the settings page opens. If a CLI step fails, rig falls back to that. "No hosting" gives a local identity only.
- **Which account a repo uses:** repos inside an account's folder (`~/Projects` for the first, `~/Projects/<name>` for others), or cloned through its alias (`git@github.com-<name>:...`). Everything else uses the **default account**, picked in `rig setup` (Git) or with `rig git default <account|none>`. With **none**, git refuses to commit until a repo matches an account, so nothing goes out under the wrong one.
- **Host CLIs:** adding an account selects its host's CLI (`gh`, `glab`, `tea`) and installs it; removing the last account on that host offers to deselect it. They're toggled in `rig setup` under Git too.

## The catalog

| Category | Items |
|---|---|
| CLI tools | zoxide, eza, bat, delta, lazygit, jq, tealdeer |
| Terminal & desktop | Ghostty, JetBrainsMono Nerd Font, clipboard tools, keyboard-driven desktop (KDE shortcuts / AeroSpace), **Hyprland desktop** (Arch: a complete keyboard-first gruvbox desktop; `rig info hyprland` has its keys), **Helium browser** (Arch via the AUR, macOS) |
| TUI apps | yazi, btop |
| Containers | Podman (rootless, `docker` and `docker compose` work, `DOCKER_HOST` set; podman machine on macOS), lazydocker |
| Languages | python (pyright, ruff, uv), web (ts_ls, prettierd), ops (Ansible, YAML schemas, OpenTofu, Docker, shell), go, rust |
| Homelab | Tailscale |
| Git | host CLIs: gh (GitHub), glab (GitLab), tea (Gitea, Forgejo, Codeberg); in the Git section with your accounts |
| Coding agents | Claude Code, Copilot CLI, Codex CLI, Gemini CLI, OpenCode |
| OS settings | Ghostty as default terminal, Helium as default browser, open text files in Neovim (Linux); Dock left/hidden/instant, Finder tweaks, fast key repeat (macOS) |

**OS settings** are applied with the previous value of each one recorded first; deselecting the item (or `rig uninstall`) puts the old values back, including removing a setting that wasn't set before. `rig settings list` shows what's applied.

Neovim picks up the language servers, formatters and parsers of the selected languages. Items that need Node, Go or Rust pull in that **runtime** (fnm + Node LTS, Go, rustup), and deselecting the last item that needs it offers to delete it. Item guides: [docs/catalog](docs/catalog). The catalog itself: `home/.chezmoidata/catalog/`.

## Coding agents

Tick them in `rig setup` (Coding agents), or `rig add codex`. When several are selected, setup asks which one `dev` starts (`rig agents default <name>` changes it). rig installs them through each vendor's official route and updates them with `rig update`; deselecting one uninstalls it if rig installed it. Logins, API keys and agent settings are yours.

## dev: workspaces

`dev` builds tmux sessions for projects. Run it in a repo: your agent on the left, nvim on the right. Run it anywhere else (or press `Alt-p`, or `prefix f` in tmux) for the project picker: your git repos (the ones you've been in, most used first, plus everything under `~/Projects`; repos nested inside another repo are left out), colour-coded: open sessions green (`● open`) at the top, then projects with a workspace file blue (`★ workspace`), then plain projects; folders, when searching, are dimmed. The preview says what Enter will do; it sits beside the list when there's room, below it in a narrow window, and is hidden in a small one (`ctrl-/` toggles it). It lists only those until you type: then every other folder under your home joins the search (dependency and cache folders left out), so `vintage` finds `~/Pictures/Vintagestory`; clearing the search goes back to the projects. A folder opens as itself. You can also type a full path (`/tmp`, `~/Downloads/thing`) and press Enter.

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

## srv: your servers as folders

`srv` mounts a server's home folder at `~/Servers/<host>`, over SSH: open its files in nvim, point an agent at it, unmount when done.

```sh
srv                      # picker (also prefix m in tmux, Alt-m): enter mounts/unmounts
srv mount ops-server     # mount the home folder (srv mount ops-server /opt/stacks for another path)
srv dev ops-server       # mount it and open a dev workspace there: your agent + nvim on the server's files
srv ssh ops-server       # a shell there (srv ssh ops-server -- <command> for one command)
srv umount ops-server    # or --all; --force for a stuck mount
srv add                  # add a host: name, user@host[:port], folder
srv import hosts.txt     # add hosts from a file: a simple list or an Ansible inventory
```

While anything is mounted, the prompt shows ` ⇅ ops-server` (or ` ⇅ 3`) and so does the tmux status bar.

- **How:** rclone over SSH, using your normal ssh (keys, the agent, `~/.ssh/config`, known_hosts). macOS mounts with `rclone nfsmount` (its own NFS client: no macFUSE, nothing to change in System Settings or Recovery); Linux with `rclone mount` (FUSE, built into the kernel, no root). Mounts last until you unmount, log out or reboot.
- **Importing hosts:** the first setup on a machine asks once for a hosts file to copy into srv (on any machine, Tailscale or not): a simple list (`name  user@host[:port]  [folder]` per line, see `extras/srv-hosts.example`) or an Ansible inventory (users and addresses come from its `group_vars`/`host_vars`). `srv import <file>` does it any time and remembers the file; it only replaces hosts it imported. The list lives on the machine only (`~/.config/srv/hosts`), never in this repo.
- **With agents:** `srv dev <host>` runs your agent with the server's home as its folder, so it edits the server's files directly. It works as the login user, so root-owned files (`/etc`, system config) can't be changed through the mount; commands still run over ssh (`srv ssh <host> -- <cmd>`, which the agent can use too). `git` and big searches over a mount are slow: run those on the server.
- **macOS:** not yet verified on a real Mac.

## Packages

`home/.chezmoidata/packages.yaml` declares the core and the per-OS names. Where packages come from:

- **Arch:** pacman, and yay for the AUR (the bootstrap installs it unless yay or paru is there; `rig update` runs `yay -Syu`)
- **macOS:** Homebrew
- **Debian/Ubuntu, Fedora:** the distro for the base system only; **Homebrew on Linux** for developer tools, which the distros ship too old or not at all

`packages.yaml` holds the core list and how names map per OS; everything else comes from the catalog. A package just for this machine: `rig add <pkg>` (kept in this machine's config).

## What's in it

- **zsh** (`~/.config/zsh`, via `ZDOTDIR`): emacs keys, shared history in `~/.local/state/zsh`, fzf (Ctrl-R / Ctrl-T / Alt-C), zoxide (`z`), autosuggestions, syntax highlighting, a git-aware prompt. Machine-local additions: `~/.config/zsh/local.zsh`.
- **tmux** (`C-Space` prefix; **`prefix Space` shows a menu of the keys**, and the status bar says so while the prefix is held): `\` / `-` split, `C-h/j/k/l` moves across tmux panes *and* nvim splits, `prefix f` workspace picker, `prefix m` server picker, `prefix g` lazygit, `prefix r` reload, `v`/`y` copy (OSC52, works over SSH).
- **Ghostty** (when selected): every window opens in tmux, as its own session in the window's folder that goes away when the window closes, so tabs and splits are always tmux's (`prefix c`, `\`, `-`). Ghostty's own tab and split keys are off on Linux and macOS. `dev` sessions are separate and persist; the picker doesn't list the per-window ones. `ghostty -e <cmd>` and SSH logins skip tmux; `RIG_NO_TMUX=1 ghostty` gives a plain shell. Also: gruvbox, the Nerd Font, OSC52 clipboard; over SSH it brings its terminfo along, so servers understand it. Option is Alt on macOS.
- **Neovim** 0.12 with `vim.pack`: gruvbox, mini.nvim, fzf-lua, treesitter, blink.cmp, Mason + LSP, conform (format on save), grug-far. Press `<leader>` (Space) and wait for a menu; `<leader>fk` searches every key by description.
- **git**: delta for diffs, sensible defaults. No identity in the repo: it's machine-local (`~/.config/git/identities.gitconfig`).
- **Theme:** gruvbox dark everywhere; colours in `home/.chezmoidata/theme.yaml`.

## Neovim keys

New to this setup (or back after a while)? **`:Tutor dotfiles`** is a short hands-on course on these keys, the editing extras, git review and the terminal around Neovim. `<Space>` shows what you can press next; `<Space>fk` searches every key.


| Keys | Group |
|---|---|
| `<leader>ff` `fg` `fw` `fb` `fr` `fh` `fk` `f/` `f.` | **find**: files, grep, word, buffers, recent, help, keymaps, lines, resume |
| `<leader>cd` `cr` `ci` `ct` `cs` `cS` `ca` `cn` `cf` `cx` `cX` `cl` | **code**: definition, references, implementations, type, symbols, action, rename, format, diagnostics |
| `<leader>gg` `gs` `go`, `[h` `]h`, `gh` `gH` | **git**: lazygit, changed files, diff overlay, next/prev hunk, apply/reset hunk |
| `<leader>sr` `sw` | **search/replace** across the project |
| `<leader>uw` `ud` `un` `uf` | **UI**: wrap, inline diagnostics, relative numbers, format on save |
| `<leader>e` `E`, `<leader><space>` | explorer (file / cwd), recent & open files |

Neovim's built-ins work too: `grn` rename, `gra` action, `grr` references, `gri` implementation, `K` hover, `[d` `]d` diagnostics, `gc` comment. Completion: `C-n`/`C-p` move, `C-y` or Enter accept, `C-e` dismiss.

## Tests and upkeep

- **Tests** run in throwaway containers (Docker or Podman, whichever is installed): `tests/run.sh <test> [image]` with `roundtrip`, `installer`, `git-dev`, `languages`, `srv`, `settings`, `wm` (image `archlinux:latest` by default, or `ubuntu:24.04`). GitHub Actions (`.github/workflows/test.yml`) runs lint and these on every push and monthly: the container tests (Arch, Ubuntu), a **WSL** job (Ubuntu 24.04 under WSL2 on a Windows runner: `wsl` and `roundtrip`, through `tests/here.sh`), a **macOS** job (install, settings, srv over nfsmount, uninstall), and the heavy `languages` test monthly or by hand.
- **Pre-commit checks:** enable once per clone with `git config core.hooksPath .githooks` (shellcheck, zsh syntax, keys mentioned in docs exist, tutor exercises, the stack record, nothing private).
- **Stack review:** `docs/stack.yaml` records every component, why it was chosen and when to look again. Every few months (`rig doctor` says when) ask your agent to "do the stack review" (procedure in AGENTS.md): it researches current upstream changes, reports, and changes only what you approve.

## Notes

- **WSL:** install JetBrainsMono Nerd Font on Windows and pick it in Windows Terminal. Not yet verified on a real WSL machine.
- **macOS:** the path exists but isn't verified on a real Mac yet.
