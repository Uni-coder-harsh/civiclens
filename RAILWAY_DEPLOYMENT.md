# Railway Production Deployment Guide
# CivicLens Backend + ONNX Model

## The Problem
Supabase free tier has a 50 MB file size limit.
best.onnx is ~99 MB — too large for Supabase Storage free tier.

## Solution: GitHub Releases (free, 2GB limit per file)

### Step 1: Create a GitHub Personal Access Token
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Scopes needed: `repo` (full)
4. Copy the token

### Step 2: Upload best.onnx to GitHub Releases

Option A — Using the upload script (no gh CLI needed):
```bash
export GITHUB_TOKEN=ghp_your_token_here
python3 ml-engine/upload_model_to_github.py
```

Option B — Using gh CLI (after installing):
```bash
gh auth login
gh release create v1.0.0-model ml-engine/best.onnx \
  --title "CivicLens ONNX Model v1.0" \
  --notes "YOLO11m crack detection model (99MB)"
```

After upload, you'll get a URL like:
```
https://github.com/Uni-coder-harsh/civiclens/releases/download/v1.0.0-model/best.onnx
```

### Step 3: Set Railway Environment Variables

In your Railway service dashboard → Variables, add:

| Variable | Value |
|---|---|
| `MODEL_DOWNLOAD_URL` | `https://github.com/Uni-coder-harsh/civiclens/releases/download/v1.0.0-model/best.onnx` |
| `MODEL_PATH` | `/tmp/best.onnx` |
| `MODEL_PROVIDER` | `CPUExecutionProvider` |
| `MODEL_CONFIDENCE_THRESHOLD` | `0.25` |
| `MODEL_IOU_THRESHOLD` | `0.45` |

### Step 4: What Happens on Railway Cold Start

1. Backend starts
2. `get_inference_engine()` is called on first `/detect` request
3. `MODEL_PATH` (`/tmp/best.onnx`) does not exist
4. `MODEL_DOWNLOAD_URL` is set → downloads from GitHub Releases (~30s for 99MB on Railway)
5. Model is loaded into memory
6. All subsequent requests use the cached in-memory session (~250ms inference)

Note: `/tmp` is ephemeral on Railway — model re-downloads on each container restart.
If you want to avoid re-downloads, use Railway's Persistent Volume (mount at `/data/models`
and set `MODEL_PATH=/data/models/best.onnx`).

## Alternative: Railway Persistent Volume (avoid re-download)

1. In Railway → your service → Settings → Volumes
2. Add volume mounted at `/data/models`
3. Upload best.onnx once using:
   ```bash
   railway run -- python3 -c "
   import urllib.request
   url = 'https://github.com/.../best.onnx'
   urllib.request.urlretrieve(url, '/data/models/best.onnx')
   print('Done')
   "
   ```
4. Set `MODEL_PATH=/data/models/best.onnx` and remove `MODEL_DOWNLOAD_URL`
5. Model persists across restarts — zero cold-start penalty

## Local Development

No changes needed. The model is already at `ml-engine/best.onnx`.
Backend finds it automatically via `MODEL_PATH=ml-engine/best.onnx` (default).
