@echo off
REM Scene Detection Wrapper Script for Windows
REM Runs ffmpeg scene detection and signals completion via status file

setlocal enabledelayedexpansion

set VIDEO_FILE=%~1
set START_TIME=%2
set DURATION=%3
set THRESHOLD=%4
set OUTPUT_FILE=%~5
set STATUS_FILE=%OUTPUT_FILE%.status
set PID_FILE=%OUTPUT_FILE%.pid
set FFMPEG_PATH=%~6
set DOWNSCALE_WIDTH=%7

REM Get our process ID using PowerShell
REM This is the batch script's PID which will be used to kill the process tree if needed
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "$pid = [System.Diagnostics.Process]::GetCurrentProcess().Id; Write-Output $pid"') do set BATCH_PID=%%i

REM Write PID to file so Lua can kill us if needed
echo !BATCH_PID! > "%PID_FILE%"

REM Write "processing" status
echo processing > "%STATUS_FILE%"

REM Build video filter based on downscale setting
if "%DOWNSCALE_WIDTH%" == "" goto NO_DOWNSCALE
if "%DOWNSCALE_WIDTH%" == "0" goto NO_DOWNSCALE

set VIDEO_FILTER=scale=%DOWNSCALE_WIDTH%:-1,select='gt(scene,%THRESHOLD%)',showinfo
goto RUN_FFMPEG

:NO_DOWNSCALE
set VIDEO_FILTER=select='gt(scene,%THRESHOLD%)',showinfo

:RUN_FFMPEG
REM Run ffmpeg scene detection
"%FFMPEG_PATH%" -ss %START_TIME% -t %DURATION% -i "%VIDEO_FILE%" -vf "%VIDEO_FILTER%" -f null - > "%OUTPUT_FILE%" 2>&1

REM Check if ffmpeg succeeded
if %ERRORLEVEL% EQU 0 (
    echo done > "%STATUS_FILE%"
) else (
    echo error > "%STATUS_FILE%"
)

REM Clean up PID file
del /F /Q "%PID_FILE%" 2>nul

endlocal
