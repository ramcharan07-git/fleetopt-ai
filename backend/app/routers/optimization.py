import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.models.entities import (
    Schedule, ScheduleVersion, VehicleAssignment, DriverDuty, OptimizationRun,
    Trip, Vehicle, Driver, DriverQualification, DriverLeave, Incident, User, AuditLog
)
from app.schemas.schemas import (
    OptimizeRequest, OptimizeResponse, AssignmentDTO,
    ScheduleApprovalRequest, RescheduleRequest, RescheduleResponse,
    WhatIfSimulateRequest, WhatIfSimulateResponse
)
from app.optimization.joint_optimizer import JointFleetOptimizer
from app.optimization.what_if_simulator import WhatIfSimulator
from app.security.auth import require_admin, require_staff, get_current_user

router = APIRouter(tags=["Optimization Engine"])

@router.get("/schedules")
def get_schedules(date: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(Schedule)
    if date:
        query = query.filter(Schedule.date == date)
    schedules = query.order_by(Schedule.created_at.desc()).all()
    return [{
        "id": s.id,
        "name": s.name,
        "date": s.date,
        "status": s.status,
        "version": s.version,
        "created_at": s.created_at.isoformat() if s.created_at else None
    } for s in schedules]

@router.post("/optimize", response_model=OptimizeResponse)
def run_optimization(
    opt_req: OptimizeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff)
):
    # 1. Gather all trips
    db_trips = db.query(Trip).all()
    if not db_trips:
        raise HTTPException(status_code=400, detail="No trips found in database to schedule")

    trips_payload = [{
        "id": t.id,
        "trip_number": t.trip_number,
        "route_id": t.route_id,
        "start_time": t.start_time,
        "end_time": t.end_time,
        "demand": t.estimated_demand
    } for t in db_trips]

    # 2. Gather active vehicles
    db_vehicles = db.query(Vehicle).all()
    vehicles_payload = [{
        "id": v.id,
        "plate_number": v.plate_number,
        "capacity": 55,
        "status": v.status,
        "cost_per_km": 1.85
    } for v in db_vehicles]

    # 3. Gather active drivers and qualifications
    db_drivers = db.query(Driver).filter(Driver.is_active == True).all()
    
    # Check leaves for this date
    leaves = db.query(DriverLeave).filter(
        DriverLeave.status == "approved",
        DriverLeave.start_date <= opt_req.date,
        DriverLeave.end_date >= opt_req.date
    ).all()
    absent_driver_ids = [l.driver_id for l in leaves]

    drivers_payload = []
    for d in db_drivers:
        quals = [q.qualification_name for q in d.qualifications]
        drivers_payload.append({
            "id": d.id,
            "user_name": d.user.full_name if d.user else d.employee_id,
            "qualifications": quals,
            "preferences": {"shift": d.preferences.preferred_shift if d.preferences else "morning"}
        })

    # Run Joint Optimizer
    optimizer = JointFleetOptimizer(
        max_duty_hours=opt_req.max_duty_hours,
        min_rest_hours=opt_req.min_rest_hours,
        time_limit_seconds=opt_req.time_limit_seconds
    )
    result = optimizer.optimize(
        trips=trips_payload,
        vehicles=vehicles_payload,
        drivers=drivers_payload,
        absent_driver_ids=absent_driver_ids
    )

    # Save to database inside a transaction
    schedule_id = str(uuid.uuid4())
    schedule_name = opt_req.schedule_name or f"Optimized Schedule - {opt_req.date}"
    
    schedule = Schedule(
        id=schedule_id,
        name=schedule_name,
        date=opt_req.date,
        status="draft",
        version=1
    )
    db.add(schedule)

    # Save assignments & driver duties
    assignments_dto = []
    trip_map = {t.id: t for t in db_trips}
    veh_map = {v.id: v for v in db_vehicles}
    drv_map = {d.id: d for d in db_drivers}

    # Group driver duties
    driver_duty_map = {}

    for assign in result["assignments"]:
        t = trip_map.get(assign["trip_id"])
        v = veh_map.get(assign["vehicle_id"]) if assign["vehicle_id"] else None
        d = drv_map.get(assign["driver_id"]) if assign["driver_id"] else None

        v_assign = VehicleAssignment(
            id=str(uuid.uuid4()),
            schedule_id=schedule_id,
            trip_id=assign["trip_id"],
            vehicle_id=assign["vehicle_id"],
            start_time=t.start_time if t else "08:00",
            end_time=t.end_time if t else "09:00",
            is_locked=False,
            uncovered=assign["uncovered"]
        )
        db.add(v_assign)

        if assign["driver_id"]:
            if assign["driver_id"] not in driver_duty_map:
                driver_duty_map[assign["driver_id"]] = {
                    "start": assign["start_time"],
                    "end": assign["end_time"],
                    "trips": []
                }
            driver_duty_map[assign["driver_id"]]["trips"].append(assign["trip_id"])

        assignments_dto.append(AssignmentDTO(
            trip_id=assign["trip_id"],
            trip_number=t.trip_number if t else "",
            route_number=t.route.route_number if t and t.route else "",
            start_time=assign["start_time"],
            end_time=assign["end_time"],
            vehicle_id=assign["vehicle_id"],
            vehicle_plate=v.plate_number if v else None,
            driver_id=assign["driver_id"],
            driver_name=d.user.full_name if d and d.user else (d.employee_id if d else None),
            uncovered=assign["uncovered"]
        ))

    # Save Driver Duties
    for drv_id, duty_info in driver_duty_map.items():
        duty = DriverDuty(
            id=str(uuid.uuid4()),
            schedule_id=schedule_id,
            driver_id=drv_id,
            duty_code=f"DUTY-{drv_id[:8].upper()}",
            start_time=duty_info["start"],
            end_time=duty_info["end"],
            total_driving_minutes=len(duty_info["trips"]) * 40,
            status="assigned",
            is_locked=False,
            uncovered=False
        )
        db.add(duty)

    # Save Optimization Run log
    opt_run = OptimizationRun(
        id=str(uuid.uuid4()),
        schedule_id=schedule_id,
        algorithm="OR-Tools CP-SAT Joint VSP/DDRP",
        status=result["solver_status"],
        solve_time_seconds=result["solve_duration_seconds"],
        objective_score=result["objective_score"],
        covered_trips=result["covered_trips"],
        uncovered_trips=result["uncovered_trips"],
        total_operating_cost=result["estimated_cost"],
        solver_status=result["solver_status"],
        solver_message=result["explanation"]
    )
    db.add(opt_run)

    # Audit Log
    db.add(AuditLog(
        user_id=current_user.id,
        action="RUN_OPTIMIZATION",
        entity_type="schedule",
        entity_id=schedule_id,
        change_details={"covered": result["covered_trips"], "uncovered": result["uncovered_trips"]}
    ))

    db.commit()

    return OptimizeResponse(
        schedule_id=schedule_id,
        date=opt_req.date,
        solver_status=result["solver_status"],
        solve_duration_seconds=result["solve_duration_seconds"],
        objective_score=result["objective_score"],
        total_trips=result["total_trips"],
        covered_trips=result["covered_trips"],
        uncovered_trips=result["uncovered_trips"],
        vehicles_used=result["vehicles_used"],
        drivers_used=result["drivers_used"],
        estimated_cost=result["estimated_cost"],
        assignments=assignments_dto,
        explanation=result["explanation"]
    )

@router.get("/optimization-runs/{id}")
def get_optimization_run(id: str, db: Session = Depends(get_db)):
    run = db.query(OptimizationRun).filter(OptimizationRun.id == id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Optimization run not found")
    return {
        "id": run.id,
        "schedule_id": run.schedule_id,
        "algorithm": run.algorithm,
        "solver_status": run.solver_status,
        "solve_time_seconds": run.solve_time_seconds,
        "objective_score": run.objective_score,
        "covered_trips": run.covered_trips,
        "uncovered_trips": run.uncovered_trips,
        "total_operating_cost": run.total_operating_cost,
        "solver_message": run.solver_message,
        "created_at": run.created_at.isoformat() if run.created_at else None
    }

@router.post("/schedules/{id}/approve")
def approve_schedule(
    id: str,
    req: ScheduleApprovalRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    schedule = db.query(Schedule).filter(Schedule.id == id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")

    # Transactional approval & optimistic concurrency version bump
    new_version_num = schedule.version + 1
    schedule.status = "approved"
    schedule.version = new_version_num

    # Create immutable ScheduleVersion snapshot record
    version_record = ScheduleVersion(
        id=str(uuid.uuid4()),
        schedule_id=schedule.id,
        version_number=new_version_num,
        status="approved",
        change_summary=req.notes or "Official schedule approval",
        approved_by=current_user.id,
        approved_at=datetime.utcnow()
    )
    db.add(version_record)

    # Lock assignments
    db.query(VehicleAssignment).filter(VehicleAssignment.schedule_id == id).update({"is_locked": True})
    db.query(DriverDuty).filter(DriverDuty.schedule_id == id).update({"is_locked": True})

    # Audit log
    db.add(AuditLog(
        user_id=current_user.id,
        action="APPROVE_SCHEDULE",
        entity_type="schedule",
        entity_id=id,
        change_details={"version": new_version_num, "notes": req.notes}
    ))
    db.commit()

    return {
        "message": "Schedule approved successfully and locked for operations.",
        "schedule_id": id,
        "status": "approved",
        "version": new_version_num
    }

@router.post("/reschedule", response_model=RescheduleResponse)
def reschedule_disruption(
    req: RescheduleRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff)
):
    incident = db.query(Incident).filter(Incident.id == req.incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident record not found")

    schedule = db.query(Schedule).filter(Schedule.id == req.schedule_id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")

    # Identify affected assignments
    affected_query = db.query(VehicleAssignment).filter(VehicleAssignment.schedule_id == req.schedule_id)
    if incident.vehicle_id:
        affected_query = affected_query.filter(VehicleAssignment.vehicle_id == incident.vehicle_id)
    elif incident.driver_id:
        pass

    affected_assignments = affected_query.all()
    affected_count = len(affected_assignments)

    # Find replacement vehicle from spare active vehicles not currently assigned
    replacement_v = db.query(Vehicle).filter(
        Vehicle.status == "active",
        Vehicle.id != incident.vehicle_id
    ).first()

    reassigned_count = 0
    uncovered_count = 0

    if replacement_v:
        for a in affected_assignments:
            a.vehicle_id = replacement_v.id
            a.uncovered = False
            reassigned_count += 1
        incident.status = "resolved"
        msg = f"Reassigned {reassigned_count} trips to spare vehicle {replacement_v.plate_number}."
    else:
        for a in affected_assignments:
            a.vehicle_id = None
            a.uncovered = True
            uncovered_count += 1
        msg = f"No spare vehicle available. {uncovered_count} trips marked uncovered."

    schedule.version += 1
    db.add(AuditLog(
        user_id=current_user.id,
        action="RESCHEDULE_DISRUPTION",
        entity_type="incident",
        entity_id=incident.id,
        change_details={"affected": affected_count, "reassigned": reassigned_count}
    ))
    db.commit()

    return RescheduleResponse(
        schedule_id=schedule.id,
        affected_trips_count=affected_count,
        reassigned_trips_count=reassigned_count,
        uncovered_trips_count=uncovered_count,
        replacement_vehicle_id=replacement_v.id if replacement_v else None,
        status="success",
        message=msg
    )

@router.post("/simulate", response_model=WhatIfSimulateResponse)
def simulate_scenario(
    sim_req: WhatIfSimulateRequest,
    db: Session = Depends(get_db)
):
    trips = db.query(Trip).all()
    vehicles = db.query(Vehicle).all()
    drivers = db.query(Driver).filter(Driver.is_active == True).all()

    trips_payload = [{"id": t.id, "trip_number": t.trip_number, "start_time": t.start_time, "end_time": t.end_time, "demand": t.estimated_demand} for t in trips]
    vehicles_payload = [{"id": v.id, "plate_number": v.plate_number, "status": v.status, "capacity": 55} for v in vehicles]
    drivers_payload = [{"id": d.id, "qualifications": ["standard_bus"], "preferences": {"shift": "morning"}} for d in drivers]

    simulator = WhatIfSimulator()
    res = simulator.run_simulation(
        base_trips=trips_payload,
        base_vehicles=vehicles_payload,
        base_drivers=drivers_payload,
        available_buses_count=sim_req.available_buses_count,
        absent_drivers_count=sim_req.absent_drivers_count or 0,
        trip_multiplier=sim_req.trip_multiplier,
        passenger_demand_percentage=sim_req.passenger_demand_percentage,
        vehicle_breakdowns_count=sim_req.vehicle_breakdowns_count,
        priority_mode=sim_req.priority_mode
    )

    return WhatIfSimulateResponse(
        baseline_covered=res["baseline_covered"],
        simulated_covered=res["simulated_covered"],
        baseline_cost=res["baseline_cost"],
        simulated_cost=res["simulated_cost"],
        uncovered_trips_count=res["simulated_uncovered"],
        active_buses=res["active_buses"],
        active_drivers=res["active_drivers"],
        solve_time_seconds=res["solve_time_seconds"],
        constraint_violations=res["constraint_violations"]
    )
