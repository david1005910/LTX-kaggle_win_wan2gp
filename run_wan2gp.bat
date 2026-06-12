@echo off
title WanGP
wsl.exe -e bash -lc "export PATH=/home/sharkey/anaconda3/bin:$PATH && /mnt/e/LTX-Kaggle/run_wan2gp.sh"
pause
