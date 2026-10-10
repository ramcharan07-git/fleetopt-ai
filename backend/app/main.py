from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.database.session import engine, Base, SessionLocal
from app.routers import auth, fleet, transit, optimization, operations, analytics, navigation
from app.database.mysql import check_mysql_health
from app.database.mongodb import mongo_manager
from app.models.entities import User

# Initialize tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="FleetOpt AI API",
    description="Autonomous Public Fleet Scheduling and Driver Duty Rostering Combinatorial Optimizer",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS setup for mobile and web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------------------------
# Health Endpoints
# ------------------------------------------------------------------------------
@app.get("/api/health", tags=["Health"])
def health_check():
    mysql_stat = check_mysql_health()
    mongo_stat = mongo_manager.health_check()
    is_healthy = mysql_stat.get("status") in ["healthy"]
    return {
        "status": "healthy" if is_healthy else "degraded",
        "service": "FleetOpt AI Backend",
        "version": "1.0.0",
        "mysql": mysql_stat,
        "mongodb": mongo_stat,
        "optimizer": "Google OR-Tools CP-SAT Enabled",
        "ml": "Scikit-Learn Random Forest Enabled"
    }

@app.get("/api/health/mysql", tags=["Health"])
def health_mysql():
    return check_mysql_health()

@app.get("/api/health/mongodb", tags=["Health"])
def health_mongodb():
    return mongo_manager.health_check()

# Include all modular routers
app.include_router(auth.router, prefix="/api")
app.include_router(fleet.router, prefix="/api")
app.include_router(transit.router, prefix="/api")
app.include_router(optimization.router, prefix="/api")
app.include_router(operations.router, prefix="/api")
app.include_router(analytics.router, prefix="/api")
app.include_router(navigation.router, prefix="/api")

@app.on_event("startup")
def on_startup():
    # Automatically seed initial demo data if database is empty
    db = SessionLocal()
    try:
        user_count = db.query(User).count()
        if user_count == 0:
            print("[*] Database is empty. Running initial demo seed...")
            from database.seeds.seed_demo_data import seed_database
            seed_database()
            print("[OK] Seed complete.")
    except Exception as e:
        print(f"[!] Startup seed check skipped: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
