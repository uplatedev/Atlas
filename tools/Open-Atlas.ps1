# Open de editor met dezelfde gecontroleerde engine als Check-Atlas.ps1.
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'Atlas-Engine.ps1')
    $engine = Get-AtlasEngine
    $project = Join-Path (Split-Path $PSScriptRoot -Parent) 'game'
    if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {
        throw "Atlas-project ontbreekt: $project"
    }
    # Gebruik de GUI-exe naast de console-exe als die aanwezig is.
    $editor = $engine -replace '_console\.exe$', '.exe'
    if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) { $editor = $engine }
    Write-Host 'Atlas openen. F5 speelt het project; F8 stopt. Sluit de editor om dit script af te ronden.'
    $process = Start-Process -FilePath $editor -ArgumentList @('--editor', '--path', ('"' + $project + '"')) -WindowStyle Normal -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "De Godot-editor stopte met exitcode $($process.ExitCode)." }
    exit 0
}
catch {
    [Console]::Error.WriteLine("Atlas openen mislukt: $($_.Exception.Message)")
    exit 1
}
