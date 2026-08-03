import argparse
import os
from pathlib import Path
from ultralytics import YOLO
import cv2

def predict_image(model_path: str, source_path: str, output_path: str = None, conf: float = 0.25) -> str:
    """
    Runs damage detection inference on a custom image using the trained YOLO model (PyTorch or ONNX).
    Draws predicted bounding boxes and saves/displays the result.
    
    Args:
        model_path: Path to the .pt or .onnx model weights.
        source_path: Path or URL to the input test image.
        output_path: Path to save the annotated output image. If None, saves in outputs/predictions.
        conf: Confidence threshold for predictions.
    """
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found at: {model_path}")
        
    if not os.path.exists(source_path):
        raise FileNotFoundError(f"Source image file not found at: {source_path}")
        
    print(f"Loading model: {model_path}")
    # YOLO automatically handles loading ONNX or PyTorch weights
    # Note: ONNX requires specifying task='detect' during initialization
    task = "detect" if model_path.endswith(".onnx") else None
    model = YOLO(model_path, task=task)
    
    print(f"Running inference on: {source_path}")
    # Run prediction
    results = model.predict(source_path, conf=conf)
    result = results[0]
    
    # Draw boxes using YOLO's built-in plot utility
    annotated_img = result.plot() # Returns BGR image
    
    # Setup default output path if not provided
    if output_path is None:
        output_dir = Path("outputs/predictions")
        output_dir.mkdir(parents=True, exist_ok=True)
        img_name = Path(source_path).name
        output_path = str(output_dir / f"pred_{img_name}")
        
    # Save the output image
    cv2.imwrite(output_path, annotated_img)
    print(f"Annotated image successfully saved to: {output_path}")
    
    # Print out detected bounding boxes summary
    print("\n--- Detection Results Summary ---")
    boxes = result.boxes
    if len(boxes) == 0:
        print("No damage detected.")
    else:
        for idx, box in enumerate(boxes):
            cls_id = int(box.cls[0])
            cls_name = result.names[cls_id]
            score = float(box.conf[0])
            xyxy = box.xyxy[0].tolist()
            print(f"[{idx+1}] Class: `{cls_name}` | Confidence: {score:.2%} | Box coordinates: {xyxy}")
    print("---------------------------------\n")
    
    return output_path

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CivicLens Custom Image Tester")
    parser.add_argument("--model", type=str, required=True, help="Path to trained .pt or .onnx model weights")
    parser.add_argument("--source", type=str, required=True, help="Path to custom image for testing")
    parser.add_argument("--output", type=str, default=None, help="Path to save output annotated image")
    parser.add_argument("--conf", type=float, default=0.25, help="Confidence threshold (default: 0.25)")
    
    args = parser.parse_args()
    
    predict_image(
        model_path=args.model,
        source_path=args.source,
        output_path=args.output,
        conf=args.conf
    )
