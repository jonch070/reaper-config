@echo off
setlocal
title ACE-Step 1.5 - Auto Installer (Manual Mode)
color 0A

echo ========================================================
echo        ACE-STEP 1.5 AUTOMATED INSTALLER
echo      Optimized for Reaper Integration (Scripting)
echo ========================================================
echo.

:: 1. CHECK GIT
echo [1/5] Checking for Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Git is not installed on this computer!
    echo Please install Git from: https://git-scm.com/downloads
    echo After installing, please run this script again.
    pause
    exit /b
)
echo [OK] Git found.
echo.

:: 2. CHECK & INSTALL UV
echo [2/5] Checking for 'uv' package manager...
uv --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] 'uv' not found. Installing automatically...
    powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
    
    :: Temporarily update PATH for this session
    set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
) else (
    echo [OK] 'uv' is ready.
)
echo.

:: 3. CLONE REPOSITORY
echo [3/5] Downloading ACE-Step-1.5 source code from GitHub...
if exist "ACE-Step-1.5" (
    echo [INFO] Folder already exists. Updating to the latest version...
    cd ACE-Step-1.5
    git pull
) else (
    git clone https://github.com/ace-step/ACE-Step-1.5.git
    cd ACE-Step-1.5
)
echo.

:: 4. INSTALL ENVIRONMENT & DEPENDENCIES
echo [4/5] Installing Python environment and libraries...
echo Note: This step will automatically install Python if missing.
echo Please wait, this may take a few minutes...
call uv sync
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Failed to install dependencies. Please check your internet connection!
    pause
    exit /b
)
echo.

:: 5. CREATE STARTUP SCRIPT
echo [5/5] Creating startup script for API Server...

:: Create start_api_server.bat inside the folder
(
echo @echo off
echo title ACE-Step API Server
echo echo Starting ACE-Step Server...
echo echo API Endpoint: http://127.0.0.1:8001
echo echo -------------------------------------
echo uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1
echo pause
) > start_api_server.bat

echo.
echo ========================================================
echo               INSTALLATION COMPLETE!
echo ========================================================
echo 1. Installation folder: %CD%
echo 2. To start the API Server for Reaper, run: start_api_server.bat
echo 3. To run the standard Web UI, type: uv run acestep
echo.
pause