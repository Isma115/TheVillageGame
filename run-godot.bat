@echo off
rem Ejecuta Pradera con el Godot local de Windows (godot-engine\Godot.exe).
rem Uso: run-godot.bat [--editor] [--headless -- --smoke-test] ...

setlocal
set "REPO_DIR=%~dp0"
set "GODOT_BIN=%REPO_DIR%godot-engine\Godot.exe"
set "GAME_DIR=%REPO_DIR%game"

if not exist "%GODOT_BIN%" (
    echo No se encuentra el Godot local: %GODOT_BIN%
    exit /b 1
)

"%GODOT_BIN%" --path "%GAME_DIR%" %*
exit /b %errorlevel%
