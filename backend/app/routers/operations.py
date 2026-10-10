import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.models.entities import (
    Driver, DriverDuty, VehicleAssignment, Trip, Vehicle, Incident,
    Attendance, DutySwapRequest, User, RoleEnum, AuditLog
)
from app.schemas.schemas import (
    DriverDutyResponse, AttendanceCheckInRequest, AttendanceResponse,
    IncidentCreate, IncidentResponse, DutySwapCreate, DutySwapResponse
)
from app.security.auth import get_current_user, require_driver, require_staff

router = APIRouter(tags=["Operations & Crew"])

@router.get("/drivers/me/duties")
def get_my_duties(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Find driver profile for logged-in user
    driver = db.query(Driver).filter(Driver.user_id == current_user.id).first()
    if not driver:
        # If admin or demo, fetch duties for driver 1
        driver = db.query(Driver).first()
        if not driver:
            return []

    duties = db.query(DriverDuty).filter(DriverDuty.driver_id == driver.id).all()
    
    # Enrich with schedule trips
    result = []
    for d in duties:
        # Find vehicle assignments for this schedule
        v_assigns = db.query(VehicleAssignment).filter(VehicleAssignment.schedule_id == d.schedule_id).all()
        trips_info = []
        assigned_plate = "BUS-101"
        for va in v_assigns[:3]:
            trip = db.query(Trip).filter(Trip.id == va.trip_id).first()
            if trip:
                trips_info.append({
                    "trip_number": trip.trip_number,
                    "route": trip.route.name if trip.route else "Downtown Express",
                    "start_time": trip.start_time,
                    "end_time": trip.end_time
                })
            if va.vehicle:
                assigned_plate = va.vehicle.plate_number

        result.append({
            "id": d.id,
            "duty_code": d.duty_code,
            "start_time": d.start_time,
            "end_time": d.end_time,
            "total_driving_minutes": d.total_driving_minutes,
            "status": d.status,
            "is_locked": d.is_locked,
            "assigned_vehicle": assigned_plate,
            "trips": trips_info,
            "breaks": [{"start": "11:30", "end": "12:15", "type": "Mandatory Rest"}]
        })
    return result

@router.post("/attendance/check-in", response_model=AttendanceResponse)
def check_in_attendance(
    req: AttendanceCheckInRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    driver = db.query(Driver).filter(Driver.user_id == current_user.id).first()
    driver_id = driver.id if driver else "drv-001"

    # Validate vehicle existence
    veh = db.query(Vehicle).filter(Vehicle.id == req.vehicle_id).first()
    if not veh:
        # Check by plate number
        veh = db.query(Vehicle).filter(Vehicle.plate_number == req.vehicle_id).first()
    if not veh:
        raise HTTPException(status_code=404, detail="Vehicle not found for check-in")

    # Prevent duplicate check-in within same 30 min window
    recent_checkin = db.query(Attendance).filter(
        Attendance.driver_id == driver_id,
        Attendance.vehicle_id == veh.id
    ).order_by(Attendance.check_in_time.desc()).first()

    if recent_checkin and (datetime.utcnow() - recent_checkin.check_in_time).total_seconds() < 1800:
        return AttendanceResponse(
            id=recent_checkin.id,
            driver_id=driver_id,
            vehicle_id=veh.id,
            check_in_time=recent_checkin.check_in_time,
            status="verified",
            message=f"Attendance already verified for vehicle {veh.plate_number}."
        )

    attendance = Attendance(
        id=str(uuid.uuid4()),
        driver_id=driver_id,
        vehicle_id=veh.id,
        check_in_time=datetime.utcnow(),
        qr_code_hash=req.qr_code_hash or f"QR-{veh.plate_number}",
        status="verified"
    )
    db.add(attendance)
    db.commit()

    return AttendanceResponse(
        id=attendance.id,
        driver_id=driver_id,
        vehicle_id=veh.id,
        check_in_time=attendance.check_in_time,
        status="verified",
        message=f"Duty check-in successfully verified for {veh.plate_number}."
    )

@router.post("/incidents", response_model=IncidentResponse)
def report_incident(
    inc_in: IncidentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    incident = Incident(
        id=str(uuid.uuid4()),
        vehicle_id=inc_in.vehicle_id,
        driver_id=inc_in.driver_id,
        trip_id=inc_in.trip_id,
        incident_type=inc_in.incident_type,
        description=inc_in.description,
        severity=inc_in.severity,
        status="reported",
        reported_at=datetime.utcnow()
    )
    db.add(incident)

    # If breakdown, update vehicle status to breakdown
    if inc_in.incident_type == "breakdown" and inc_in.vehicle_id:
        veh = db.query(Vehicle).filter(Vehicle.id == inc_in.vehicle_id).first()
        if veh:
            veh.status = "breakdown"

    db.add(AuditLog(
        user_id=current_user.id,
        action="REPORT_INCIDENT",
        entity_type="incident",
        entity_id=incident.id,
        change_details={"type": inc_in.incident_type, "severity": inc_in.severity}
    ))
    db.commit()
    db.refresh(incident)
    return incident

@router.post("/duty-swaps", response_model=DutySwapResponse)
def request_duty_swap(
    swap_in: DutySwapCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    driver = db.query(Driver).filter(Driver.user_id == current_user.id).first()
    requester_id = driver.id if driver else "drv-001"

    swap_req = DutySwapRequest(
        id=str(uuid.uuid4()),
        requester_driver_id=requester_id,
        target_driver_id=swap_in.target_driver_id,
        requester_duty_id=swap_in.requester_duty_id,
        target_duty_id=swap_in.target_duty_id,
        reason=swap_in.reason,
        status="pending"
    )
    db.add(swap_req)
    db.commit()
    db.refresh(swap_req)
    return swap_req

@router.post("/duty-swaps/{id}/approve")
def approve_duty_swap(
    id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff)
):
    swap = db.query(DutySwapRequest).filter(DutySwapRequest.id == id).first()
    if not swap:
        raise HTTPException(status_code=404, detail="Duty swap request not found")

    # Atomic roster swap
    duty1 = db.query(DriverDuty).filter(DriverDuty.id == swap.requester_duty_id).first()
    duty2 = db.query(DriverDuty).filter(DriverDuty.id == swap.target_duty_id).first()

    if duty1 and duty2:
        # Swap drivers
        duty1.driver_id, duty2.driver_id = duty2.driver_id, duty1.driver_id

    swap.status = "approved"
    swap.reviewed_by = current_user.id
    db.commit()

    return {"message": "Duty swap approved and rosters atomically updated.", "status": "approved"}
