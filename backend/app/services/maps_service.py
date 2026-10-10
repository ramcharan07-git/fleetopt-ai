import math
import logging
from typing import Dict, Any, List, Optional, Tuple
import httpx
from app.core.config import settings

logger = logging.getLogger("fleetopt.maps")

def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates great-circle distance in kilometers between two coordinates."""
    r = 6371.0  # Earth radius in km
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0)**2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r * c

class MapsService:
    """Google Maps Platform integration with resilient local geometric fallback."""
    def __init__(self):
        self.api_key = settings.GOOGLE_MAPS_API_KEY

    def is_configured(self) -> bool:
        return bool(self.api_key and not self.api_key.startswith("AIzaSyExample"))

    async def calculate_matrix(
        self,
        origins: List[Tuple[float, float]],
        destinations: List[Tuple[float, float]],
        traffic_aware: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Calculates distance and travel time matrix between origin and destination points.
        Uses Google Distance Matrix API if configured, otherwise computes realistic road estimates.
        """
        if self.is_configured():
            try:
                orig_param = "|".join(f"{lat},{lng}" for lat, lng in origins)
                dest_param = "|".join(f"{lat},{lng}" for lat, lng in destinations)
                url = f"https://maps.googleapis.com/maps/api/distancematrix/json?origins={orig_param}&destinations={dest_param}&key={self.api_key}"
                if traffic_aware:
                    url += "&departure_time=now"
                
                async with httpx.AsyncClient(timeout=6.0) as client:
                    resp = await client.get(url)
                    data = resp.json()
                    if data.get("status") == "OK":
                        results = []
                        rows = data.get("rows", [])
                        for i, row in enumerate(rows):
                            elements = row.get("elements", [])
                            for j, elem in enumerate(elements):
                                if elem.get("status") == "OK":
                                    dur = elem.get("duration_in_traffic", elem.get("duration", {}))
                                    dist = elem.get("distance", {})
                                    results.append({
                                        "origin_index": i,
                                        "destination_index": j,
                                        "distance_km": round(dist.get("value", 0) / 1000.0, 2),
                                        "duration_minutes": round(dur.get("value", 0) / 60.0, 1),
                                        "traffic_aware": "duration_in_traffic" in elem
                                    })
                        return results
            except Exception as e:
                logger.warning(f"[MapsService] Google Matrix request failed: {e}. Using geometric road model.")

        # Kinematic road fallback: urban road tortuosity factor ~1.32, avg speed 28 km/h
        results = []
        for i, (lat1, lon1) in enumerate(origins):
            for j, (lat2, lon2) in enumerate(destinations):
                crow_km = haversine_distance_km(lat1, lon1, lat2, lon2)
                road_km = round(crow_km * 1.32, 2)
                # Traffic congestion factor during peak hours
                avg_speed_kmh = 28.0
                duration_min = round((road_km / avg_speed_kmh) * 60.0, 1)
                results.append({
                    "origin_index": i,
                    "destination_index": j,
                    "distance_km": road_km,
                    "duration_minutes": max(1.0, duration_min),
                    "traffic_aware": False,
                    "source": "urban_kinematic_model"
                })
        return results

    async def geocode(self, address: str) -> Optional[Dict[str, Any]]:
        """Geocodes an address into latitude and longitude."""
        if self.is_configured():
            try:
                url = f"https://maps.googleapis.com/maps/api/geocode/json?address={address}&key={self.api_key}"
                async with httpx.AsyncClient(timeout=5.0) as client:
                    resp = await client.get(url)
                    data = resp.json()
                    if data.get("status") == "OK" and data.get("results"):
                        loc = data["results"][0]["geometry"]["location"]
                        return {
                            "lat": loc["lat"],
                            "lng": loc["lng"],
                            "formatted_address": data["results"][0].get("formatted_address")
                        }
            except Exception as e:
                logger.warning(f"[MapsService] Geocode failed: {e}")
        return None

maps_service = MapsService()
