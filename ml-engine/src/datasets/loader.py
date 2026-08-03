import os
import shutil
from pathlib import Path
from sklearn.model_selection import train_test_split
from tqdm import tqdm
from PIL import Image
from ..utils.logger import setup_logger
from ..preprocessing.convert import convert_voc_bbox, convert_coco_bbox, parse_voc_xml


logger = setup_logger("datasets.loader")

def prepare_unified_dataset(config: dict) -> Path:
    """
    Scans all enabled datasets in the configuration, converts their annotations
    to the target 7-class taxonomy, creates splits, and populates /tmp/unified_dataset
    using symlinks. Returns the path to the generated YOLO dataset yaml configuration.
    """
    unified_dir = Path(config["workspace"]["unified_data_dir"])
    logger.info(f"Setting up unified dataset directory at {unified_dir}")
    
    # Reset unified directory
    if unified_dir.exists():
        shutil.rmtree(unified_dir)
    
    for split in ["train", "val"]:
        (unified_dir / "images" / split).mkdir(parents=True, exist_ok=True)
        (unified_dir / "labels" / split).mkdir(parents=True, exist_ok=True)
        
    target_classes = config["target_classes"]
    class_to_idx = {name: idx for idx, name in enumerate(target_classes)}
    
    # We will accumulate records as a list of dicts:
    # {"image_path": Path or PIL.Image, "labels": [[class_idx, cx, cy, w, h]], "is_hf": bool}
    all_records = []
    
    datasets_cfg = config.get("datasets", {})
    
    for key, ds_info in datasets_cfg.items():
        if not ds_info.get("enabled", False):
            logger.info(f"Dataset {key} is disabled. Skipping.")
            continue
            
        logger.info(f"Processing dataset: {ds_info['name']} (Format: {ds_info['format']})")
        mapping = ds_info.get("class_mapping", {})
        
        if ds_info["format"] == "yolo":
            # Can have VOC XML annotations or YOLO text annotations
            root = Path(ds_info["root"])
            if not root.exists():
                logger.warning(f"Root path {root} for dataset {key} does not exist. Skipping.")
                continue
                
            # Scan for images
            image_extensions = [".jpg", ".jpeg", ".png", ".PNG", ".JPG"]
            img_files = []
            for ext in image_extensions:
                img_files.extend(root.glob(f"**/*{ext}"))
                
            for img_path in tqdm(img_files, desc=f"Loading YOLO/VOC from {key}"):
                # Find annotations: look for XML (VOC) or TXT (YOLO)
                xml_path = img_path.with_suffix(".xml")
                # Also try mapping from 'images' to 'annotations' or 'labels' directory
                # Example: RDD2022 has images in "China_Motorbike/images" and XML in "China_Motorbike/annotations/xmls"
                parts = list(img_path.parts)
                
                # Check for standard VOC XML
                xml_cand = None
                if "images" in parts:
                    idx = parts.index("images")
                    parts_xml = parts.copy()
                    parts_xml[idx] = "annotations"
                    # Add XML subdirectories if applicable
                    xml_cand = Path(*parts_xml).with_suffix(".xml")
                    if not xml_cand.exists() and "xmls" not in parts_xml:
                        parts_xml.insert(idx + 1, "xmls")
                        xml_cand = Path(*parts_xml).with_suffix(".xml")
                
                boxes = []
                if xml_cand and xml_cand.exists():
                    # Parse VOC XML
                    boxes = parse_voc_xml(xml_cand)
                elif xml_path.exists():
                    boxes = parse_voc_xml(xml_path)
                else:
                    # Look for YOLO .txt file in sibling labels directory
                    txt_cand = None
                    if "images" in parts:
                        idx = parts.index("images")
                        parts_txt = parts.copy()
                        parts_txt[idx] = "labels"
                        txt_cand = Path(*parts_txt).with_suffix(".txt")
                        
                    if txt_cand and txt_cand.exists():
                        # Parse YOLO txt
                        try:
                            with open(txt_cand, "r") as f:
                                for line in f:
                                    parts = line.strip().split()
                                    if len(parts) >= 5:
                                        src_class_id = int(parts[0])
                                        cx, cy, w, h = map(float, parts[1:5])
                                        target_class = mapping.get(src_class_id)
                                        if target_class in class_to_idx:
                                            boxes.append({
                                                "label": target_class,
                                                "bbox": (cx, cy, w, h)
                                            })
                        except Exception as e:
                            logger.error(f"Error reading labels from {txt_cand}: {e}")
                
                if boxes:
                    mapped_labels = []
                    for box in boxes:
                        label_name = box["label"]
                        # Some source label names are strings (e.g. from XML) and mapping keys might be ints or strings
                        target_class = mapping.get(label_name) or mapping.get(str(label_name)) or mapping.get(int(label_name) if str(label_name).isdigit() else None)
                        if target_class in class_to_idx:
                            c_idx = class_to_idx[target_class]
                            cx, cy, w, h = box["bbox"]
                            mapped_labels.append([c_idx, cx, cy, w, h])
                    if mapped_labels:
                        all_records.append({
                            "image_path": img_path,
                            "labels": mapped_labels,
                            "is_hf": False
                        })
                        
        elif ds_info["format"] == "coco":
            root = Path(ds_info["root"])
            if not root.exists():
                logger.warning(f"Root path {root} for dataset {key} does not exist. Skipping.")
                continue
                
            # Find any coco JSON file
            coco_files = list(root.glob("**/*.json"))
            if not coco_files:
                logger.warning(f"No COCO JSON metadata found in {root}")
                continue
                
            for coco_path in coco_files:
                try:
                    with open(coco_path, "r") as f:
                        coco_data = json.load(f)
                except Exception as e:
                    logger.error(f"Failed to load COCO JSON at {coco_path}: {e}")
                    continue
                
                # Check if it has expected COCO keys
                if "images" not in coco_data or "annotations" not in coco_data:
                    continue
                    
                logger.info(f"Parsing COCO JSON {coco_path}")
                images_dict = {img["id"]: img for img in coco_data["images"]}
                categories_dict = {cat["id"]: cat["name"] for cat in coco_data["categories"]}
                
                # Map annotations to image IDs
                img_annotations = {}
                for ann in coco_data["annotations"]:
                    img_id = ann["image_id"]
                    if img_id not in img_annotations:
                        img_annotations[img_id] = []
                    img_annotations[img_id].append(ann)
                    
                for img_id, anns in tqdm(img_annotations.items(), desc="Parsing COCO records"):
                    img_metadata = images_dict.get(img_id)
                    if not img_metadata:
                        continue
                    
                    img_filename = img_metadata["file_name"]
                    # Search for the image file locally
                    cand_paths = list(root.glob(f"**/{img_filename}"))
                    if not cand_paths:
                        continue
                    img_path = cand_paths[0]
                    img_w = img_metadata["width"]
                    img_h = img_metadata["height"]
                    
                    mapped_labels = []
                    for ann in anns:
                        cat_name = categories_dict.get(ann["category_id"])
                        target_class = mapping.get(cat_name) or mapping.get(str(cat_name))
                        if target_class in class_to_idx:
                            c_idx = class_to_idx[target_class]
                            bbox = ann["bbox"] # [xmin, ymin, w, h]
                            cx, cy, w, h = convert_coco_bbox((img_w, img_h), bbox)
                            mapped_labels.append([c_idx, cx, cy, w, h])
                            
                    if mapped_labels:
                        all_records.append({
                            "image_path": img_path,
                            "labels": mapped_labels,
                            "is_hf": False
                        })
                        
        elif ds_info["format"] == "hf":
            # Hugging Face Dataset loading
            hf_path = ds_info["hf_path"]
            logger.info(f"Loading dataset {hf_path} from Hugging Face hub...")
            try:
                from datasets import load_dataset
                # Load the train split
                hf_ds = load_dataset(hf_path, split="train")
                
                # Hugging Face object detection datasets typically feature structure:
                # { 'image': PIL.Image, 'objects': { 'bbox': [[ymin, xmin, ymax, xmax]], 'category': [0] } }
                # Let's inspect its features and parse
                features = hf_ds.features
                logger.info(f"Hugging Face dataset features: {features}")
                
                # Try to locate category class names
                category_names = []
                if "objects" in features and "category" in features["objects"].feature:
                    category_names = features["objects"].feature["category"].names
                
                for idx, item in enumerate(tqdm(hf_ds, desc="Parsing HF Dataset")):
                    # Check if 'image' and 'objects' keys exist
                    if "image" not in item or "objects" not in item:
                        continue
                        
                    pil_img = item["image"]
                    objects = item["objects"]
                    
                    bboxes = objects.get("bbox", [])
                    categories = objects.get("category", [])
                    
                    img_w, img_h = pil_img.size
                    mapped_labels = []
                    
                    for bbox, cat_id in zip(bboxes, categories):
                        # Some HF datasets store category as int, map it to category name
                        cat_name = category_names[cat_id] if cat_id < len(category_names) else str(cat_id)
                        target_class = mapping.get(cat_name) or mapping.get(str(cat_name)) or mapping.get(cat_id)
                        
                        if target_class in class_to_idx:
                            c_idx = class_to_idx[target_class]
                            # Bounding box formats in HF datasets can vary: COCO [xmin, ymin, w, h] is typical.
                            # We assume standard COCO format. If it is normalized or VOC, handle it.
                            # Let's check bounding box sizes. If values are <= 1.0, they might be normalized.
                            if any(val > 1.01 for val in bbox):
                                # Pixels
                                cx, cy, w, h = convert_coco_bbox((img_w, img_h), bbox)
                            else:
                                # Already normalized coco
                                cx = bbox[0] + bbox[2]/2.0
                                cy = bbox[1] + bbox[3]/2.0
                                w = bbox[2]
                                h = bbox[3]
                            mapped_labels.append([c_idx, cx, cy, w, h])
                            
                    if mapped_labels:
                        all_records.append({
                            "image_path": pil_img,
                            "labels": mapped_labels,
                            "is_hf": True,
                            "hf_index": idx
                        })
                        
            except Exception as e:
                logger.error(f"Failed to load/parse HF dataset {hf_path}: {e}")
                
    if not all_records:
        raise ValueError("No records found in any of the configured and enabled datasets. Please double check dataset mounts/configurations.")
        
    logger.info(f"Total unified annotations loaded: {len(all_records)}")
    
    # Split into train/validation (85% train, 15% validation)
    train_records, val_records = train_test_split(all_records, test_size=0.15, random_state=config.get("training", {}).get("seed", 42))
    
    logger.info(f"Split results: Train={len(train_records)}, Validation={len(val_records)}")
    
    def save_split_data(records, split_name):
        img_dir = unified_dir / "images" / split_name
        label_dir = unified_dir / "labels" / split_name
        
        for idx, rec in enumerate(tqdm(records, desc=f"Saving {split_name} split")):
            base_name = f"img_{split_name}_{idx:06d}"
            
            # Save or symlink image
            target_img_path = None
            if rec["is_hf"]:
                # Save PIL Image to target directory
                target_img_path = img_dir / f"{base_name}.jpg"
                rec["image_path"].convert("RGB").save(target_img_path)
            else:
                # Symlink local image to avoid copy overhead and disk space
                original_img_path = rec["image_path"]
                suffix = original_img_path.suffix
                target_img_path = img_dir / f"{base_name}{suffix}"
                try:
                    os.symlink(original_img_path, target_img_path)
                except FileExistsError:
                    pass
                except Exception as e:
                    # Fallback to copy if symlinking fails
                    shutil.copy(original_img_path, target_img_path)
            
            # Save label text file
            txt_path = label_dir / f"{base_name}.txt"
            with open(txt_path, "w") as f:
                for lbl in rec["labels"]:
                    line = f"{lbl[0]} {lbl[1]:.6f} {lbl[2]:.6f} {lbl[3]:.6f} {lbl[4]:.6f}\n"
                    f.write(line)

    save_split_data(train_records, "train")
    save_split_data(val_records, "val")
    
    # Write dataset_yolo.yaml for Ultralytics
    yolo_yaml_path = unified_dir / "dataset.yaml"
    yolo_yaml_content = {
        "path": str(unified_dir),
        "train": "images/train",
        "val": "images/val",
        "names": {idx: name for idx, name in enumerate(target_classes)}
    }
    
    import yaml
    with open(yolo_yaml_path, "w") as f:
        yaml.safe_dump(yolo_yaml_content, f, default_flow_style=False)
        
    logger.info(f"YOLO dataset config written to {yolo_yaml_path}")
    return yolo_yaml_path
