# Gedeelde interne hulp voor de twee gebruikersscripts; PowerShell 5.1 en 7.
Set-StrictMode -Version Latest

function Invoke-AtlasEngine {
    param([string]$Engine, [string[]]$Arguments, [int]$TimeoutSeconds = 120)
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $Engine
    # Alle argumenten komen uit deze scripts; Windows-bestandspaden bevatten geen quotes.
    $start.Arguments = ($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'Godot kon niet starten.' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            throw "Godot reageerde niet binnen $TimeoutSeconds seconden."
        }
        $output = ($stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()).Trim()
        if ($process.ExitCode -ne 0 -or $output -match '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):') {
            throw "Godot-stap mislukt (exitcode $($process.ExitCode)).`n$output"
        }
        return $output
    }
    finally { $process.Dispose() }
}

function Get-AtlasEngine {
    $toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
    $engine = $env:ATLAS_GODOT
    $localFile = Join-Path $PSScriptRoot 'godot.local.json'
    if ([string]::IsNullOrWhiteSpace($engine) -and (Test-Path -LiteralPath $localFile)) {
        $engine = (Get-Content -LiteralPath $localFile -Raw | ConvertFrom-Json).godotPath
    }
    if ([string]::IsNullOrWhiteSpace($engine)) {
        throw "Godot ontbreekt. Pak de Windows Standard-versie uit via $($toolchain.downloadPage). Stel ATLAS_GODOT in op het volledige pad naar de console-exe, of vul tools/godot.local.json in (zie docs/TESTING.md)."
    }
    if (-not [IO.Path]::IsPathRooted($engine) -or -not (Test-Path -LiteralPath $engine -PathType Leaf)) {
        throw "Godot-pad bestaat niet of is niet absoluut: $engine. Controleer ATLAS_GODOT of tools/godot.local.json."
    }
    $version = Invoke-AtlasEngine -Engine $engine -Arguments @('--version') -TimeoutSeconds 15
    if ($version -cne $toolchain.godotVersion) {
        throw "Verkeerde Godot-versie: '$version'. Atlas vereist '$($toolchain.godotVersion)'. Download: $($toolchain.downloadPage). Pas je lokale enginepad aan."
    }
    return $engine
}
