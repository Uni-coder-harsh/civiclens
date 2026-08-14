#!/usr/bin/env python3
"""
CivicLens — Phase 5-9: LocateAnything-3B Real Image Test Script
Run this on Lightning Studio AFTER setup_env.sh to verify the model works
on real CivicLens images before building the inference service.

Usage:
    python ml-engine/lightning/test_locate_anything.py --image /path/to/crack.jpg
    python ml-engine/lightning/test_locate_anything.py --image /path/to/image.webp --mode road
    python ml-engine/lightning/test_locate_anything.py --image img.jpg --multi-prompt

Output:
    - Prints raw model output (Phase 6)
    - Prints parsed detections (Phase 8)
    - Saves annotated image for visual validation (Phase 9)
    - Saves JSON result (Phase 10)
"""
import sys
import json
import argparse
import logging
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

# Allow running from repo root or ml-engine/lightning/
repo_root = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(repo_root / "ml-engine"))


def main():
    parser = argparse.ArgumentParser(description="Test LocateAnything-3B on a real CivicLens image")
    parser.add_argument("--image", "-i", required=True, help="Path to input image")
    parser.add_argument("--mode", default="road", choices=["road", "bridge", "general_infrastructure"],
                        help="Inspection mode — selects appropriate prompts")
    parser.add_argument("--prompt", "-p", default=None, help="Override prompt text")
    parser.add_argument("--multi-prompt", action="store_true",
                        help="Run multiple prompts and merge detections (Phase 7)")
    parser.add_argument("--annotate", "-a", action="store_true", default=True,
                        help="Save annotated image (default: True)")
    parser.add_argument("--output-dir", "-o", default=".", help="Directory to save outputs")
    parser.add_argument("--device", default="cuda", help="Device: cuda or cpu")
    args = parser.parse_args()

    image_path = Path(args.image)
    if not image_path.exists():
        print(f"❌ Image not found: {image_path}", file=sys.stderr)
        sys.exit(1)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # ── Phase 2/3: GPU check ──────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("  PHASE 2: GPU ENVIRONMENT CHECK")
    print("=" * 60)
    try:
        import torch
        print(f"  PyTorch   : {torch.__version__}")
        print(f"  CUDA      : {torch.cuda.is_available()}")
        if torch.cuda.is_available():
            props = torch.cuda.get_device_properties(0)
            free, total = torch.cuda.mem_get_info(0)
            print(f"  GPU       : {props.name}")
            print(f"  VRAM      : {total/(1024**3):.1f}GB total, {free/(1024**3):.1f}GB free")
        elif args.device == "cuda":
            print("  ❌ CUDA not available. Use --device cpu (slow, for testing only)")
            sys.exit(1)
    except ImportError:
        print("  ❌ PyTorch not installed. Run: bash ml-engine/lightning/setup_env.sh")
        sys.exit(1)

    # ── Phase 4: Load model ───────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("  PHASE 4: LOADING LocateAnything-3B")
    print("=" * 60)
    from src.locate_anything import LocateAnythingEngine
    engine = LocateAnythingEngine(device=args.device)
    engine.load()
    print(f"  ✅ Model loaded in {engine._load_time_ms:.0f}ms")

    # ── Phase 5-6: Run on real image and inspect raw output ───────────────────
    print("\n" + "=" * 60)
    print(f"  PHASE 5-6: REAL IMAGE INFERENCE")
    print(f"  Image : {image_path}")
    print(f"  Mode  : {args.mode}")
    print("=" * 60)

    if args.multi_prompt:
        result = engine.detect_multi_prompt(str(image_path), inspection_mode=args.mode)
        print(f"\n  Prompts used: {result.get('prompts_used', [])}")
    else:
        result = engine.detect(str(image_path), prompt=args.prompt, inspection_mode=args.mode)
        print(f"\n  Prompt used: {result.get('prompt_used', '')}")

    # ── Phase 6: Raw output inspection ───────────────────────────────────────
    print("\n" + "-" * 60)
    print("  PHASE 6: RAW MODEL OUTPUT")
    print("-" * 60)
    if "raw_output" in result:
        print(f"  {result['raw_output']}")
    elif "raw_outputs" in result:
        for p, o in result["raw_outputs"].items():
            print(f"  [{p}]\n  {o}\n")

    # ── Phase 8: Parsed detections ────────────────────────────────────────────
    print("\n" + "-" * 60)
    print("  PHASE 8: PARSED DETECTIONS")
    print("-" * 60)
    print(f"  Total detections: {result['detection_count']}")
    print(f"  Image size      : {result['image']['width']}x{result['image']['height']} px")
    print(f"  Timing          : {result['timing_ms']['total']:.1f}ms total")

    if result["detection_count"] == 0:
        print("\n  ⚠️  No detections. Check raw output above.")
        print("     Possible causes:")
        print("     - Model produced text without bounding box tokens")
        print("     - Prompt needs adjustment")
        print("     - Model format differs — inspect raw output closely")
    else:
        for i, det in enumerate(result["detections"], 1):
            bb = det["bounding_box"]
            score = det.get("grounding_score") or det.get("confidence", "N/A")
            print(f"\n  [{i}] {det.get('label', det.get('class_name', 'damage'))}")
            print(f"       Box   : x1={bb['x1']} y1={bb['y1']} x2={bb['x2']} y2={bb['y2']}")
            print(f"       Size  : {bb['width']}x{bb['height']} px")
            if score != "N/A":
                print(f"       Score : {score}")

    # ── Phase 9: Annotated image ──────────────────────────────────────────────
    if args.annotate:
        print("\n" + "-" * 60)
        print("  PHASE 9: ANNOTATED IMAGE")
        print("-" * 60)
        from PIL import Image
        annotated = engine.annotate(str(image_path), result["detections"])
        out_img = output_dir / f"{image_path.stem}_located.jpg"
        annotated.save(str(out_img), quality=95)
        print(f"  ✅ Annotated image saved: {out_img}")

    # ── Phase 10: Save normalized JSON ───────────────────────────────────────
    out_json = output_dir / f"{image_path.stem}_result.json"
    # Remove raw output from saved JSON (too verbose for storage)
    save_result = {k: v for k, v in result.items() if k not in ("raw_output", "raw_outputs")}
    out_json.write_text(json.dumps(save_result, indent=2))
    print(f"\n  ✅ JSON result saved: {out_json}")

    print("\n" + "=" * 60)
    print("  TEST COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    main()
