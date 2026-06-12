#!/usr/bin/env bash
# Smoke test: 헤드리스로 t2v_1.3B 짧은 클립 1건 생성 후 결과 폴더 표시.
# 주의: 같은 GPU/VRAM을 쓰므로 7860 서버가 켜져 있으면 먼저 종료해야 함.
set -e

WGP_DIR="/mnt/e/LTX-Kaggle/Wan2GP"
SETTINGS="settings/test_smoke.json"
OUTDIR="$WGP_DIR/outputs"

if pgrep -f "python wgp.py" >/dev/null; then
    echo "[!] 실행 중인 wgp.py 프로세스 발견. VRAM 충돌 방지를 위해 먼저 종료해 주세요:"
    pgrep -af "python wgp.py"
    echo "    예) pkill -f 'python wgp.py'"
    exit 1
fi

cd "$WGP_DIR"
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate wan2gp

echo "[*] Dry-run 검증..."
python wgp.py --process "$SETTINGS" --output-dir "$OUTDIR" --attention sdpa --profile 4 --perc-reserved-mem-max 0.4 --dry-run

echo
echo "[*] 실제 생성 시작 (1.3B / 25프레임 / 15스텝, 첫 실행은 모델 로딩에 5~15분 추가됨)"
python wgp.py --process "$SETTINGS" --output-dir "$OUTDIR" --attention sdpa --profile 4 --perc-reserved-mem-max 0.4

echo
echo "[✓] 완료. 최신 mp4:"
ls -t "$OUTDIR"/*.mp4 2>/dev/null | head -1
