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
# Windows PowerShell 5.1 drops the double quotes in an argument to a native program
function Arg($json) { if ($PSVersionTable.PSVersion.Major -lt 7) { $json -replace '"', '\"' } else { $json } }
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
# PowerToys.DSC.exe, its output (stderr too) as lines; 5.1 would throw on a
# stderr line under ErrorActionPreference Stop, so not for this call
function Invoke-Dsc([string] $exe) {
  $ErrorActionPreference = 'Continue'
  & $exe @args 2>&1 | ForEach-Object { "$_" }
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
  $res = Invoke-Dsc $Dsc set --resource settings --module $Module --input (Arg $in)
  if ($LASTEXITCODE -ne 0) { Exit-Unexpected "set $Module failed, exit $LASTEXITCODE" $res }
  exit 0
}
$out = Invoke-Dsc $Dsc get --resource settings --module $Module
if ($LASTEXITCODE -ne 0) { Exit-Unexpected "get $Module failed, exit $LASTEXITCODE" $out }
$cur = Read-Json $out
if (-not $cur) { Exit-Unexpected "get $Module, no JSON" $out }
# {"settings":{"properties":{...},"name":...}} for most modules (as documented);
# App's settings sit right in "settings" (startup, theme, enabled: {...})
if (-not $cur.settings) { Exit-Unexpected "get $Module, no settings" $out }
$target = if ($cur.settings.PSObject.Properties['properties']) { $cur.settings.properties } else { $cur.settings }
if ($Save) { [IO.File]::WriteAllText($Save, ($cur | ConvertTo-Json -Depth 30 -Compress), (New-Object Text.UTF8Encoding $false)) }
Merge $target ($Want | ConvertFrom-Json)
$in = $cur | ConvertTo-Json -Depth 30 -Compress
$res = Invoke-Dsc $Dsc set --resource settings --module $Module --input (Arg $in)
if ($LASTEXITCODE -ne 0) { Exit-Unexpected "set $Module failed, exit $LASTEXITCODE" $res }
exit 0
