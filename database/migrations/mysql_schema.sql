-- ==============================================================================
-- FLEETOPT AI - MYSQL 8.X COMPLETE PRODUCTION SCHEMA
-- Authoritative Relational Transport Operations Database
-- ==============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- 1. USERS
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role ENUM('super_admin', 'driver', 'depot_manager', 'passenger') NOT NULL DEFAULT 'passenger',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_role (role),
    INDEX idx_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. DEPOTS
CREATE TABLE IF NOT EXISTS depots (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    address VARCHAR(500) NULL,
    capacity INT NOT NULL DEFAULT 50,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_depots_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. VEHICLES
CREATE TABLE IF NOT EXISTS vehicles (
    id VARCHAR(36) PRIMARY KEY,
    plate_number VARCHAR(50) NOT NULL UNIQUE,
    vin VARCHAR(100) NULL UNIQUE,
    depot_id VARCHAR(36) NULL,
    vehicle_type VARCHAR(100) NOT NULL DEFAULT 'Standard Bus',
    capacity INT NOT NULL DEFAULT 55,
    status ENUM('active', 'maintenance', 'breakdown', 'retired') NOT NULL DEFAULT 'active',
    odometer_km DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    fuel_level_percent DECIMAL(5, 2) NOT NULL DEFAULT 100.00,
    year_manufactured INT NOT NULL DEFAULT 2022,
    qr_code VARCHAR(255) NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (depot_id) REFERENCES depots(id) ON DELETE SET NULL,
    INDEX idx_vehicles_status (status),
    INDEX idx_vehicles_depot (depot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. DRIVERS
CREATE TABLE IF NOT EXISTS drivers (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL UNIQUE,
    depot_id VARCHAR(36) NULL,
    license_number VARCHAR(100) NOT NULL UNIQUE,
    license_expiry DATE NOT NULL,
    qualifications JSON NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    seniority_level INT NOT NULL DEFAULT 1,
    max_weekly_hours DECIMAL(5, 2) NOT NULL DEFAULT 40.00,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (depot_id) REFERENCES depots(id) ON DELETE SET NULL,
    INDEX idx_drivers_available (is_available),
    INDEX idx_drivers_depot (depot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. ROUTES
CREATE TABLE IF NOT EXISTS routes (
    id VARCHAR(36) PRIMARY KEY,
    route_number VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    origin VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    distance_km DECIMAL(8, 2) NOT NULL,
    estimated_duration_minutes INT NOT NULL,
    color_hex VARCHAR(10) NOT NULL DEFAULT '#00A86B',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_routes_number (route_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. STOPS
CREATE TABLE IF NOT EXISTS stops (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    address VARCHAR(500) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_stops_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. TRIPS
CREATE TABLE IF NOT EXISTS trips (
    id VARCHAR(36) PRIMARY KEY,
    route_id VARCHAR(36) NOT NULL,
    trip_number VARCHAR(100) NOT NULL UNIQUE,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    direction ENUM('outbound', 'inbound') NOT NULL DEFAULT 'outbound',
    estimated_demand INT NOT NULL DEFAULT 40,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
    INDEX idx_trips_route (route_id),
    INDEX idx_trips_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. DRIVER AVAILABILITY
CREATE TABLE IF NOT EXISTS driver_availability (
    id VARCHAR(36) PRIMARY KEY,
    driver_id VARCHAR(36) NOT NULL,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    reason VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE CASCADE,
    UNIQUE KEY uq_driver_date_avail (driver_id, date, start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. SCHEDULES
CREATE TABLE IF NOT EXISTS schedules (
    id VARCHAR(36) PRIMARY KEY,
    date DATE NOT NULL,
    version INT NOT NULL DEFAULT 1,
    status ENUM('draft', 'optimized', 'approved', 'published', 'archived') NOT NULL DEFAULT 'draft',
    solver_status VARCHAR(50) NOT NULL DEFAULT 'FEASIBLE',
    solve_duration_seconds DECIMAL(8, 2) NOT NULL DEFAULT 0.00,
    objective_score DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_trips INT NOT NULL DEFAULT 0,
    covered_trips INT NOT NULL DEFAULT 0,
    uncovered_trips INT NOT NULL DEFAULT 0,
    approved_by VARCHAR(36) NULL,
    approved_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_schedules_date (date, version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. DRIVER DUTIES
CREATE TABLE IF NOT EXISTS driver_duties (
    id VARCHAR(36) PRIMARY KEY,
    schedule_id VARCHAR(36) NOT NULL,
    driver_id VARCHAR(36) NOT NULL,
    duty_code VARCHAR(100) NOT NULL,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    total_driving_minutes INT NOT NULL DEFAULT 0,
    total_duty_minutes INT NOT NULL DEFAULT 0,
    status ENUM('assigned', 'in_progress', 'completed', 'swapped') NOT NULL DEFAULT 'assigned',
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE,
    FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE CASCADE,
    INDEX idx_duties_driver (driver_id, date),
    INDEX idx_duties_schedule (schedule_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. VEHICLE ASSIGNMENTS
CREATE TABLE IF NOT EXISTS vehicle_assignments (
    id VARCHAR(36) PRIMARY KEY,
    schedule_id VARCHAR(36) NOT NULL,
    trip_id VARCHAR(36) NOT NULL,
    vehicle_id VARCHAR(36) NOT NULL,
    driver_id VARCHAR(36) NOT NULL,
    duty_id VARCHAR(36) NULL,
    is_uncovered BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE CASCADE,
    FOREIGN KEY (duty_id) REFERENCES driver_duties(id) ON DELETE SET NULL,
    INDEX idx_assignments_trip (trip_id),
    INDEX idx_assignments_vehicle (vehicle_id),
    INDEX idx_assignments_driver (driver_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. MAINTENANCE
CREATE TABLE IF NOT EXISTS maintenance (
    id VARCHAR(36) PRIMARY KEY,
    vehicle_id VARCHAR(36) NOT NULL,
    maintenance_type ENUM('routine', 'inspection', 'emergency', 'repair') NOT NULL,
    description TEXT NOT NULL,
    start_date DATETIME NOT NULL,
    end_date DATETIME NULL,
    status ENUM('scheduled', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'scheduled',
    cost DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    INDEX idx_maintenance_vehicle (vehicle_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 13. ATTENDANCE
CREATE TABLE IF NOT EXISTS attendance (
    id VARCHAR(36) PRIMARY KEY,
    driver_id VARCHAR(36) NOT NULL,
    vehicle_id VARCHAR(36) NULL,
    check_in_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    check_out_time DATETIME NULL,
    status ENUM('on_duty', 'off_duty', 'late', 'absent') NOT NULL DEFAULT 'on_duty',
    qr_verified BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE CASCADE,
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE SET NULL,
    INDEX idx_attendance_driver (driver_id, check_in_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 14. DRIVER LEAVE
CREATE TABLE IF NOT EXISTS driver_leave (
    id VARCHAR(36) PRIMARY KEY,
    driver_id VARCHAR(36) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    leave_type ENUM('annual', 'sick', 'emergency', 'unpaid') NOT NULL,
    status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
    reason TEXT NULL,
    approved_by VARCHAR(36) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE CASCADE,
    FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 15. OPTIMIZATION RUNS
CREATE TABLE IF NOT EXISTS optimization_runs (
    id VARCHAR(36) PRIMARY KEY,
    run_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    target_date DATE NOT NULL,
    solver_status VARCHAR(50) NOT NULL,
    solve_duration_seconds DECIMAL(8, 2) NOT NULL,
    objective_value DECIMAL(14, 2) NOT NULL,
    total_trips INT NOT NULL,
    covered_trips INT NOT NULL,
    uncovered_trips INT NOT NULL,
    vehicles_used INT NOT NULL,
    drivers_used INT NOT NULL,
    estimated_operating_cost DECIMAL(12, 2) NOT NULL,
    parameters JSON NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 16. INCIDENTS
CREATE TABLE IF NOT EXISTS incidents (
    id VARCHAR(36) PRIMARY KEY,
    vehicle_id VARCHAR(36) NULL,
    driver_id VARCHAR(36) NULL,
    incident_type ENUM('breakdown', 'traffic_delay', 'absenteeism', 'accident', 'weather') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
    status ENUM('open', 'investigating', 'rescheduled', 'resolved') NOT NULL DEFAULT 'open',
    latitude DECIMAL(10, 8) NULL,
    longitude DECIMAL(11, 8) NULL,
    description TEXT NOT NULL,
    reported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE SET NULL,
    FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE SET NULL,
    INDEX idx_incidents_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 17. AUDIT LOGS
CREATE TABLE IF NOT EXISTS audit_logs (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NULL,
    action VARCHAR(100) NOT NULL,
    entity_name VARCHAR(100) NOT NULL,
    entity_id VARCHAR(36) NOT NULL,
    details JSON NULL,
    ip_address VARCHAR(45) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_audit_entity (entity_name, entity_id),
    INDEX idx_audit_time (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
