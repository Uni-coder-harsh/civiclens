# CivicLens — LocateAnything-3B Integration Guide

This document describes the end-to-end workflow for integrating `nvidia/LocateAnything-3B`
into CivicLens as a remote GPU inference provider alongside the existing YOLO ONNX model.

## Architecture

```
Flutter app
    ↓
CivicLens FastAPI Backend (Railway)
    ↓  AI_PROVIDER=locateanything
LocateAnythingClient (backend/app/modules/ai/locate_anything_client.py)
    ↓  HTTP POST /detect  +  Bearer token
LocateAnything-3B Inference Service (ml-engine/locate_serve.py)
    ↓  Running on Lightning AI GPU Studio
nvidia/LocateAnything-3B (loaded once at startup)
    ↓
Normalized detection JSON
    ↓  back up the chain
Flutter shows bounding boxes
```

The existing ONNX model remains fully intact as the default (`AI_PROVIDER=onnx`).

---

## Phase-by-Phase Execution

### Phase 1 — Already done: Repository inspection
Existing AI module found at `backend/app/modules/ai/`.
Existing ONNX engine at `ml-engine/src/inference/engine.py` — untouched.

### Phase 2 — Verify Lightning GPU

1. Open **Lightning AI Studio** → attach a GPU (L4 or better recommended, ≥8GB VRAM)
2. Open the Lightning terminal
3. Clone/pull the repo:
   ```bash
   git clone https://github.com/Uni-coder-harsh/civiclens.git
   cd civiclens
   ```
4. Run the GPU diagnostic:
   ```bash
   python ml-engine/lightning/gpu_check.py
   ```
   Expected output:
   ```
   CUDA available: True
   GPU: NVIDIA L4 / T4 / A10G
   VRAM: 22.5GB total, 22.0GB free
   ✅ Sufficient VRAM for LocateAnything-3B
   ```
   If CUDA is unavailable: the diagnostic exits with a clear error.

### Phase 3 — Install dependencies (Lightning)

```bash
bash ml-engine/lightning/setup_env.sh
# or
pip install -r ml-engine/lightning/requirements.txt
```

### Phase 4-9 — Load and test on real image

```bash
# Test with the CivicLens crack image
python ml-engine/lightning/test_locate_anything.py \
    --image /path/to/crack.webp \
    --mode road \
    --annotate

# Run multiple prompts to find best one
python ml-engine/lightning/test_locate_anything.py \
    --image /path/to/crack.webp \
    --mode road \
    --multi-prompt

# Test bridge inspection
python ml-engine/lightning/test_locate_anything.py \
    --image /path/to/bridge.jpg \
    --mode bridge \
    --annotate
```

The script:
- Reports GPU state
- Loads the model and times it
- Prints the **raw model output** (Phase 6 — critical for understanding actual output format)
- Tries 3 parsing strategies for bounding boxes
- Saves annotated image as `{stem}_located.jpg`
- Saves JSON result as `{stem}_result.json`

> ⚠️ If the model outputs text but no bounding boxes are found, **read the raw output**.
> The actual token format must be observed before claiming the parser works.

### Phase 11 — Start the inference service (Lightning)

```bash
export LA_SERVICE_SECRET=change-me-to-something-random
python ml-engine/locate_serve.py

# Access docs at:
# http://<lightning-studio-ip>:8000/docs
```

Health check:
```bash
curl http://localhost:8000/health
```

### Phase 12 — Connect Railway backend to Lightning service

Set these environment variables in Railway:

| Variable | Value |
|---|---|
| `AI_PROVIDER` | `locateanything` |
| `LA_INFERENCE_URL` | `https://<your-lightning-studio-url>:8000` |
| `LA_SERVICE_SECRET` | Same secret as set on Lightning |
| `LA_TIMEOUT_SECONDS` | `60` (adjust for GPU speed) |

To fall back to ONNX: set `AI_PROVIDER=onnx` (or remove the env var).

### Phase 16 — Benchmark

```bash
curl -X POST \
    -H "Authorization: Bearer $LA_SERVICE_SECRET" \
    -F "image=@/path/to/crack.webp" \
    http://localhost:8000/benchmark
```

### Phase 17 — Compare ONNX vs LocateAnything

Run both on the same image:
```bash
# ONNX
python ml-engine/predict.py --image crack.webp --annotate

# LocateAnything
python ml-engine/lightning/test_locate_anything.py --image crack.webp --annotate
```

---

## File Map

| File | Purpose |
|---|---|
| `ml-engine/lightning/gpu_check.py` | Phase 2: GPU diagnostic |
| `ml-engine/lightning/setup_env.sh` | Phase 3: Dependency install |
| `ml-engine/lightning/requirements.txt` | Phase 3: Python deps |
| `ml-engine/lightning/test_locate_anything.py` | Phase 5-10: Real image test |
| `ml-engine/src/locate_anything/__init__.py` | Core engine (load + parse + annotate) |
| `ml-engine/locate_serve.py` | Phase 11: FastAPI service (Lightning) |
| `backend/app/modules/ai/locate_anything_client.py` | Phase 12: Backend HTTP client |
| `backend/app/modules/ai/service.py` | Provider routing (`AI_PROVIDER`) |
| `backend/app/core/config.py` | `AI_PROVIDER`, `LA_INFERENCE_URL`, `LA_SERVICE_SECRET` |

## What is NOT changed

- `ml-engine/best.onnx` — unchanged
- `ml-engine/src/inference/engine.py` — unchanged
- `backend/app/modules/ai/onnx_engine.py` — unchanged
- `backend/app/modules/ai/router.py` — unchanged
- `flutter-app/` — unchanged (already consumes DetectionResult schema)

## Important Notes

### Raw output inspection (Phase 6)

LocateAnything-3B uses custom grounding tokens. The exact format may differ from what's
shown in the paper. The engine tries 3 parsing strategies in order:
1. LocateAnything native `<obj>...</obj><loc>...</loc>` tokens
2. QWen2-VL `<|object_ref_start|>...<|box_start|>...<|box_end|>` tokens  
3. Plain coordinate pattern matching

**If none work**, read `raw_output` in the JSON result and update `_parse_grounding_output`
in `ml-engine/src/locate_anything/__init__.py` with the actual format.

### VRAM requirements

- LocateAnything-3B in bfloat16: ~6-7GB VRAM
- Recommended: L4 (24GB), T4 (16GB), or A10G (24GB) on Lightning
- T4 (16GB) is sufficient and cheaper

### Security

- `LA_SERVICE_SECRET` must be set on **both** Railway and Lightning
- Never commit it — use env vars only
- The `/health` endpoint is public (no auth) for Railway health checks
- The `/detect` and `/benchmark` endpoints require the Bearer token
