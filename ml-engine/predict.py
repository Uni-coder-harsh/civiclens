#!/usr/bin/env python3
"""
CivicLens Crack Detection CLI Predictor
Runs inference on a local image using the ONNX model — no server required.

Usage:
    python predict.py --image path/to/road.jpg
    python predict.py --image path/to/road.jpg --conf 0.30 --iou 0.45
    python predict.py --image path/to/road.jpg --annotate --output annotated.jpg
"""

import argparse
import json
import os
import sys
import logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Allow running from the ml-engine dir directly
sys.path.insert(0, str(Path(__file__).resolve().parent))

from src.inference.engine import CrackONNXInferenceEngine

DEFAULT_MODEL_PATH = str(Path(__file__).resolve().parent / "best.onnx")


def main():
    parser = argparse.ArgumentParser(description="CivicLens ONNX Crack Detection Inference")
    parser.add_argument("--image", "-i", required=True, help="Path to input image (JPEG/PNG/WEBP)")
    parser.add_argument("--model", "-m", default=DEFAULT_MODEL_PATH, help="Path to best.onnx model")
    parser.add_argument("--conf", "-c", type=float, default=0.25, help="Confidence threshold (default: 0.25)")
    parser.add_argument("--iou", type=float, default=0.45, help="IoU threshold for NMS (default: 0.45)")
    parser.add_argument("--annotate", "-a", action="store_true", help="Generate annotated output image")
    parser.add_argument("--output", "-o", default=None, help="Path to save annotated image")
    parser.add_argument("--json-only", action="store_true", help="Print raw JSON only")
    args = parser.parse_args()

    if not os.path.exists(args.image):
        print(f"Error: Image not found: {args.image}", file=sys.stderr)
        sys.exit(1)

    engine = CrackONNXInferenceEngine(
        model_path=args.model,
        conf_threshold=args.conf,
        iou_threshold=args.iou,
    )

    result = engine.detect(args.image)

    if args.json_only:
        print(json.dumps(result, indent=2))
        return

    print("\n" + "=" * 60)
    print("  CIVICLENS CRACK DETECTION RESULT")
    print("=" * 60)
    print(f"  Status        : {result['status']}")
    print(f"  Model         : {result['model']['name']} ({result['model']['version']})")
    print(f"  Image Size    : {result['image']['width']} x {result['image']['height']} px")
    print(f"  Detections    : {result['detection_count']}")
    print(f"  Timing        : {result['timing_ms']['total']:.1f} ms total")
    print(f"    Preprocess  : {result['timing_ms']['preprocess']:.1f} ms")
    print(f"    Inference   : {result['timing_ms']['inference']:.1f} ms")
    print(f"    Postprocess : {result['timing_ms']['postprocess']:.1f} ms")
    print("-" * 60)

    if result["detection_count"] == 0:
        print("  No cracks or road defects detected above threshold.")
    else:
        for i, det in enumerate(result["detections"], 1):
            bb = det["bounding_box"]
            print(f"  [{i}] {det['class_name']}")
            print(f"      Confidence : {det['confidence'] * 100:.1f}%")
            print(f"      Bounding   : x1={bb['x1']} y1={bb['y1']} x2={bb['x2']} y2={bb['y2']}")
            print(f"      Size       : {bb['width']} x {bb['height']} px")
    print("=" * 60 + "\n")

    if args.annotate or args.output:
        from PIL import Image
        annotated = engine.annotate(args.image, result["detections"])

        if args.output:
            out_path = args.output
        else:
            stem = Path(args.image).stem
            out_path = str(Path(args.image).parent / f"{stem}_annotated.jpg")

        annotated.save(out_path, quality=95)
        print(f"  Annotated image saved to: {out_path}")


if __name__ == "__main__":
    main()
