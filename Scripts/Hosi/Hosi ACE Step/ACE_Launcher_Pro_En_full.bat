@echo off
title ACE-STEP 1.5 PRO LAUNCHER - BY GEMINI FOR PRODUCER LA CHI NHAN
color 0B
cls

:MENU
cls
echo ========================================================================
echo               ACE-STEP 1.5 CONTROL CENTER - V3.1 (ULTIMATE)
echo               Exclusively for Producer La Chi Nhan in Can Tho
echo ========================================================================
echo.
echo    [1] RUN MODEL TURBO + 1.7B LM (Standard)
echo        - Best for: Fast beat generation, demo ideas, basic Text-to-Music.
echo        - Pros: Lightweight, super fast render speed (4-8 steps). [8-bit Quantized]
echo        - Cons: May skip words in long songs, incorrect Verse/Chorus structure.
echo        - Warning: DO NOT use for Stem Extraction (Extract).
echo.
echo    [2] RUN MODEL TURBO + 4B LM (100% ACCURATE LYRICS) - *RECOMMENDED*
echo        - Best for: Long LYRICS, Remix/Cover needing exact structure.
echo        - Pros: 4B LM remembers lyrics perfectly, clear vocals. Still very fast.
echo        - Warning: DO NOT use for Stem Extraction (Extract) as DiT Turbo generates artifacts.
echo.
echo    [3] RUN MODEL BASE + 1.7B LM (Stem Extraction Specialist)
echo        - Best for: STEM EXTRACTION (EXTRACT) - Get Acapella, Bass, Drums from audio.
echo        - Pros: Extremely clean extraction, preserves original audio quality.
echo        - Cons: Very slow render (Full 50 steps). Not for long lyrics generation.
echo.
echo    [4] RUN MODEL BASE + 4B LM (ULTIMATE STUDIO MASTER)
echo        - Best for: Finalizing tracks (MASTERING), rendering complete songs.
echo        - Pros: Absolute perfection from pronunciation to crisp audio quality.
echo        - Warning: Extremely heavy and slow. Go make some coffee while waiting!
echo.
echo    [5] EXIT
echo.
echo ========================================================================
choice /c 12345 /n /m "=> CHOOSE A VERSION TO RUN (1/2/3/4/5): "

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
echo [STARTING] MODEL TURBO + 1.7B LM...
echo ------------------------------------------------------------------------
uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1 --offload_dit_to_cpu True --quantization int8_weight_only --config_path "D:\ACE-Step-1.5\checkpoints\acestep-v15-turbo" --lm_model_path "D:\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-1.7B"
pause
goto MENU

:RUN_TURBO_4B
cls
color 0A
echo.
echo [STARTING] MODEL TURBO + 4B LM (100% ACCURATE LYRICS)...
echo ------------------------------------------------------------------------
uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1 --offload_dit_to_cpu True --quantization int8_weight_only --config_path "D:\ACE-Step-1.5\checkpoints\acestep-v15-turbo" --lm_model_path "D:\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-4B"
pause
goto MENU

:RUN_BASE_17B
cls
color 0E
echo.
echo [STARTING] MODEL BASE + 1.7B LM (STEM EXTRACTION SPECIALIST)...
echo ------------------------------------------------------------------------
uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1 --offload_dit_to_cpu True --quantization int8_weight_only --config_path "D:\ACE-Step-1.5\checkpoints\acestep-v15-base" --lm_model_path "D:\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-1.7B"
pause
goto MENU

:RUN_BASE_4B
cls
color 0C
echo.
echo [STARTING] MODEL BASE + 4B LM (ULTIMATE STUDIO MASTER)...
echo ------------------------------------------------------------------------
uv run acestep --port 8001 --enable-api --backend pt --server-name 127.0.0.1 --offload_dit_to_cpu True --quantization int8_weight_only --config_path "D:\ACE-Step-1.5\checkpoints\acestep-v15-base" --lm_model_path "D:\ACE-Step-1.5\checkpoints\acestep-5Hz-lm-4B"
pause
goto MENU

:EXIT
exit