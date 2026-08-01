#!/usr/bin/env pwsh
# Ejecuta Pradera con el Godot local de Windows (godot-engine/Godot.exe).
# Uso:
#   .\run-godot.ps1                -> abre el juego
#   .\run-godot.ps1 --editor       -> abre el editor
#   .\run-godot.ps1 --headless -- --smoke-test
$ErrorActionPreference = "Stop"

$repoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotBin = Join-Path $repoDir "godot-engine\Godot.exe"
$gameDir = Join-Path $repoDir "game"

if (-not (Test-Path -LiteralPath $godotBin)) {
    Write-Host "No se encuentra el Godot local: $godotBin" -ForegroundColor Red
    exit 1
}

& $godotBin --path $gameDir @args
exit $LASTEXITCODE
