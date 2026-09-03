#!/usr/bin/env bash
#
# setup.sh — prepare the GPU instance to run the benchmarks.
#
# The AWS Deep Learning AMI already ships with NVIDIA drivers, CUDA, and PyTorch,
# so this mostly verifies the environment and installs the couple of extra bits the
# benchmarks need (matplotlib + Jupyter, if not already present).
#
# Usage (on the instance, after SSH):
#   bash setup.sh
#
set -euo pipefail

echo "==> Checking GPU is visible to the OS..."
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi
else
  echo "WARNING: nvidia-smi not found. Are you on a GPU instance with the DL AMI?"
fi

echo
echo "==> Locating a Python with PyTorch..."
# The DL AMI exposes PyTorch via conda envs (e.g. 'pytorch') or the base python.
PY=python3
if command -v conda >/dev/null 2>&1; then
  # Prefer a conda env whose name contains 'pytorch' if one exists.
  PT_ENV=$(conda env list | awk '/pytorch/{print $1; exit}')
  if [ -n "${PT_ENV:-}" ]; then
    echo "Found conda env: ${PT_ENV}. Activating."
    # shellcheck disable=SC1091
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${PT_ENV}"
    PY=python
  fi
fi

echo
echo "==> Python / PyTorch / CUDA versions:"
"${PY}" - <<'PYEOF'
import torch
print("PyTorch        :", torch.__version__)
print("CUDA available :", torch.cuda.is_available())
if torch.cuda.is_available():
    print("GPU            :", torch.cuda.get_device_name(0))
    print("CUDA (torch)   :", torch.version.cuda)
PYEOF

echo
echo "==> Installing benchmark extras (matplotlib, jupyter) if missing..."
"${PY}" -m pip install --quiet --upgrade matplotlib jupyter

echo
echo "==> Setup complete."
echo "    Run the benchmarks:"
echo "      cd benchmarks"
echo "      ${PY} matmul_benchmark.py"
echo "      ${PY} cnn_benchmark.py"
echo "      ${PY} plot_results.py"
echo
echo "    Or start Jupyter (then use scripts/tunnel.sh from your laptop):"
echo "      jupyter notebook --no-browser --port=8888"
