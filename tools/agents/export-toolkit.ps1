param([Parameter(Mandatory=$true)][string]$Destination)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
& (Join-Path $PSScriptRoot 'repo/local-only.ps1') -Action check
& py -3 -B (Join-Path $PSScriptRoot 'lib/toolkit.py') export --destination $Destination
if ($LASTEXITCODE -ne 0) { throw 'Toolkit export failed.' }
