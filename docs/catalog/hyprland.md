# Hyprland desktop

A keyboard-first tiling desktop in gruvbox: Hyprland with one thin Waybar,
fuzzel for launching (and the clipboard, power and key menus), mako for
notifications, hyprlock and hypridle, screenshots, an on-screen popup for
volume and brightness, and a night light. Selecting it also selects Ghostty,
the Nerd Font, the clipboard tools and yazi. Arch only, for now.

## Logging in
- **A machine with a login screen** (SDDM on KDE, ...): pick
  **Hyprland (uwsm-managed)** there. Your other desktop stays as it was; the
  GTK look and the bar only apply inside Hyprland.
- **A machine without one** (a fresh box set up from the console): rig sets
  up greetd with tuigreet, which starts Hyprland. Deselecting the item gives
  back the original login.

## Keys (mod = Super)
`mod+/` shows all of them, with what each does.

| Keys | What |
|---|---|
| `mod+h/j/k/l` | focus left/down/up/right |
| `mod+shift+h/j/k/l` | move the window |
| `mod+ctrl+h/j/k/l` | resize |
| `mod+1..9` / `mod+shift+1..9` | workspace / send the window there |
| `mod+return` | terminal (Ghostty, in tmux) |
| `mod+space` | launcher |
| `mod+v` | clipboard history |
| `mod+e` / `mod+shift+e` | files: yazi / Thunar |
| `mod+q` | close |
| `mod+shift+f` / `mod+shift+space` | fullscreen / float |
| `mod+a` / `mod+w` / `mod+b` | audio / Wi-Fi / Bluetooth (TUIs, floating) |
| `mod+n` | night light on/off |
| `mod+escape` / `mod+shift+escape` | lock / power menu |
| `Print` / `shift+Print` / `ctrl+Print` | screenshot: area to clipboard / area, then annotate / whole screen |
| media keys | volume, brightness, play/pause, with a popup |
| `mod` + drag | move (left button) or resize (right button) a window |

The bar: click audio, network or Bluetooth for its TUI; the moon toggles the
night light.

## This machine
Monitors, keyboard layout and anything else machine-specific go in
`~/.config/hypr/local.lua`. It isn't in the repo and is loaded last, so it can
override any setting. For example:

```lua
hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
hl.config({ input = { kb_layout = "gb" } })
```

## Idle
Dim at 5 minutes, lock at 10, screen off at 11; the screen locks before
sleep. There's no automatic suspend; add a listener to `hypridle.conf` in a
local copy if you want one.

## Under the hood
- Configs: `~/.config/hypr` (`hyprland.lua`, Lua since Hyprland 0.55; lock and
  idle), `waybar`, `fuzzel`, `mako`, `swayosd`, `satty`, and `uwsm/env-hyprland`
  (the look of GTK and Qt apps, in Hyprland sessions only). Colours come from
  `theme.yaml`.
- `desk` runs the actions behind the keys (`desk help`).
- `rig doctor` checks the config with `Hyprland --verify-config`.
- NetworkManager and Bluetooth are switched on if nothing else manages them.
