#!/usr/bin/env python3
"""
CivicLens — Test script using official LocateAnythingWorker.
"""
import sys
import time
import json
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

# Add ml-engine to sys.path
repo_root = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(repo_root / "ml-engine"))

# Import src.locate_anything to apply the runtime patches!
import src.locate_anything
from src.locate_anything.locateanything_worker import LocateAnythingWorker


def test_model(image_path: str, output_dir: Path):
    print("\n" + "=" * 60)
    print("  LOADING LocateAnythingWorker")
    print("=" * 60)
    
    # Initialize LocateAnythingWorker using the official model loader
    worker = LocateAnythingWorker(
        model_path="nvidia/LocateAnything-3B",
        device="cuda",
        dtype=src.locate_anything.torch.bfloat16,
    )
    print("  ✅ LocateAnythingWorker initialized and model loaded.")

    # Load input image
    image = Image.open(image_path).convert("RGB")
    orig_w, orig_h = image.size
    print(f"  Image loaded: {image_path} ({orig_w}x{orig_h})")

    # Define the 6 test configurations
    tests = [
        {"id": 1, "type": "detect", "input": ["potholes"]},
        {"id": 2, "type": "detect", "input": ["cracks"]},
        {"id": 3, "type": "detect", "input": ["potholes", "cracks"]},
        {"id": 4, "type": "detect", "input": ["potholes", "cracks", "road damage"]},
        {"id": 5, "type": "ground_multi", "input": "potholes on the road surface"},
        {"id": 6, "type": "ground_multi", "input": "visible cracks in the pavement"},
    ]

    all_results = {}

    for t in tests:
        print("\n" + "-" * 60)
        print(f"  RUNNING TEST {t['id']}: {t['type'].upper()} ({t['input']})")
        print("-" * 60)
        
        t_start = time.perf_counter()
        
        if t["type"] == "detect":
            # Call official detect method
            res = worker.detect(
                image,
                categories=t["input"],
                generation_mode="hybrid",
                max_new_tokens=8192,
            )
        else:
            # Call official ground_multi method
            res = worker.ground_multi(
                image,
                phrase=t["input"],
                generation_mode="hybrid",
                max_new_tokens=8192,
            )
            
        latency_ms = (time.perf_counter() - t_start) * 1000
        raw_answer = res["answer"]
        
        # Parse coordinates using official parse_boxes
        parsed_boxes = LocateAnythingWorker.parse_boxes(raw_answer, orig_w, orig_h)
        
        # Print all required metrics
        print(f"  Method used      : worker.{t['type']}()")
        print(f"  Input            : {t['input']}")
        print(f"  Raw answer       : {raw_answer!r}")
        print(f"  Parsed boxes     : {parsed_boxes}")
        print(f"  Image dimensions : {orig_w}x{orig_h} px")
        print(f"  Number of boxes  : {len(parsed_boxes)}")
        print(f"  Latency          : {latency_ms:.1f} ms")

        # Save result for JSON dump
        all_results[f"test_{t['id']}"] = {
            "method": f"worker.{t['type']}",
            "input": t["input"],
            "raw_answer": raw_answer,
            "parsed_boxes": parsed_boxes,
            "latency_ms": round(latency_ms, 2),
        }

        # Annotate image
        annotated_image = image.copy()
        draw = ImageDraw.Draw(annotated_image)
        for box in parsed_boxes:
            draw.rectangle(
                [box["x1"], box["y1"], box["x2"], box["y2"]],
                outline="red",
                width=4,
            )
            
        # Save annotated image
        stem = Path(image_path).stem
        out_img_path = output_dir / f"{stem}_test_{t['id']}_annotated.jpg"
        annotated_image.save(out_img_path, quality=95)
        print(f"  ✅ Annotated image saved: {out_img_path}")

    # Save JSON results
    out_json_path = output_dir / f"{Path(image_path).stem}_official_results.json"
    with open(out_json_path, "w") as f:
        json.dump(all_results, f, indent=2)
    print(f"\n  ✅ JSON result saved: {out_json_path}")
    print("\n" + "=" * 60)
    print("  ALL TESTS COMPLETED SUCCESSFULLY")
    print("=" * 60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test official LocateAnythingWorker")
    parser.add_argument("--image", default="/teamspace/studios/this_studio/1.webp", help="Path to input image")
    parser.add_argument("--output-dir", default=".", help="Output directory")
    args = parser.parse_args()
    
    test_model(args.image, Path(args.output_dir))
