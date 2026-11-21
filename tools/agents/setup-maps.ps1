param([switch]$Repair, [switch]$ConfigOnly, [string]$MapsSeed)
$ErrorActionPreference = 'Stop'
$setupArguments = @('-3','-B',(Join-Path $PSScriptRoot 'setup/setup-maps.py'))
if ($Repair) { $setupArguments += '--repair' }
if ($ConfigOnly) { $setupArguments += '--config-only' }
if ($MapsSeed) { $setupArguments += @('--maps-seed',$MapsSeed) }
& py @setupArguments
if ($LASTEXITCODE -ne 0) { throw 'Maps runtime/config setup failed.' }
