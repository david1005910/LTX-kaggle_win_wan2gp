@echo off
title WanGP Smoke Test
wsl.exe -e bash -lc "export PATH=/home/sharkey/anaconda3/bin:$PATH && /mnt/e/LTX-Kaggle/test_wan2gp.sh"
echo.
echo [*] 결과 폴더 열기...
start "" "E:\LTX-Kaggle\Wan2GP\outputs"
pause
