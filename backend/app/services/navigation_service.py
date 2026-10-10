import logging
import math
from typing import Dict, Any, List, Optional
import httpx
from app.core.config import settings
from app.services.maps_service import haversine_distance_km

logger = logging.getLogger("fleetopt.navigation")

class NavigationService:
    """Road navigation and turn-by-turn guidance service."""
    def __init__(self):
        self.routing_key = settings.ROUTING_API_KEY or settings.GOOGLE_MAPS_API_KEY

    def is_google_routes_configured(self) -> bool:
        return bool(self.routing_key and not self.routing_key.startswith("AIzaSyExample"))

    async def get_route_navigation(
        self,
        origin_lat: float,
        origin_lng: float,
        dest_lat: float,
        dest_lng: float,
        stops: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        """
        Generates full road route geometry, turn maneuvers, distance, and ETA.
        Uses OSRM / Google Routes API with urban corridor fallback.
        """
        stops = stops or []
        waypoints_coords = [f"{origin_lng},{origin_lat}"]
        for s in stops:
            waypoints_coords.append(f"{s['lng']},{s['lat']}")
        waypoints_coords.append(f"{dest_lng},{dest_lat}")

        # 1. Attempt OSRM Public Driving Routing for genuine road geometry & maneuvers
        try:
            coord_str = ";".join(waypoints_coords)
            url = f"https://router.project-osrm.org/route/v1/driving/{coord_str}?overview=full&geometries=geojson&steps=true"
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.get(url)
                if resp.status_code == 200:
                    data = resp.json()
                    routes = data.get("routes", [])
                    if routes:
                        r0 = routes[0]
                        geometry = r0.get("geometry", {}).get("coordinates", [])
                        legs = r0.get("legs", [])
                        
                        steps_list = []
                        for leg in legs:
                            for step in leg.get("steps", []):
                                maneuver = step.get("maneuver", {})
                                m_type = maneuver.get("type", "turn")
                                m_modifier = maneuver.get("modifier", "straight")
                                name = step.get("name") or "Transit Corridor"
                                
                                instruction = f"{m_type.capitalize()} {m_modifier} onto {name}" if name else f"Continue {m_modifier}"
                                steps_list.append({
                                    "instruction": instruction,
                                    "distance_meters": int(step.get("distance", 0)),
                                    "duration_seconds": int(step.get("duration", 0)),
                                    "maneuver_type": m_type,
                                    "maneuver_modifier": m_modifier,
                                    "location": maneuver.get("location", [origin_lng, origin_lat])
                                })

                        total_distance_km = round(r0.get("distance", 0) / 1000.0, 2)
                        total_duration_minutes = round(r0.get("duration", 0) / 60.0, 1)

                        return {
                            "provider": "OSRM Road Network",
                            "total_distance_km": total_distance_km,
                            "estimated_duration_minutes": total_duration_minutes,
                            "traffic_aware": False,
                            "polyline_coordinates": [[pt[1], pt[0]] for pt in geometry],  # [lat, lng]
                            "steps": steps_list,
                            "next_instruction": steps_list[0]["instruction"] if steps_list else "Head toward route corridor",
                            "external_navigation_url": f"https://www.google.com/maps/dir/?api=1&origin={origin_lat},{origin_lng}&destination={dest_lat},{dest_lng}&travelmode=driving"
                        }
        except Exception as e:
            logger.info(f"[NavigationService] OSRM router unavailable ({e}). Using street grid synthesis.")

        # 2. Resilient Urban Manhattan Grid Route Synthesizer
        # Generates realistic right-angle street turns rather than straight lines
        synthesized_polyline: List[List[float]] = []
        synthesized_steps: List[Dict[str, Any]] = []
        all_points = [{"lat": origin_lat, "lng": origin_lng, "name": "Current Location"}]
        for s in stops:
            all_points.append({"lat": s["lat"], "lng": s["lng"], "name": s.get("name", "Stop")})
        all_points.append({"lat": dest_lat, "lng": dest_lng, "name": "Destination Hub"})

        total_distance = 0.0
        for i in range(len(all_points) - 1):
            p1 = all_points[i]
            p2 = all_points[i+1]
            
            # Corner waypoint (Manhattan grid step)
            corner_lat = p2["lat"]
            corner_lng = p1["lng"]

            # Segment distances
            d1 = haversine_distance_km(p1["lat"], p1["lng"], corner_lat, corner_lng)
            d2 = haversine_distance_km(corner_lat, corner_lng, p2["lat"], p2["lng"])
            seg_dist = d1 + d2
            total_distance += seg_dist

            synthesized_polyline.extend([
                [round(p1["lat"], 6), round(p1["lng"], 6)],
                [round(corner_lat, 6), round(corner_lng, 6)],
                [round(p2["lat"], 6), round(p2["lng"], 6)]
            ])

            synthesized_steps.append({
                "instruction": f"Head toward {corner_lat:.4f}, turn toward {p2['name']}",
                "distance_meters": int(seg_dist * 1000),
                "duration_seconds": int((seg_dist / 28.0) * 3600),
                "maneuver_type": "turn",
                "maneuver_modifier": "right" if p2["lng"] > p1["lng"] else "left",
                "location": [p1["lng"], p1["lat"]]
            })

        synthesized_steps.append({
            "instruction": f"Arrive at {all_points[-1]['name']}",
            "distance_meters": 0,
            "duration_seconds": 0,
            "maneuver_type": "arrive",
            "maneuver_modifier": "straight",
            "location": [dest_lng, dest_lat]
        })

        total_duration = max(2.0, round((total_distance / 28.0) * 60.0, 1))

        return {
            "provider": "Urban Grid Corridor Synthesizer",
            "total_distance_km": round(total_distance, 2),
            "estimated_duration_minutes": total_duration,
            "traffic_aware": False,
            "polyline_coordinates": synthesized_polyline,
            "steps": synthesized_steps,
            "next_instruction": synthesized_steps[0]["instruction"] if synthesized_steps else "Proceed onto designated bus lane",
            "external_navigation_url": f"https://www.google.com/maps/dir/?api=1&origin={origin_lat},{origin_lng}&destination={dest_lat},{dest_lng}&travelmode=driving"
        }

navigation_service = NavigationService()
