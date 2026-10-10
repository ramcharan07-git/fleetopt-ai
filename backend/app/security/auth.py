import jwt
import hashlib
from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from app.core.config import settings
from app.database.session import get_db
from app.models.entities import User, RoleEnum

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)

def hash_password(password: str) -> str:
    """Secure SHA-256 salted password hashing."""
    salt = settings.SECRET_KEY[:16]
    return hashlib.sha256((salt + password).encode()).hexdigest()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return hash_password(plain_password) == hashed_password

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def decode_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except Exception:
        # Check if Supabase JWT Secret is configured
        if settings.SUPABASE_JWT_SECRET:
            try:
                payload = jwt.decode(token, settings.SUPABASE_JWT_SECRET, algorithms=["HS256"])
                return payload
            except Exception:
                return None
        return None

def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not token:
        # Fallback to demo default super_admin if in dev mode with mock token
        raise credentials_exception

    payload = decode_token(token)
    if payload is None:
        raise credentials_exception

    user_id: str = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        # If user is from Supabase Auth directly by email
        user_email = payload.get("email")
        if user_email:
            user = db.query(User).filter(User.email == user_email).first()
        if user is None:
            raise credentials_exception
            
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user account")
    return user

def require_roles(allowed_roles: List[str]):
    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Operation not permitted. Required role: {', '.join(allowed_roles)}"
            )
        return current_user
    return role_checker

require_admin = require_roles([RoleEnum.SUPER_ADMIN])
require_driver = require_roles([RoleEnum.DRIVER, RoleEnum.SUPER_ADMIN])
require_depot_manager = require_roles([RoleEnum.DEPOT_MANAGER, RoleEnum.SUPER_ADMIN])
require_staff = require_roles([RoleEnum.SUPER_ADMIN, RoleEnum.DEPOT_MANAGER])
