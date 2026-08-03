from pathlib import Path
from ultralytics import YOLO
from src.utils.logger import setup_logger

logger = setup_logger("evaluation.evaluate")

def evaluate_model(weights_path: Path, yolo_yaml_path: Path, config: dict) -> dict:
    """Evaluates the trained YOLO model on the validation dataset."""
    logger.info(f"Loading trained weights for evaluation from: {weights_path}")
    model = YOLO(weights_path)
    
    logger.info("Running validation split evaluation...")
    metrics = model.val(
        data=str(yolo_yaml_path),
        project=str(Path(config["workspace"]["output_dir"]) / "runs"),
        name=f"{config['training'].get('name', 'yolo11m_run')}_val",
        save_json=True
    )
    
    # Extract performance metrics
    eval_results = {
        "precision": float(metrics.box.mp),
        "recall": float(metrics.box.mr),
        "map50": float(metrics.box.map50),
        "map50_95": float(metrics.box.map)
    }
    
    logger.info("--- Validation Metrics Summary ---")
    logger.info(f"Mean Precision: {eval_results['precision']:.4f}")
    logger.info(f"Mean Recall:    {eval_results['recall']:.4f}")
    logger.info(f"mAP@0.5:        {eval_results['map50']:.4f}")
    logger.info(f"mAP@0.5:0.95:   {eval_results['map50_95']:.4f}")
    logger.info("----------------------------------")
    
    return eval_results
