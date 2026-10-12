# Open de editor met dezelfde gecontroleerde engine als Check-Atlas.ps1.
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'Atlas-Engine.ps1')
    $engine = Get-AtlasEngine
    $project = Join-Path (Split-Path $PSScriptRoot -Parent) 'game'
    if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {
        throw "Atlas-project ontbreekt: $project"
    }
    # Toon alleen de editor; verberg het extra consolevenster van de console-exe.
    Start-Process -FilePath $engine -ArgumentList @('--editor', '--path', ('"' + $project + '"')) -WindowStyle Hidden | Out-Null
    Write-Host 'Atlas is gestart in de Godot-editor. F6 speelt de open scene; F5 het project.'
    exit 0
}
catch {
    [Console]::Error.WriteLine("Atlas openen mislukt: $($_.Exception.Message)")
    exit 1
}
