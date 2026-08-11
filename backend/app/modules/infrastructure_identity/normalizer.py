import re


def normalize_company_name(name: str) -> str:
    """
    Normalizes corporate names for robust cross-source matching.
    Preserves company identity while eliminating formatting variations.

    Example:
    'ABC Infrastructure Pvt Ltd' -> 'ABC INFRASTRUCTURE'
    'ABC Infra Pvt. Ltd.' -> 'ABC INFRASTRUCTURE'
    """
    if not name:
        return ""

    text = name.upper().strip()

    # Expand common abbreviations for consistent matching
    text = re.sub(r'\bINFRA\b', 'INFRASTRUCTURE', text)
    text = re.sub(r'\bCONST\b', 'CONSTRUCTION', text)
    text = re.sub(r'\bENGG\b', 'ENGINEERING', text)

    # Strip legal entity suffixes
    suffixes = [
        r'\bPRIVATE\s+LIMITED\b', r'\bPVT\.?\s*LTD\.?\b', r'\bLIMITED\b', r'\bLTD\.?\b',
        r'\bCORP(ORATION)?\b', r'\bINC(ORPORATED)?\b', r'\bCO(MPANY)?\b', r'\bLLP\b'
    ]
    for s in suffixes:
        text = re.sub(s, '', text)

    # Remove non-alphanumeric characters except spaces
    text = re.sub(r'[^A-Z0-9\s]', '', text)

    # Collapse multiple whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def normalize_road_name(name: str) -> str:
    """
    Normalizes Indian road and highway designations into standard codes.

    Example:
    'National Highway 44' -> 'NH-44'
    'N.H. 44' -> 'NH-44'
    'State Highway 12' -> 'SH-12'
    """
    if not name:
        return ""

    text = name.strip()

    # Match National Highways
    nh_match = re.search(r'(?:NATIONAL\s+HIGHWAY|N\.?H\.?)[-\s]*([0-9A-Z]+)', text, re.IGNORECASE)
    if nh_match:
        number = nh_match.group(1).lstrip('0')
        return f"NH-{number}"

    # Match State Highways
    sh_match = re.search(r'(?:STATE\s+HIGHWAY|S\.?H\.?)[-\s]*([0-9A-Z]+)', text, re.IGNORECASE)
    if sh_match:
        number = sh_match.group(1).lstrip('0')
        return f"SH-{number}"

    # Match Major District Roads
    mdr_match = re.search(r'(?:MAJOR\s+DISTRICT\s+ROAD|M\.?D\.?R\.?)[-\s]*([0-9A-Z]+)', text, re.IGNORECASE)
    if mdr_match:
        number = mdr_match.group(1).lstrip('0')
        return f"MDR-{number}"

    return text


def normalize_authority_name(authority: str) -> str:
    """
    Normalizes authority names to canonical abbreviations.
    """
    if not authority:
        return "Local Road Authority"

    text = authority.upper().strip()

    if any(k in text for k in ["NHAI", "NATIONAL HIGHWAYS AUTHORITY"]):
        return "NHAI"
    if any(k in text for k in ["MORTH", "MINISTRY OF ROAD TRANSPORT"]):
        return "MoRTH"
    if any(k in text for k in ["PMGSY", "GRAM SADAK"]):
        return "PMGSY"
    if any(k in text for k in ["PWD", "PUBLIC WORKS"]):
        return "State PWD"
    if any(k in text for k in ["BBMP", "MUNICIPAL", "CORPORATION"]):
        return "Municipal Authority"

    return authority.title()
