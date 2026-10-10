import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.models.entities import Route, Trip, Stop, RouteStop, User
from app.schemas.schemas import RouteCreate, RouteResponse, TripCreate, TripResponse, StopResponse
from app.security.auth import require_admin

router = APIRouter(tags=["Transit Network"])

@router.get("/routes", response_model=List[RouteResponse])
def get_routes(is_active: Optional[bool] = None, db: Session = Depends(get_db)):
    query = db.query(Route)
    if is_active is not None:
        query = query.filter(Route.is_active == is_active)
    return query.all()

@router.post("/routes", response_model=RouteResponse)
def create_route(
    r_in: RouteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    existing = db.query(Route).filter(Route.route_number == r_in.route_number).first()
    if existing:
        raise HTTPException(status_code=400, detail="Route number already exists")

    new_route = Route(
        id=str(uuid.uuid4()),
        route_number=r_in.route_number,
        name=r_in.name,
        origin=r_in.origin,
        destination=r_in.destination,
        distance_km=r_in.distance_km,
        estimated_duration_minutes=r_in.estimated_duration_minutes,
        is_active=True
    )
    db.add(new_route)
    db.commit()
    db.refresh(new_route)
    return new_route

@router.get("/trips", response_model=List[TripResponse])
def get_trips(
    route_id: Optional[str] = None,
    day_of_week: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Trip)
    if route_id:
        query = query.filter(Trip.route_id == route_id)
    if day_of_week:
        query = query.filter(Trip.day_of_week == day_of_week)
    return query.all()

@router.post("/trips", response_model=TripResponse)
def create_trip(
    t_in: TripCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    trip = Trip(
        id=str(uuid.uuid4()),
        route_id=t_in.route_id,
        trip_number=t_in.trip_number,
        direction=t_in.direction,
        start_time=t_in.start_time,
        end_time=t_in.end_time,
        day_of_week=t_in.day_of_week,
        estimated_demand=t_in.estimated_demand
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return trip

@router.get("/stops", response_model=List[StopResponse])
def get_stops(db: Session = Depends(get_db)):
    return db.query(Stop).all()
