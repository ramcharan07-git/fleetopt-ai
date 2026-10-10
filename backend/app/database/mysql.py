import logging
import time
from typing import Generator, Dict, Any, Optional
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool
from app.core.config import settings

logger = logging.getLogger("fleetopt.mysql")

# Determine active MySQL or relational connection URL
_mysql_url = settings.MYSQL_DATABASE_URL or settings.DATABASE_URL
if _mysql_url.startswith("postgres://"):
    _mysql_url = _mysql_url.replace("postgres://", "postgresql://", 1)

# Configure pooling depending on dialect
_engine_kwargs: Dict[str, Any] = {
    "pool_pre_ping": True,
    "echo": False,
}

if "mysql" in _mysql_url:
    _engine_kwargs.update({
        "poolclass": QueuePool,
        "pool_size": 10,
        "max_overflow": 20,
        "pool_recycle": 3600,
        "pool_timeout": 30,
        "connect_args": {"charset": "utf8mb4"}
    })
elif _mysql_url.startswith("sqlite"):
    _engine_kwargs["connect_args"] = {"check_same_thread": False}

mysql_engine = create_engine(_mysql_url, **_engine_kwargs)
MySQLSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=mysql_engine)

def get_mysql_db() -> Generator[Session, None, None]:
    """Dependency that yields a managed transactional MySQL session."""
    db = MySQLSessionLocal()
    try:
        yield db
    finally:
        db.close()

def check_mysql_health() -> Dict[str, Any]:
    """
    Executes an actual database query to verify MySQL connection health,
    latency, and transactional read capability.
    """
    start_time = time.perf_counter()
    dialect_name = mysql_engine.dialect.name
    configured_mysql_url = settings.MYSQL_DATABASE_URL is not None

    try:
        with mysql_engine.connect() as conn:
            result = conn.execute(text("SELECT 1")).scalar()
            latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
            
            # Check table counts if tables exist
            table_info = {}
            try:
                user_count = conn.execute(text("SELECT COUNT(*) FROM users")).scalar()
                vehicle_count = conn.execute(text("SELECT COUNT(*) FROM vehicles")).scalar()
                table_info = {"users_count": user_count, "vehicles_count": vehicle_count}
            except Exception:
                table_info = {"note": "Tables not yet populated"}

            return {
                "status": "healthy" if result == 1 else "unhealthy",
                "dialect": dialect_name,
                "latency_ms": latency_ms,
                "is_mysql_native": dialect_name == "mysql",
                "configured": configured_mysql_url,
                "pool_size": getattr(mysql_engine.pool, "size", lambda: 0)(),
                "table_metrics": table_info
            }
    except Exception as e:
        latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
        logger.error(f"[MySQL Health Check Failed] {e}")
        return {
            "status": "unhealthy",
            "dialect": dialect_name,
            "latency_ms": latency_ms,
            "configured": configured_mysql_url,
            "error": str(e)
        }
