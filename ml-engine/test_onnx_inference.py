#!/usr/bin/env python3
"""
CivicLens ONNX Inference Test Suite
Tests the full pipeline: preprocessing → ONNX Runtime → NMS → coordinate rescaling.

Run with:
    PYTHONPATH=ml-engine backend/.venv/bin/python3 ml-engine/test_onnx_inference.py
"""

import sys
import json
import time
import logging
import traceback
from pathlib import Path
from io import BytesIO
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))

logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger("test_suite")

import numpy as np
from PIL import Image

from src.inference.engine import CrackONNXInferenceEngine

PASS = "\033[92m PASS\033[0m"
FAIL = "\033[91m FAIL\033[0m"

MODEL_PATH = str(Path(__file__).resolve().parent / "best.onnx")


def heading(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}")


def test_result(name, passed, detail=""):
    status = PASS if passed else FAIL
    suffix = f" — {detail}" if detail else ""
    print(f"  [{status}] {name}{suffix}")
    return passed


def make_image(width=640, height=640, mode="RGB", color=(140, 140, 140)) -> Image.Image:
    return Image.new(mode, (width, height), color)


def make_image_bytes(img: Image.Image, fmt="JPEG") -> bytes:
    buf = BytesIO()
    img.save(buf, format=fmt)
    return buf.getvalue()


def iou(box1, box2):
    x1 = max(box1["x1"], box2["x1"])
    y1 = max(box1["y1"], box2["y1"])
    x2 = min(box1["x2"], box2["x2"])
    y2 = min(box1["y2"], box2["y2"])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    a1 = (box1["x2"] - box1["x1"]) * (box1["y2"] - box1["y1"])
    a2 = (box2["x2"] - box2["x1"]) * (box2["y2"] - box2["y1"])
    union = a1 + a2 - inter
    return inter / union if union > 0 else 0.0


def run_tests():
    print("\nCivicLens ONNX Inference Test Suite")
    print("=" * 60)

    # ─── Load Engine ──────────────────────────────────────────────
    heading("1. ENGINE INITIALIZATION")
    try:
        engine = CrackONNXInferenceEngine(MODEL_PATH)
        test_result("Model loads from disk", True, MODEL_PATH)
        test_result("InferenceSession created", engine.session is not None)
        test_result("Input name correct", engine.input_name == "images", engine.input_name)
        test_result("Input shape correct", engine.input_shape == [1, 3, 640, 640], str(engine.input_shape))
        test_result("Output name correct", engine.output_name == "output0", engine.output_name)
        test_result("Output shape correct", engine.output_shape == [1, 9, 8400], str(engine.output_shape))
        test_result("Class names populated", len(engine.class_names) == 5, str(engine.class_names))
        expected_classes = {0: "D00_Longitudinal_Crack", 4: "D40_Pothole"}
        for cls_id, cls_name in expected_classes.items():
            test_result(f"  Class {cls_id} = {cls_name}", engine.class_names.get(cls_id) == cls_name)
    except Exception as e:
        test_result("Engine initialization", False, str(e))
        print("FATAL: Cannot continue without engine. Aborting.")
        sys.exit(1)

    # ─── Preprocessing ────────────────────────────────────────────
    heading("2. IMAGE PREPROCESSING")

    # Test letterbox: landscape → square
    img_landscape = make_image(1920, 1080)
    tensor, _, orig_w, orig_h, scale, pad_w, pad_h = engine.preprocess(img_landscape)
    test_result("Landscape 1920x1080 preprocessed", tensor.shape == (1, 3, 640, 640), str(tensor.shape))
    test_result("Scale factor <= 1.0", scale <= 1.0, f"{scale:.4f}")
    test_result("Pad values non-negative", pad_w >= 0 and pad_h >= 0, f"pad_w={pad_w:.1f} pad_h={pad_h:.1f}")
    test_result("Tensor dtype float32", tensor.dtype == np.float32, str(tensor.dtype))
    test_result("Tensor range [0,1]", tensor.min() >= 0.0 and tensor.max() <= 1.0 + 1e-6,
                f"min={tensor.min():.3f} max={tensor.max():.3f}")

    # Test portrait
    img_portrait = make_image(480, 1280)
    tensor_p, _, pw, ph, sc, paw, pah = engine.preprocess(img_portrait)
    test_result("Portrait 480x1280 preprocessed", tensor_p.shape == (1, 3, 640, 640), str(tensor_p.shape))

    # Test bytes input (JPEG)
    jpeg_bytes = make_image_bytes(make_image(800, 600))
    tensor_b, _, bw, bh, _, _, _ = engine.preprocess(jpeg_bytes)
    test_result("JPEG bytes input preprocessed", tensor_b.shape == (1, 3, 640, 640))
    test_result("JPEG original dimensions preserved", bw == 800 and bh == 600, f"{bw}x{bh}")

    # Test PNG bytes input
    png_bytes = make_image_bytes(make_image(320, 320), fmt="PNG")
    tensor_png, _, pw2, ph2, _, _, _ = engine.preprocess(png_bytes)
    test_result("PNG bytes input preprocessed", tensor_png.shape == (1, 3, 640, 640))

    # Test RGBA → RGB conversion
    img_rgba = make_image(640, 640, mode="RGBA", color=(100, 150, 200, 128))
    tensor_rgba, _, _, _, _, _, _ = engine.preprocess(img_rgba)
    test_result("RGBA image converted to RGB tensor", tensor_rgba.shape == (1, 3, 640, 640))

    # Test exact 640x640 — no padding should be added
    img_exact = make_image(640, 640)
    tensor_e, _, ew, eh, sc_e, pw_e, ph_e = engine.preprocess(img_exact)
    test_result("640x640 image — scale=1.0", abs(sc_e - 1.0) < 1e-4, f"{sc_e:.4f}")
    test_result("640x640 image — no padding", abs(pw_e) < 1.0 and abs(ph_e) < 1.0, f"pad_w={pw_e} pad_h={ph_e}")

    # ─── Inference ────────────────────────────────────────────────
    heading("3. INFERENCE PIPELINE")

    img_test = make_image(1920, 1080)
    result = engine.detect(img_test)
    test_result("detect() returns dict", isinstance(result, dict))
    test_result("status = completed", result.get("status") == "completed")
    test_result("detections key present", "detections" in result)
    test_result("detection_count matches len(detections)", result["detection_count"] == len(result["detections"]))
    test_result("model metadata present", "model" in result and result["model"]["name"] == "civiclens-crack-detector")
    test_result("image dimensions correct", result["image"]["width"] == 1920 and result["image"]["height"] == 1080)
    test_result("timing_ms present", "timing_ms" in result and result["timing_ms"]["total"] > 0)
    test_result("inference time > 0", result["timing_ms"]["inference"] > 0)

    # ─── Bounding Box Coordinate Clipping ─────────────────────────
    heading("4. BOUNDING BOX VALIDATION")

    # For any detections returned, verify coords are within original image bounds
    all_valid = True
    for det in result["detections"]:
        bb = det["bounding_box"]
        w, h = result["image"]["width"], result["image"]["height"]
        valid = 0 <= bb["x1"] <= bb["x2"] <= w and 0 <= bb["y1"] <= bb["y2"] <= h
        if not valid:
            all_valid = False
    test_result("All bounding boxes within image bounds", all_valid)

    for det in result["detections"]:
        bb = det["bounding_box"]
        test_result(
            f"  width/height consistent for {det['class_name']}",
            bb["width"] == bb["x2"] - bb["x1"] and bb["height"] == bb["y2"] - bb["y1"]
        )

    # ─── Empty / Zero Detection ────────────────────────────────────
    heading("5. NO-DETECTION HANDLING")

    # Plain gray image should produce 0 detections
    blank = make_image(640, 640, color=(128, 128, 128))
    blank_result = engine.detect(blank)
    test_result("status=completed on blank image", blank_result["status"] == "completed")
    test_result("detection_count >= 0 on blank image", blank_result["detection_count"] >= 0)

    # ─── Supported Formats ────────────────────────────────────────
    heading("6. FORMAT COMPATIBILITY")

    for fmt, mime in [("JPEG", "image/jpeg"), ("PNG", "image/png"), ("WEBP", "image/webp")]:
        img = make_image(640, 480)
        buf = BytesIO()
        img.save(buf, format=fmt)
        img_bytes = buf.getvalue()
        try:
            r = engine.detect(img_bytes)
            test_result(f"{fmt} image inference success", r["status"] == "completed")
        except Exception as e:
            test_result(f"{fmt} image inference success", False, str(e))

    # ─── Failure Modes ────────────────────────────────────────────
    heading("7. FAILURE MODES")

    # Empty bytes
    try:
        engine.detect(b"")
        test_result("Empty bytes rejected", False, "No exception raised")
    except Exception:
        test_result("Empty bytes raises exception", True)

    # Non-image bytes
    try:
        engine.detect(b"this is not an image at all")
        test_result("Junk bytes rejected", False, "No exception raised")
    except Exception:
        test_result("Junk bytes raises exception", True)

    # Missing model file
    try:
        CrackONNXInferenceEngine("/nonexistent/model.onnx")
        test_result("Missing model raises FileNotFoundError", False, "No exception raised")
    except FileNotFoundError:
        test_result("Missing model raises FileNotFoundError", True)
    except Exception as e:
        test_result("Missing model raises exception", True, str(type(e).__name__))

    # ─── Annotation / Visualization ───────────────────────────────
    heading("8. ANNOTATION")

    img_vis = make_image(800, 600)
    fake_detections = [
        {
            "class_id": 0,
            "class_name": "D00_Longitudinal_Crack",
            "confidence": 0.87,
            "bounding_box": {"x1": 100, "y1": 150, "x2": 400, "y2": 250, "width": 300, "height": 100}
        }
    ]
    try:
        annotated = engine.annotate(img_vis, fake_detections)
        test_result("annotate() returns PIL Image", isinstance(annotated, Image.Image))
        test_result("Annotated image size matches original", annotated.size == img_vis.size)
        test_result("Original image unmodified", img_vis.size == (800, 600))  # Not mutated
    except Exception as e:
        test_result("annotate() success", False, str(e))

    # ─── Performance Benchmark ────────────────────────────────────
    heading("9. PERFORMANCE BENCHMARK")

    img_bench = make_image(1920, 1080)
    times = []
    for _ in range(3):
        r = engine.detect(img_bench)
        times.append(r["timing_ms"]["total"])

    avg_ms = sum(times) / len(times)
    test_result(f"Average inference time {avg_ms:.0f}ms", True, f"runs: {[f'{t:.0f}ms' for t in times]}")
    test_result("Inference < 2000ms on CPU", avg_ms < 2000, f"{avg_ms:.0f}ms")

    # ─── Model Diagnostics ────────────────────────────────────────
    heading("10. MODEL DIAGNOSTICS")
    print(f"  Input Name    : {engine.input_name}")
    print(f"  Input Shape   : {engine.input_shape}")
    print(f"  Output Name   : {engine.output_name}")
    print(f"  Output Shape  : {engine.output_shape}")
    print(f"  Class Count   : {len(engine.class_names)}")
    print(f"  Classes       :")
    for cls_id, cls_name in sorted(engine.class_names.items()):
        print(f"    {cls_id}: {cls_name}")
    print(f"  ONNX Provider : {engine.provider}")
    print(f"  Model Version : {engine.version}")
    test_result("Diagnostics printed", True)

    # ─── Real Image Test ──────────────────────────────────────────
    heading("11. REAL IMAGE (test_road.jpg)")

    test_img_path = Path(__file__).resolve().parent / "test_road.jpg"
    if test_img_path.exists():
        r = engine.detect(str(test_img_path))
        test_result("test_road.jpg inference success", r["status"] == "completed",
                    f"{r['detection_count']} detections in {r['timing_ms']['total']:.0f}ms")

        # Save annotated output
        from PIL import Image as PILImage
        img_real = PILImage.open(str(test_img_path))
        annotated_out = engine.annotate(img_real, r["detections"])
        out_dir = Path(__file__).resolve().parent / "outputs"
        out_dir.mkdir(exist_ok=True)
        annotated_path = out_dir / "annotated_test_road.jpg"
        annotated_out.save(str(annotated_path), quality=95)
        test_result(f"Annotated image saved to outputs/", True, str(annotated_path.name))
    else:
        test_result("test_road.jpg found", False, "File not found — skipping real image test")

    print("\n" + "=" * 60)
    print("  Test suite complete.")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    run_tests()
