import ast
import logging
import os
import time
from io import BytesIO
from typing import Any

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageDraw

logger = logging.getLogger("civiclens.ai.engine")


def letterbox(
    img: Image.Image,
    target_size: tuple[int, int] = (640, 640),
    fill_color: tuple[int, int, int] = (114, 114, 114),
) -> tuple[Image.Image, float, float, float]:
    orig_w, orig_h = img.size
    target_w, target_h = target_size
    scale = min(target_w / orig_w, target_h / orig_h)
    new_w = int(round(orig_w * scale))
    new_h = int(round(orig_h * scale))

    img_resized = img.resize((new_w, new_h), Image.Resampling.BILINEAR)
    canvas = Image.new("RGB", target_size, fill_color)

    pad_w = (target_w - new_w) / 2.0
    pad_h = (target_h - new_h) / 2.0
    canvas.paste(img_resized, (int(round(pad_w)), int(round(pad_h))))

    return canvas, scale, pad_w, pad_h


def nms(boxes: np.ndarray, scores: np.ndarray, iou_threshold: float) -> list[int]:
    if len(boxes) == 0:
        return []

    x1 = boxes[:, 0]
    y1 = boxes[:, 1]
    x2 = boxes[:, 2]
    y2 = boxes[:, 3]

    areas = (x2 - x1) * (y2 - y1)
    order = scores.argsort()[::-1]

    keep = []
    while order.size > 0:
        i = order[0]
        keep.append(int(i))

        xx1 = np.maximum(x1[i], x1[order[1:]])
        yy1 = np.maximum(y1[i], y1[order[1:]])
        xx2 = np.minimum(x2[i], x2[order[1:]])
        yy2 = np.minimum(y2[i], y2[order[1:]])

        w = np.maximum(0.0, xx2 - xx1)
        h = np.maximum(0.0, yy2 - yy1)
        inter = w * h

        ovr = inter / (areas[i] + areas[order[1:]] - inter + 1e-6)
        inds = np.where(ovr <= iou_threshold)[0]
        order = order[inds + 1]

    return keep


class CrackONNXInferenceEngine:
    """Production ONNX Runtime inference engine for CivicLens crack detection."""

    def __init__(
        self,
        model_path: str = "ml-engine/best.onnx",
        provider: str = "CPUExecutionProvider",
        conf_threshold: float = 0.25,
        iou_threshold: float = 0.45,
        input_size: int = 640,
        version: str = "crack-detector-v1",
    ):
        self.model_path = model_path
        self.provider = provider
        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        self.input_size = input_size
        self.version = version

        if not os.path.exists(self.model_path):
            raise FileNotFoundError(f"ONNX model file not found at: {self.model_path}")

        logger.info("[ONNXEngine] Initializing ONNX Runtime session for %s", self.model_path)
        self.session = ort.InferenceSession(self.model_path, providers=[self.provider])

        self.input_meta = self.session.get_inputs()[0]
        self.output_meta = self.session.get_outputs()[0]
        self.input_name = self.input_meta.name
        self.output_name = self.output_meta.name
        self.input_shape = self.input_meta.shape
        self.output_shape = self.output_meta.shape

        # Dynamically adapt input_size to match model's expected shape if static
        if len(self.input_shape) == 4 and isinstance(self.input_shape[2], int):
            old_size = self.input_size
            self.input_size = self.input_shape[2]
            if old_size != self.input_size:
                logger.info(
                    "[ONNXEngine] Dynamic input size override: configured=%d, using model native resolution=%d",
                    old_size,
                    self.input_size,
                )

        meta = self.session.get_modelmeta()
        custom_map = meta.custom_metadata_map or {}
        names_str = custom_map.get("names", "")

        self.class_names: dict[int, str] = {
            0: "D00_Longitudinal_Crack",
            1: "D10_Transverse_Crack",
            2: "D20_Alligator_Crack",
            3: "D30_Other_Corruption",
            4: "D40_Pothole",
        }

        if names_str:
            try:
                parsed_names = ast.literal_eval(names_str)
                if isinstance(parsed_names, dict):
                    self.class_names = {int(k): str(v) for k, v in parsed_names.items()}
            except Exception as exc:
                logger.warning("[ONNXEngine] Could not parse metadata class names: %s", exc)

        logger.info(
            "[ONNXEngine] Session ready | Input: %s %s | Output: %s %s | Classes: %s",
            self.input_name,
            self.input_shape,
            self.output_name,
            self.output_shape,
            list(self.class_names.values()),
        )

    def preprocess(self, image_input: Any) -> tuple[np.ndarray, Image.Image, int, int, float, float, float]:
        if isinstance(image_input, bytes):
            img = Image.open(BytesIO(image_input))
        elif isinstance(image_input, Image.Image):
            img = image_input
        elif isinstance(image_input, str):
            img = Image.open(image_input)
        else:
            raise ValueError(f"Unsupported image input type: {type(image_input)}")

        img = img.convert("RGB")
        orig_w, orig_h = img.size

        if orig_w == 0 or orig_h == 0:
            raise ValueError("Image dimensions cannot be zero.")

        canvas, scale, pad_w, pad_h = letterbox(img, target_size=(self.input_size, self.input_size))
        arr = np.array(canvas, dtype=np.float32) / 255.0
        arr = np.transpose(arr, (2, 0, 1))
        tensor = np.expand_dims(arr, axis=0)

        return tensor, img, orig_w, orig_h, scale, pad_w, pad_h

    def detect(
        self,
        image_input: Any,
        conf_threshold: float | None = None,
        iou_threshold: float | None = None,
    ) -> dict[str, Any]:
        conf_thresh = conf_threshold if conf_threshold is not None else self.conf_threshold
        iou_thresh = iou_threshold if iou_threshold is not None else self.iou_threshold

        t_start = time.perf_counter()

        tensor, _, orig_w, orig_h, scale, pad_w, pad_h = self.preprocess(image_input)
        t_prep = time.perf_counter()

        outputs = self.session.run([self.output_name], {self.input_name: tensor})
        t_infer = time.perf_counter()

        raw_out = outputs[0][0]
        predictions = raw_out.T

        boxes_640 = predictions[:, 0:4]
        scores_matrix = predictions[:, 4:]

        max_scores = np.max(scores_matrix, axis=1)
        max_classes = np.argmax(scores_matrix, axis=1)

        mask = max_scores >= conf_thresh
        cand_boxes = boxes_640[mask]
        cand_scores = max_scores[mask]
        cand_classes = max_classes[mask]
        num_candidates = len(cand_scores)

        final_detections = []
        if num_candidates > 0:
            cx = cand_boxes[:, 0]
            cy = cand_boxes[:, 1]
            w = cand_boxes[:, 2]
            h = cand_boxes[:, 3]

            x1_640 = cx - (w / 2.0)
            y1_640 = cy - (h / 2.0)
            x2_640 = cx + (w / 2.0)
            y2_640 = cy + (h / 2.0)

            x1_orig = np.clip((x1_640 - pad_w) / scale, 0, orig_w)
            y1_orig = np.clip((y1_640 - pad_h) / scale, 0, orig_h)
            x2_orig = np.clip((x2_640 - pad_w) / scale, 0, orig_w)
            y2_orig = np.clip((y2_640 - pad_h) / scale, 0, orig_h)

            boxes_orig = np.column_stack([x1_orig, y1_orig, x2_orig, y2_orig])
            keep_indices = nms(boxes_orig, cand_scores, iou_thresh)

            for idx in keep_indices:
                b = boxes_orig[idx]
                cls_id = int(cand_classes[idx])
                conf = float(cand_scores[idx])
                cls_name = self.class_names.get(cls_id, f"class_{cls_id}")

                bx1, by1, bx2, by2 = int(round(b[0])), int(round(b[1])), int(round(b[2])), int(round(b[3]))
                bw = max(0, bx2 - bx1)
                bh = max(0, by2 - by1)

                final_detections.append(
                    {
                        "class_id": cls_id,
                        "class_name": cls_name,
                        "confidence": round(conf, 4),
                        "bounding_box": {
                            "x1": bx1,
                            "y1": by1,
                            "x2": bx2,
                            "y2": by2,
                            "width": bw,
                            "height": bh,
                        },
                    }
                )

        t_post = time.perf_counter()

        return {
            "status": "completed",
            "model": {
                "name": "civiclens-crack-detector",
                "version": self.version,
                "runtime": "onnxruntime",
                "provider": self.provider,
            },
            "image": {
                "width": orig_w,
                "height": orig_h,
            },
            "detections": final_detections,
            "detection_count": len(final_detections),
            "timing_ms": {
                "preprocess": round((t_prep - t_start) * 1000, 2),
                "inference": round((t_infer - t_prep) * 1000, 2),
                "postprocess": round((t_post - t_infer) * 1000, 2),
                "total": round((t_post - t_start) * 1000, 2),
            },
            "diagnostic": {
                "candidates_filtered": num_candidates,
                "conf_threshold": conf_thresh,
                "iou_threshold": iou_thresh,
            },
        }

    def annotate(self, image_input: Any, detections: list[dict[str, Any]]) -> Image.Image:
        if isinstance(image_input, bytes):
            img = Image.open(BytesIO(image_input)).copy()
        elif isinstance(image_input, Image.Image):
            img = image_input.copy()
        elif isinstance(image_input, str):
            img = Image.open(image_input).copy()
        else:
            raise ValueError(f"Unsupported image input type: {type(image_input)}")

        img = img.convert("RGB")
        draw = ImageDraw.Draw(img)

        colors = [
            (239, 68, 68),
            (249, 115, 22),
            (168, 85, 247),
            (234, 179, 8),
            (236, 72, 153),
        ]

        for det in detections:
            bbox = det["bounding_box"]
            x1, y1, x2, y2 = bbox["x1"], bbox["y1"], bbox["x2"], bbox["y2"]
            cls_id = det["class_id"]
            cls_name = det["class_name"]
            conf = det["confidence"]

            color = colors[cls_id % len(colors)]
            label = f"{cls_name} {int(conf * 100)}%"

            draw.rectangle([x1, y1, x2, y2], outline=color, width=4)

            text_size = draw.textlength(label) if hasattr(draw, "textlength") else len(label) * 8
            text_h = 18
            bg_box = [x1, max(0, y1 - text_h - 4), x1 + text_size + 10, max(text_h + 4, y1)]
            draw.rectangle(bg_box, fill=color)
            draw.text((x1 + 4, max(2, y1 - text_h - 2)), label, fill=(255, 255, 255))

        return img
