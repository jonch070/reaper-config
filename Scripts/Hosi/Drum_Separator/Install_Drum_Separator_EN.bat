@echo off
color 0A
title Hosi Drum Components Separator - Installer

echo ========================================================
echo   AI LIBRARY INSTALLER (Hosi Drum Components Separator)
echo ========================================================
echo.

:: Check Python
python --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    color 0C
    echo [ERROR]: Python was not found on your system!
    echo Please install Python 3.9 or higher (Make sure to check "Add Python to PATH") before running this installer.
    echo Visit https://www.python.org/downloads/ to download the latest Python.
    echo.
    pause
    exit /b
)

echo [OK] Python found! Installing required dependencies...
echo.
echo ========================================================
echo 1/2: Installing audio-separator (Core AI Engine)
echo ========================================================
python -m pip install --upgrade pip
python -m pip install audio-separator

echo.
echo ========================================================
echo 2/2: Installing onnxruntime (Model Execution Support)
echo ========================================================
python -m pip install onnxruntime

echo.
color 0E
echo ========================================================
echo INSTALLATION COMPLETE!
echo You can now open REAPER and Load the Script:
echo Hosi_Drum_Components_Separator.lua
echo into your Action List.
echo ========================================================
pause
