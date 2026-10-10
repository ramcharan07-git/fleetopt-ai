import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.models.entities import Vehicle, Driver, Depot, VehicleType, MaintenanceRecord, User, RoleEnum, AuditLog
from app.schemas.schemas import VehicleCreate, VehicleUpdate, VehicleResponse, DriverCreate, DriverResponse
from app.security.auth import get_current_user, require_admin, require_staff

router = APIRouter(tags=["Fleet & Crew"])

@router.get("/vehicles", response_model=List[VehicleResponse])
def get_vehicles(
    status: Optional[str] = None,
    depot_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Vehicle)
    if status:
        query = query.filter(Vehicle.status == status)
    if depot_id:
        query = query.filter(Vehicle.depot_id == depot_id)
    return query.all()

@router.post("/vehicles", response_model=VehicleResponse)
def create_vehicle(
    v_in: VehicleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff)
):
    existing = db.query(Vehicle).filter(Vehicle.plate_number == v_in.plate_number).first()
    if existing:
        raise HTTPException(status_code=400, detail="Vehicle plate number already registered")

    new_veh = Vehicle(
        id=str(uuid.uuid4()),
        plate_number=v_in.plate_number,
        vehicle_type_id=v_in.vehicle_type_id,
        depot_id=v_in.depot_id,
        status=v_in.status,
        odometer_km=v_in.odometer_km,
        year_manufactured=v_in.year_manufactured,
        qr_code=f"QR-{v_in.plate_number}"
    )
    db.add(new_veh)
    
    # Audit log
    db.add(AuditLog(
        user_id=current_user.id,
        action="CREATE_VEHICLE",
        entity_type="vehicle",
        entity_id=new_veh.id,
        change_details={"plate_number": v_in.plate_number}
    ))
    db.commit()
    db.refresh(new_veh)
    return new_veh

@router.patch("/vehicles/{id}", response_model=VehicleResponse)
def update_vehicle(
    id: str,
    v_update: VehicleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff)
):
    veh = db.query(Vehicle).filter(Vehicle.id == id).first()
    if not veh:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    old_status = veh.status
    if v_update.status is not None:
        veh.status = v_update.status
    if v_update.depot_id is not None:
        veh.depot_id = v_update.depot_id
    if v_update.odometer_km is not None:
        veh.odometer_km = v_update.odometer_km

    db.add(AuditLog(
        user_id=current_user.id,
        action="UPDATE_VEHICLE",
        entity_type="vehicle",
        entity_id=veh.id,
        change_details={"old_status": old_status, "new_status": veh.status}
    ))
    db.commit()
    db.refresh(veh)
    return veh

@router.get("/drivers", response_model=List[DriverResponse])
def get_drivers(
    depot_id: Optional[str] = None,
    is_active: Optional[bool] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Driver)
    if depot_id:
        query = query.filter(Driver.depot_id == depot_id)
    if is_active is not None:
        query = query.filter(Driver.is_active == is_active)
    return query.all()

@router.post("/drivers", response_model=DriverResponse)
def create_driver(
    d_in: DriverCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    existing = db.query(Driver).filter(Driver.employee_id == d_in.employee_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Employee ID already exists")

    drv = Driver(
        id=str(uuid.uuid4()),
        user_id=d_in.user_id,
        employee_id=d_in.employee_id,
        depot_id=d_in.depot_id,
        license_number=d_in.license_number,
        license_expiry=d_in.license_expiry,
        is_active=True
    )
    db.add(drv)
    db.commit()
    db.refresh(drv)
    return drv

@router.get("/depots")
def get_depots(db: Session = Depends(get_db)):
    depots = db.query(Depot).all()
    return [{
        "id": d.id,
        "name": d.name,
        "code": d.code,
        "latitude": d.latitude,
        "longitude": d.longitude,
        "address": d.address,
        "capacity": d.capacity
    } for d in depots]

@router.get("/maintenance")
def get_maintenance(db: Session = Depends(get_db)):
    records = db.query(MaintenanceRecord).all()
    return [{
        "id": r.id,
        "vehicle_id": r.vehicle_id,
        "maintenance_type": r.maintenance_type,
        "description": r.description,
        "cost": r.cost,
        "status": r.status,
        "service_date": r.service_date.isoformat() if r.service_date else None
    } for r in records]
