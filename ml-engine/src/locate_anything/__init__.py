"""
CivicLens — LocateAnything-3B Inference Engine
src/locate_anything/engine.py

This module implements the LocateAnything-3B vision-language grounding model
as a CivicLens inference provider. It is designed to run on a remote GPU
(Lightning AI) and is NOT meant to run inside the FastAPI process on Railway.

Architecture:
    Lightning GPU (this file) → JSON response → FastAPI backend → Flutter

The ONNX engine (src/inference/engine.py) remains fully intact as a fallback.
"""
from __future__ import annotations

import re
import time
import logging
from typing import Any

logger = logging.getLogger(__name__)

# ── Model configuration ───────────────────────────────────────────────────────
MODEL_ID = "nvidia/LocateAnything-3B"

# Inspection-mode prompts — empirically chosen for CivicLens use cases
PROMPTS = {
    "road": [
        "Locate all visible cracks in this road image.",
        "Locate all visible potholes in this image.",
        "Locate all visible road surface damage.",
        "Locate each distinct crack or damaged region.",
    ],
    "bridge": [
        "Locate visible cracks, spalling, exposed reinforcement, and other concrete damage.",
        "Locate all visible concrete cracks in this bridge image.",
        "Locate all visible structural damage.",
    ],
    "general_infrastructure": [
        "Locate all visible damage in this infrastructure image.",
        "Locate all visible cracks or deterioration.",
    ],
}

DEFAULT_PROMPT = "Locate all visible cracks and road damage in this image."


class LocateAnythingEngine:
    """
    Wraps nvidia/LocateAnything-3B for CivicLens crack/damage localization.
    Loaded ONCE at service startup and kept in GPU memory.
    """

    def __init__(self, device: str = "cuda", dtype_str: str = "bfloat16"):
        self.model_id = MODEL_ID
        self.device = device
        self.dtype_str = dtype_str
        self._model = None
        self._processor = None
        self._loaded = False
        self._load_time_ms: float = 0.0

    # ── Lifecycle ─────────────────────────────────────────────────────────────

    def load(self) -> None:
        """
        Load the model and processor. Call this at service startup.
        Raises RuntimeError if CUDA is unavailable.
        """
        import torch
        from transformers import AutoProcessor, AutoModel
        import transformers.modeling_utils
        import inspect

        if not getattr(transformers.modeling_utils.PreTrainedModel.__init__, "_is_patched", False):
            original_init = transformers.modeling_utils.PreTrainedModel.__init__
            def patched_init(self, *args, **kwargs):
                original_method = getattr(self, "_check_and_adjust_attn_implementation", None)
                if original_method is not None:
                    def safe_check_and_adjust(*m_args, **m_kwargs):
                        try:
                            sig = inspect.signature(original_method)
                            has_kwargs = any(p.kind == inspect.Parameter.VAR_KEYWORD for p in sig.parameters.values())
                            has_allow_all = "allow_all_kernels" in sig.parameters
                            if not (has_kwargs or has_allow_all) and "allow_all_kernels" in m_kwargs:
                                m_kwargs.pop("allow_all_kernels", None)
                        except Exception:
                            pass
                        return original_method(*m_args, **m_kwargs)
                    self._check_and_adjust_attn_implementation = safe_check_and_adjust
                return original_init(self, *args, **kwargs)
            patched_init._is_patched = True
            transformers.modeling_utils.PreTrainedModel.__init__ = patched_init

            # Patch get_expanded_tied_weights_keys to convert legacy list keys to dict keys
            original_get_tied_keys = transformers.modeling_utils.PreTrainedModel.get_expanded_tied_weights_keys
            def patched_get_tied_keys(self, *args, **kwargs):
                if hasattr(self, "_tied_weights_keys"):
                    val = self._tied_weights_keys
                    if isinstance(val, list):
                        tied_dict = {}
                        # Dynamically find the input embedding parameter name
                        embed_name = "model.embed_tokens.weight"
                        try:
                            for name, _ in self.named_parameters():
                                if "embed_tokens.weight" in name or "wte.weight" in name:
                                    embed_name = name
                                    break
                        except Exception:
                            pass
                        for k in val:
                            if k == "lm_head.weight":
                                tied_dict[k] = embed_name
                            else:
                                tied_dict[k] = k
                        self.__dict__["_tied_weights_keys"] = tied_dict
                return original_get_tied_keys(self, *args, **kwargs)
            transformers.modeling_utils.PreTrainedModel.get_expanded_tied_weights_keys = patched_get_tied_keys

            # Patch all_tied_weights_keys property on PreTrainedModel to dynamically resolve on demand
            # if post_init is skipped or overridden by custom architectures.
            def get_all_tied_keys(self):
                if "all_tied_weights_keys" not in self.__dict__:
                    try:
                        self.__dict__["all_tied_weights_keys"] = self.get_expanded_tied_weights_keys(all_submodels=False)
                    except Exception:
                        self.__dict__["all_tied_weights_keys"] = []
                return self.__dict__["all_tied_weights_keys"]

            def set_all_tied_keys(self, val):
                self.__dict__["all_tied_weights_keys"] = val

            transformers.modeling_utils.PreTrainedModel.all_tied_weights_keys = property(
                fget=get_all_tied_keys,
                fset=set_all_tied_keys
            )

        # Patch Qwen2Config to support rope_theta property to prevent AttributeError
        # when NVIDIA's custom model files read it from Qwen2Config.
        try:
            from transformers import Qwen2Config
            # Use getattr/setattr wrapped in property to handle both reading and initialization writes
            Qwen2Config.rope_theta = property(
                fget=lambda self: getattr(self, "_rope_theta_val", 1000000.0),
                fset=lambda self, val: setattr(self, "_rope_theta_val", val)
            )
        except Exception as e:
            logger.warning(f"[LocateAnything] Failed to patch Qwen2Config: {e}")

        # Patch DynamicCache to restore both to_legacy_cache and from_legacy_cache methods for backward compatibility
        try:
            import transformers.cache_utils
            if not hasattr(transformers.cache_utils.DynamicCache, "to_legacy_cache"):
                def to_legacy_cache(self):
                    legacy_cache = ()
                    if hasattr(self, "layers"):
                        for layer in self.layers:
                            legacy_cache += ((layer.keys, layer.values),)
                    else:
                        for layer_idx in range(len(getattr(self, "key_cache", []))):
                            legacy_cache += ((self.key_cache[layer_idx], self.value_cache[layer_idx]),)
                    return legacy_cache
                transformers.cache_utils.DynamicCache.to_legacy_cache = to_legacy_cache

            if not hasattr(transformers.cache_utils.DynamicCache, "from_legacy_cache"):
                @classmethod
                def from_legacy_cache(cls, past_key_values=None):
                    cache = cls()
                    if past_key_values is not None:
                        if hasattr(cache, "layers"):
                            from transformers.cache_utils import DynamicLayer
                            cache.layers = []
                            for layer_idx, (key, value) in enumerate(past_key_values):
                                layer = DynamicLayer()
                                layer.keys = key
                                layer.values = value
                                layer.is_initialized = True
                                layer.dtype = key.dtype
                                layer.device = key.device
                                cache.layers.append(layer)
                        else:
                            cache.key_cache = [layer[0] for layer in past_key_values]
                            cache.value_cache = [layer[1] for layer in past_key_values]
                    return cache
                transformers.cache_utils.DynamicCache.from_legacy_cache = from_legacy_cache
        except Exception as e:
            logger.warning(f"[LocateAnything] Failed to patch DynamicCache: {e}")

        if self._loaded:
            logger.info("[LocateAnything] Already loaded, skipping.")
            return

        if self.device == "cuda" and not torch.cuda.is_available():
            raise RuntimeError(
                "CUDA is not available. LocateAnything-3B requires a GPU. "
                "Run gpu_check.py to diagnose."
            )

        dtype = torch.bfloat16 if self.dtype_str == "bfloat16" else torch.float16
        logger.info(f"[LocateAnything] Loading {self.model_id} on {self.device} ({self.dtype_str})...")
        t0 = time.perf_counter()

        self._processor = AutoProcessor.from_pretrained(
            self.model_id,
            trust_remote_code=True,
        )
        self._model = AutoModel.from_pretrained(
            self.model_id,
            torch_dtype=dtype,
            device_map="auto" if self.device == "cuda" else self.device,
            trust_remote_code=True,
        )
        if hasattr(self._processor, "tokenizer"):
            self._model.tokenizer = self._processor.tokenizer
        self._model.eval()
        self._load_time_ms = (time.perf_counter() - t0) * 1000
        self._loaded = True
        logger.info(f"[LocateAnything] Loaded in {self._load_time_ms:.0f}ms")

    def is_loaded(self) -> bool:
        return self._loaded

    # ── Core inference ────────────────────────────────────────────────────────

    def detect(
        self,
        image_input: Any,
        prompt: str | None = None,
        inspection_mode: str = "road",
    ) -> dict[str, Any]:
        """
        Run LocateAnything-3B on a single image.

        Args:
            image_input: PIL.Image, file path (str), or raw bytes.
            prompt: Override the default prompt for this inspection mode.
            inspection_mode: "road" | "bridge" | "general_infrastructure"

        Returns:
            Normalized CivicLens detection dict (same contract as ONNX engine).
        """
        import torch
        from PIL import Image
        from io import BytesIO

        if not self._loaded:
            raise RuntimeError("Model not loaded. Call engine.load() first.")

        # ── Load image ────────────────────────────────────────────────────────
        if isinstance(image_input, bytes):
            pil_img = Image.open(BytesIO(image_input)).convert("RGB")
        elif isinstance(image_input, str):
            pil_img = Image.open(image_input).convert("RGB")
        elif hasattr(image_input, "mode"):
            pil_img = image_input.convert("RGB")
        else:
            raise ValueError(f"Unsupported image input type: {type(image_input)}")

        orig_w, orig_h = pil_img.size

        # ── Select prompt ─────────────────────────────────────────────────────
        active_prompt = prompt or PROMPTS.get(inspection_mode, [DEFAULT_PROMPT])[0]
        logger.info(f"[LocateAnything] Running inference | {orig_w}x{orig_h} | prompt: {active_prompt!r}")

        t_start = time.perf_counter()

        # ── Preprocess ────────────────────────────────────────────────────────
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image"},
                    {"type": "text", "text": active_prompt}
                ]
            }
        ]
        text_prompt = self._processor.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )

        inputs = self._processor(
            text=text_prompt,
            images=[pil_img],
            return_tensors="pt",
        ).to(self.device)
        t_prep = time.perf_counter()

        # ── Inference ─────────────────────────────────────────────────────────
        with torch.inference_mode():
            output_ids = self._model.generate(
                **inputs,
                max_new_tokens=512,
                do_sample=False,
                use_cache=True,
                tokenizer=self._processor.tokenizer,
            )
        t_infer = time.perf_counter()

        # NVIDIA's generate() returns the decoded output string directly
        raw_text = output_ids

        logger.info(f"[LocateAnything] Raw output: {raw_text[:500]!r}")

        # ── Parse grounding output ────────────────────────────────────────────
        detections = self._parse_grounding_output(raw_text, orig_w, orig_h, active_prompt)
        t_post = time.perf_counter()

        return {
            "status": "completed",
            "model": {
                "name": "LocateAnything-3B",
                "version": MODEL_ID,
                "runtime": "transformers",
                "provider": self.device,
            },
            "image": {
                "width": orig_w,
                "height": orig_h,
            },
            "detections": detections,
            "detection_count": len(detections),
            "raw_output": raw_text,  # preserved for debugging
            "prompt_used": active_prompt,
            "timing_ms": {
                "preprocess": round((t_prep - t_start) * 1000, 2),
                "inference": round((t_infer - t_prep) * 1000, 2),
                "postprocess": round((t_post - t_infer) * 1000, 2),
                "total": round((t_post - t_start) * 1000, 2),
            },
        }

    # ── Multi-prompt evaluation ───────────────────────────────────────────────

    def detect_multi_prompt(
        self,
        image_input: Any,
        inspection_mode: str = "road",
        max_prompts: int = 2,
    ) -> dict[str, Any]:
        """
        Run multiple prompts on the same image and merge unique detections.
        Useful during evaluation to find which prompts work best.
        """
        prompts = PROMPTS.get(inspection_mode, [DEFAULT_PROMPT])[:max_prompts]
        all_detections = []
        timing_total = 0.0
        raw_outputs = {}

        for prompt in prompts:
            result = self.detect(image_input, prompt=prompt, inspection_mode=inspection_mode)
            raw_outputs[prompt] = result.get("raw_output", "")
            timing_total += result["timing_ms"]["total"]
            for det in result["detections"]:
                if not self._is_duplicate(det, all_detections):
                    all_detections.append(det)

        return {
            "status": "completed",
            "model": result["model"],
            "image": result["image"],
            "detections": all_detections,
            "detection_count": len(all_detections),
            "prompts_used": prompts,
            "raw_outputs": raw_outputs,
            "timing_ms": {"total": round(timing_total, 2)},
        }

    # ── Output parsing ────────────────────────────────────────────────────────

    def _parse_grounding_output(
        self,
        raw_text: str,
        orig_w: int,
        orig_h: int,
        prompt: str,
    ) -> list[dict[str, Any]]:
        """
        Parse LocateAnything-3B grounding output into CivicLens detection format.

        LocateAnything-3B outputs coordinates in one of these formats
        (we handle both, since the exact format depends on the model version):

        Format A — normalized [0,1] enclosed in special tokens:
            <obj>crack</obj><loc>0.12,0.34,0.56,0.78</loc>

        Format B — pixel coordinate boxes:
            crack [x1=100, y1=200, x2=300, y2=400]

        Format C — QWen-style bounding box tokens:
            <|object_ref_start|>crack<|object_ref_end|>
            <|box_start|>(x1,y1),(x2,y2)<|box_end|>

        We try all three. The first that yields results wins.
        """
        detections: list[dict[str, Any]] = []

        # ── Strategy A: LocateAnything native grounding tokens ────────────────
        detections = self._parse_locate_anything_tokens(raw_text, orig_w, orig_h)
        if detections:
            logger.info(f"[LocateAnything] Parsed {len(detections)} detections via strategy A (LA tokens)")
            return detections

        # ── Strategy B: QWen2-VL box tokens ──────────────────────────────────
        detections = self._parse_qwen_box_tokens(raw_text, orig_w, orig_h)
        if detections:
            logger.info(f"[LocateAnything] Parsed {len(detections)} detections via strategy B (QWen tokens)")
            return detections

        # ── Strategy C: Plain coordinate patterns ─────────────────────────────
        detections = self._parse_plain_coordinates(raw_text, orig_w, orig_h, prompt)
        if detections:
            logger.info(f"[LocateAnything] Parsed {len(detections)} detections via strategy C (plain coords)")
            return detections

        logger.warning(f"[LocateAnything] No bounding boxes found in output. Raw: {raw_text[:300]!r}")
        return []

    def _parse_locate_anything_tokens(
        self, text: str, orig_w: int, orig_h: int
    ) -> list[dict[str, Any]]:
        """
        Parse <obj>label</obj><loc>x1_norm,y1_norm,x2_norm,y2_norm</loc> format.
        Coordinates are normalized [0, 1].
        """
        detections = []
        # Pattern: <obj>LABEL</obj><loc>X1,Y1,X2,Y2</loc>
        pattern = re.compile(
            r"<obj>(.*?)</obj>\s*<loc>([\d.]+),([\d.]+),([\d.]+),([\d.]+)</loc>",
            re.DOTALL | re.IGNORECASE,
        )
        for m in pattern.finditer(text):
            label = m.group(1).strip()
            x1_n, y1_n, x2_n, y2_n = float(m.group(2)), float(m.group(3)), float(m.group(4)), float(m.group(5))
            det = self._norm_to_pixel_det(label, x1_n, y1_n, x2_n, y2_n, orig_w, orig_h)
            if det:
                detections.append(det)
        return detections

    def _parse_qwen_box_tokens(
        self, text: str, orig_w: int, orig_h: int
    ) -> list[dict[str, Any]]:
        """
        Parse QWen2-VL format:
        <|object_ref_start|>label<|object_ref_end|><|box_start|>(x1,y1),(x2,y2)<|box_end|>
        Coordinates may be normalized [0,1000] style.
        """
        detections = []
        pattern = re.compile(
            r"<\|object_ref_start\|>(.*?)<\|object_ref_end\|>\s*"
            r"<\|box_start\|>\((\d+),(\d+)\),\((\d+),(\d+)\)<\|box_end\|>",
            re.DOTALL | re.IGNORECASE,
        )
        for m in pattern.finditer(text):
            label = m.group(1).strip()
            x1, y1, x2, y2 = int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5))
            # QWen uses [0,1000] normalized space
            if max(x1, y1, x2, y2) <= 1000:
                x1_n, y1_n = x1 / 1000.0, y1 / 1000.0
                x2_n, y2_n = x2 / 1000.0, y2 / 1000.0
                det = self._norm_to_pixel_det(label, x1_n, y1_n, x2_n, y2_n, orig_w, orig_h)
            else:
                # Pixel coordinates
                det = self._pixel_det(label, x1, y1, x2, y2, orig_w, orig_h)
            if det:
                detections.append(det)
        return detections

    def _parse_plain_coordinates(
        self, text: str, orig_w: int, orig_h: int, prompt: str
    ) -> list[dict[str, Any]]:
        """
        Fallback: extract any float 4-tuples that look like bounding boxes.
        Uses the prompt's subject as the label.
        """
        detections = []
        # Extract label from prompt
        label = self._label_from_prompt(prompt)

        # Normalized: 4 floats between 0 and 1
        norm_pattern = re.compile(
            r"\[?(0\.\d+|1\.0),\s*(0\.\d+|1\.0),\s*(0\.\d+|1\.0),\s*(0\.\d+|1\.0)\]?"
        )
        for m in norm_pattern.finditer(text):
            x1_n, y1_n, x2_n, y2_n = float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))
            det = self._norm_to_pixel_det(label, x1_n, y1_n, x2_n, y2_n, orig_w, orig_h)
            if det:
                detections.append(det)

        if not detections:
            # Pixel coordinates: 4 integers
            px_pattern = re.compile(r"\[?(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\]?")
            for m in px_pattern.finditer(text):
                x1, y1, x2, y2 = int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))
                det = self._pixel_det(label, x1, y1, x2, y2, orig_w, orig_h)
                if det:
                    detections.append(det)

        return detections

    # ── Coordinate helpers ────────────────────────────────────────────────────

    def _norm_to_pixel_det(
        self,
        label: str,
        x1_n: float, y1_n: float,
        x2_n: float, y2_n: float,
        orig_w: int, orig_h: int,
        score: float | None = None,
    ) -> dict[str, Any] | None:
        x1 = int(round(x1_n * orig_w))
        y1 = int(round(y1_n * orig_h))
        x2 = int(round(x2_n * orig_w))
        y2 = int(round(y2_n * orig_h))
        return self._pixel_det(label, x1, y1, x2, y2, orig_w, orig_h, score)

    def _pixel_det(
        self,
        label: str,
        x1: int, y1: int,
        x2: int, y2: int,
        orig_w: int, orig_h: int,
        score: float | None = None,
    ) -> dict[str, Any] | None:
        # Clip to image bounds
        x1 = max(0, min(x1, orig_w - 1))
        y1 = max(0, min(y1, orig_h - 1))
        x2 = max(0, min(x2, orig_w))
        y2 = max(0, min(y2, orig_h))

        # Ensure x1 < x2 and y1 < y2
        if x1 >= x2 or y1 >= y2:
            logger.debug(f"[LocateAnything] Skipping degenerate box: [{x1},{y1},{x2},{y2}]")
            return None

        det: dict[str, Any] = {
            "label": label or "damage",
            "bounding_box": {
                "x1": x1,
                "y1": y1,
                "x2": x2,
                "y2": y2,
                "width": x2 - x1,
                "height": y2 - y1,
            },
        }
        # Only include score if model actually provides it
        if score is not None:
            det["grounding_score"] = round(score, 4)

        return det

    def _label_from_prompt(self, prompt: str) -> str:
        """Extract a short damage label from the inspection prompt."""
        prompt_lower = prompt.lower()
        if "pothole" in prompt_lower:
            return "pothole"
        if "crack" in prompt_lower:
            return "crack"
        if "spalling" in prompt_lower or "reinforcement" in prompt_lower:
            return "concrete_damage"
        if "damage" in prompt_lower:
            return "damage"
        return "defect"

    def _is_duplicate(
        self,
        det: dict[str, Any],
        existing: list[dict[str, Any]],
        iou_threshold: float = 0.5,
    ) -> bool:
        """Simple IoU-based duplicate suppression across multi-prompt results."""
        bb = det["bounding_box"]
        for ex in existing:
            eb = ex["bounding_box"]
            iou = self._iou(
                bb["x1"], bb["y1"], bb["x2"], bb["y2"],
                eb["x1"], eb["y1"], eb["x2"], eb["y2"],
            )
            if iou > iou_threshold:
                return True
        return False

    @staticmethod
    def _iou(x1a, y1a, x2a, y2a, x1b, y1b, x2b, y2b) -> float:
        ix1 = max(x1a, x1b)
        iy1 = max(y1a, y1b)
        ix2 = min(x2a, x2b)
        iy2 = min(y2a, y2b)
        inter = max(0, ix2 - ix1) * max(0, iy2 - iy1)
        if inter == 0:
            return 0.0
        area_a = (x2a - x1a) * (y2a - y1a)
        area_b = (x2b - x1b) * (y2b - y1b)
        return inter / (area_a + area_b - inter)

    # ── Annotation ────────────────────────────────────────────────────────────

    def annotate(self, image_input: Any, detections: list[dict[str, Any]]) -> "Image.Image":
        """
        Draw bounding boxes on the image and return the annotated PIL Image.
        Labels use the detection's 'label' key (LocateAnything format).
        Compatible with both the LA detection format and the ONNX format.
        """
        from PIL import Image, ImageDraw, ImageFont
        from io import BytesIO

        if isinstance(image_input, bytes):
            img = Image.open(BytesIO(image_input)).convert("RGB").copy()
        elif isinstance(image_input, str):
            img = Image.open(image_input).convert("RGB").copy()
        elif hasattr(image_input, "mode"):
            img = image_input.convert("RGB").copy()
        else:
            raise ValueError(f"Unsupported image input type: {type(image_input)}")

        draw = ImageDraw.Draw(img)
        colors = [
            (239, 68, 68),    # red
            (249, 115, 22),   # orange
            (168, 85, 247),   # purple
            (234, 179, 8),    # yellow
            (34, 197, 94),    # green
        ]

        for i, det in enumerate(detections):
            bb = det["bounding_box"]
            x1, y1, x2, y2 = bb["x1"], bb["y1"], bb["x2"], bb["y2"]
            color = colors[i % len(colors)]

            label = det.get("label") or det.get("class_name", "damage")
            score = det.get("grounding_score") or det.get("confidence")
            label_text = f"{label} {int(score * 100)}%" if score is not None else label

            draw.rectangle([x1, y1, x2, y2], outline=color, width=3)
            text_w = draw.textlength(label_text) if hasattr(draw, "textlength") else len(label_text) * 7
            text_h = 16
            draw.rectangle([x1, max(0, y1 - text_h - 4), x1 + text_w + 8, max(text_h + 4, y1)], fill=color)
            draw.text((x1 + 4, max(2, y1 - text_h - 2)), label_text, fill=(255, 255, 255))

        return img
