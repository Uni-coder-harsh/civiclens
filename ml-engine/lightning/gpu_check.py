#!/usr/bin/env python3
"""
CivicLens — Phase 2: Lightning AI GPU Diagnostic
Run this FIRST on the Lightning Studio to verify the GPU environment
before attempting to load LocateAnything-3B.

Usage (inside Lightning Studio terminal):
    python ml-engine/lightning/gpu_check.py
"""
import sys
import platform

print("=" * 60)
print("  CIVICLENS — LIGHTNING GPU DIAGNOSTIC")
print("=" * 60)
print(f"  Python        : {platform.python_version()}")
print(f"  Platform      : {platform.platform()}")

# ── PyTorch ─────────────────────────────────────────────────────────────────
try:
    import torch
    print(f"  PyTorch       : {torch.__version__}")
    cuda_available = torch.cuda.is_available()
    print(f"  CUDA available: {cuda_available}")
    if cuda_available:
        print(f"  CUDA version  : {torch.version.cuda}")
        gpu_count = torch.cuda.device_count()
        print(f"  GPU count     : {gpu_count}")
        for i in range(gpu_count):
            props = torch.cuda.get_device_properties(i)
            total_vram_gb = props.total_memory / (1024 ** 3)
            free_vram = torch.cuda.mem_get_info(i)
            free_vram_gb = free_vram[0] / (1024 ** 3)
            print(f"  GPU [{i}]        : {props.name}")
            print(f"    Total VRAM  : {total_vram_gb:.2f} GB")
            print(f"    Free VRAM   : {free_vram_gb:.2f} GB")
            if total_vram_gb < 8.0:
                print(f"  ⚠️  WARNING: LocateAnything-3B typically requires >= 8GB VRAM.")
                print(f"     Available: {total_vram_gb:.2f} GB — may not load.")
            else:
                print(f"  ✅ Sufficient VRAM for LocateAnything-3B (7B params bfloat16 ~7GB)")
    else:
        print("  ❌ CUDA NOT AVAILABLE — Cannot run LocateAnything-3B on this machine.")
        print("     Ensure you are in a Lightning GPU Studio with NVIDIA GPU attached.")
        sys.exit(1)
except ImportError:
    print("  ❌ PyTorch not installed. Run: pip install torch")
    sys.exit(1)

# ── Transformers ─────────────────────────────────────────────────────────────
try:
    import transformers
    print(f"  Transformers  : {transformers.__version__}")
except ImportError:
    print("  ⚠️  Transformers not installed. Run: pip install transformers>=4.40.0")

# ── Accelerate ───────────────────────────────────────────────────────────────
try:
    import accelerate
    print(f"  Accelerate    : {accelerate.__version__}")
except ImportError:
    print("  ⚠️  Accelerate not installed. Run: pip install accelerate")

# ── Pillow ───────────────────────────────────────────────────────────────────
try:
    from PIL import Image
    import PIL
    print(f"  Pillow        : {PIL.__version__}")
except ImportError:
    print("  ⚠️  Pillow not installed. Run: pip install Pillow")

# ── Flash attention (optional but good for speed) ────────────────────────────
try:
    import flash_attn
    print(f"  Flash-Attn    : {flash_attn.__version__}")
except ImportError:
    print("  ℹ️  flash_attn not available (optional, improves speed).")

print("=" * 60)
print("  GPU diagnostic complete. Ready to proceed.")
print("=" * 60)
