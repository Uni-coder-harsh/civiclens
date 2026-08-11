import math
from typing import List, Optional
from app.modules.infrastructure_identity.normalizer import (
    normalize_road_name,
    normalize_company_name,
    normalize_authority_name,
)


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculates great-circle distance between two geographic coordinates in meters.
    """
    R = 6371000.0  # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

    return R * c


def calculate_effective_distance(distance_m: float, gps_accuracy_m: Optional[float] = None) -> float:
    """
    Adjusts raw geographic distance to account for GPS accuracy / location uncertainty.

    Conceptually:
    effective_distance = distance / (gps_accuracy + epsilon)
    """
    accuracy = max(1.0, gps_accuracy_m if gps_accuracy_m is not None else 10.0)
    epsilon = 1.0
    return distance_m / (accuracy + epsilon)


def calculate_match_score(
    road_ref_match: bool,
    name_similarity: float,
    distance_m: float,
    gps_accuracy_m: Optional[float] = None,
    authority_match: bool = False,
    type_hint_match: bool = False,
) -> float:
    """
    Calculates candidate match score (0.0 to 1.0) using configurable feature weights.

    match_score = w1*road_ref + w2*name_sim + w3*geo_proximity + w4*authority + w5*type_hint
    """
    # Proximity score degrades smoothly up to 250m
    max_radius = 250.0
    geo_proximity_score = max(0.0, 1.0 - (distance_m / max_radius))

    w1 = 0.35  # Road reference (e.g. NH-44)
    w2 = 0.25  # Asset / bridge name similarity
    w3 = 0.25  # Geo proximity
    w4 = 0.10  # Authority hint
    w5 = 0.05  # Infrastructure type hint

    score = (
        (1.0 if road_ref_match else 0.0) * w1
        + name_similarity * w2
        + geo_proximity_score * w3
        + (1.0 if authority_match else 0.0) * w4
        + (1.0 if type_hint_match else 0.0) * w5
    )

    # Scale by GPS uncertainty factor if distance exceeds GPS accuracy threshold
    if gps_accuracy_m and gps_accuracy_m > 50.0 and distance_m > gps_accuracy_m:
        score *= 0.85

    return round(min(1.0, max(0.0, score)), 4)


def generate_procurement_query_signals(
    road_name: str,
    road_reference: Optional[str],
    district: Optional[str],
    state: Optional[str],
    type_hint: Optional[str],
) -> List[str]:
    """
    Constructs multiple search query signals for government eProcurement & Open Data portals.
    Prevents redundant network requests while ensuring high recall.
    """
    signals = []
    norm_road = normalize_road_name(road_reference or road_name)

    if norm_road and norm_road.startswith("NH-"):
        signals.append(norm_road)
        if district:
            signals.append(f"{norm_road} {district}")
    
    if road_name and road_name.lower() != norm_road.lower():
        signals.append(road_name)

    if type_hint and district:
        signals.append(f"{type_hint.lower()} {district}")

    if district and state:
        signals.append(f"infrastructure {district} {state}")

    # Deduplicate while preserving search order
    seen = set()
    deduped = []
    for s in signals:
        clean = s.strip()
        if clean and clean.lower() not in seen:
            seen.add(clean.lower())
            deduped.append(clean)

    return deduped[:5]
