import time
import math
from datetime import datetime
from typing import Dict, Any, List, Optional

# Realistic transit route paths with high-precision street coordinates (New York Transit Corridor)
ROUTE_GEOMETRIES = {
    "route-r101": {
        "id": "route-r101",
        "route_number": "R101",
        "name": "Downtown Express",
        "color": "#00A86B",  # Emerald Green
        "waypoints": [
            {"lat": 40.7527, "lng": -73.9772, "name": "Grand Central Terminal"},
            {"lat": 40.7536, "lng": -73.9832, "name": "Bryant Park (42nd St)"},
            {"lat": 40.7495, "lng": -73.9879, "name": "Herald Square (34th St)"},
            {"lat": 40.7411, "lng": -73.9897, "name": "Flatiron District (23rd St)"},
            {"lat": 40.7359, "lng": -73.9911, "name": "Union Square (14th St)"},
            {"lat": 40.7299, "lng": -73.9911, "name": "Astor Place (8th St)"},
            {"lat": 40.7188, "lng": -74.0006, "name": "SoHo Canal Street"},
            {"lat": 40.7127, "lng": -74.0059, "name": "City Hall Broadway"},
            {"lat": 40.7071, "lng": -74.0090, "name": "Wall Street Financial Hub"}
        ]
    },
    "route-r102": {
        "id": "route-r102",
        "route_number": "R102",
        "name": "Airport Shuttle",
        "color": "#2A6F97",  # Transit Blue
        "waypoints": [
            {"lat": 40.7580, "lng": -73.9855, "name": "Times Square Terminal"},
            {"lat": 40.7484, "lng": -73.9680, "name": "Midtown East / UN Plaza"},
            {"lat": 40.7440, "lng": -73.9480, "name": "Queens Plaza Link"},
            {"lat": 40.7380, "lng": -73.9100, "name": "Sunnyside Yards"},
            {"lat": 40.7300, "lng": -73.8650, "name": "Rego Park Center"},
            {"lat": 40.7130, "lng": -73.8310, "name": "Kew Gardens Interchange"},
            {"lat": 40.6850, "lng": -73.8050, "name": "Van Wyck South"},
            {"lat": 40.6440, "lng": -73.7820, "name": "JFK Airport Terminal 4"}
        ]
    },
    "route-r105": {
        "id": "route-r105",
        "route_number": "R105",
        "name": "Harbor Promenade",
        "color": "#FF9F1C",  # Amber Orange
        "waypoints": [
            {"lat": 40.7033, "lng": -74.0170, "name": "Battery Park Maritime"},
            {"lat": 40.7126, "lng": -74.0134, "name": "World Trade Center West"},
            {"lat": 40.7190, "lng": -74.0115, "name": "Tribeca Waterfront"},
            {"lat": 40.7330, "lng": -74.0090, "name": "West Village Greenway"},
            {"lat": 40.7460, "lng": -74.0080, "name": "Chelsea Piers Sports Complex"},
            {"lat": 40.7520, "lng": -74.0040, "name": "High Line North Park"},
            {"lat": 40.7540, "lng": -74.0020, "name": "Hudson Yards Transit Plaza"}
        ]
    },
    "route-r106": {
        "id": "route-r106",
        "route_number": "R106",
        "name": "Crosstown Link",
        "color": "#E63946",  # Crimson Red
        "waypoints": [
            {"lat": 40.7280, "lng": -73.9780, "name": "East Village 1st Ave"},
            {"lat": 40.7330, "lng": -73.9850, "name": "Stuyvesant Square"},
            {"lat": 40.7360, "lng": -73.9910, "name": "Union Square North"},
            {"lat": 40.7400, "lng": -73.9980, "name": "Chelsea 6th Ave"},
            {"lat": 40.7440, "lng": -74.0050, "name": "Meatpacking West"}
        ]
    }
}

def calculate_bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates compass heading from point 1 to point 2 (0 - 360 degrees)."""
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_lambda = math.radians(lon2 - lon1)

    y = math.sin(delta_lambda) * math.cos(phi2)
    x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(delta_lambda)
    theta = math.atan2(y, x)
    bearing = (math.degrees(theta) + 360.0) % 360.0
    return round(bearing, 1)

def haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Computes great-circle distance in meters between two GPS coordinates."""
    r = 6371000.0  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0)**2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r * c

class TelemetryEngine:
    """
    Real-Time GPS Telemetry Engine.
    Simulates moving bus trajectories with realistic kinematic progression,
    or accepts physical device GPS telemetry updates.
    """
    def __init__(self):
        # Override storage for real hardware GPS reports: {vehicle_id: data}
        self.hardware_gps_overrides: Dict[str, Dict[str, Any]] = {}
        # Reference epoch for synchronous deterministic continuous motion
        self.start_epoch = time.time()

    def report_hardware_gps(
        self,
        vehicle_id: str,
        latitude: float,
        longitude: float,
        speed_kmh: float,
        heading: float
    ) -> Dict[str, Any]:
        """Ingests real-time hardware GPS location from driver device."""
        now = datetime.utcnow()
        override = {
            "vehicle_id": vehicle_id,
            "latitude": latitude,
            "longitude": longitude,
            "speed_kmh": round(speed_kmh, 1),
            "heading": round(heading, 1),
            "timestamp": now.isoformat(),
            "is_simulated": False
        }
        self.hardware_gps_overrides[vehicle_id] = override
        return override

    def get_live_vehicle_telemetry(self, vehicle_id: str, bus_index: int) -> Dict[str, Any]:
        """
        Computes the current real-time GPS coordinates, speed, heading, and ETA
        for a fleet vehicle moving continuously along its route.
        """
        # Assign vehicle to a route based on index
        route_keys = list(ROUTE_GEOMETRIES.keys())
        route_key = route_keys[bus_index % len(route_keys)]
        route_info = ROUTE_GEOMETRIES[route_key]

        # If hardware device is reporting live GPS, return that real data enriched with route info!
        if vehicle_id in self.hardware_gps_overrides:
            data = dict(self.hardware_gps_overrides[vehicle_id])
            data["status"] = "In Transit (Hardware GPS)"
            data["driver_name"] = data.get("driver_name") or f"Driver #{bus_index + 1}"
            data["plate_number"] = data.get("plate_number") or f"BUS-{100 + bus_index + 1}"
            data["route_id"] = route_info["id"]
            data["route_number"] = route_info["route_number"]
            data["route_name"] = route_info["name"]
            data["color_hex"] = route_info["color"]
            data["capacity"] = 55
            data["occupancy_pax"] = data.get("occupancy_pax") or 32
            data["next_stop"] = data.get("next_stop") or route_info["waypoints"][1]["name"]
            data["distance_to_next_m"] = data.get("distance_to_next_m") or 350
            data["eta_minutes"] = data.get("eta_minutes") or 1.2
            data["direction"] = "Outbound"
            return data
        waypoints = route_info["waypoints"]
        num_points = len(waypoints)

        # Elapsed time in seconds
        elapsed = time.time() - self.start_epoch
        # Stagger each bus along the route by bus_index offset
        offset_seconds = bus_index * 45.0
        total_cycle_seconds = 240.0  # 4 minutes to complete full one-way route cycle

        # Position along path: float from 0 to (num_points - 1)
        cycle_progress = ((elapsed + offset_seconds) % (total_cycle_seconds * 2)) / total_cycle_seconds
        
        # Support round-trip ping-pong traversal
        if cycle_progress > 1.0:
            # Traveling back
            direction = "Inbound"
            param = (num_points - 1) * (2.0 - cycle_progress)
        else:
            direction = "Outbound"
            param = (num_points - 1) * cycle_progress

        idx_curr = min(num_points - 2, max(0, int(math.floor(param))))
        idx_next = idx_curr + 1
        fraction = param - idx_curr

        # Interpolate Lat and Lng smoothly
        p1 = waypoints[idx_curr]
        p2 = waypoints[idx_next]

        lat = p1["lat"] + (p2["lat"] - p1["lat"]) * fraction
        lng = p1["lng"] + (p2["lng"] - p1["lng"]) * fraction

        # Calculate bearing / heading
        if direction == "Outbound":
            bearing = calculate_bearing(p1["lat"], p1["lng"], p2["lat"], p2["lng"])
            next_stop_name = p2["name"]
            dist_to_next = haversine_distance_meters(lat, lng, p2["lat"], p2["lng"])
        else:
            bearing = calculate_bearing(p2["lat"], p2["lng"], p1["lat"], p1["lng"])
            next_stop_name = p1["name"]
            dist_to_next = haversine_distance_meters(lat, lng, p1["lat"], p1["lng"])

        # Realistic velocity profile
        # Slows down when approaching a stop (< 80 meters)
        if dist_to_next < 80.0:
            speed = 8.0 + (dist_to_next / 80.0) * 16.0
            status_text = "Approaching Stop"
        elif dist_to_next < 25.0:
            speed = 0.0
            status_text = "Boarding Passengers"
        else:
            # Cruising speed with slight sinusoidal variation
            speed = 36.0 + math.sin(elapsed * 0.2 + bus_index) * 8.0
            status_text = "In Transit"

        # ETA in minutes to next stop
        speed_mps = max(2.0, (speed * 1000.0) / 3600.0)
        eta_seconds = dist_to_next / speed_mps
        eta_minutes = round(eta_seconds / 60.0, 1)

        # Dynamic passenger occupancy
        capacity = 55
        pax = int(28 + math.sin(elapsed * 0.05 + bus_index) * 18)
        pax = max(10, min(capacity, pax))

        plate = f"BUS-{100 + bus_index + 1}"
        driver_name = f"Driver #{bus_index + 1}"

        return {
            "vehicle_id": vehicle_id,
            "plate_number": plate,
            "driver_name": driver_name,
            "route_id": route_info["id"],
            "route_number": route_info["route_number"],
            "route_name": route_info["name"],
            "color_hex": route_info["color"],
            "latitude": round(lat, 6),
            "longitude": round(lng, 6),
            "speed_kmh": round(speed, 1),
            "heading": bearing,
            "next_stop": next_stop_name,
            "distance_to_next_m": int(dist_to_next),
            "eta_minutes": eta_minutes,
            "occupancy_pax": pax,
            "capacity": capacity,
            "status": status_text,
            "direction": direction,
            "timestamp": datetime.utcnow().isoformat(),
            "is_simulated": True
        }

    def get_all_live_telemetry(self, vehicle_count: int = 12) -> List[Dict[str, Any]]:
        """Returns live telemetry for all active fleet buses."""
        telemetry_list = []
        for i in range(vehicle_count):
            veh_id = f"veh-{i+1:03d}"
            data = self.get_live_vehicle_telemetry(veh_id, i)
            telemetry_list.append(data)
        return telemetry_list

    def get_route_geometries(self) -> List[Dict[str, Any]]:
        """Returns full route polylines and stop waypoints for map rendering."""
        return list(ROUTE_GEOMETRIES.values())

# Global singleton telemetry engine
telemetry_engine = TelemetryEngine()
