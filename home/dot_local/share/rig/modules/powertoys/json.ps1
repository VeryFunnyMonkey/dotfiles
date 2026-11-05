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

if ($File) {
  $doc = if (Test-Path $File) { Get-Content -Raw $File | ConvertFrom-Json } else { New-Object psobject }
  Merge $doc ($Want | ConvertFrom-Json)
  New-Item -ItemType Directory -Force (Split-Path $File) | Out-Null
  [IO.File]::WriteAllText($File, ($doc | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding $false))
  exit 0
}
if ($Restore) {
  $in = (Get-Content -Raw $Restore | ConvertFrom-Json) | ConvertTo-Json -Depth 30 -Compress
  & $Dsc set --resource settings --module $Module --input (Arg $in) | Out-Null
  exit $LASTEXITCODE
}
$cur = (& $Dsc get --resource settings --module $Module) | ConvertFrom-Json
if ($Save) { [IO.File]::WriteAllText($Save, ($cur | ConvertTo-Json -Depth 30 -Compress), (New-Object Text.UTF8Encoding $false)) }
Merge $cur.settings.properties ($Want | ConvertFrom-Json)
$in = $cur | ConvertTo-Json -Depth 30 -Compress
& $Dsc set --resource settings --module $Module --input (Arg $in) | Out-Null
exit $LASTEXITCODE
