-- ==============================================================================
-- FLEETOPT AI - INITIAL DATABASE SCHEMA MIGRATION
-- Compatible with PostgreSQL 14+ and Supabase
-- Autonomous Public Fleet Scheduling & Driver Duty Rostering Combinatorial Optimizer
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'passenger' CHECK (role IN ('super_admin', 'driver', 'depot_manager', 'passenger')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Profiles Table
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phone VARCHAR(50),
    avatar_url VARCHAR(500),
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Depots Table
CREATE TABLE IF NOT EXISTS depots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address VARCHAR(500),
    capacity INTEGER NOT NULL DEFAULT 50,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Vehicle Types Table
CREATE TABLE IF NOT EXISTS vehicle_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    capacity INTEGER NOT NULL,
    fuel_type VARCHAR(50) DEFAULT 'Diesel',
    cost_per_km DOUBLE PRECISION NOT NULL DEFAULT 1.85
);

-- 5. Vehicles Table
CREATE TABLE IF NOT EXISTS vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plate_number VARCHAR(50) UNIQUE NOT NULL,
    vehicle_type_id UUID REFERENCES vehicle_types(id),
    depot_id UUID REFERENCES depots(id),
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'breakdown', 'retired')),
    odometer_km DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    year_manufactured INTEGER NOT NULL DEFAULT 2022,
    last_service_date TIMESTAMPTZ,
    next_service_due TIMESTAMPTZ,
    qr_code VARCHAR(100) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Drivers Table
CREATE TABLE IF NOT EXISTS drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    employee_id VARCHAR(50) UNIQUE NOT NULL,
    depot_id UUID REFERENCES depots(id),
    license_number VARCHAR(100) NOT NULL,
    license_expiry TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    total_hours_this_week DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Driver Qualifications Table
CREATE TABLE IF NOT EXISTS driver_qualifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    qualification_name VARCHAR(100) NOT NULL,
    issued_date TIMESTAMPTZ,
    expiry_date TIMESTAMPTZ
);

-- 8. Driver Availability Table
CREATE TABLE IF NOT EXISTS driver_availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    date VARCHAR(20) NOT NULL,
    start_time VARCHAR(10) NOT NULL,
    end_time VARCHAR(10) NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE
);

-- 9. Driver Leave Table
CREATE TABLE IF NOT EXISTS driver_leave (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    start_date VARCHAR(20) NOT NULL,
    end_date VARCHAR(20) NOT NULL,
    reason VARCHAR(255),
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. Driver Preferences Table
CREATE TABLE IF NOT EXISTS driver_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID UNIQUE NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    preferred_shift VARCHAR(50) DEFAULT 'morning',
    max_weekly_hours DOUBLE PRECISION DEFAULT 40.0
);

-- 11. Routes Table
CREATE TABLE IF NOT EXISTS routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_number VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    origin VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    distance_km DOUBLE PRECISION NOT NULL DEFAULT 15.0,
    estimated_duration_minutes INTEGER NOT NULL DEFAULT 45,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. Stops Table
CREATE TABLE IF NOT EXISTS stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL
);

-- 13. Route Stops Table
CREATE TABLE IF NOT EXISTS route_stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    stop_id UUID NOT NULL REFERENCES stops(id) ON DELETE CASCADE,
    stop_order INTEGER NOT NULL,
    distance_from_prev_km DOUBLE PRECISION DEFAULT 1.5,
    travel_time_minutes INTEGER DEFAULT 4
);

-- 14. Trips Table
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    trip_number VARCHAR(50) NOT NULL,
    direction VARCHAR(20) NOT NULL DEFAULT 'outbound',
    start_time VARCHAR(10) NOT NULL,
    end_time VARCHAR(10) NOT NULL,
    day_of_week VARCHAR(20) DEFAULT 'daily',
    estimated_demand INTEGER DEFAULT 40
);

-- 15. Schedules Table
CREATE TABLE IF NOT EXISTS schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    date VARCHAR(20) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'approved', 'cancelled')),
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 16. Schedule Versions Table
CREATE TABLE IF NOT EXISTS schedule_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    change_summary TEXT,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 17. Vehicle Assignments Table
CREATE TABLE IF NOT EXISTS vehicle_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    start_time VARCHAR(10) NOT NULL,
    end_time VARCHAR(10) NOT NULL,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    uncovered BOOLEAN NOT NULL DEFAULT FALSE
);

-- 18. Driver Duties Table
CREATE TABLE IF NOT EXISTS driver_duties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    duty_code VARCHAR(50) NOT NULL,
    start_time VARCHAR(10) NOT NULL,
    end_time VARCHAR(10) NOT NULL,
    total_driving_minutes INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL DEFAULT 'assigned',
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    uncovered BOOLEAN NOT NULL DEFAULT FALSE
);

-- 19. Duty Breaks Table
CREATE TABLE IF NOT EXISTS duty_breaks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    duty_id UUID NOT NULL REFERENCES driver_duties(id) ON DELETE CASCADE,
    break_start VARCHAR(10) NOT NULL,
    break_end VARCHAR(10) NOT NULL,
    break_type VARCHAR(50) DEFAULT 'mandatory_rest'
);

-- 20. Maintenance Records Table
CREATE TABLE IF NOT EXISTS maintenance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    maintenance_type VARCHAR(100) NOT NULL,
    description TEXT,
    cost DOUBLE PRECISION DEFAULT 0.0,
    service_date TIMESTAMPTZ DEFAULT NOW(),
    completed_date TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'completed'
);

-- 21. Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID REFERENCES vehicles(id),
    driver_id UUID REFERENCES drivers(id),
    trip_id UUID REFERENCES trips(id),
    incident_type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    severity VARCHAR(50) DEFAULT 'medium',
    status VARCHAR(50) DEFAULT 'reported',
    reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 22. Vehicle Locations Table
CREATE TABLE IF NOT EXISTS vehicle_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    speed_kmh DOUBLE PRECISION DEFAULT 0.0,
    heading DOUBLE PRECISION DEFAULT 0.0,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_simulated BOOLEAN DEFAULT TRUE
);

-- 23. Passenger Demand Table
CREATE TABLE IF NOT EXISTS passenger_demand (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    date VARCHAR(20) NOT NULL,
    time_window VARCHAR(20) NOT NULL,
    actual_passengers INTEGER NOT NULL,
    weather VARCHAR(50) DEFAULT 'Clear',
    is_holiday BOOLEAN DEFAULT FALSE,
    is_event BOOLEAN DEFAULT FALSE
);

-- 24. Demand Predictions Table
CREATE TABLE IF NOT EXISTS demand_predictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    date VARCHAR(20) NOT NULL,
    time_window VARCHAR(20) NOT NULL,
    predicted_passengers DOUBLE PRECISION NOT NULL,
    demand_level VARCHAR(50) DEFAULT 'Moderate',
    model_version VARCHAR(50) DEFAULT 'RF-v1.0',
    confidence_score DOUBLE PRECISION DEFAULT 0.88,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 25. Optimization Runs Table
CREATE TABLE IF NOT EXISTS optimization_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
    algorithm VARCHAR(100) DEFAULT 'OR-Tools CP-SAT VSP/DDRP',
    status VARCHAR(50) DEFAULT 'completed',
    solve_time_seconds DOUBLE PRECISION DEFAULT 0.0,
    objective_score DOUBLE PRECISION DEFAULT 0.0,
    covered_trips INTEGER DEFAULT 0,
    uncovered_trips INTEGER DEFAULT 0,
    total_operating_cost DOUBLE PRECISION DEFAULT 0.0,
    solver_status VARCHAR(50) DEFAULT 'OPTIMAL',
    solver_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 26. Attendance Table
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id),
    duty_id UUID REFERENCES driver_duties(id),
    check_in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    check_out_time TIMESTAMPTZ,
    qr_code_hash VARCHAR(255),
    status VARCHAR(50) DEFAULT 'verified'
);

-- 27. Duty Swap Requests Table
CREATE TABLE IF NOT EXISTS duty_swap_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    target_driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    requester_duty_id UUID REFERENCES driver_duties(id),
    target_duty_id UUID REFERENCES driver_duties(id),
    reason TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    reviewed_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 28. Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) DEFAULT 'info',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 29. Audit Logs Table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100),
    change_details JSONB,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON vehicles(status);
CREATE INDEX IF NOT EXISTS idx_vehicles_depot ON vehicles(depot_id);
CREATE INDEX IF NOT EXISTS idx_drivers_employee ON drivers(employee_id);
CREATE INDEX IF NOT EXISTS idx_trips_route ON trips(route_id);
CREATE INDEX IF NOT EXISTS idx_trips_start_time ON trips(start_time);
CREATE INDEX IF NOT EXISTS idx_schedules_date ON schedules(date);
CREATE INDEX IF NOT EXISTS idx_vehicle_assignments_schedule ON vehicle_assignments(schedule_id);
CREATE INDEX IF NOT EXISTS idx_driver_duties_driver ON driver_duties(driver_id);
CREATE INDEX IF NOT EXISTS idx_attendance_driver ON attendance(driver_id);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
CREATE INDEX IF NOT EXISTS idx_vehicle_locations_vehicle ON vehicle_locations(vehicle_id);

-- Enable Row Level Security (RLS) on key tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_duties ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_assignments ENABLE ROW LEVEL SECURITY;

-- Base Public RLS Policies
CREATE POLICY "Public Read Routes" ON routes FOR SELECT USING (true);
CREATE POLICY "Public Read Stops" ON stops FOR SELECT USING (true);
CREATE POLICY "Public Read Trips" ON trips FOR SELECT USING (true);
