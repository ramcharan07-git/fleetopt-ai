import pytest
import sys
import os
from datetime import datetime

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient
from app.main import app
from app.database.session import SessionLocal
from app.database.mysql import check_mysql_health
from app.database.mongodb import mongo_manager
from app.models.entities import Driver, Vehicle, Route, Trip, Incident, Schedule, User
from app.security.auth import create_access_token
from app.services.navigation_service import navigation_service
from app.services.maps_service import haversine_distance_km

client = TestClient(app)

# Test 1: Login & Token Authentication
def test_1_login_authentication():
    response = client.post("/api/auth/login", json={
        "email": "admin@fleetopt.ai",
        "password": "AdminPass123!"
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["user"]["role"] == "super_admin"

# Test 2: Read Driver Record from Relational / MySQL Database
def test_2_read_driver_record_from_db():
    db = SessionLocal()
    try:
        driver = db.query(Driver).first()
        assert driver is not None
        assert driver.employee_id is not None
        assert driver.license_number is not None
    finally:
        db.close()

# Test 3: Read Vehicles and Route Assignments
def test_3_read_vehicles_and_routes():
    res_veh = client.get("/api/vehicles")
    assert res_veh.status_code == 200
    vehicles = res_veh.json()
    assert len(vehicles) >= 10

    res_routes = client.get("/api/routes")
    assert res_routes.status_code == 200
    routes = res_routes.json()
    assert len(routes) >= 4

# Test 4: Health of Dual-Databases (MySQL & MongoDB)
def test_4_dual_database_health():
    mysql_health = check_mysql_health()
    assert mysql_health["status"] == "healthy"
    assert mysql_health["latency_ms"] >= 0

    mongo_health = mongo_manager.health_check()
    assert mongo_health["status"] in ["healthy", "not_configured", "in_memory_fallback"]
    assert "vehicle_locations" in mongo_health["collections"]

# Test 5: Start Authorized Vehicle Tracking Session
def test_5_start_tracking_session():
    res = client.post("/api/tracking/start", json={
        "vehicle_id": "veh-001",
        "trip_id": "trip-r101-01",
        "driver_id": "drv-001"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "tracking_active"
    assert "session_id" in data
    assert data["vehicle_id"] == "veh-001"

# Test 6: Write GPS Data to MongoDB
def test_6_write_gps_to_mongodb():
    payload = {
        "vehicle_id": "veh-001",
        "session_id": "nav-sess-unit-test",
        "latitude": 40.7527,
        "longitude": -73.9772,
        "speed_kmh": 36.5,
        "heading": 85.0,
        "accuracy_meters": 4.5
    }
    res = client.post("/api/tracking/location", json=payload)
    assert res.status_code == 200
    assert res.json()["status"] == "ingested"

    # Verify directly inside MongoDB collection
    coll = mongo_manager.get_collection("vehicle_locations")
    doc = coll.find_one({"vehicle_id": "veh-001"})
    assert doc is not None
    assert doc["latitude"] == 40.7527
    assert doc["speed_kmh"] == 36.5
    assert doc["location"]["type"] == "Point"

# Test 7: Retrieve Latest Stored GPS Coordinates
def test_7_get_latest_stored_gps():
    res = client.get("/api/vehicles/veh-001/location")
    assert res.status_code == 200
    data = res.json()
    assert data["latitude"] == 40.7527
    assert data["longitude"] == -73.9772
    assert data["speed_kmh"] == 36.5
    assert data["is_stale"] is False

# Test 8: Display Bus Movement on Live Map Telemetry
def test_8_live_map_vehicle_telemetry():
    res = client.get("/api/vehicle-locations")
    assert res.status_code == 200
    buses = res.json()
    assert len(buses) >= 8
    # Has compass heading and route details
    assert "heading" in buses[0]
    assert "next_stop" in buses[0]
    assert "eta_minutes" in buses[0]

# Test 9: Generate Road Directions, Maneuvers & ETA
def test_9_turn_by_turn_road_directions():
    res = client.get("/api/navigation/route?origin_lat=40.7527&origin_lng=-73.9772&dest_lat=40.7071&dest_lng=-74.0090")
    assert res.status_code == 200
    data = res.json()
    assert "total_distance_km" in data
    assert data["total_distance_km"] > 0
    assert "polyline_coordinates" in data
    assert len(data["polyline_coordinates"]) >= 3
    assert "steps" in data
    assert len(data["steps"]) >= 1
    assert "external_navigation_url" in data

# Test 10: Report Bus Breakdown Incident
def test_10_report_bus_breakdown():
    admin_token = create_access_token(data={"sub": "u-admin-001", "role": "super_admin"})
    res = client.post(
        "/api/incidents",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "incident_type": "breakdown",
            "vehicle_id": "veh-001",
            "description": "Engine overheat near 34th St Herald Sq",
            "severity": "critical"
        }
    )
    assert res.status_code == 200
    inc = res.json()
    assert inc["incident_type"] == "breakdown"
    assert inc["severity"] == "critical"

# Test 11: Find Feasible Nearby Replacement Vehicles
def test_11_find_nearest_replacement_buses():
    res = client.get("/api/replacements/nearest?broken_vehicle_id=veh-001")
    assert res.status_code == 200
    data = res.json()
    assert data["total_candidates_evaluated"] > 0
    assert len(data["proposals"]) > 0
    # Replacement has road distance and feasible driver
    best = data["recommendation"]
    assert best is not None
    assert "plate_number" in best
    assert "travel_time_minutes" in best
    assert "feasible_driver" in best
    assert best["road_distance_km"] >= 0

# Test 12: Run Schedule Reoptimization with Disruption
def test_12_run_schedule_reoptimization():
    import uuid
    admin_token = create_access_token(data={"sub": "u-admin-001", "role": "super_admin"})
    db = SessionLocal()
    try:
        sched = db.query(Schedule).first()
        if not sched:
            sched = Schedule(
                id=str(uuid.uuid4()),
                name="Master Transit Schedule 2026-10-10",
                date="2026-10-10",
                version=1,
                status="draft"
            )
            db.add(sched)
            db.commit()

        inc = db.query(Incident).first()
        if not inc:
            inc = Incident(
                id=str(uuid.uuid4()),
                incident_type="breakdown",
                severity="medium",
                status="open",
                description="Engine test breakdown",
                reported_at=datetime.utcnow()
            )
            db.add(inc)
            db.commit()

        inc_id = inc.id
        sched_id = sched.id
    finally:
        db.close()

    res = client.post(
        "/api/reschedule",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "incident_id": inc_id,
            "schedule_id": sched_id
        }
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] in ["success", "rescheduled", "disruption_managed"]

# Test 13: Stop Active Tracking Session Upon Trip Completion
def test_13_stop_tracking_session():
    res = client.post("/api/tracking/stop", json={
        "vehicle_id": "veh-001",
        "reason": "trip_completed"
    })
    assert res.status_code == 200
    assert res.json()["status"] == "tracking_stopped"

# Test 14: Verify Safe Offline Fallback Behavior
def test_14_safe_offline_fallback():
    # If external routing is unavailable, geometric corridor model responds cleanly
    matrix_res = pytest.importorskip("asyncio").run(
        navigation_service.get_route_navigation(40.75, -73.98, 40.71, -74.00)
    )
    assert matrix_res["total_distance_km"] > 0
    assert len(matrix_res["polyline_coordinates"]) > 0

# Test 15: Role-based Authorization / Security
def test_15_role_authorization_check():
    # Attempting to access admin-only dispatch endpoints without token or as passenger
    pass_token = create_access_token(data={"sub": "u-pass-001", "role": "passenger"})
    res = client.post(
        "/api/schedules/sched-2026-10-10/approve",
        headers={"Authorization": f"Bearer {pass_token}"}
    )
    # Must be 403 Forbidden for passenger role
    assert res.status_code in [401, 403]
