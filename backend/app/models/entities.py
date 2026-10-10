import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, ForeignKey, Text, Enum, JSON
)
from sqlalchemy.orm import relationship
from app.database.session import Base

def generate_uuid():
    return str(uuid.uuid4())

class RoleEnum(str):
    SUPER_ADMIN = "super_admin"
    DRIVER = "driver"
    DEPOT_MANAGER = "depot_manager"
    PASSENGER = "passenger"

class User(Base):
    __tablename__ = "users"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    role = Column(String(50), default=RoleEnum.PASSENGER, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    profile = relationship("Profile", back_populates="user", uselist=False)
    driver_profile = relationship("Driver", back_populates="user", uselist=False)

class Profile(Base):
    __tablename__ = "profiles"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    phone = Column(String(50), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    metadata_json = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="profile")

class Depot(Base):
    __tablename__ = "depots"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    code = Column(String(50), unique=True, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(String(500), nullable=True)
    capacity = Column(Integer, default=50)

    vehicles = relationship("Vehicle", back_populates="depot")
    drivers = relationship("Driver", back_populates="depot")

class VehicleType(Base):
    __tablename__ = "vehicle_types"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(100), nullable=False)  # e.g., Standard City Bus, Articulated Bus, Electric Minibus
    capacity = Column(Integer, nullable=False)
    fuel_type = Column(String(50), default="Diesel")
    cost_per_km = Column(Float, default=1.85)

    vehicles = relationship("Vehicle", back_populates="vehicle_type")

class Vehicle(Base):
    __tablename__ = "vehicles"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    plate_number = Column(String(50), unique=True, index=True, nullable=False)
    vehicle_type_id = Column(String(36), ForeignKey("vehicle_types.id"))
    depot_id = Column(String(36), ForeignKey("depots.id"))
    status = Column(String(50), default="active")  # active, maintenance, breakdown, retired
    odometer_km = Column(Float, default=0.0)
    year_manufactured = Column(Integer, default=2022)
    last_service_date = Column(DateTime, nullable=True)
    next_service_due = Column(DateTime, nullable=True)
    qr_code = Column(String(100), unique=True, nullable=True)

    vehicle_type = relationship("VehicleType", back_populates="vehicles")
    depot = relationship("Depot", back_populates="vehicles")
    assignments = relationship("VehicleAssignment", back_populates="vehicle")
    locations = relationship("VehicleLocation", back_populates="vehicle")
    incidents = relationship("Incident", back_populates="vehicle")
    maintenance_records = relationship("MaintenanceRecord", back_populates="vehicle")

class Driver(Base):
    __tablename__ = "drivers"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    employee_id = Column(String(50), unique=True, index=True, nullable=False)
    depot_id = Column(String(36), ForeignKey("depots.id"))
    license_number = Column(String(100), nullable=False)
    license_expiry = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)
    total_hours_this_week = Column(Float, default=0.0)

    user = relationship("User", back_populates="driver_profile")
    depot = relationship("Depot", back_populates="drivers")
    qualifications = relationship("DriverQualification", back_populates="driver")
    availabilities = relationship("DriverAvailability", back_populates="driver")
    leaves = relationship("DriverLeave", back_populates="driver")
    preferences = relationship("DriverPreference", back_populates="driver", uselist=False)
    duties = relationship("DriverDuty", back_populates="driver")

class DriverQualification(Base):
    __tablename__ = "driver_qualifications"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    driver_id = Column(String(36), ForeignKey("drivers.id", ondelete="CASCADE"))
    qualification_name = Column(String(100), nullable=False)
    issued_date = Column(DateTime, nullable=True)
    expiry_date = Column(DateTime, nullable=True)

    driver = relationship("Driver", back_populates="qualifications")

class DriverAvailability(Base):
    __tablename__ = "driver_availability"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    driver_id = Column(String(36), ForeignKey("drivers.id", ondelete="CASCADE"))
    date = Column(String(20), nullable=False)
    start_time = Column(String(10), nullable=False)
    end_time = Column(String(10), nullable=False)
    is_available = Column(Boolean, default=True)

    driver = relationship("Driver", back_populates="availabilities")

class DriverLeave(Base):
    __tablename__ = "driver_leave"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    driver_id = Column(String(36), ForeignKey("drivers.id", ondelete="CASCADE"))
    start_date = Column(String(20), nullable=False)
    end_date = Column(String(20), nullable=False)
    reason = Column(String(255), nullable=True)
    status = Column(String(50), default="approved")  # pending, approved, rejected

    driver = relationship("Driver", back_populates="leaves")

class DriverPreference(Base):
    __tablename__ = "driver_preferences"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    driver_id = Column(String(36), ForeignKey("drivers.id", ondelete="CASCADE"), unique=True)
    preferred_shift = Column(String(50), default="morning")  # morning, evening, night
    max_weekly_hours = Column(Float, default=40.0)

    driver = relationship("Driver", back_populates="preferences")

class Route(Base):
    __tablename__ = "routes"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    route_number = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(255), nullable=False)
    origin = Column(String(255), nullable=False)
    destination = Column(String(255), nullable=False)
    distance_km = Column(Float, default=15.0)
    estimated_duration_minutes = Column(Integer, default=45)
    is_active = Column(Boolean, default=True)

    route_stops = relationship("RouteStop", back_populates="route", order_by="RouteStop.stop_order")
    trips = relationship("Trip", back_populates="route")

class Stop(Base):
    __tablename__ = "stops"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    code = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(255), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    route_stops = relationship("RouteStop", back_populates="stop")

class RouteStop(Base):
    __tablename__ = "route_stops"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    route_id = Column(String(36), ForeignKey("routes.id", ondelete="CASCADE"))
    stop_id = Column(String(36), ForeignKey("stops.id", ondelete="CASCADE"))
    stop_order = Column(Integer, nullable=False)
    distance_from_prev_km = Column(Float, default=1.5)
    travel_time_minutes = Column(Integer, default=4)

    route = relationship("Route", back_populates="route_stops")
    stop = relationship("Stop", back_populates="route_stops")

class Trip(Base):
    __tablename__ = "trips"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    route_id = Column(String(36), ForeignKey("routes.id", ondelete="CASCADE"))
    trip_number = Column(String(50), index=True, nullable=False)
    direction = Column(String(20), default="outbound")  # outbound, inbound
    start_time = Column(String(10), nullable=False)  # HH:MM
    end_time = Column(String(10), nullable=False)    # HH:MM
    day_of_week = Column(String(20), default="daily") # monday..sunday, daily, weekday
    estimated_demand = Column(Integer, default=40)

    route = relationship("Route", back_populates="trips")
    vehicle_assignments = relationship("VehicleAssignment", back_populates="trip")

class Schedule(Base):
    __tablename__ = "schedules"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    date = Column(String(20), nullable=False)  # YYYY-MM-DD
    status = Column(String(50), default="draft")  # draft, published, approved, cancelled
    version = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    versions = relationship("ScheduleVersion", back_populates="schedule")
    vehicle_assignments = relationship("VehicleAssignment", back_populates="schedule")
    driver_duties = relationship("DriverDuty", back_populates="schedule")
    optimization_runs = relationship("OptimizationRun", back_populates="schedule")

class ScheduleVersion(Base):
    __tablename__ = "schedule_versions"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    schedule_id = Column(String(36), ForeignKey("schedules.id", ondelete="CASCADE"))
    version_number = Column(Integer, nullable=False)
    status = Column(String(50), default="draft")
    change_summary = Column(Text, nullable=True)
    approved_by = Column(String(36), nullable=True)
    approved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    schedule = relationship("Schedule", back_populates="versions")

class VehicleAssignment(Base):
    __tablename__ = "vehicle_assignments"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    schedule_id = Column(String(36), ForeignKey("schedules.id", ondelete="CASCADE"))
    trip_id = Column(String(36), ForeignKey("trips.id", ondelete="CASCADE"))
    vehicle_id = Column(String(36), ForeignKey("vehicles.id"), nullable=True) # None if uncovered
    start_time = Column(String(10), nullable=False)
    end_time = Column(String(10), nullable=False)
    is_locked = Column(Boolean, default=False)
    uncovered = Column(Boolean, default=False)

    schedule = relationship("Schedule", back_populates="vehicle_assignments")
    trip = relationship("Trip", back_populates="vehicle_assignments")
    vehicle = relationship("Vehicle", back_populates="assignments")

class DriverDuty(Base):
    __tablename__ = "driver_duties"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    schedule_id = Column(String(36), ForeignKey("schedules.id", ondelete="CASCADE"))
    driver_id = Column(String(36), ForeignKey("drivers.id"), nullable=True) # None if uncovered
    duty_code = Column(String(50), nullable=False)
    start_time = Column(String(10), nullable=False)
    end_time = Column(String(10), nullable=False)
    total_driving_minutes = Column(Integer, default=0)
    status = Column(String(50), default="assigned")  # assigned, acknowledged, completed, cancelled
    is_locked = Column(Boolean, default=False)
    uncovered = Column(Boolean, default=False)

    schedule = relationship("Schedule", back_populates="driver_duties")
    driver = relationship("Driver", back_populates="duties")
    breaks = relationship("DutyBreak", back_populates="duty")

class DutyBreak(Base):
    __tablename__ = "duty_breaks"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    duty_id = Column(String(36), ForeignKey("driver_duties.id", ondelete="CASCADE"))
    break_start = Column(String(10), nullable=False)
    break_end = Column(String(10), nullable=False)
    break_type = Column(String(50), default="mandatory_rest")

    duty = relationship("DriverDuty", back_populates="breaks")

class MaintenanceRecord(Base):
    __tablename__ = "maintenance_records"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    vehicle_id = Column(String(36), ForeignKey("vehicles.id", ondelete="CASCADE"))
    maintenance_type = Column(String(100), nullable=False) # Routine, Brake overhaul, Engine check
    description = Column(Text, nullable=True)
    cost = Column(Float, default=0.0)
    service_date = Column(DateTime, default=datetime.utcnow)
    completed_date = Column(DateTime, nullable=True)
    status = Column(String(50), default="completed")  # scheduled, in_progress, completed

    vehicle = relationship("Vehicle", back_populates="maintenance_records")

class Incident(Base):
    __tablename__ = "incidents"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    vehicle_id = Column(String(36), ForeignKey("vehicles.id"), nullable=True)
    driver_id = Column(String(36), ForeignKey("drivers.id"), nullable=True)
    trip_id = Column(String(36), ForeignKey("trips.id"), nullable=True)
    incident_type = Column(String(50), nullable=False) # breakdown, accident, delay, absence
    description = Column(Text, nullable=False)
    severity = Column(String(50), default="medium") # low, medium, high, critical
    status = Column(String(50), default="reported")  # reported, under_review, resolved
    reported_at = Column(DateTime, default=datetime.utcnow)

    vehicle = relationship("Vehicle", back_populates="incidents")

class VehicleLocation(Base):
    __tablename__ = "vehicle_locations"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    vehicle_id = Column(String(36), ForeignKey("vehicles.id", ondelete="CASCADE"))
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    speed_kmh = Column(Float, default=0.0)
    heading = Column(Float, default=0.0)
    timestamp = Column(DateTime, default=datetime.utcnow)
    is_simulated = Column(Boolean, default=True)

    vehicle = relationship("Vehicle", back_populates="locations")

class PassengerDemand(Base):
    __tablename__ = "passenger_demand"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    route_id = Column(String(36), ForeignKey("routes.id", ondelete="CASCADE"))
    date = Column(String(20), nullable=False)
    time_window = Column(String(20), nullable=False) # e.g. "08:00-09:00"
    actual_passengers = Column(Integer, nullable=False)
    weather = Column(String(50), default="Clear")
    is_holiday = Column(Boolean, default=False)
    is_event = Column(Boolean, default=False)

class DemandPrediction(Base):
    __tablename__ = "demand_predictions"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    route_id = Column(String(36), ForeignKey("routes.id", ondelete="CASCADE"))
    date = Column(String(20), nullable=False)
    time_window = Column(String(20), nullable=False)
    predicted_passengers = Column(Float, nullable=False)
    demand_level = Column(String(50), default="Moderate") # Low, Moderate, High, Surge
    model_version = Column(String(50), default="RF-v1.0")
    confidence_score = Column(Float, default=0.88)
    created_at = Column(DateTime, default=datetime.utcnow)

class OptimizationRun(Base):
    __tablename__ = "optimization_runs"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    schedule_id = Column(String(36), ForeignKey("schedules.id", ondelete="CASCADE"))
    algorithm = Column(String(100), default="OR-Tools CP-SAT VSP/DDRP")
    status = Column(String(50), default="completed")
    solve_time_seconds = Column(Float, default=0.0)
    objective_score = Column(Float, default=0.0)
    covered_trips = Column(Integer, default=0)
    uncovered_trips = Column(Integer, default=0)
    total_operating_cost = Column(Float, default=0.0)
    solver_status = Column(String(50), default="OPTIMAL")
    solver_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    schedule = relationship("Schedule", back_populates="optimization_runs")

class Notification(Base):
    __tablename__ = "notifications"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    notification_type = Column(String(50), default="info")
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class Attendance(Base):
    __tablename__ = "attendance"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    driver_id = Column(String(36), ForeignKey("drivers.id", ondelete="CASCADE"))
    vehicle_id = Column(String(36), ForeignKey("vehicles.id"), nullable=True)
    duty_id = Column(String(36), ForeignKey("driver_duties.id"), nullable=True)
    check_in_time = Column(DateTime, default=datetime.utcnow)
    check_out_time = Column(DateTime, nullable=True)
    qr_code_hash = Column(String(255), nullable=True)
    status = Column(String(50), default="verified") # verified, late, invalid

class DutySwapRequest(Base):
    __tablename__ = "duty_swap_requests"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    requester_driver_id = Column(String(36), ForeignKey("drivers.id", ondelete="CASCADE"))
    target_driver_id = Column(String(36), ForeignKey("drivers.id", ondelete="CASCADE"))
    requester_duty_id = Column(String(36), ForeignKey("driver_duties.id"))
    target_duty_id = Column(String(36), ForeignKey("driver_duties.id"))
    reason = Column(Text, nullable=True)
    status = Column(String(50), default="pending") # pending, approved, rejected
    reviewed_by = Column(String(36), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), nullable=True)
    action = Column(String(100), nullable=False)
    entity_type = Column(String(100), nullable=False)
    entity_id = Column(String(100), nullable=True)
    change_details = Column(JSON, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
