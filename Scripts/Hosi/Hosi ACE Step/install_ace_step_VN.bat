@echo off
setlocal
title ACE-Step 1.5 - Auto Installer (Hosi Version)
color 0A

echo ========================================================
echo       TU DONG CAI DAT ACE-STEP 1.5 (Manual Mode)
echo           Toi uu cho viec tich hop Reaper
echo ========================================================
echo.

:: 1. KIEM TRA GIT
echo [1/5] Dang kiem tra Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo [LOI] May tinh chua cai Git!
    echo Vui long cai Dat Git tai: https://git-scm.com/downloads
    echo Sau khi cai xong, hay chay lai file nay.
    pause
    exit /b
)
echoOK: Da tim thay Git.
echo.

:: 2. KIEM TRA VA CAI DAT UV
echo [2/5] Dang kiem tra trinh quan ly 'uv'...
uv --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [THONG BAO] Chua thay 'uv'. Dang tien hanh cai dat tu dong...
    powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
    
    :: Cap nhat duong dan moi truong tam thoi cho phien lam viec nay
    set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
) else (
    echo OK: Da tim thay 'uv'.
)
echo.

:: 3. TAI MA NGUON (CLONE REPO)
echo [3/5] Dang tai ma nguon ACE-Step-1.5 tu GitHub...
if exist "ACE-Step-1.5" (
    echo [THONG BAO] Thu muc da ton tai. Dang cap nhat code moi nhat...
    cd ACE-Step-1.5
    git pull
) else (
    git clone https://github.com/ace-step/ACE-Step-1.5.git
    cd ACE-Step-1.5
)
echo.

:: 4. CAI DAT MOI TRUONG AO & THU VIEN
echo [4/5] Dang cai dat thu vien Python (co the mat vai phut)...
echo Luu y: Buoc nay se tu dong cai Python neu thieu.
call uv sync
if %errorlevel% neq 0 (
    color 0C
    echo [LOI] Khong the cai dat thu vien. Kiem tra lai mang internet!
    pause
    exit /b
)
echo.

:: 5. TAO FILE KHOI CHAY (STARTUP SCRIPT)
echo [5/5] Dang tao file khoi chay nhanh cho Reaper...

:: Tao file run_api.bat de chay server voi che do API
(
echo @echo off
echo title ACE-Step API Server
echo echo Dang khoi dong Server ACE-Step...
echo echo API Endpoint: http://127.0.0.1:8001
echo echo -------------------------------------
echo uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1
echo pause
) > start_api_server.bat

echo.
echo ========================================================
echo               CAI DAT HOAN TAT!
echo ========================================================
echo 1. Thu muc cai dat: %CD%
echo 2. De chay Server cho Reaper, hay chay file: start_api_server.bat
echo 3. De dung giao dien Web binh thuong, go lenh: uv run acestep
echo.
pause