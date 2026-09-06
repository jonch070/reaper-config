@echo off
color 0A
title Hosi Drum Components Separator - Installer

echo ========================================================
echo   CAY DAT THU VIEN AI (Hosi Drum Components Separator)
echo ========================================================
echo.

:: Kiem tra Python
python --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    color 0C
    echo [LOI]: Khong tim thay Python tren he thong cua ban!
    echo Vui long cai dat Python 3.9 tro len (Nho tich vao "Add Python to PATH") truoc khi chay file nay.
    echo Vao https://www.python.org/downloads/ de tai Python moi nhat.
    echo.
    pause
    exit /b
)

echo [OK] Da tim thay Python! Dang tien hanh cai dat cac thu vien can thiet...
echo.
echo ========================================================
echo 1/2: Cai dat audio-separator (Loi thao tac AI)
echo ========================================================
python -m pip install --upgrade pip
python -m pip install audio-separator

echo.
echo ========================================================
echo 2/2: Cai dat onnxruntime (Ho tro chay Model)
echo ========================================================
python -m pip install onnxruntime

echo.
color 0E
echo ========================================================
echo HOAN TAT!
echo Bay gio ban co the bat REAPER va Load thao tac Script:
echo Hosi_Drum_Components_Separator.lua
echo vao danh sach Action de su dung.
echo ========================================================
pause
