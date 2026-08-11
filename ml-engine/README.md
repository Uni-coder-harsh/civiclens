# CivicLens ML Engine — Inference

Road and infrastructure defect detection using a trained YOLO11m ONNX model.

## Structure

```
ml-engine/
├── best.onnx                  # Trained YOLO11m model (ONNX, opset 20, ~103 MB)
├── predict.py                 # CLI tool: run inference on any local image
├── test_onnx_inference.py     # Comprehensive automated test suite
├── test_road.jpg              # Sample test image
├── requirements.txt           # Inference-only dependencies
├── outputs/                   # Annotated output images saved here
└── src/
    └── inference/
        ├── __init__.py
        └── engine.py          # CrackONNXInferenceEngine — the core inference class
```

## Detected Classes

| ID | Class Name              | Description                        |
|----|-------------------------|------------------------------------|
| 0  | D00_Longitudinal_Crack  | Cracks running parallel to road    |
| 1  | D10_Transverse_Crack    | Cracks perpendicular to road       |
| 2  | D20_Alligator_Crack     | Interconnected crack network       |
| 3  | D30_Other_Corruption    | Surface degradation, rutting, etc. |
| 4  | D40_Pothole             | Potholes                           |

## Model Info

| Property        | Value                            |
|-----------------|----------------------------------|
| Architecture    | YOLO11m (Ultralytics)            |
| Task            | Object Detection                 |
| Input           | 1 × 3 × 640 × 640 (RGB float32)  |
| Output          | 1 × 9 × 8400                     |
| Runtime         | ONNX Runtime ≥ 1.18              |
| ONNX Opset      | 20                               |
| Model size      | ~103 MB                          |

## CLI Usage

```bash
# Basic detection
python ml-engine/predict.py --image path/to/road.jpg

# With annotation output
python ml-engine/predict.py --image path/to/road.jpg --annotate --output annotated.jpg

# Custom thresholds
python ml-engine/predict.py --image path/to/road.jpg --conf 0.30 --iou 0.45

# JSON-only output (for scripting)
python ml-engine/predict.py --image path/to/road.jpg --json-only
```

## Running the Test Suite

```bash
PYTHONPATH=ml-engine backend/.venv/bin/python3 ml-engine/test_onnx_inference.py
```

## Backend API

The engine is integrated into the FastAPI backend:

```
POST /v1/prediction/detect
Content-Type: multipart/form-data
Authorization: Bearer <token>

file=@road.jpg
```

Response:
```json
{
  "status": "completed",
  "model": { "name": "civiclens-crack-detector", "version": "crack-detector-v1", ... },
  "image": { "width": 1920, "height": 1080 },
  "detections": [
    {
      "class_id": 0,
      "class_name": "D00_Longitudinal_Crack",
      "confidence": 0.87,
      "bounding_box": { "x1": 421, "y1": 183, "x2": 712, "y2": 270, "width": 291, "height": 87 }
    }
  ],
  "detection_count": 1,
  "timing_ms": { "preprocess": 15, "inference": 240, "postprocess": 2, "total": 257 }
}
```

## Inference Pipeline

```
Image bytes (JPEG/PNG/WEBP)
    ↓
Pillow decode + RGB convert
    ↓
Letterbox resize to 640×640  (preserves aspect ratio, pads with grey 114,114,114)
    ↓
Normalize [0, 255] → [0.0, 1.0]
    ↓
HWC → CHW → add batch dim  →  [1, 3, 640, 640] float32
    ↓
ONNX Runtime InferenceSession.run()
    ↓
output0: [1, 9, 8400]  →  transpose  →  [8400, 9]
    ↓
Decode: cx,cy,w,h + 5 class scores per anchor
    ↓
Confidence threshold filter
    ↓
Rescale to original image coordinates
    ↓
Vectorized NMS (per IoU threshold)
    ↓
Structured detection JSON
```
