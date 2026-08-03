import xml.etree.ElementTree as ET
from pathlib import Path
import json

def convert_voc_bbox(size: tuple, box: tuple) -> tuple:
    """
    Converts VOC [xmin, ymin, xmax, ymax] to YOLO [x_center, y_center, width, height] (normalized).
    size: (width, height) of image
    box: (xmin, ymin, xmax, ymax) in pixels
    """
    dw = 1.0 / size[0] if size[0] > 0 else 0
    dh = 1.0 / size[1] if size[1] > 0 else 0
    x_center = (box[0] + box[2]) / 2.0
    y_center = (box[1] + box[3]) / 2.0
    w = box[2] - box[0]
    h = box[3] - box[1]
    
    # Restrict to bounds
    return (x_center * dw, y_center * dh, w * dw, h * dh)

def convert_coco_bbox(size: tuple, box: list) -> tuple:
    """
    Converts COCO [xmin, ymin, width, height] to YOLO [x_center, y_center, width, height] (normalized).
    size: (width, height) of image
    box: [xmin, ymin, width, height] in pixels
    """
    dw = 1.0 / size[0] if size[0] > 0 else 0
    dh = 1.0 / size[1] if size[1] > 0 else 0
    x_center = box[0] + box[2] / 2.0
    y_center = box[1] + box[3] / 2.0
    w = box[2]
    h = box[3]
    
    return (x_center * dw, y_center * dh, w * dw, h * dh)

def parse_voc_xml(xml_path: Path) -> list:
    """Parses a VOC XML annotation file and returns a list of bounding boxes with their label names."""
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
    except Exception as e:
        print(f"Error parsing XML file {xml_path}: {e}")
        return []
        
    size_elem = root.find('size')
    if size_elem is None:
        return []
    width = int(size_elem.find('width').text)
    height = int(size_elem.find('height').text)
    
    boxes = []
    for obj in root.findall('object'):
        label = obj.find('name').text
        bndbox = obj.find('bndbox')
        xmin = float(bndbox.find('xmin').text)
        ymin = float(bndbox.find('ymin').text)
        xmax = float(bndbox.find('xmax').text)
        ymax = float(bndbox.find('ymax').text)
        
        yolo_box = convert_voc_bbox((width, height), (xmin, ymin, xmax, ymax))
        boxes.append({"label": label, "bbox": yolo_box})
        
    return boxes
