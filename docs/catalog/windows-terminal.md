# Windows Terminal

The terminal on Windows, set up from inside WSL:

- **JetBrainsMono Nerd Font**, installed for your Windows user (no admin). Apps
  started after it see it; restart Windows Terminal once.
- **gruvbox**: a colour scheme from `theme.yaml`, and this distro's profile with
  the font, starting in `~`. Both are in rig's *fragment*,
  `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\rig\rig.json`, not in
  your `settings.json`.
- **This distro as the default profile**: the one line rig changes in
  `settings.json` (`defaultProfile`). The previous value is recorded and put
  back when you deselect the item. If Windows Terminal hasn't been opened yet,
  open it once and run `rig modules sync winterm`.
- **Each window in tmux**, as with Ghostty: every window (and tab) is its own
  tmux session, in the folder it opened in, gone when it closes. Tabs and
  splits are tmux's (`prefix c`, `\` and `-`). Not over SSH or inside tmux;
  `RIG_NO_TMUX=1` turns it off. (That's zsh's doing, `.zshrc`, keyed on
  Windows Terminal's `WT_SESSION`.)

`install.ps1` ticks this item. Deselecting it removes the fragment and the
font, and puts the default profile back.
