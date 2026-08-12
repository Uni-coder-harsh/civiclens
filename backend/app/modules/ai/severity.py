"""
CivicLens AI Severity Engine

Translates raw ONNX detection results into a standardized severity assessment.
The detector only finds objects — this layer interprets them for CivicLens context.

IMPORTANT: No fake scores. Severity is derived from:
  - Detected class type (some are inherently more dangerous)
  - Confidence of the best detection
  - Number of detections (more = worse)
  - Bounding box area fraction (larger defect = more severe)
"""

from typing import List, Dict, Any, Optional


# ── Class danger weights ──────────────────────────────────────────────────────
# Based on road engineering standards (IRC, ASTM, PASER scale)
CLASS_DANGER = {
    "D40_Pothole":              1.00,   # Immediate safety hazard
    "D20_Alligator_Crack":      0.90,   # Structural failure pattern
    "D10_Transverse_Crack":     0.65,   # Stress fracture, progresses fast
    "D00_Longitudinal_Crack":   0.55,   # Joint/edge failure
    "D30_Other_Corruption":     0.45,   # Surface degradation, rutting
}

# ── Severity thresholds (0–100 score → label) ─────────────────────────────────
SEVERITY_LEVELS = [
    (75, "critical", "Critical structural defect requiring immediate intervention."),
    (50, "high",     "Significant defect posing safety risk. Repair within 48 hours."),
    (25, "medium",   "Moderate surface damage. Schedule repair within 2 weeks."),
    ( 0, "low",      "Minor cosmetic surface imperfection. Monitor regularly."),
]


def compute_severity(
    detections: List[Dict[str, Any]],
    image_width: int = 640,
    image_height: int = 640,
) -> Dict[str, Any]:
    """
    Derives a severity assessment from ONNX detection results.

    Returns a dict with:
      - severity_label: "low" | "medium" | "high" | "critical"
      - severity_score: 0–100 float
      - primary_class: most dangerous detected class name
      - primary_confidence: its detection confidence
      - explanation: human-readable description
      - detection_count: total detections
    """

    if not detections:
        return {
            "severity_label": "low",
            "severity_score": 0.0,
            "primary_class": None,
            "primary_confidence": None,
            "explanation": "No road defects detected in this image.",
            "detection_count": 0,
        }

    image_area = max(image_width * image_height, 1)

    # Score each detection
    scored = []
    for det in detections:
        cls = det.get("class_name", "")
        conf = float(det.get("confidence", 0))
        bb = det.get("bounding_box", {})

        danger_weight = CLASS_DANGER.get(cls, 0.4)

        # Area fraction of defect relative to image
        det_area = bb.get("width", 0) * bb.get("height", 0)
        area_fraction = min(det_area / image_area, 1.0)

        # Score: danger × confidence × (1 + 0.5 × area_fraction)
        raw_score = danger_weight * conf * (1.0 + 0.5 * area_fraction) * 100
        scored.append((raw_score, cls, conf, det))

    # Sort by score descending
    scored.sort(key=lambda x: x[0], reverse=True)

    best_score, best_class, best_conf, _ = scored[0]

    # Multi-detection boost: +5% per additional detection, max +25%
    extra = min(len(scored) - 1, 5) * 5.0
    final_score = min(best_score + extra, 100.0)

    # Map score to severity label
    severity_label = "low"
    explanation = ""
    for threshold, label, desc in SEVERITY_LEVELS:
        if final_score >= threshold:
            severity_label = label
            explanation = desc
            break

    return {
        "severity_label": severity_label,
        "severity_score": round(final_score, 1),
        "primary_class": best_class,
        "primary_confidence": round(best_conf, 4),
        "explanation": explanation,
        "detection_count": len(detections),
    }


def severity_to_readable(class_name: Optional[str], confidence: Optional[float]) -> str:
    """
    Returns a short human-readable AI label for the Flutter card.
    e.g. "Pothole (91%)"
    """
    if not class_name:
        return "No defect detected"

    display_names = {
        "D00_Longitudinal_Crack": "Longitudinal Crack",
        "D10_Transverse_Crack":   "Transverse Crack",
        "D20_Alligator_Crack":    "Alligator Crack",
        "D30_Other_Corruption":   "Road Corruption",
        "D40_Pothole":            "Pothole",
    }
    name = display_names.get(class_name, class_name.replace("_", " "))
    if confidence is not None:
        return f"{name} ({int(confidence * 100)}%)"
    return name
