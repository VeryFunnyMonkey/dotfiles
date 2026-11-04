-- Hyprland, from the dotfiles' hyprland item: a keyboard-first desktop.
-- mod = Super: the same keys as the keyboard-driven desktop item on KDE/macOS.
--   colours        theme.lua (rendered from .chezmoidata/theme.yaml)
--   this machine   local.lua (monitors, keyboard layout...): not in the repo,
--                  loaded last so it can override anything here
--   the keys       mod+/ lists them (or: rig info hyprland)
-- Apps are started with `desk run`, which uses uwsm when the session runs
-- under it, so each gets its own systemd scope.

local c = require("theme")
local function rgb(hex) return "rgb(" .. hex:gsub("^#", "") .. ")" end
local function run(cmd) return "desk run " .. cmd end

local terminal = "ghostty"
-- mod is Super; HYPR_MOD overrides it (e.g. ALT when running Hyprland nested
-- in another desktop that keeps the Super shortcuts for itself)
local mod = os.getenv("HYPR_MOD") or "SUPER"

----------------------------------------------------------------- monitors ---
-- Every monitor at its preferred mode; set yours in local.lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

---------------------------------------------------------------- autostart ---
hl.on("hyprland.start", function()
    hl.exec_cmd(run("waybar"))
    hl.exec_cmd(run("hypridle"))
    hl.exec_cmd(run("/usr/lib/hyprpolkitagent/hyprpolkitagent"))
    hl.exec_cmd(run("swayosd-server"))
    hl.exec_cmd(run("wl-paste --watch cliphist store"))
end)
-- mako starts on the first notification (D-Bus activation).

---------------------------------------------------------------------- look ---
-- "Tight": small gaps, a thin border (aqua when focused), slight rounding,
-- no blur or shadows, short animations.
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 4,
        border_size = 2,
        col = {
            active_border = rgb(c.aqua),
            inactive_border = rgb(c.bg2),
        },
        resize_on_border = true,
        layout = "dwindle",
    },
    decoration = {
        rounding = 4,
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = {
        background_color = rgb(c.bg),
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        focus_on_activate = true,
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true,
    },
    cursor = { inactive_timeout = 3 },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        repeat_delay = 250,
        repeat_rate = 40,
        touchpad = { natural_scroll = true },
    },
    xwayland = { force_zero_scaling = true },
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

hl.curve("snap", { type = "bezier", points = { { 0.2, 0.9 }, { 0.1, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 3, bezier = "snap" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "snap", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "snap", style = "popin 90%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "snap", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "snap" })

-------------------------------------------------------------------- rules ---
-- The system TUIs (audio, Wi-Fi, Bluetooth) open as a centred floating terminal.
hl.window_rule({ name = "rig-float", match = { class = "^rig\\.float$" }, float = true, size = "60% 60%", center = true })
hl.window_rule({ name = "dialogs", match = { title = "^(Open|Save|Select|Choose).*" }, float = true, center = true })
hl.window_rule({ name = "pip", match = { title = "^Picture.in.[Pp]icture$" }, float = true, pin = true })
hl.window_rule({ name = "no-maximize-requests", match = { class = ".*" }, suppress_event = "maximize" })
hl.layer_rule({ name = "quiet-menus", match = { namespace = "^(launcher|swayosd)$" }, no_anim = true })

--------------------------------------------------------------------- keys ---
local function bind(keys, action, desc, opts)
    opts = opts or {}
    opts.description = desc
    hl.bind(keys, action, opts)
end
local function key(k) return mod .. " + " .. k end

-- windows
for k, dir in pairs({ H = "left", J = "down", K = "up", L = "right" }) do
    bind(key(k), hl.dsp.focus({ direction = dir }), "focus " .. dir)
    bind(key("SHIFT + " .. k), hl.dsp.window.move({ direction = dir }), "move window " .. dir)
end
bind(key("CTRL + H"), hl.dsp.window.resize({ x = -40, y = 0, relative = true }), "narrower", { repeating = true })
bind(key("CTRL + L"), hl.dsp.window.resize({ x = 40, y = 0, relative = true }), "wider", { repeating = true })
bind(key("CTRL + K"), hl.dsp.window.resize({ x = 0, y = -40, relative = true }), "shorter", { repeating = true })
bind(key("CTRL + J"), hl.dsp.window.resize({ x = 0, y = 40, relative = true }), "taller", { repeating = true })
bind(key("Q"), hl.dsp.window.close(), "close window")
bind(key("SHIFT + F"), hl.dsp.window.fullscreen(), "fullscreen")
bind(key("SHIFT + SPACE"), hl.dsp.window.float({ action = "toggle" }), "float / tile")
bind(key("mouse:272"), hl.dsp.window.drag(), "drag to move", { mouse = true })
bind(key("mouse:273"), hl.dsp.window.resize(), "drag to resize", { mouse = true })

-- workspaces
for i = 1, 9 do
    bind(key(tostring(i)), hl.dsp.focus({ workspace = i }), "workspace " .. i)
    bind(key("SHIFT + " .. i), hl.dsp.window.move({ workspace = i }), "send window to workspace " .. i)
end

-- apps
bind(key("RETURN"), hl.dsp.exec_cmd(run(terminal)), "terminal")
bind(key("SHIFT + RETURN"), hl.dsp.exec_cmd("desk browser"), "browser")
bind(key("SPACE"), hl.dsp.exec_cmd("desk launch"), "launcher")
bind(key("V"), hl.dsp.exec_cmd("desk clipboard"), "clipboard history")
bind(key("E"), hl.dsp.exec_cmd(run(terminal .. " -e yazi")), "files (yazi)")
bind(key("SHIFT + E"), hl.dsp.exec_cmd(run("thunar")), "files (Thunar)")

-- controls (TUIs in a floating terminal)
bind(key("A"), hl.dsp.exec_cmd("desk float wiremix"), "audio")
bind(key("W"), hl.dsp.exec_cmd("desk float nmtui"), "Wi-Fi and network")
bind(key("B"), hl.dsp.exec_cmd("desk float bluetui"), "Bluetooth")
bind(key("N"), hl.dsp.exec_cmd("desk nightlight"), "night light on/off")

-- session
bind(key("ESCAPE"), hl.dsp.exec_cmd("loginctl lock-session"), "lock")
bind(key("SHIFT + ESCAPE"), hl.dsp.exec_cmd("desk power"), "power menu")
bind(key("SLASH"), hl.dsp.exec_cmd("desk keys"), "these keys")

-- screenshots
bind("Print", hl.dsp.exec_cmd("desk shot area"), "screenshot: area to clipboard")
bind("SHIFT + Print", hl.dsp.exec_cmd("desk shot edit"), "screenshot: area, then annotate")
bind("CTRL + Print", hl.dsp.exec_cmd("desk shot screen"), "screenshot: whole screen")

-- media keys (work on the lock screen too)
local media = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), "volume up", media)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), "volume down", media)
bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), "mute", { locked = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"), "microphone mute", { locked = true })
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"), "brightness up", media)
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), "brightness down", media)
bind("Caps_Lock", hl.dsp.exec_cmd("swayosd-client --caps-lock"), "caps lock indicator", { release = true, non_consuming = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "play / pause", { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "play / pause", { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "next track", { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "previous track", { locked = true })

------------------------------------------------------------- this machine ---
local here = os.getenv("HOME") .. "/.config/hypr/local.lua"
local f = io.open(here, "r")
if f then
    f:close()
    dofile(here)
end
