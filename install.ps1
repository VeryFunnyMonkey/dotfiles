<#
  install.ps1: set up a Windows machine. In PowerShell:
    irm https://raw.githubusercontent.com/VeryFunnyMonkey/dotfiles/main/install.ps1 | iex
  Or, choosing up front (scripts, CI):
    & ([scriptblock]::Create((irm .../install.ps1))) -Distro Ubuntu

  It does only what has to happen on the Windows side:
    1. checks Windows (10 2004 or newer) and winget
    2. installs WSL if it's missing (asks for admin for that step alone), then
       carries on by itself after the restart it needs
    3. installs the distro you pick: Ubuntu (the default), Arch or Fedora
    4. creates your Linux user (with sudo) and makes it the default
    5. runs the normal installer inside it (install.sh: rig setup), with
       Windows Terminal and the keyboard-driven desktop (GlazeWM) ticked;
       PowerToys is always set up. Everything rig does on Windows is undoable:
       rig uninstall, inside WSL.
    6. opens Windows Terminal in the new distro
#>
[CmdletBinding()]
param(
  [ValidateSet('Ubuntu', 'Arch', 'Fedora')] [string] $Distro,
  [string] $Branch,
  [switch] $Resume
)
$ErrorActionPreference = 'Stop'
$Repo = if ($env:RIG_REPO) { $env:RIG_REPO } else { 'VeryFunnyMonkey' }
if (-not $Branch) { $Branch = if ($env:RIG_BRANCH) { $env:RIG_BRANCH } else { 'main' } }
$Raw = "https://raw.githubusercontent.com/$Repo/dotfiles/$Branch"
$State = Join-Path $env:LOCALAPPDATA 'rig'
$Self = Join-Path $State 'install.ps1'
$env:WSL_UTF8 = '1'   # wsl.exe prints UTF-16 otherwise

function Say([string] $m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok([string] $m) { Write-Host "  + $m" -ForegroundColor Green }
function Note([string] $m) { Write-Host "  $m" -ForegroundColor DarkGray }
function Fail([string] $m) { Write-Host "rig: $m" -ForegroundColor Red; exit 1 }

# ------------------------------------------------------------ 1. checks ------
Say 'checking Windows'
$build = [Environment]::OSVersion.Version.Build
if ($build -lt 19041) { Fail "WSL 2 needs Windows 10 version 2004 (build 19041) or newer; this is build $build" }
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
  Fail 'winget is missing: install "App Installer" from the Microsoft Store, then run this again'
}
Ok "Windows build $build, winget"
# a copy of this script, so it can carry on after a restart
New-Item -ItemType Directory -Force $State | Out-Null
if ($PSCommandPath -and (Test-Path $PSCommandPath)) { Copy-Item -Force $PSCommandPath $Self }
else { Invoke-WebRequest -UseBasicParsing "$Raw/install.ps1" -OutFile $Self }

# ------------------------------------------------------------ 2. WSL ---------
function Test-Wsl { & wsl.exe --status *> $null; return ($LASTEXITCODE -eq 0) }
if (-not (Test-Wsl)) {
  Say 'installing WSL (Windows asks for admin for this step)'
  $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile', '-Command', 'wsl.exe --install --no-distribution'
  if ($p.ExitCode -ne 0) { Fail "installing WSL failed (exit $($p.ExitCode)); try by hand: wsl --install --no-distribution" }
  if (-not (Test-Wsl)) {
    # carry on after the restart, once, at the next login
    $again = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Self`" -Resume -Branch $Branch"
    if ($Distro) { $again += " -Distro $Distro" }
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name rig -Value $again
    Ok 'WSL is installed; Windows needs a restart to finish it'
    Note 'after you log back in, this setup carries on by itself'
    if ((Read-Host 'Restart now? [Y/n]') -notmatch '^[nN]') { Restart-Computer }
    exit 0
  }
}
Ok 'WSL is ready'
if ($Resume) { Note 'carrying on after the restart' }

# ------------------------------------------------------------ 3. distro ------
$online = (& wsl.exe --list --online) | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ }
function Resolve-Distro([string] $choice) {
  switch ($choice) {
    'Ubuntu' { return 'Ubuntu' }
    'Arch' { return 'archlinux' }
    'Fedora' {   # the name carries the version: the newest one offered
      return $online | Where-Object { $_ -match '^FedoraLinux-\d+$' } |
        Sort-Object { [int]($_ -replace '\D', '') } | Select-Object -Last 1
    }
  }
}
if (-not $Distro) {
  Say 'which Linux?'
  Write-Host '  1) Ubuntu  (default)'
  Write-Host '  2) Arch'
  Write-Host '  3) Fedora'
  $pick = Read-Host 'Pick 1-3 [1]'
  $Distro = switch ($pick) { '2' { 'Arch' } '3' { 'Fedora' } default { 'Ubuntu' } }
}
$name = Resolve-Distro $Distro
if (-not $name -or ($online -notcontains $name)) { Fail "WSL doesn't offer $Distro here (wsl --list --online)" }

$installed = (& wsl.exe --list --quiet) | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($installed -contains $name) {
  Ok "$name is already installed; using it"
} else {
  Say "installing $name"
  & wsl.exe --install -d $name --no-launch
  if ($LASTEXITCODE -ne 0) { Fail "installing $name failed; try by hand: wsl --install -d $name" }
  Ok "$name installed"
}
function Invoke-InDistro([string] $user, [string] $cmd) { & wsl.exe -d $name -u $user -- sh -c $cmd }

# ------------------------------------------------------------ 4. your user ---
$current = (Invoke-InDistro root 'getent passwd 1000 | cut -d: -f1') | Select-Object -First 1
if ($current) {
  Ok "Linux user: $current"
  $user = $current
} else {
  Say "your Linux user in $name"
  do { $user = (Read-Host 'Username (lowercase)').Trim() } until ($user -match '^[a-z_][a-z0-9_-]*$')
  do {
    $p1 = Read-Host 'Password (for sudo)' -AsSecureString
    $p2 = Read-Host 'Again' -AsSecureString
    $pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
    $pw2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
    if ($pw -ne $pw2) { Note "they don't match; again" }
  } until ($pw -eq $pw2 -and $pw)
  # sudo and the admin group differ: sudo on Ubuntu, wheel on Arch and Fedora
  $prep = switch ($Distro) {
    'Arch' { 'pacman-key --init >/dev/null && pacman-key --populate >/dev/null && pacman -Sy --noconfirm --needed sudo >/dev/null && echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel && G=wheel' }
    'Fedora' { 'dnf -y -q install sudo >/dev/null && G=wheel' }
    default { 'G=sudo' }
  }
  Invoke-InDistro root "set -e; $prep; useradd -m -s /bin/bash -G `$G $user; printf '[user]\ndefault=$user\n' >> /etc/wsl.conf"
  if ($LASTEXITCODE -ne 0) { Fail "couldn't create $user" }
  # the password goes in on stdin, never as an argument (PowerShell adds a CR)
  "${user}:$pw" | & wsl.exe -d $name -u root -- sh -c "tr -d '\r' | chpasswd"
  if ($LASTEXITCODE -ne 0) { Fail "couldn't set the password; inside ${name}: sudo passwd $user" }
  $pw = $null; $pw2 = $null
  & wsl.exe --terminate $name | Out-Null   # the default user applies from the next start
  Ok "user $user (sudo), the default in $name"
}

# ------------------------------------------------------------ 5. rig ---------
# Windows Terminal: the installer and everything after it run there
if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
  Say 'installing Windows Terminal'
  & winget.exe install --id Microsoft.WindowsTerminal --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null
}
Say "setting up $name (the rig installer)"
Note 'pick what you want; Windows Terminal and the keyboard-driven desktop are ticked'
$run = "curl -fsSL $Raw/install.sh | RIG_BRANCH=$Branch sh -s -- --select windows-terminal,wm"
& wsl.exe -d $name --cd ~ -- bash -lc $run
if ($LASTEXITCODE -ne 0) { Fail "the installer didn't finish; run it again inside ${name}: $run" }

# ------------------------------------------------------------ 6. done --------
# Windows Terminal writes its settings on its first start; rig then makes the
# new distro its default (and shows it in gruvbox)
$wtSettings = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$fresh = -not (Test-Path $wtSettings)
Start-Process wt.exe -ArgumentList '-p', $name
if ($fresh) {
  for ($i = 0; $i -lt 20 -and -not (Test-Path $wtSettings); $i++) { Start-Sleep 1 }
  & wsl.exe -d $name -- bash -lc '~/.local/bin/rig modules sync winterm' | Out-Null
}
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name rig -ErrorAction SilentlyContinue
Say 'done'
Note "Windows Terminal opens $name; alt+enter opens it too, alt+space is the launcher"
Note "everything rig set up: rig doctor (inside $name); undo it all: rig uninstall"
