# Controleer versie, import en de ingestelde hoofdscene. Een fout levert exitcode 1 op.
param([switch]$CharacterChecks)

$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'Atlas-Engine.ps1')
    $engine = Get-AtlasEngine
    $project = Join-Path (Split-Path $PSScriptRoot -Parent) 'game'
    if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {
        throw "Atlas-project ontbreekt: $project"
    }
    Write-Host 'Godot-versie akkoord. Project importeren...'
    Write-Host (Invoke-AtlasEngine -Engine $engine -Arguments @('--headless', '--path', $project, '--import'))
    Write-Host 'Hoofdscene headless starten (10 frames)...'
	Write-Host (Invoke-AtlasEngine -Engine $engine -Arguments @('--headless', '--path', $project, '--quit-after', '10'))
	if ($CharacterChecks) {
		Write-Host 'Character-physics en scenecontrole uitvoeren...'
		Write-Host (Invoke-AtlasEngine -Engine $engine -Arguments @('--headless', '--path', $project, '--script', 'res://tests/character_checks.gd'))
	}
    Write-Host 'Atlas: versie, import en headless-start geslaagd.'
    exit 0
}
catch {
    [Console]::Error.WriteLine("Atlas-controle mislukt: $($_.Exception.Message)")
    exit 1
}
