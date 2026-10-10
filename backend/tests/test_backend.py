import pytest
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.optimization.vehicle_scheduler import VehicleScheduler
from app.optimization.driver_rosterer import DriverRosterer
from app.optimization.joint_optimizer import JointFleetOptimizer
from app.optimization.what_if_simulator import WhatIfSimulator
from app.ml.demand_predictor import DemandPredictor
from app.security.auth import hash_password, verify_password, create_access_token, decode_token

# Test 1: Authentication and Password Hashing
def test_password_hashing():
    pw = "SecretTransitPass123!"
    hashed = hash_password(pw)
    assert hashed != pw
    assert verify_password(pw, hashed) is True
    assert verify_password("WrongPass", hashed) is False

def test_jwt_token():
    token = create_access_token(data={"sub": "user-123", "role": "super_admin"})
    payload = decode_token(token)
    assert payload is not None
    assert payload.get("sub") == "user-123"
    assert payload.get("role") == "super_admin"

# Test 2: Vehicle Scheduling Optimizer (VSP)
def test_vehicle_scheduler_normal():
    scheduler = VehicleScheduler(time_limit_seconds=10)
    trips = [
        {"id": "t1", "trip_number": "TRIP-01", "start_time": "08:00", "end_time": "09:00", "demand": 40, "route_id": "r1"},
        {"id": "t2", "trip_number": "TRIP-02", "start_time": "09:30", "end_time": "10:30", "demand": 45, "route_id": "r1"},
        {"id": "t3", "trip_number": "TRIP-03", "start_time": "08:30", "end_time": "09:30", "demand": 30, "route_id": "r2"},
    ]
    vehicles = [
        {"id": "v1", "plate_number": "BUS-101", "capacity": 55, "status": "active", "cost_per_km": 1.8},
        {"id": "v2", "plate_number": "BUS-102", "capacity": 55, "status": "active", "cost_per_km": 1.8},
    ]

    result = scheduler.solve(trips=trips, vehicles=vehicles)
    assert result["solver_status"] in ["OPTIMAL", "FEASIBLE"]
    assert result["covered_trips"] == 3
    assert result["uncovered_trips"] == 0
    # t1 and t2 can be sequential on v1, while t3 overlaps with t1 so needs v2
    assert result["assignments"]["t1"] is not None
    assert result["assignments"]["t2"] is not None
    assert result["assignments"]["t3"] is not None

def test_vehicle_scheduler_insufficient_fleet():
    # 2 overlapping trips, only 1 vehicle -> 1 trip must be flagged uncovered via explicit penalty
    scheduler = VehicleScheduler(time_limit_seconds=10)
    trips = [
        {"id": "t1", "trip_number": "TRIP-01", "start_time": "08:00", "end_time": "09:00", "demand": 40, "route_id": "r1"},
        {"id": "t2", "trip_number": "TRIP-02", "start_time": "08:15", "end_time": "09:15", "demand": 45, "route_id": "r2"},
    ]
    vehicles = [
        {"id": "v1", "plate_number": "BUS-101", "capacity": 55, "status": "active", "cost_per_km": 1.8},
    ]
    result = scheduler.solve(trips=trips, vehicles=vehicles)
    assert result["covered_trips"] == 1
    assert result["uncovered_trips"] == 1
    assert len(result["uncovered_trip_ids"]) == 1

# Test 3: Driver Duty Rostering Optimizer (DDRP)
def test_driver_rosterer_normal_and_absence():
    rosterer = DriverRosterer(max_duty_hours=8.0, min_rest_hours=11.0, time_limit_seconds=10)
    trips = [
        {"id": "t1", "trip_number": "TRIP-01", "start_time": "08:00", "end_time": "09:30", "required_qualification": "standard_bus"},
        {"id": "t2", "trip_number": "TRIP-02", "start_time": "10:00", "end_time": "11:30", "required_qualification": "standard_bus"},
    ]
    drivers = [
        {"id": "d1", "user_name": "Driver One", "qualifications": ["standard_bus"], "preferences": {"shift": "morning"}},
        {"id": "d2", "user_name": "Driver Two", "qualifications": ["standard_bus"], "preferences": {"shift": "morning"}},
    ]
    # Normal solve
    res = rosterer.solve(trips=trips, drivers=drivers)
    assert res["covered_trips"] == 2
    assert res["uncovered_trips"] == 0

    # With driver 1 absent
    res_absent = rosterer.solve(trips=trips, drivers=drivers, absent_driver_ids=["d1"])
    assert res_absent["covered_trips"] == 2
    # Driver 2 should cover sequential trips
    assert res_absent["assignments"]["t1"] == "d2"
    assert res_absent["assignments"]["t2"] == "d2"

# Test 4: Joint Optimizer
def test_joint_optimizer():
    optimizer = JointFleetOptimizer(max_duty_hours=8.0, time_limit_seconds=10)
    trips = [
        {"id": "t1", "trip_number": "TRIP-01", "start_time": "08:00", "end_time": "09:00", "demand": 40, "route_id": "r1"},
        {"id": "t2", "trip_number": "TRIP-02", "start_time": "09:30", "end_time": "10:30", "demand": 40, "route_id": "r1"},
    ]
    vehicles = [
        {"id": "v1", "plate_number": "BUS-101", "capacity": 50, "status": "active"},
    ]
    drivers = [
        {"id": "d1", "qualifications": ["standard_bus"], "preferences": {"shift": "morning"}},
    ]
    joint_res = optimizer.optimize(trips=trips, vehicles=vehicles, drivers=drivers)
    assert joint_res["total_trips"] == 2
    assert joint_res["covered_trips"] == 2
    assert joint_res["vehicles_used"] == 1
    assert joint_res["drivers_used"] == 1

# Test 5: What-If Simulator
def test_what_if_simulator():
    sim = WhatIfSimulator()
    trips = [
        {"id": "t1", "trip_number": "TRIP-01", "start_time": "08:00", "end_time": "09:00", "demand": 40, "route_id": "r1"},
        {"id": "t2", "trip_number": "TRIP-02", "start_time": "08:30", "end_time": "09:30", "demand": 40, "route_id": "r1"},
    ]
    vehicles = [
        {"id": "v1", "plate_number": "BUS-101", "capacity": 50, "status": "active"},
        {"id": "v2", "plate_number": "BUS-102", "capacity": 50, "status": "active"},
    ]
    drivers = [
        {"id": "d1", "qualifications": ["standard_bus"], "preferences": {"shift": "morning"}},
        {"id": "d2", "qualifications": ["standard_bus"], "preferences": {"shift": "morning"}},
    ]

    # Simulate 1 vehicle breakdown
    sim_res = sim.run_simulation(
        base_trips=trips,
        base_vehicles=vehicles,
        base_drivers=drivers,
        vehicle_breakdowns_count=1
    )
    assert sim_res["baseline_covered"] == 2
    # Because trips overlap and 1 of 2 vehicles broke down, 1 trip must become uncovered
    assert sim_res["simulated_uncovered"] >= 1

# Test 6: AI Passenger Demand Predictor
def test_demand_predictor():
    predictor = DemandPredictor()
    # Test fallback baseline before training
    baseline_pred = predictor.predict(route_id="route-r101", time_window="08:00-09:00")
    assert "predicted_passengers" in baseline_pred
    assert baseline_pred["demand_level"] in ["Low", "Moderate", "High", "Surge"]

    # Generate synthetic training records
    records = []
    for h in range(6, 22):
        for d in range(1, 6):
            records.append({
                "route_id": "route-r101",
                "time_window": f"{h:02d}:00-{(h+1):02d}:00",
                "day_of_week": d,
                "is_holiday": False,
                "is_event": False,
                "actual_passengers": 30 + (25 if h in [8, 9, 17, 18] else 5),
                "weather": "Clear"
            })
    metrics = predictor.train(records)
    assert predictor.is_trained is True
    assert "mae" in metrics
    assert "rmse" in metrics

    # Predict with trained model
    pred = predictor.predict(route_id="route-r101", time_window="08:00-09:00", weather="Clear")
    assert pred["estimation_method"] == "RandomForestRegressor"
    assert pred["predicted_passengers"] >= 20
