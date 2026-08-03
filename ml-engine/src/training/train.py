from pathlib import Path
from ultralytics import YOLO
from src.utils.logger import setup_logger

logger = setup_logger("training.train")

def train_yolo(yolo_yaml_path: Path, config: dict) -> Path:
    """Runs YOLO training using model configurations and training parameters."""
    model_name = config["model"]["name"]
    logger.info(f"Initializing model: {model_name}")
    
    # Load model
    model = YOLO(f"{model_name}.pt") # Download pretrained weights automatically if not found
    
    # Extract training configs and augmentations
    training_params = config["training"]
    aug_params = config.get("augmentation", {})
    
    # Combine training and augmentation arguments
    train_kwargs = {}
    
    # Map key Ultralytics settings
    train_kwargs["data"] = str(yolo_yaml_path)
    train_kwargs["epochs"] = training_params.get("epochs", 100)
    train_kwargs["batch"] = training_params.get("batch_size", 16)
    train_kwargs["imgsz"] = training_params.get("imgsz", 640)
    train_kwargs["device"] = training_params.get("device", "cuda")
    train_kwargs["workers"] = training_params.get("workers", 4)
    train_kwargs["optimizer"] = training_params.get("optimizer", "AdamW")
    train_kwargs["lr0"] = training_params.get("lr0", 0.01)
    train_kwargs["lrf"] = training_params.get("lrf", 0.01)
    train_kwargs["momentum"] = training_params.get("momentum", 0.937)
    train_kwargs["weight_decay"] = training_params.get("weight_decay", 0.0005)
    train_kwargs["warmup_epochs"] = training_params.get("warmup_epochs", 3.0)
    train_kwargs["warmup_momentum"] = training_params.get("warmup_momentum", 0.8)
    train_kwargs["warmup_bias_lr"] = training_params.get("warmup_bias_lr", 0.1)
    train_kwargs["box"] = training_params.get("box", 7.5)
    train_kwargs["cls"] = training_params.get("cls", 0.5)
    train_kwargs["dfl"] = training_params.get("dfl", 1.5)
    train_kwargs["val"] = training_params.get("val", True)
    train_kwargs["save"] = training_params.get("save", True)
    train_kwargs["save_period"] = training_params.get("save_period", -1)
    train_kwargs["cache"] = training_params.get("cache", False)
    train_kwargs["patience"] = training_params.get("patience", 20)
    train_kwargs["seed"] = training_params.get("seed", 42)
    train_kwargs["project"] = str(Path(config["workspace"]["output_dir"]) / "runs")
    train_kwargs["name"] = training_params.get("name", "yolo11m_run")
    
    # Add augmentation settings
    for aug_key, aug_val in aug_params.items():
        train_kwargs[aug_key] = aug_val
        
    logger.info(f"Starting training run '{train_kwargs['name']}' in project '{train_kwargs['project']}'...")
    
    # Run training
    results = model.train(**train_kwargs)
    
    # Path to best weights
    best_weights_path = Path(train_kwargs["project"]) / train_kwargs["name"] / "weights" / "best.pt"
    logger.info(f"Training completed. Best weights saved to: {best_weights_path}")
    
    return best_weights_path
