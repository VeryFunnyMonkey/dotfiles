# PowerToys

Set up on every Windows machine (it isn't a choice in the installer).
Installed with winget, for your user, and started at login.

What rig changes (everything else stays as PowerToys ships it; the values
are the `powertoys_settings` of the item in `catalog/windows.yaml`):

| | |
|---|---|
| **Command Palette** | on, opening with `alt+space` (apps, files, `=` calculator, `>` commands, windows, WinGet search) |
| **PowerToys Run** | off: Command Palette replaces it |
| **FancyZones** | off: GlazeWM (the keyboard-driven desktop) places windows |
| theme | dark |

The settings go through PowerToys' own tool (`PowerToys.DSC.exe`). Before the
first change rig saves each part's settings, and `rig uninstall` sets them
back (and uninstalls PowerToys, if rig installed it). Change anything else in
PowerToys' Settings as usual; rig only sets the values above, on each sync.
