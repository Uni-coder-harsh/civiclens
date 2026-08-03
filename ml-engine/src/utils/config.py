import os
import yaml
from pathlib import Path

def load_yaml(file_path: Path) -> dict:
    if not file_path.exists():
        return {}
    with open(file_path, 'r') as f:
        data = yaml.safe_load(f)
    return data if data is not None else {}

def load_config(config_dir: str = None) -> dict:
    """Loads and merges all yaml configuration files from the configs directory."""
    if config_dir is None:
        # Default path relative to this file
        current_dir = Path(__file__).resolve().parent
        config_dir = current_dir.parent.parent / "configs"
    else:
        config_dir = Path(config_dir)

    dataset_cfg = load_yaml(config_dir / "dataset.yaml")
    model_cfg = load_yaml(config_dir / "model.yaml")
    train_cfg = load_yaml(config_dir / "train.yaml")
    aug_cfg = load_yaml(config_dir / "augmentation.yaml")

    # Combine into a single unified configuration dict
    config = {}
    config.update(dataset_cfg)
    config.update(model_cfg)
    config.update(train_cfg)
    config.update(aug_cfg)
    
    return config
