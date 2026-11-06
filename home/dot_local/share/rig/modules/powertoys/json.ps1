# modules/powertoys/json.ps1: JSON edits on the Windows side, for rig's
# powertoys module (run with powershell.exe; Windows PowerShell 5.1 is enough).
#   -Dsc <PowerToys.DSC.exe> -Module <name> [-Save <file>] -Want <json>
#       PowerToys settings: read the module's settings (saved to -Save first),
#       merge -Want into its properties, and set the result.
#   -Dsc ... -Module <name> -Restore <file>   set a saved copy back as it was
#   -File <settings.json> -Want <json>        merge into a JSON file (Command Palette)
param([string]$Dsc, [string]$Module, [string]$Save, [string]$Restore, [string]$File, [string]$Want)
$ErrorActionPreference = 'Stop'

function Merge($into, $from) {
  foreach ($p in $from.PSObject.Properties) {
    $cur = $into.PSObject.Properties[$p.Name]
    if ($cur -and $cur.Value -is [pscustomobject] -and $p.Value -is [pscustomobject]) { Merge $cur.Value $p.Value }
    else { $into | Add-Member -Force -NotePropertyName $p.Name -NotePropertyValue $p.Value }
  }
}
# JSON from a program's output: all of it, else its last line that is JSON
# (a tool may print other lines around it). $null if there's none.
function Read-Json($lines) {
  $text = ($lines | Out-String).Trim()
  if (-not $text) { return $null }
  try { return $text | ConvertFrom-Json } catch { Write-Verbose 'not JSON as a whole; looking for a JSON line' }
  foreach ($l in @($lines)[-1..-(@($lines).Count)]) {
    if ("$l".TrimStart().StartsWith('{')) { try { return "$l" | ConvertFrom-Json } catch { Write-Verbose "not JSON: $l" } }
  }
  return $null
}
# One argument as Windows programs split a command line (CommandLineToArgvW):
# quoted, inner quotes and the backslashes before them escaped. PowerShell's
# own passing can't be trusted with JSON: 5.1 leaves an argument that already
# has quotes in it unquoted, so the JSON splits at every space.
function Format-Arg([string] $a) {
  if ($a -and $a -notmatch '[\s"]') { return $a }
  $a = $a -replace '(\\*)"', '$1$1\"'
  $a = $a -replace '(\\+)$', '$1$1'
  return '"' + $a + '"'
}
# PowerToys.DSC.exe with exactly these arguments: its output (stderr too) as
# lines, and its exit code.
function Invoke-Dsc([string] $exe) {
  $psi = New-Object Diagnostics.ProcessStartInfo $exe
  $psi.Arguments = ($args | ForEach-Object { Format-Arg "$_" }) -join ' '
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $p = [Diagnostics.Process]::Start($psi)
  $err = $p.StandardError.ReadToEndAsync()
  $out = $p.StandardOutput.ReadToEnd()
  $p.WaitForExit()
  [pscustomobject]@{ Code = $p.ExitCode; Lines = @(("$out`n$($err.Result)") -split "`r?`n" | Where-Object { $_ -ne '' }) }
}
function Exit-Unexpected($what, $lines) {
  [Console]::Error.WriteLine("rig: PowerToys' DSC printed something rig didn't expect ($what):")
  [Console]::Error.WriteLine((($lines | Out-String).Trim() -split "`n" | Select-Object -First 30) -join "`n")
  exit 2
}

if ($File) {
  $text = if (Test-Path $File) { (Get-Content -Raw $File) } else { '' }
  $doc = if ($text -and $text.Trim()) { $text | ConvertFrom-Json } else { New-Object psobject }
  Merge $doc ($Want | ConvertFrom-Json)
  New-Item -ItemType Directory -Force (Split-Path $File) | Out-Null
  [IO.File]::WriteAllText($File, ($doc | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding $false))
  exit 0
}
if ($Restore) {
  $in = (Get-Content -Raw $Restore | ConvertFrom-Json) | ConvertTo-Json -Depth 30 -Compress
  $res = Invoke-Dsc $Dsc set --resource settings --module $Module --input $in
  if ($res.Code -ne 0) { Exit-Unexpected "set $Module failed, exit $($res.Code)" $res.Lines }
  exit 0
}
$got = Invoke-Dsc $Dsc get --resource settings --module $Module
$out = $got.Lines
if ($got.Code -ne 0) { Exit-Unexpected "get $Module failed, exit $($got.Code)" $out }
$cur = Read-Json $out
if (-not $cur) { Exit-Unexpected "get $Module, no JSON" $out }
# {"settings":{"properties":{...},"name":...}} for most modules (as documented);
# App's settings sit right in "settings" (startup, theme, enabled: {...})
if (-not $cur.settings) { Exit-Unexpected "get $Module, no settings" $out }
$target = if ($cur.settings.PSObject.Properties['properties']) { $cur.settings.properties } else { $cur.settings }
if ($Save) { [IO.File]::WriteAllText($Save, ($cur | ConvertTo-Json -Depth 30 -Compress), (New-Object Text.UTF8Encoding $false)) }
Merge $target ($Want | ConvertFrom-Json)
$in = $cur | ConvertTo-Json -Depth 30 -Compress
$res = Invoke-Dsc $Dsc set --resource settings --module $Module --input $in
if ($res.Code -ne 0) { Exit-Unexpected "set $Module failed, exit $($res.Code)" $res.Lines }
exit 0
