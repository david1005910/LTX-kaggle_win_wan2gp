#!/usr/bin/env bash
set -e
PROJECT_DIR="/mnt/e/LTX-Kaggle"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
[ -d Wan2GP ] || git clone https://github.com/deepbeepmeep/Wan2GP.git
cd Wan2GP
source "$(conda info --base)/etc/profile.d/conda.sh"
conda env list | grep -q "^wan2gp " || conda create -n wan2gp python=3.10.9 -y
conda activate wan2gp
python -c "import sys; print('ACTIVE ENV:', sys.executable)"
pip install torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1 --index-url https://download.pytorch.org/whl/test/cu128
sed -i '/^vector[-_]quantize[-_]pytorch[[:space:]]*$/d' requirements.txt
pip install -r requirements.txt
echo "✅ 설치 완료. 실행: bash /mnt/e/LTX-Kaggle/run_wan2gp.sh"
