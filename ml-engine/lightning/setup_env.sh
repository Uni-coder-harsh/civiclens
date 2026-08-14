#!/bin/bash
# CivicLens — Phase 3: Lightning AI Environment Setup
# Run inside Lightning Studio terminal AFTER gpu_check.py passes.
#
# Usage:
#   bash ml-engine/lightning/setup_env.sh
#
set -e

echo "=========================================="
echo " CivicLens — Lightning Environment Setup"
echo "=========================================="

# Ensure we're in the repo root
cd "$(dirname "$0")/../.."
echo "[1/5] Working directory: $(pwd)"

# Upgrade pip
echo "[2/5] Upgrading pip..."
pip install --upgrade pip --quiet

# Core ML dependencies for LocateAnything-3B
echo "[3/5] Installing LocateAnything-3B dependencies..."
pip install \
    "transformers>=4.46.0" \
    "accelerate>=0.34.0" \
    "Pillow>=10.0" \
    "torch>=2.3.0" \
    "torchvision" \
    "sentencepiece" \
    "einops" \
    --quiet

# Inference service dependencies
echo "[4/5] Installing inference service dependencies..."
pip install \
    "fastapi>=0.111.0" \
    "uvicorn[standard]>=0.30.0" \
    "python-multipart" \
    "httpx>=0.27.0" \
    --quiet

# Optional but improves decode speed
echo "[5/5] Installing optional acceleration packages..."
pip install "flash-attn" --no-build-isolation --quiet 2>/dev/null || echo "   flash-attn not available on this GPU/driver, continuing without."

echo "=========================================="
echo " Setup complete."
echo " Run GPU check: python ml-engine/lightning/gpu_check.py"
echo "=========================================="
