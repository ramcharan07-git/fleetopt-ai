import os
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    PROJECT_NAME: str = "FleetOpt AI"
    API_V1_STR: str = "/api"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    
    # Secret Key & JWT
    SECRET_KEY: str = os.getenv("SECRET_KEY", "fleetopt-ai-super-secure-production-secret-key-32chars")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours
    
    # Databases
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./fleetopt.db")
    MYSQL_DATABASE_URL: Optional[str] = os.getenv("MYSQL_DATABASE_URL", None)
    
    # MongoDB Atlas
    MONGODB_URI: Optional[str] = os.getenv("MONGODB_URI", None)
    MONGODB_DATABASE: str = os.getenv("MONGODB_DATABASE", "fleetopt_telemetry")
    
    # External APIs
    GOOGLE_MAPS_API_KEY: Optional[str] = os.getenv("GOOGLE_MAPS_API_KEY", None)
    ROUTING_API_KEY: Optional[str] = os.getenv("ROUTING_API_KEY", None)
    OPENWEATHER_API_KEY: Optional[str] = os.getenv("OPENWEATHER_API_KEY", None)
    FIREBASE_CREDENTIALS_PATH: Optional[str] = os.getenv("FIREBASE_CREDENTIALS_PATH", None)
    FCM_SERVER_KEY: Optional[str] = os.getenv("FCM_SERVER_KEY", None)
    
    # Supabase (Optional)
    SUPABASE_URL: Optional[str] = os.getenv("SUPABASE_URL", None)
    SUPABASE_ANON_KEY: Optional[str] = os.getenv("SUPABASE_ANON_KEY", None)
    SUPABASE_JWT_SECRET: Optional[str] = os.getenv("SUPABASE_JWT_SECRET", None)
    
    # Optimizer Defaults
    DEFAULT_MAX_DUTY_HOURS: float = 8.0
    DEFAULT_MIN_REST_HOURS: float = 11.0
    DEFAULT_MAX_DRIVING_WITHOUT_BREAK: float = 4.5
    DEFAULT_BREAK_DURATION_MINUTES: int = 45
    SOLVER_TIME_LIMIT_SECONDS: int = 30

    class Config:
        env_file = ".env"
        extra = "allow"

settings = Settings()
