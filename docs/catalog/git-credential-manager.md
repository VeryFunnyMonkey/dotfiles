# Git Credential Manager (Windows)

git inside WSL signs in through Windows: your Windows and work accounts
(Entra ID, through MSAL), with the credentials in Windows' own store. It's
the setup Git Credential Manager's guide recommends for WSL. `install.ps1`
ticks it.

What rig does:

- installs **Git for Windows** with winget if it isn't there (it carries
  GCM); one you already have, per user or for everyone, is used as it is
- finds `git-credential-manager.exe` in it (`ucrt64` since Git for Windows
  2.56, `mingw64` before, `clangarm64` on ARM) and makes it git's only
  credential helper
- sets `credential.https://dev.azure.com.useHttpPath`, which Azure DevOps needs

Both settings go in `~/.config/git/local.gitconfig` (machine-local, never in
the repo), recorded first: deselecting the item, or `rig uninstall`, takes
them out again. `rig doctor` checks the helper is still where Git for
Windows put it (an update can move it: `rig modules sync gcm` finds it again).

GCM runs as a Windows program, so it reads Git for Windows' settings
(`%USERPROFILE%\.gitconfig`), not WSL's: proxy settings, say, belong there too.
