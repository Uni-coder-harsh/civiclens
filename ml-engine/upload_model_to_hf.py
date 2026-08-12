#!/usr/bin/env python3
"""
Upload best.onnx to Hugging Face Hub (free, unlimited size, ML-native CDN).

Usage:
    pip install huggingface_hub
    huggingface-cli login     # enter your HF token from https://huggingface.co/settings/tokens
    python3 upload_model_to_hf.py

After upload, the direct download URL will be:
    https://huggingface.co/{your-username}/civiclens-crack-detector/resolve/main/best.onnx

Set MODEL_DOWNLOAD_URL to that URL on Railway.
"""

import sys
from pathlib import Path

MODEL_PATH = Path(__file__).resolve().parent / "best.onnx"
REPO_ID    = "Uni-coder-harsh/civiclens-crack-detector"   # HF repo to create

try:
    from huggingface_hub import HfApi, create_repo
except ImportError:
    print("Installing huggingface_hub...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "huggingface_hub"])
    from huggingface_hub import HfApi, create_repo

api = HfApi()

print(f"\n{'='*60}")
print("  CIVICLENS ONNX MODEL — HUGGING FACE UPLOAD")
print(f"{'='*60}\n")

if not MODEL_PATH.exists():
    print(f"ERROR: Model not found at {MODEL_PATH}")
    sys.exit(1)

# Create repo if it doesn't exist
print(f"Creating/verifying HF repo: {REPO_ID} ...")
try:
    create_repo(repo_id=REPO_ID, repo_type="model", exist_ok=True)
    print(f"  Repo ready: https://huggingface.co/{REPO_ID}")
except Exception as e:
    print(f"  Repo create note: {e}")

# Upload model file
print(f"\nUploading {MODEL_PATH.name} ({MODEL_PATH.stat().st_size // 1024 // 1024} MB) ...")
print("  (This may take 1-2 minutes on a slow connection)")

url = api.upload_file(
    path_or_fileobj=str(MODEL_PATH),
    path_in_repo="best.onnx",
    repo_id=REPO_ID,
    repo_type="model",
    commit_message="Upload CivicLens YOLO11m ONNX crack detection model",
)

download_url = f"https://huggingface.co/{REPO_ID}/resolve/main/best.onnx"

print(f"\n{'='*60}")
print("  ✅ UPLOAD COMPLETE")
print(f"{'='*60}")
print(f"\n  HF Repo   : https://huggingface.co/{REPO_ID}")
print(f"  Direct URL: {download_url}")
print(f"\n  Set these env vars on Railway:")
print(f"  MODEL_DOWNLOAD_URL={download_url}")
print(f"  MODEL_PATH=/tmp/best.onnx")
print(f"\n{'='*60}\n")
