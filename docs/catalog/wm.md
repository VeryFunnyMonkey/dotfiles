# wm: keyboard-driven desktop

One keymap on KDE and macOS. `mod` is the key second from the space bar: **Meta** (Super) on a PC keyboard, **Option** on a Mac.

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

**Option keys left free for the shell:** `b`, `f`, `c`, `p`, `d`, `m` (word movement, fzf, the dev and srv pickers).

## Vimium (keyboard browsing)

`extras/vimium-options.json` holds Vimium settings (hjkl scrolling, `f` link hints, `J`/`K` tabs, `H`/`L` back/forward, exclusions for Google Docs and Gmail). Install Vimium from your browser's extension store, then Vimium Options → Backup and Restore → choose that file.
