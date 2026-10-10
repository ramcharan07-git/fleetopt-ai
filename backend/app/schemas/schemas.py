from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Any, Dict
from datetime import datetime

# Auth Schemas
class Token(BaseModel):
    access_token: str
    token_type: str
    user: Dict[str, Any]

class TokenPayload(BaseModel):
    sub: Optional[str] = None
    role: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: str = "passenger"

class UserResponse(BaseModel):
    id: str
    email: str
    full_name: str
    role: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

# Vehicle Schemas
class VehicleTypeResponse(BaseModel):
    id: str
    name: str
    capacity: int
    fuel_type: str
    cost_per_km: float

    class Config:
        from_attributes = True

class VehicleCreate(BaseModel):
    plate_number: str
    vehicle_type_id: str
    depot_id: str
    status: str = "active"
    year_manufactured: int = 2023
    odometer_km: float = 0.0

class VehicleUpdate(BaseModel):
    status: Optional[str] = None
    depot_id: Optional[str] = None
    odometer_km: Optional[float] = None

class VehicleResponse(BaseModel):
    id: str
    plate_number: str
    vehicle_type_id: Optional[str] = None
    depot_id: Optional[str] = None
    status: str
    odometer_km: float
    year_manufactured: int
    qr_code: Optional[str] = None

    class Config:
        from_attributes = True

# Driver Schemas
class DriverCreate(BaseModel):
    user_id: str
    employee_id: str
    depot_id: str
    license_number: str
    license_expiry: Optional[datetime] = None

class DriverUpdate(BaseModel):
    is_active: Optional[bool] = None
    depot_id: Optional[str] = None
    total_hours_this_week: Optional[float] = None

class DriverResponse(BaseModel):
    id: str
    user_id: str
    employee_id: str
    depot_id: Optional[str] = None
    license_number: str
    is_active: bool
    total_hours_this_week: float
    user: Optional[UserResponse] = None

    class Config:
        from_attributes = True

# Route & Trip Schemas
class StopResponse(BaseModel):
    id: str
    code: str
    name: str
    latitude: float
    longitude: float

    class Config:
        from_attributes = True

class RouteCreate(BaseModel):
    route_number: str
    name: str
    origin: str
    destination: str
    distance_km: float = 15.0
    estimated_duration_minutes: int = 45

class RouteResponse(BaseModel):
    id: str
    route_number: str
    name: str
    origin: str
    destination: str
    distance_km: float
    estimated_duration_minutes: int
    is_active: bool

    class Config:
        from_attributes = True

class TripCreate(BaseModel):
    route_id: str
    trip_number: str
    direction: str = "outbound"
    start_time: str
    end_time: str
    day_of_week: str = "daily"
    estimated_demand: int = 40

class TripResponse(BaseModel):
    id: str
    route_id: str
    trip_number: str
    direction: str
    start_time: str
    end_time: str
    day_of_week: str
    estimated_demand: int

    class Config:
        from_attributes = True

# Optimization Schemas
class OptimizeRequest(BaseModel):
    date: str  # YYYY-MM-DD
    schedule_name: Optional[str] = None
    max_duty_hours: float = 8.0
    min_rest_hours: float = 11.0
    weight_uncovered: float = 1000.0
    weight_deadhead: float = 1.0
    weight_overtime: float = 10.0
    time_limit_seconds: int = 30

class AssignmentDTO(BaseModel):
    trip_id: str
    trip_number: str
    route_number: str
    start_time: str
    end_time: str
    vehicle_id: Optional[str] = None
    vehicle_plate: Optional[str] = None
    driver_id: Optional[str] = None
    driver_name: Optional[str] = None
    uncovered: bool = False

class OptimizeResponse(BaseModel):
    schedule_id: str
    date: str
    solver_status: str
    solve_duration_seconds: float
    objective_score: float
    total_trips: int
    covered_trips: int
    uncovered_trips: int
    vehicles_used: int
    drivers_used: int
    estimated_cost: float
    assignments: List[AssignmentDTO]
    explanation: Optional[str] = None

class WhatIfSimulateRequest(BaseModel):
    date: str
    available_buses_count: Optional[int] = None
    absent_drivers_count: Optional[int] = None
    trip_multiplier: float = 1.0  # 0.8 to 1.5
    passenger_demand_percentage: float = 100.0
    vehicle_breakdowns_count: int = 0
    priority_mode: str = "balanced"  # balanced, cost_saver, max_service

class WhatIfSimulateResponse(BaseModel):
    baseline_covered: int
    simulated_covered: int
    baseline_cost: float
    simulated_cost: float
    uncovered_trips_count: int
    active_buses: int
    active_drivers: int
    solve_time_seconds: float
    constraint_violations: List[str] = []

# Schedule Approval
class ScheduleApprovalRequest(BaseModel):
    notes: Optional[str] = "Approved by transport manager"

# Driver Duties
class DriverDutyResponse(BaseModel):
    id: str
    duty_code: str
    start_time: str
    end_time: str
    total_driving_minutes: int
    status: str
    is_locked: bool
    uncovered: bool
    trips: List[Dict[str, Any]] = []

# Attendance
class AttendanceCheckInRequest(BaseModel):
    vehicle_id: str
    qr_code_hash: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class AttendanceResponse(BaseModel):
    id: str
    driver_id: str
    vehicle_id: str
    check_in_time: datetime
    status: str
    message: str

# Incident & Disruption
class IncidentCreate(BaseModel):
    incident_type: str  # breakdown, accident, delay, absence
    vehicle_id: Optional[str] = None
    driver_id: Optional[str] = None
    trip_id: Optional[str] = None
    description: str
    severity: str = "medium"

class IncidentResponse(BaseModel):
    id: str
    incident_type: str
    description: str
    severity: str
    status: str
    reported_at: datetime

    class Config:
        from_attributes = True

class RescheduleRequest(BaseModel):
    incident_id: str
    schedule_id: str

class RescheduleResponse(BaseModel):
    schedule_id: str
    affected_trips_count: int
    reassigned_trips_count: int
    uncovered_trips_count: int
    replacement_vehicle_id: Optional[str] = None
    replacement_driver_id: Optional[str] = None
    status: str
    message: str

# Duty Swap
class DutySwapCreate(BaseModel):
    requester_duty_id: str
    target_driver_id: str
    target_duty_id: str
    reason: Optional[str] = None

class DutySwapResponse(BaseModel):
    id: str
    requester_driver_id: str
    target_driver_id: str
    status: str
    created_at: datetime

# Analytics & GPS
class AnalyticsOverviewResponse(BaseModel):
    active_buses: int
    available_buses: int
    maintenance_buses: int
    drivers_on_duty: int
    available_drivers: int
    total_trips: int
    covered_trips: int
    uncovered_trips: int
    fleet_utilization_rate: float
    driver_utilization_rate: float
    total_operating_cost: float
    breakdown_count: int

class VehicleLocationResponse(BaseModel):
    vehicle_id: str
    plate_number: str
    latitude: float
    longitude: float
    speed_kmh: float
    heading: float
    timestamp: Any
    is_simulated: bool
    route_name: Optional[str] = None
    route_id: Optional[str] = None
    route_number: Optional[str] = None
    color_hex: Optional[str] = None
    driver_name: Optional[str] = None
    next_stop: Optional[str] = None
    distance_to_next_m: Optional[int] = None
    eta_minutes: Optional[float] = None
    occupancy_pax: Optional[int] = None
    capacity: Optional[int] = None
    status: Optional[str] = None
    direction: Optional[str] = None

class DeviceGpsReportRequest(BaseModel):
    vehicle_id: str
    latitude: float
    longitude: float
    speed_kmh: float = 0.0
    heading: float = 0.0
