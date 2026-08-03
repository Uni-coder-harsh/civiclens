import shutil
from pathlib import Path
from ultralytics import YOLO
from ..utils.logger import setup_logger


logger = setup_logger("inference.export")

def export_model_to_onnx(weights_path: Path, config: dict, eval_results: dict) -> Path:
    """Exports PyTorch model weights to ONNX format and generates a model card."""
    logger.info(f"Loading weights for export: {weights_path}")
    model = YOLO(weights_path)
    
    logger.info("Exporting model to ONNX format...")
    # Ultralytics export helper
    exported_onnx_path_str = model.export(format="onnx", dynamic=True)
    exported_onnx_path = Path(exported_onnx_path_str)
    
    # Destination directory
    output_dir = Path(config["workspace"]["output_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)
    
    target_onnx_path = output_dir / "road_detector_v1.onnx"
    shutil.move(str(exported_onnx_path), str(target_onnx_path))
    logger.info(f"ONNX model successfully moved to production path: {target_onnx_path}")
    
    # Create Model Card
    generate_model_card(target_onnx_path.parent, config, eval_results)
    
    return target_onnx_path

def generate_model_card(output_dir: Path, config: dict, eval_results: dict):
    """Generates a structured model card README file for deployment."""
    card_path = output_dir / "README.md"
    logger.info(f"Generating Model Card at {card_path}")
    
    model_name = config["model"]["name"]
    target_classes = config["target_classes"]
    
    content = f"""# Model Card: CivicLens Road & Bridge Damage Detector (v1)

This repository artifact contains the production-ready ONNX model for road & bridge damage detection.

## Model Details
- **Architecture**: YOLO11 (Variant: `{model_name}`)
- **Format**: ONNX (Exported with dynamic batch size and shape inputs)
- **Input Image Size**: 640x640 pixels (RGB)
- **Training Epochs**: {config['training'].get('epochs', 100)}
- **Optimizer**: {config['training'].get('optimizer', 'AdamW')}

## Unified Taxonomy
The model detects the following 7 classes of road & bridge damage:
{chr(10).join([f"- **Class {idx}**: `{name}`" for idx, name in enumerate(target_classes)])}

## Performance Evaluation
Evaluated on validation split (15% holdout):
- **mAP@0.5**: {eval_results.get('map50', 0.0):.4f}
- **mAP@0.5:0.95**: {eval_results.get('map50_95', 0.0):.4f}
- **Mean Precision**: {eval_results.get('precision', 0.0):.4f}
- **Mean Recall**: {eval_results.get('recall', 0.0):.4f}

## Deployment Instructions
You can load this model directly using OpenCV or ONNX Runtime in python, or pull it directly into the backend server.

### PyTorch/ONNX Inference Example:
```python
import onnxruntime as ort
import numpy as np

# Load model session
session = ort.InferenceSession("road_detector_v1.onnx")

# Inputs are RGB format, normalized to [0, 1], shape [batch, channels, height, width]
input_name = session.get_inputs()[0].name
output_name = session.get_outputs()[0].name
```
"""
    with open(card_path, "w") as f:
        f.write(content)
        
    logger.info("Model Card generated successfully.")
