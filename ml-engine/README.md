# CivicLens ML Engine 🚀

Welcome to the **CivicLens Model Development Engine**. This repository is configured to train, evaluate, and export state-of-the-art computer vision models for road and bridge damage detection using **YOLO11**.

---

## 📂 Repository Structure

The ML Engine uses a clean, production-grade layout. The code resides entirely inside the repository, using notebooks strictly as minimal runners.

```text
ml-engine/
│
├── configs/                  # Config files driving training/dataset definitions
│   ├── dataset.yaml          # Dataset directories and taxonomy mappings
│   ├── train.yaml            # Hyperparameters, batch size, epochs
│   ├── model.yaml            # Model model family selection (YOLO11)
│   └── augmentation.yaml     # Spatial and color space augmentations
│
├── notebooks/                # Notebook runners for Kaggle / Colab
│   ├── 01_train.ipynb        # Run model training pipeline
│   ├── 02_evaluate.ipynb     # Check performance on validation split
│   └── 03_export.ipynb       # Export model weights to ONNX format
│
├── src/                      # Source code modules
│   ├── datasets/             # Dataset loader and symlinking operations
│   ├── preprocessing/         # Bounding box coordinates converters
│   ├── training/             # PyTorch training loops and executors
│   ├── evaluation/           # validation metric utilities
│   ├── inference/            # ONNX exporting and model card compiler
│   └── utils/                # Configuration parsing, seeding, logging
│
├── requirements.txt          # Python packages list
├── taxonomy.md               # Damage class & severity specifications
├── pipeline.md               # Pipeline architecture & data flows
├── KAGGLE_GUIDE.md           # Instructions on how to run on Kaggle
└── progress.md               # Project milestones and experiment logs
```

---

## 📑 Core Documentation Contracts

Before editing code or running experiments, please align on the following three contract files:
1. **[configs/dataset.yaml](file:///home/harsh/Desktop/CodeNova/civiclens/ml-engine/configs/dataset.yaml)**: Dictates enabled source datasets, paths, and local/remote configurations.
2. **[taxonomy.md](file:///home/harsh/Desktop/CodeNova/civiclens/ml-engine/taxonomy.md)**: Defines the frozen list of damage classes, severity metrics, and label translations.
3. **[pipeline.md](file:///home/harsh/Desktop/CodeNova/civiclens/ml-engine/pipeline.md)**: Details loaders, preprocessings, and export serialization protocols.

---

## 🏃 Running in Kaggle

To run this pipeline on Kaggle without transferring heavy zip files or copying thousands of lines:
1. Mount the necessary datasets (`rdd2022`, `bridge-crack`, etc.) to `/kaggle/input/...`.
2. Clone the repository once:
   ```bash
   !git clone https://github.com/Uni-coder-harsh/civiclens.git
   ```
3. Open **`notebooks/01_train.ipynb`** and run the cells.
4. If you modify code locally in VS Code, push to GitHub, then run the pull cell in your Kaggle notebook:
   ```bash
   %cd /kaggle/working/civiclens
   !git pull origin main
   ```

For detailed setup instructions, see the **[Kaggle Model Training Guide](file:///home/harsh/Desktop/CodeNova/civiclens/ml-engine/KAGGLE_GUIDE.md)**.

---

## 📊 Outputs

All training outputs are automatically generated inside the `/kaggle/working/outputs/` directory:
- **`outputs/runs/detect/yolo11m_run/`**: CSV metrics, precision-recall curves, confusion matrices, and training logs.
- **`outputs/road_detector_v1.onnx`**: The final dynamic ONNX model ready for backend deployment.
- **`outputs/README.md`**: The compiled model card detailing class maps and performance metrics.
