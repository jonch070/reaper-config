@echo off
title ACE-STEP 1.5 PRO LAUNCHER - BY GEMINI FOR PRODUCER LA CHI NHAN
color 0B
cls

:MENU
cls
echo ========================================================================
echo               ACE-STEP 1.5 CONTROL CENTER - V3.1 (ULTIMATE)
echo               Danh rieng cho Producer La Chi Nhan tai Can Tho
echo ========================================================================
echo.
echo    [1] CHAY MODEL TURBO + NAO 1.7B (Tieu chuan)
echo        - Phu hop: Tao beat nhanh, demo y tuong, Text-to-Music co ban.
echo        - Uu diem: Nhe may, toc do render sieu nhanh (4-8 buoc). [Da Nen 8-bit]
echo        - Nhuoc diem: Hat bai dai de bi nuot chu, sai cau truc Verse/Chorus.
echo        - Canh bao: KHONG dung de tach Stem (Extract).
echo.
echo    [2] CHAY MODEL TURBO + NAO 4B (CHUAN LOI 100%) - *KHUYEN DUNG*
echo        - Phu hop: Tao nhac co LYRICS dai, Remix/Cover can giu dung cau truc.
echo        - Uu diem: Nao 4B nho loi sieu chuan, hat ro chu. Toc do van rat nhanh.
echo        - Canh bao: KHONG dung de tach Stem (Extract) vi DiT Turbo se sinh rac.
echo.
echo    [3] CHAY MODEL BASE + NAO 1.7B (Chuyen Extract Stem)
echo        - Phu hop: TACH STEM (EXTRACT) - Lay Acapella, Bass, Drum tu nhac co san.
echo        - Uu diem: Am thanh tach cuc sach, giu nguyen chat luong goc.
echo        - Nhuoc diem: Render rat cham (Full 50 buoc). Khong dung de tao loi dai.
echo.
echo    [4] CHAY MODEL BASE + NAO 4B (TRUM CUOI STUDIO)
echo        - Phu hop: Chot file cuoi (MASTERING), xuat ban ca khuc hoan chinh.
echo        - Uu diem: Hoan hao tuyet doi tu phat am den chat luong am thanh sac net.
echo        - Canh bao: Sieu nang va sieu cham. Hay di pha ca phe trong luc cho!
echo.
echo    [5] THOAT
echo.
echo ========================================================================
choice /c 12345 /n /m "=> CHON PHIEN BAN MUON CHAY (1/2/3/4/5): "

if errorlevel 5 goto EXIT
if errorlevel 4 goto RUN_BASE_4B
if errorlevel 3 goto RUN_BASE_17B
if errorlevel 2 goto RUN_TURBO_4B
if errorlevel 1 goto RUN_TURBO_17B
goto MENU

:RUN_TURBO_17B
cls
color 0D
echo.
echo [DANG KHOI DONG] MODEL TURBO + NAO 1.7B...
echo ------------------------------------------------------------------------
uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1 --offload_dit_to_cpu True --quantization int8_weight_only --config_path "D:\ACE-Step-1.5\checkpoints\acestep-v15-turbo" --lm_model_path "D:\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-1.7B"
pause
goto MENU

:RUN_TURBO_4B
cls
color 0A
echo.
echo [DANG KHOI DONG] MODEL TURBO + NAO 4B (CHUAN LOI 100%)...
echo ------------------------------------------------------------------------
uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1 --offload_dit_to_cpu True --quantization int8_weight_only --config_path "D:\ACE-Step-1.5\checkpoints\acestep-v15-turbo" --lm_model_path "D:\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-4B"
pause
goto MENU

:RUN_BASE_17B
cls
color 0E
echo.
echo [DANG KHOI DONG] MODEL BASE + NAO 1.7B (CHUYEN EXTRACT)...
echo ------------------------------------------------------------------------
uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1 --offload_dit_to_cpu True --quantization int8_weight_only --config_path "D:\ACE-Step-1.5\checkpoints\acestep-v15-base" --lm_model_path "D:\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-1.7B"
pause
goto MENU

:RUN_BASE_4B
cls
color 0C
echo.
echo [DANG KHOI DONG] MODEL BASE + NAO 4B (TRUM CUOI STUDIO)...
echo ------------------------------------------------------------------------
uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1 --offload_dit_to_cpu True --quantization int8_weight_only --config_path "D:\ACE-Step-1.5\checkpoints\acestep-v15-base" --lm_model_path "D:\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-4B"
pause
goto MENU

:EXIT
exit