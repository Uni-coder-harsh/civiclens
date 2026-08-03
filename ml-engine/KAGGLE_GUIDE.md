# Kaggle Model Training Guide

This guide describes how to run the `civiclens` road & bridge damage training pipeline on Kaggle.

---

## 1. Kaggle Notebook Setup

When creating a new notebook on Kaggle, configure the environment settings:

* **Accelerator**: **GPU T4 x2** (highly recommended. Avoid GPU P100, as Kaggle's pre-installed PyTorch build does not support its Pascal sm_60 compute capability by default).
* **Internet**: Turn **ON** (needed for `git clone`, `pip install`, and Hugging Face integration).

* **Persistence**: Filesystem - Variables and Files (optional, but convenient).

---

## 2. Attaching Datasets

In the right-hand panel of your Kaggle notebook, click **"Add Input"** and attach the following datasets. Make sure their folder names match the paths configured in `configs/dataset.yaml`:

| Dataset Name | Kaggle Search Term / URL | Expected Path |
| :--- | :--- | :--- |
| **RDD2022** | `rdd2022` or `road-damage-detection-2022` | `/kaggle/input/rdd2022` |
| **Bridge Crack** | `bridge-crack` | `/kaggle/input/bridge-crack` |
| **Custom India** | `custom-india` or upload your custom dataset zip | `/kaggle/input/custom-india` |

---

## 3. The 30-Line Kaggle Runner Notebook

Create a code cell at the top of your notebook to clone the repository and run the pipeline.

### Setup Cell (Run once per session)
```python
# 1. Clone the repository (if not already cloned)
import os
if not os.path.exists('/kaggle/working/civiclens'):
    print("Cloning repository...")
    !git clone https://github.com/Uni-coder-harsh/civiclens.git /kaggle/working/civiclens
else:
    print("Repository already cloned.")

# 2. Navigate to ml-engine
%cd /kaggle/working/civiclens/ml-engine

# 3. Install requirements
!pip install -r requirements.txt
```

### Development Pull Cell (Run whenever you push code from VS Code)
```python
# Pull latest code modifications from Github without re-cloning
%cd /kaggle/working/civiclens
!git checkout main
!git pull origin main
%cd /kaggle/working/civiclens/ml-engine
```

### Pipeline Execution Cell
```python
# Run the pipeline
from src.training.pipeline import run_pipeline

# This runs loading, preprocessing, training, evaluation, and exporting automatically
run_pipeline()
```

---

## 4. Retrieving Outputs & Artifacts

Once training completes, all artifacts will be generated in `/kaggle/working/outputs/`:
- **Weights**: `/kaggle/working/outputs/runs/detect/yolo11m_run/weights/best.onnx` (and `best.pt`)
- **Metrics**: `/kaggle/working/outputs/runs/detect/yolo11m_run/results.csv`
- **Validation Visualizations**: Confusion matrices and curves in `/kaggle/working/outputs/runs/detect/yolo11m_run/`

To download them directly, you can download files from the Kaggle Output viewer or run a command to upload them to Hugging Face or another cloud storage.
