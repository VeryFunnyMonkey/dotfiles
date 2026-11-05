# wm: keyboard-driven desktop

One keymap on KDE, macOS and Windows. `mod` is **Meta** (Super) on KDE, **Option** on a Mac, and **Alt** on Windows (Windows keeps the Win-key shortcuts for itself: Win+L locks, Win+1..9 open taskbar apps).

| Keys | Does |
|---|---|
| `mod+h/j/k/l` | focus the window left / below / above / right |
| `mod+shift+h` / `mod+shift+l` | window to the left / right half (macOS: move it in the tiling) |
| `mod+shift+j` / `mod+shift+k` | bottom half / maximise (macOS: move down / up) |
| `mod+1..9` | go to desktop (workspace) 1-9 |
| `mod+shift+1..9` | send the window there |
| `mod+space` | launcher: KRunner (macOS: Spotlight stays on Cmd+Space, see below) |
| `mod+enter` | Ghostty |
| `mod+v` | clipboard history (Klipper / Maccy) |
| `mod+q` | close the window |
| `mod+shift+f` | fullscreen |

**KDE** uses its own window manager: windows snap rather than auto-tile (Plasma's `Meta+T` zones work too). The shortcuts are written into KDE's settings; three defaults move out of the way:

- **Lock screen**: `Meta+L` → `Meta+Escape`
- **`Meta+1..9`** stop opening taskbar apps
- **`Meta+Q`** stops opening the activity switcher

Shortcuts take effect after logging out and back in. Deselecting the item puts every previous shortcut back exactly.

**macOS** gets **AeroSpace** (tiling, workspaces 1-9, `alt-shift-space` floats a window, `alt-shift-r` reloads) and **Maccy** for clipboard history on Option+V. Dialogs and small utility windows float. AeroSpace starts at login; give it Accessibility access when macOS asks. Spotlight can't be moved to Option+Space automatically: System Settings → Keyboard → Keyboard Shortcuts → Spotlight, if you want it there. *Not yet verified on a real Mac.*

**Windows** gets **GlazeWM** (tiling, workspaces 1-9), with the same keys on Alt. Its config is rig's (`%USERPROFILE%\.glzr\glazewm\config.yaml`, gruvbox borders, small gaps); it starts at login. GlazeWM installs for all users, so Windows asks for admin once.

| Keys (Windows) | Does |
|---|---|
| `alt+h/j/k/l` | focus |
| `alt+shift+h/j/k/l` | move the window |
| `alt+ctrl+h/j/k/l` | resize |
| `alt+1..9` / `alt+shift+1..9` | workspace / send the window there |
| `alt+enter` | Windows Terminal (your WSL distro) |
| `alt+space` | launcher: Command Palette (the PowerToys item) |
| `alt+q` | close |
| `alt+shift+f` / `alt+shift+space` | fullscreen / float |
| `alt+shift+r` / `alt+shift+p` / `alt+shift+e` | reload the config / pause GlazeWM / quit it |

Clipboard history is Windows' own, `Win+V`. `alt+tab` stays Windows' window switcher. Deselecting the item stops GlazeWM, removes its config and its login entry, and uninstalls it if rig installed it.

**Option (Alt on Windows) keys left free for the shell:** `b`, `f`, `c`, `p`, `d`, `m` (word movement, fzf, the dev and srv pickers).

## Vimium (keyboard browsing)

`extras/vimium-options.json` holds Vimium settings (hjkl scrolling, `f` link hints, `J`/`K` tabs, `H`/`L` back/forward, exclusions for Google Docs and Gmail). Install Vimium from your browser's extension store, then Vimium Options → Backup and Restore → choose that file.
