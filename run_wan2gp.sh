#!/usr/bin/env bash
set -e
cd /mnt/e/LTX-Kaggle/Wan2GP
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate wan2gp
python wgp.py --t2v-1-3B --profile 4 --attention sdpa --perc-reserved-mem-max 0.4 --listen --server-port 7860
