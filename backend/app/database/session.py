import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import settings

# Adjust database URL if needed
db_url = settings.DATABASE_URL
if db_url.startswith("postgres://"):
    db_url = db_url.replace("postgres://", "postgresql://", 1)
elif db_url == "sqlite:///./fleetopt.db":
    # Anchor to authoritative workspace database file
    root_db = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "fleetopt.db"))
    if not os.path.exists(root_db):
        root_db = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "fleetopt.db"))
    db_url = f"sqlite:///{root_db}"

connect_args = {}
if db_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    db_url,
    connect_args=connect_args,
    pool_pre_ping=True,
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
