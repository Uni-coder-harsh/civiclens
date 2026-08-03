from pathlib import Path
import datetime
from ..utils.config import load_config
from ..utils.seed import set_seed
from ..utils.logger import setup_logger
from ..datasets.loader import prepare_unified_dataset
from .train import train_yolo
from ..evaluation.evaluate import evaluate_model
from ..inference.export import export_model_to_onnx


def run_pipeline(config_dir: str = None) -> bool:
    """Coordinates the entire loading, preprocessing, training, evaluation, and exporting pipeline."""
    # 1. Load Configurations
    config = load_config(config_dir)
    output_dir = Path(config["workspace"]["output_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 2. Setup Logger
    log_dir = output_dir / "logs"
    logger = setup_logger("pipeline", log_dir=str(log_dir))
    
    logger.info("==============================================")
    logger.info("   Starting CivicLens ML Training Pipeline    ")
    logger.info("==============================================")
    
    start_time = datetime.datetime.now()
    log_id = f"LOG-{start_time.strftime('%Y%m%d-%H%M%S')}"
    
    try:
        # 3. Set random seed
        seed = config.get("training", {}).get("seed", 42)
        logger.info(f"Setting random seed: {seed}")
        set_seed(seed)
        
        # 4. Prepare dataset
        logger.info("Step 1/4: Preparing unified dataset from multiple sources...")
        yolo_yaml_path = prepare_unified_dataset(config)
        logger.info(f"Dataset preparation success. Config path: {yolo_yaml_path}")
        
        # 5. Run training
        logger.info("Step 2/4: Launching model training...")
        best_weights_path = train_yolo(yolo_yaml_path, config)
        logger.info(f"Training run completed. Weights located at: {best_weights_path}")
        
        # 6. Evaluate model
        logger.info("Step 3/4: Starting model validation split evaluation...")
        eval_results = evaluate_model(best_weights_path, yolo_yaml_path, config)
        logger.info("Evaluation metrics compiled successfully.")
        
        # 7. Export weights
        logger.info("Step 4/4: Exporting model to ONNX...")
        onnx_path = export_model_to_onnx(best_weights_path, config, eval_results)
        logger.info(f"Production model exported successfully to: {onnx_path}")
        
        end_time = datetime.datetime.now()
        duration = end_time - start_time
        logger.info(f"Pipeline executed successfully in {duration}!")
        logger.info("==============================================")
        
        # Log success back to progress
        update_progress_log(log_id, "SUCCESS", f"Finished training successfully. mAP@0.5: {eval_results['map50']:.4f}, mAP@0.5-0.95: {eval_results['map50_95']:.4f}. Duration: {duration}")
        return True
        
    except Exception as e:
        logger.exception("An error occurred during pipeline execution:")
        end_time = datetime.datetime.now()
        duration = end_time - start_time
        update_progress_log(log_id, "FAILURE", f"Execution failed: {str(e)}. Duration: {duration}")
        return False

def update_progress_log(log_id: str, status: str, notes: str):
    """Proactively appends a run outcome directly into the project's progress.md log."""
    try:
        progress_path = Path(__file__).resolve().parent.parent.parent / "progress.md"
        if not progress_path.exists():
            return
            
        today = datetime.date.today().isoformat()
        log_entry = f"| `{log_id}` | {today} | Phase 4 | Pipeline Run | **{status}** | {notes} |\n"
        
        with open(progress_path, "a") as f:
            f.write(log_entry)
            
    except Exception:
        pass # Silently pass if writing progress fails to prevent breaking main run

def train(config_dir: str = None) -> bool:
    """Alias for run_pipeline for backwards compatibility with user runners."""
    return run_pipeline(config_dir)

