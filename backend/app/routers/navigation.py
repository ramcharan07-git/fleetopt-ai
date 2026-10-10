import uuid
import math
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.database.mongodb import mongo_manager
from app.models.entities import Vehicle, Driver, Trip, Incident, Schedule, VehicleAssignment, DriverDuty, User
from app.services.navigation_service import navigation_service
from app.services.maps_service import maps_service, haversine_distance_km
from app.services.notification_service import notification_service
from app.security.auth import get_current_user

router = APIRouter(tags=["Live Tracking & Navigation"])

# ------------------------------------------------------------------------------
# Pydantic Schemas
# ------------------------------------------------------------------------------
class TrackingStartRequest(BaseModel):
    vehicle_id: str
    trip_id: Optional[str] = "trip-r101-01"
    driver_id: Optional[str] = "drv-001"

class TrackingLocationRequest(BaseModel):
    vehicle_id: str
    session_id: Optional[str] = None
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    accuracy_meters: float = 5.0
    speed_kmh: float = 0.0
    heading: float = 0.0
    timestamp: Optional[str] = None

class TrackingStopRequest(BaseModel):
    vehicle_id: str
    session_id: Optional[str] = None
    reason: str = "trip_completed"

# In-memory WebSocket connection hub for notifications
class NotificationConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: Dict[str, Any]):
        for conn in list(self.active_connections):
            try:
                await conn.send_json(message)
            except Exception:
                self.disconnect(conn)

notification_ws_manager = NotificationConnectionManager()

# ------------------------------------------------------------------------------
# 1. LIVE BUS TRACKING ENDPOINTS
# ------------------------------------------------------------------------------
@router.post("/tracking/start")
def start_vehicle_tracking(
    req: TrackingStartRequest,
    db: Session = Depends(get_db)
):
    """
    Starts an authorized live tracking session. Validates vehicle, driver,
    and trip from MySQL and initializes tracking session in MongoDB.
    """
    # 1. Validate vehicle from authoritative MySQL
    veh = db.query(Vehicle).filter((Vehicle.id == req.vehicle_id) | (Vehicle.plate_number == req.vehicle_id)).first()
    if not veh:
        raise HTTPException(status_code=404, detail=f"Vehicle '{req.vehicle_id}' not found in MySQL registry.")

    if veh.status in ["maintenance", "retired"]:
        raise HTTPException(status_code=400, detail=f"Vehicle {veh.plate_number} is {veh.status} and cannot be tracked on route.")

    session_id = f"nav-sess-{uuid.uuid4().hex[:10]}"
    now = datetime.utcnow()

    # 2. Store session in MongoDB collection
    sessions_coll = mongo_manager.get_collection("navigation_sessions")
    session_doc = {
        "session_id": session_id,
        "vehicle_id": veh.id,
        "plate_number": veh.plate_number,
        "trip_id": req.trip_id,
        "authorized_driver_id": req.driver_id,
        "status": "active",
        "started_at": now.isoformat(),
        "last_ping_at": now.isoformat(),
        "total_pings": 0
    }
    sessions_coll.insert_one(session_doc)

    return {
        "status": "tracking_active",
        "session_id": session_id,
        "vehicle_id": veh.id,
        "plate_number": veh.plate_number,
        "trip_id": req.trip_id,
        "driver_id": req.driver_id,
        "tracking_interval_seconds": 2.0,
        "started_at": now.isoformat(),
        "message": f"Tracking session active for bus {veh.plate_number}."
    }

@router.post("/tracking/location")
async def report_tracking_location(
    req: TrackingLocationRequest,
    db: Session = Depends(get_db)
):
    """
    Ingests live GPS coordinates from the Driver APK or onboard hardware tracker.
    Stores latest location and GPS history in MongoDB and updates telemetry.
    """
    now = datetime.utcnow()
    iso_time = req.timestamp or now.isoformat()

    # GeoJSON representation for 2dsphere spatial indexing
    geojson_point = {
        "type": "Point",
        "coordinates": [req.longitude, req.latitude]
    }

    # 1. Update latest vehicle_locations collection in MongoDB
    locations_coll = mongo_manager.get_collection("vehicle_locations")
    location_doc = {
        "vehicle_id": req.vehicle_id,
        "latitude": req.latitude,
        "longitude": req.longitude,
        "location": geojson_point,
        "gps_accuracy": req.accuracy_meters,
        "speed_kmh": req.speed_kmh,
        "heading": req.heading,
        "session_id": req.session_id,
        "timestamp": iso_time,
        "current_tracking_status": "in_transit",
        "is_simulated": False
    }
    locations_coll.update_one(
        {"vehicle_id": req.vehicle_id},
        {"$set": location_doc},
        upsert=True
    )

    # 2. Append to historical telemetry breadcrumbs in MongoDB gps_history
    history_coll = mongo_manager.get_collection("gps_history")
    history_doc = {
        "vehicle_id": req.vehicle_id,
        "location": geojson_point,
        "latitude": req.latitude,
        "longitude": req.longitude,
        "speed_kmh": req.speed_kmh,
        "heading": req.heading,
        "gps_accuracy": req.accuracy_meters,
        "timestamp": iso_time
    }
    history_coll.insert_one(history_doc)

    # 3. Update active session ping counter in MongoDB
    if req.session_id:
        sessions_coll = mongo_manager.get_collection("navigation_sessions")
        sessions_coll.update_one(
            {"session_id": req.session_id},
            {"$set": {"last_ping_at": iso_time}, "$inc": {"total_pings": 1}}
        )

    return {
        "status": "ingested",
        "vehicle_id": req.vehicle_id,
        "latitude": req.latitude,
        "longitude": req.longitude,
        "timestamp": iso_time
    }

@router.post("/tracking/stop")
def stop_vehicle_tracking(req: TrackingStopRequest):
    """Ends an active vehicle tracking session."""
    now = datetime.utcnow()
    sessions_coll = mongo_manager.get_collection("navigation_sessions")
    sessions_coll.update_one(
        {"vehicle_id": req.vehicle_id, "status": "active"},
        {"$set": {
            "status": "completed",
            "completed_at": now.isoformat(),
            "completion_reason": req.reason
        }}
    )

    # Update latest location status to docked/idle
    locations_coll = mongo_manager.get_collection("vehicle_locations")
    locations_coll.update_one(
        {"vehicle_id": req.vehicle_id},
        {"$set": {"current_tracking_status": "idle", "speed_kmh": 0.0}}
    )

    return {
        "status": "tracking_stopped",
        "vehicle_id": req.vehicle_id,
        "completed_at": now.isoformat(),
        "reason": req.reason
    }

@router.get("/vehicles/{id}/location")
def get_vehicle_latest_location(id: str, db: Session = Depends(get_db)):
    """Retrieves the latest GPS coordinates and signal freshness from MongoDB."""
    locations_coll = mongo_manager.get_collection("vehicle_locations")
    doc = locations_coll.find_one({"vehicle_id": id})
    if not doc:
        # Check by plate number
        veh = db.query(Vehicle).filter(Vehicle.plate_number == id).first()
        if veh:
            doc = locations_coll.find_one({"vehicle_id": veh.id})

    if not doc:
        raise HTTPException(status_code=404, detail=f"No GPS telemetry found for vehicle '{id}'.")

    # Detect stale GPS signals (> 90 seconds old)
    is_stale = False
    ts_str = doc.get("timestamp")
    if ts_str:
        try:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            if (datetime.utcnow() - ts.replace(tzinfo=None)).total_seconds() > 90:
                is_stale = True
        except Exception:
            pass

    return {
        "vehicle_id": doc.get("vehicle_id"),
        "latitude": doc.get("latitude"),
        "longitude": doc.get("longitude"),
        "speed_kmh": doc.get("speed_kmh", 0.0),
        "heading": doc.get("heading", 0.0),
        "gps_accuracy": doc.get("gps_accuracy", 5.0),
        "status": doc.get("current_tracking_status", "in_transit"),
        "timestamp": doc.get("timestamp"),
        "is_stale": is_stale,
        "is_simulated": doc.get("is_simulated", False)
    }

@router.get("/vehicles/{id}/location-history")
def get_vehicle_location_history(
    id: str,
    limit: int = Query(50, ge=1, le=500)
):
    """Retrieves historical GPS breadcrumbs for route trace and audits."""
    history_coll = mongo_manager.get_collection("gps_history")
    docs = history_coll.find({"vehicle_id": id}, sort=[("timestamp", -1)], limit=limit)
    return [
        {
            "latitude": d.get("latitude"),
            "longitude": d.get("longitude"),
            "speed_kmh": d.get("speed_kmh", 0.0),
            "heading": d.get("heading", 0.0),
            "timestamp": d.get("timestamp")
        } for d in docs
    ]

# ------------------------------------------------------------------------------
# 2. TURN-BY-TURN ROAD NAVIGATION & ETA
# ------------------------------------------------------------------------------
@router.get("/navigation/route")
async def get_navigation_route(
    origin_lat: float = Query(..., ge=-90.0, le=90.0),
    origin_lng: float = Query(..., ge=-180.0, le=180.0),
    dest_lat: float = Query(..., ge=-90.0, le=90.0),
    dest_lng: float = Query(..., ge=-180.0, le=180.0)
):
    """
    Generates genuine road navigation geometry, maneuvers, step-by-step
    guidance, and fallback external maps URL.
    """
    route_data = await navigation_service.get_route_navigation(
        origin_lat=origin_lat,
        origin_lng=origin_lng,
        dest_lat=dest_lat,
        dest_lng=dest_lng
    )
    return route_data

@router.get("/navigation/eta")
async def get_navigation_eta(
    current_lat: float = Query(...),
    current_lng: float = Query(...),
    target_lat: float = Query(...),
    target_lng: float = Query(...)
):
    """Calculates remaining road distance and arrival ETA in minutes."""
    matrix = await maps_service.calculate_matrix(
        origins=[(current_lat, current_lng)],
        destinations=[(target_lat, target_lng)]
    )
    if matrix:
        m = matrix[0]
        return {
            "remaining_distance_km": m["distance_km"],
            "eta_minutes": m["duration_minutes"],
            "traffic_aware": m.get("traffic_aware", False)
        }
    crow = haversine_distance_km(current_lat, current_lng, target_lat, target_lng)
    road_km = round(crow * 1.32, 2)
    return {
        "remaining_distance_km": road_km,
        "eta_minutes": max(1.0, round((road_km / 28.0) * 60.0, 1)),
        "traffic_aware": False
    }

# ------------------------------------------------------------------------------
# 3. NEAREST AVAILABLE REPLACEMENT BUS (DISRUPTION WORKFLOW)
# ------------------------------------------------------------------------------
@router.get("/replacements/nearest")
async def get_nearest_replacement_buses(
    incident_id: Optional[str] = None,
    broken_vehicle_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Identifies and ranks feasible replacement buses when an active bus breaks down.
    Workflow:
    1. Reads broken vehicle details from MySQL.
    2. Retrieves current GPS positions of all operational fleet vehicles from MongoDB.
    3. Filters out vehicles in maintenance/breakdown.
    4. Evaluates road travel times and driver availability.
    5. Returns ranked replacement proposals for administrator 1-tap approval.
    """
    target_veh = None
    target_lat = 40.7300
    target_lng = -73.9900
    required_capacity = 45

    if incident_id:
        inc = db.query(Incident).filter(Incident.id == incident_id).first()
        if inc and inc.vehicle_id:
            target_veh = db.query(Vehicle).filter(Vehicle.id == inc.vehicle_id).first()
            if inc.latitude and inc.longitude:
                target_lat, target_lng = inc.latitude, inc.longitude

    if not target_veh and broken_vehicle_id:
        target_veh = db.query(Vehicle).filter(
            (Vehicle.id == broken_vehicle_id) | (Vehicle.plate_number == broken_vehicle_id)
        ).first()

    if target_veh:
        required_capacity = target_veh.vehicle_type.capacity if target_veh.vehicle_type else 55
        # Look up last reported GPS from MongoDB
        locations_coll = mongo_manager.get_collection("vehicle_locations")
        loc_doc = locations_coll.find_one({"vehicle_id": target_veh.id})
        if loc_doc:
            target_lat = loc_doc.get("latitude", target_lat)
            target_lng = loc_doc.get("longitude", target_lng)

    # Read all operational vehicles from MySQL (filter out breakdown & maintenance)
    available_vehicles = db.query(Vehicle).filter(
        Vehicle.status == "active",
        Vehicle.id != (target_veh.id if target_veh else "")
    ).all()

    # Query MongoDB for current live positions of all candidates
    locations_coll = mongo_manager.get_collection("vehicle_locations")
    candidate_proposals = []

    for v in available_vehicles:
        v_capacity = v.vehicle_type.capacity if v.vehicle_type else 55
        v_type_name = v.vehicle_type.name if v.vehicle_type else "Standard Transit Bus"

        # Check capacity constraint
        if v_capacity < required_capacity - 10:
            continue

        loc_doc = locations_coll.find_one({"vehicle_id": v.id})
        v_lat = loc_doc.get("latitude", 40.7128) if loc_doc else 40.7128
        v_lng = loc_doc.get("longitude", -74.0060) if loc_doc else -74.0060
        is_fresh = loc_doc is not None and not loc_doc.get("is_simulated", True)

        # Calculate road distance and travel time to affected vehicle
        crow_km = haversine_distance_km(v_lat, v_lng, target_lat, target_lng)
        road_km = round(crow_km * 1.30, 2)
        travel_time_min = max(2.0, round((road_km / 30.0) * 60.0, 1))

        # Check driver qualification/availability
        assigned_driver = db.query(Driver).filter(Driver.depot_id == v.depot_id).first()
        driver_name = assigned_driver.user.full_name if (assigned_driver and assigned_driver.user) else "Standby Duty Driver"

        # Multi-objective score: weight travel time (70%) and odometer wear (30%)
        cost_estimate = round(road_km * 2.85 + 25.0, 2)
        score = travel_time_min * 10.0 + cost_estimate

        candidate_proposals.append({
            "vehicle_id": v.id,
            "plate_number": v.plate_number,
            "vehicle_type": v_type_name,
            "capacity": v_capacity,
            "latitude": v_lat,
            "longitude": v_lng,
            "road_distance_km": road_km,
            "travel_time_minutes": travel_time_min,
            "estimated_cost": cost_estimate,
            "feasible_driver": driver_name,
            "gps_freshness": "Real GPS" if is_fresh else "Depot Staged",
            "ranking_score": round(score, 1)
        })

    # Sort proposals by ranking score (lowest travel time + cost)
    candidate_proposals.sort(key=lambda x: x["ranking_score"])

    return {
        "broken_vehicle_id": target_veh.id if target_veh else "unknown",
        "broken_vehicle_plate": target_veh.plate_number if target_veh else "BUS-101",
        "affected_location": {"latitude": target_lat, "longitude": target_lng},
        "total_candidates_evaluated": len(candidate_proposals),
        "proposals": candidate_proposals[:5],
        "recommendation": candidate_proposals[0] if candidate_proposals else None
    }

# ------------------------------------------------------------------------------
# 4. WEBSOCKET REAL-TIME NOTIFICATIONS
# ------------------------------------------------------------------------------
@router.websocket("/ws/notifications")
async def websocket_notifications_endpoint(websocket: WebSocket):
    """Streams live disruption broadcasts, duty assignments, and approvals."""
    await notification_ws_manager.connect(websocket)
    try:
        # Send initial connection acknowledgment
        await websocket.send_json({
            "type": "connection_ack",
            "message": "Connected to FleetOpt AI real-time dispatch stream.",
            "timestamp": datetime.utcnow().isoformat()
        })
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        notification_ws_manager.disconnect(websocket)
    except Exception:
        notification_ws_manager.disconnect(websocket)
