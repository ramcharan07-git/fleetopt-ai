import sys
import os
import uuid
from datetime import datetime, timedelta

# Ensure backend app is in python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "backend")))

from app.database.session import SessionLocal, Base, engine
from app.models.entities import (
    User, Profile, Depot, VehicleType, Vehicle, Driver,
    DriverQualification, DriverAvailability, DriverLeave, DriverPreference,
    Route, Stop, RouteStop, Trip, MaintenanceRecord, Incident,
    PassengerDemand, VehicleLocation, RoleEnum,
    Schedule, VehicleAssignment, DriverDuty, DutyBreak
)
from app.security.auth import hash_password
from app.database.mongodb import mongo_manager

def seed_duties_and_assignments(db):
    sched = db.query(Schedule).first()
    if not sched:
        sched = Schedule(
            id="sched-master-today",
            name="Master Operational Transit Schedule",
            date=datetime.utcnow().strftime("%Y-%m-%d"),
            status="approved",
            version=1
        )
        db.add(sched)
        db.commit()

    if db.query(DriverDuty).count() == 0:
        print("[*] Seeding Driver Duties & Mandatory Rest Breaks...")
        for i in range(1, 31):
            is_morn = (i <= 15)
            s_time = "06:00" if is_morn else "14:00"
            e_time = "14:00" if is_morn else "22:00"
            b_s = "10:30" if is_morn else "18:30"
            b_e = "11:15" if is_morn else "19:15"
            route_code = f"R10{((i - 1) % 10) + 1}"

            duty = DriverDuty(
                id=f"duty-drv-{i:03d}",
                schedule_id=sched.id,
                driver_id=f"drv-{i:03d}",
                duty_code=f"DUTY-{route_code}-{'MORN' if is_morn else 'EVE'}",
                start_time=s_time,
                end_time=e_time,
                total_driving_minutes=420,
                status="assigned"
            )
            db.add(duty)
            db.add(DutyBreak(
                id=f"break-drv-{i:03d}",
                duty_id=duty.id,
                break_start=b_s,
                break_end=b_e,
                break_type="mandatory_rest"
            ))
        db.commit()

    if db.query(VehicleAssignment).count() == 0:
        print("[*] Seeding Vehicle Assignments for Trips...")
        trips = db.query(Trip).limit(30).all()
        for idx, t in enumerate(trips):
            veh_id = f"veh-{(idx % 28) + 1:03d}"
            va = VehicleAssignment(
                id=f"va-{idx + 1:03d}",
                schedule_id=sched.id,
                trip_id=t.id,
                vehicle_id=veh_id,
                start_time=t.start_time,
                end_time=t.end_time,
                is_locked=True
            )
            db.add(va)
        db.commit()

def seed_mongodb_telemetry():
    try:
        print("[*] Seeding MongoDB vehicle_locations & gps_history...")
        coll_loc = mongo_manager.get_collection("vehicle_locations")
        coll_hist = mongo_manager.get_collection("gps_history")
        now = datetime.utcnow()

        for i in range(1, 31):
            lat = 40.7128 + (i * 0.003)
            lng = -74.0060 + (i * 0.002)
            speed = 28.5 if i < 28 else 0.0
            status = "active" if i < 28 else ("maintenance" if i == 29 else "breakdown")

            doc = {
                "vehicle_id": f"veh-{i:03d}",
                "plate_number": f"BUS-{100 + i}",
                "trip_id": f"trip-{((i - 1) % 30) + 1:03d}",
                "driver_id": f"drv-{i:03d}",
                "latitude": lat,
                "longitude": lng,
                "location": {
                    "type": "Point",
                    "coordinates": [lng, lat]
                },
                "speed_kmh": speed,
                "heading": 45.0 + (i * 12.0) % 360,
                "accuracy_meters": 4.2,
                "status": status,
                "timestamp": now,
                "is_stale": False
            }
            coll_loc.update_one({"vehicle_id": f"veh-{i:03d}"}, {"$set": doc}, upsert=True)
            coll_hist.insert_one(doc.copy())
        print("[OK] MongoDB Telemetry successfully seeded!")
    except Exception as e:
        print(f"[!] Warning: MongoDB seed note: {e}")

def seed_database():
    print("[*] Creating all database tables...")
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # Check if users already seeded
        if db.query(User).filter(User.email == "admin@fleetopt.ai").first():
            print("[!] Core system users already seeded. Checking duties, assignments, and MongoDB...")
            seed_duties_and_assignments(db)
            seed_mongodb_telemetry()
            return

        print("[*] Seeding System Users (All 4 Roles)...")
        # 1. Super Admin
        admin_user = User(
            id="u-admin-001",
            email="admin@fleetopt.ai",
            hashed_password=hash_password("AdminPass123!"),
            full_name="Alex Mercer (Transport Director)",
            role=RoleEnum.SUPER_ADMIN,
            is_active=True
        )
        db.add(admin_user)

        # 2. Depot Manager
        depot_mgr = User(
            id="u-depot-001",
            email="depot@fleetopt.ai",
            hashed_password=hash_password("DepotPass123!"),
            full_name="Marcus Vance (Depot Operations Mgr)",
            role=RoleEnum.DEPOT_MANAGER,
            is_active=True
        )
        db.add(depot_mgr)

        # 3. Passenger
        passenger_user = User(
            id="u-passenger-001",
            email="passenger@fleetopt.ai",
            hashed_password=hash_password("PassPass123!"),
            full_name="Sarah Jenkins (Commuter)",
            role=RoleEnum.PASSENGER,
            is_active=True
        )
        db.add(passenger_user)

        # 4. 40 Drivers & User Accounts
        driver_users = []
        for i in range(1, 41):
            d_user = User(
                id=f"u-driver-{i:03d}",
                email=f"driver{i}@fleetopt.ai",
                hashed_password=hash_password(f"DriverPass123!"),
                full_name=f"Driver #{i} (Demo Fleet)",
                role=RoleEnum.DRIVER,
                is_active=True
            )
            db.add(d_user)
            driver_users.append(d_user)

        db.commit()

        print("[*] Seeding 3 Depots...")
        depots_data = [
            ("depot-001", "Central Transit Depot", "DEP-CTR", 40.7128, -74.0060, "100 Grand Concourse", 40),
            ("depot-002", "North Metro Terminal Depot", "DEP-NTH", 40.7589, -73.9851, "450 8th Avenue", 30),
            ("depot-003", "South Harbor Depot", "DEP-STH", 40.6892, -74.0445, "12 Bay Street", 25)
        ]
        depots = []
        for d_id, name, code, lat, lng, addr, cap in depots_data:
            depot = Depot(id=d_id, name=name, code=code, latitude=lat, longitude=lng, address=addr, capacity=cap)
            db.add(depot)
            depots.append(depot)
        db.commit()

        print("[*] Seeding Vehicle Types...")
        v_types_data = [
            ("vt-001", "Standard City Bus", 55, "Diesel Hybrid", 1.85),
            ("vt-002", "Articulated High-Capacity Bus", 85, "Diesel Clean", 2.40),
            ("vt-003", "Electric Minibus", 28, "100% Electric", 1.20)
        ]
        for vt_id, name, cap, fuel, cost in v_types_data:
            vt = VehicleType(id=vt_id, name=name, capacity=cap, fuel_type=fuel, cost_per_km=cost)
            db.add(vt)
        db.commit()

        print("[*] Seeding 30 Fleet Vehicles...")
        vehicles = []
        for i in range(1, 31):
            vt_id = "vt-001" if i <= 20 else ("vt-002" if i <= 26 else "vt-003")
            d_id = depots[(i - 1) % 3].id
            status = "active"
            if i == 29:
                status = "maintenance"
            elif i == 30:
                status = "breakdown"

            veh = Vehicle(
                id=f"veh-{i:03d}",
                plate_number=f"BUS-{100 + i}",
                vehicle_type_id=vt_id,
                depot_id=d_id,
                status=status,
                odometer_km=15000.0 + (i * 2400),
                year_manufactured=2021 + (i % 4),
                last_service_date=datetime.utcnow() - timedelta(days=i * 2),
                next_service_due=datetime.utcnow() + timedelta(days=90 - i),
                qr_code=f"QR-BUS-{100 + i}"
            )
            db.add(veh)
            vehicles.append(veh)

            # Add simulated location
            loc = VehicleLocation(
                id=f"loc-veh-{i:03d}",
                vehicle_id=veh.id,
                latitude=40.7128 + (i * 0.003),
                longitude=-74.0060 + (i * 0.002),
                speed_kmh=24.5 if status == "active" else 0.0,
                heading=45.0,
                is_simulated=True
            )
            db.add(loc)
        db.commit()

        print("[*] Seeding 40 Driver Profiles and Qualifications...")
        for i in range(1, 41):
            depot_id = depots[(i - 1) % 3].id
            drv = Driver(
                id=f"drv-{i:03d}",
                user_id=driver_users[i - 1].id,
                employee_id=f"DRV-{i:03d}",
                depot_id=depot_id,
                license_number=f"LIC-NY-{88000 + i}",
                is_active=True,
                total_hours_this_week=28.0 + (i % 10)
            )
            db.add(drv)

            # Qualifications
            quals = ["standard_bus"]
            if i % 3 == 0:
                quals.append("articulated_bus")
            if i % 2 == 0:
                quals.append("electric_minibus")

            for q in quals:
                db.add(DriverQualification(
                    id=str(uuid.uuid4()),
                    driver_id=drv.id,
                    qualification_name=q
                ))

            # Preferences
            pref_shift = "morning" if i <= 15 else ("evening" if i <= 30 else "night")
            db.add(DriverPreference(
                id=str(uuid.uuid4()),
                driver_id=drv.id,
                preferred_shift=pref_shift,
                max_weekly_hours=40.0
            ))

            # Approved leaves for demo (Drivers 38, 39, 40)
            if i in [38, 39, 40]:
                db.add(DriverLeave(
                    id=str(uuid.uuid4()),
                    driver_id=drv.id,
                    start_date=datetime.utcnow().strftime("%Y-%m-%d"),
                    end_date=(datetime.utcnow() + timedelta(days=3)).strftime("%Y-%m-%d"),
                    reason="Scheduled Medical / Vacation Leave",
                    status="approved"
                ))
        db.commit()

        print("[*] Seeding 10 Routes and Stops...")
        routes_meta = [
            ("R101", "Downtown Express", "Grand Central", "Wall Street", 12.5, 35),
            ("R102", "Airport Shuttle", "Times Square", "JFK International", 28.0, 55),
            ("R103", "University Line", "Columbia Heights", "Union Square", 14.0, 40),
            ("R104", "Tech Park Circular", "Silicon Alley", "Waterfront Tech", 10.0, 30),
            ("R105", "Harbor Promenade", "Battery Park", "Hudson Yards", 11.0, 32),
            ("R106", "Crosstown Link", "East Village", "Chelsea Piers", 8.5, 25),
            ("R107", "North Hills Rapid", "Harlem 125th", "Midtown Terminal", 16.0, 45),
            ("R108", "East River Loop", "Brooklyn Navy Yard", "FDR Terminal", 13.5, 38),
            ("R109", "South Coast Commuter", "Staten Ferry Slip", "Financial Hub", 18.0, 48),
            ("R110", "Suburban Flyer", "Queens Plaza", "Midtown Transit", 20.0, 50)
        ]
        created_routes = []
        for code, name, orig, dest, dist, dur in routes_meta:
            route = Route(
                id=f"route-{code.lower()}",
                route_number=code,
                name=name,
                origin=orig,
                destination=dest,
                distance_km=dist,
                estimated_duration_minutes=dur,
                is_active=True
            )
            db.add(route)
            created_routes.append(route)
        db.commit()

        print("[*] Seeding 100 Daily Trips (06:00 to 22:00)...")
        # Distribute 10 trips per route (10 routes * 10 trips = 100 trips)
        trip_counter = 1
        for route_idx, route in enumerate(created_routes):
            start_hours = [6, 7, 8, 10, 12, 14, 16, 17, 19, 21]
            for t_idx, h in enumerate(start_hours):
                m = (t_idx * 7) % 60
                dur = route.estimated_duration_minutes
                s_min = h * 60 + m
                e_min = s_min + dur

                s_str = f"{(s_min // 60) % 24:02d}:{s_min % 60:02d}"
                e_str = f"{(e_min // 60) % 24:02d}:{e_min % 60:02d}"

                trip = Trip(
                    id=f"trip-{trip_counter:03d}",
                    route_id=route.id,
                    trip_number=f"TRIP-{route.route_number}-{t_idx+1:02d}",
                    direction="outbound" if t_idx % 2 == 0 else "inbound",
                    start_time=s_str,
                    end_time=e_str,
                    day_of_week="daily",
                    estimated_demand=35 + (20 if h in [8, 9, 17, 18] else 0)
                )
                db.add(trip)

                # Seed passenger demand history
                for day_offset in range(1, 8):
                    hist_date = (datetime.utcnow() - timedelta(days=day_offset)).strftime("%Y-%m-%d")
                    db.add(PassengerDemand(
                        id=str(uuid.uuid4()),
                        route_id=route.id,
                        date=hist_date,
                        time_window=f"{h:02d}:00-{(h+1):02d}:00",
                        actual_passengers=30 + ((trip_counter * 3 + day_offset * 5) % 45),
                        weather="Clear" if day_offset % 2 == 0 else "Rain",
                        is_holiday=False,
                        is_event=False
                    ))

                trip_counter += 1
        db.commit()

        print("[*] Seeding Demo Incidents & Maintenance Records...")
        # Maintenance records
        db.add(MaintenanceRecord(
            id="maint-001",
            vehicle_id="veh-029",
            maintenance_type="Brake Pad Replacement & Inspection",
            description="Front axle pad wear detected during shift.",
            cost=450.0,
            status="in_progress"
        ))
        db.add(MaintenanceRecord(
            id="maint-002",
            vehicle_id="veh-030",
            maintenance_type="Transmission Overhaul",
            description="Vehicle stalled during morning deadhead run.",
            cost=2800.0,
            status="scheduled"
        ))

        # Sample Breakdown Incident
        db.add(Incident(
            id="inc-001",
            vehicle_id="veh-030",
            incident_type="breakdown",
            description="DEMO INCIDENT: Bus BUS-130 experienced cooling system failure on Route R102.",
            severity="high",
            status="reported"
        ))
        db.commit()

        print("[OK] FleetOpt AI Database successfully seeded with 30 buses, 40 drivers, 10 routes, 100 trips, 3 depots!")

    except Exception as e:
        db.rollback()
        print(f"[!] Error seeding database: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()
