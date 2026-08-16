# Progress

## 2026-08-12

- Integrated the Hugging Face `best.onnx` model URL into backend settings so Railway can download the model on cold start when it is not present locally.
- Fixed backend ONNX model path resolution so `ml-engine/best.onnx` resolves from the repository root.
- Connected report submission to the ONNX crack detector and now stores real `ai_confidence`, `ai_label`, `ai_severity`, and `ai_detections`.
- Added severity scoring to AI responses so Flutter can show crack type, score, severity, boxes, and detection count.
- Replaced static fallback AI values in integration report responses with real stored ML results.
- Added reverse geocoding from captured latitude/longitude so report address uses a real place name when available.
- Added on-demand historical report analysis for reports that already have an image URL.
- Added `/v1/reports/{report_id}/ai-analysis/retest` for detail-page retesting.
- Added `/v1/reports/ai-analysis/backfill` for batch analysis of older image-backed reports.
- Added backend logs for upload inference, on-demand inference, retest, and backfill so Railway logs show what the model is doing.
- Added a Flutter detail-page "Retest crack detection" button that calls the backend retest endpoint and refreshes the report.

## Notes

- Do not commit this file. It is intentionally kept as a local progress report.

## Verification

- `backend/.venv/bin/python -m compileall -q backend/app` passed.
- `PYTHONPATH=backend DEBUG=true backend/.venv/bin/pytest backend/tests/unit/test_health.py` passed.
- ONNX smoke test loaded `civiclens-crack-detector` and completed inference against `ml-engine/test_road.jpg`.
- Dart format passed on the touched Flutter files.
- Dart analyze completed with existing info-level print/deprecation notes only.
- `git diff --check` passed.

## 2026-08-12 Railway deploy fix

- Railway failed during Uvicorn startup with `ModuleNotFoundError: No module named 'PIL'`.
- Root cause: backend deployment requirements included `onnxruntime` but did not include the image-processing dependencies imported by the AI service/engine.
- Added `numpy` and `Pillow` to `backend/requirements.txt` for Railway builds.

## 2026-08-12 Railway ONNX engine fix

- Railway downloaded the Hugging Face model to `/ml-engine/best.onnx`, then failed with `No module named 'src'`.
- Root cause: the backend Docker image copies only `backend/app`, not the repo-level `ml-engine/src` package, and the old path resolver walked up to `/` in Railway.
- Added `backend/app/modules/ai/onnx_engine.py` so the backend image contains the ONNX runtime engine code.
- Updated ONNX dependency loading to resolve the model under the repo root locally or `/app` in Railway and import the packaged backend engine.
- Removed the static `0.92` report identity confidence fallback from the user reports response.
- Verified backend compile, ONNX smoke inference, health test, and `git diff --check`.
- Fixed Flutter report detail page failing to load AI components due to a 404 from fetch_defect API.
- Updated fetch_defect in backend to fetch real data from DB.
- Added Address/Location card to report detail page in Flutter.

## 2026-08-14

- Designed and integrated the LocateAnything-3B vision-language grounding model workflow with CivicLens.
- Created remote GPU environment scripts under `ml-engine/lightning/`:
  - `gpu_check.py` for VRAM and CUDA verification.
  - `setup_env.sh` and `requirements.txt` for environment configuration.
  - `test_locate_anything.py` for testing prompts, raw outputs, and bounding box localization on real road/bridge images.
- Created `ml-engine/src/locate_anything/__init__.py` providing robust parsing strategies for custom bounding box token sequences.
- Created `ml-engine/locate_serve.py` to expose the 3B model as a persistent FastAPI inference service on a remote GPU.
- Added `LocateAnythingClient` under `backend/app/modules/ai/` to route requests to the remote service.
- Refactored `_run_report_ai_analysis` in the integration router to utilize `AIService.run_detection` and handle both ONNX and LocateAnything engines transparently.
- Switched detection response schema bases from database response schemas to model request schemas to prevent invalid metadata fields.
- Fixed mock errors in auth service tests, ensuring the entire backend test suite passes with 100% success.
