"""Security helpers for password hashing and JWT lifecycle."""

import logging
from datetime import datetime, timedelta
from datetime import timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
logger = logging.getLogger(__name__)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica contraseña contra hash"""
    if not hashed_password:
        return False

    try:
        return pwd_context.verify(plain_password, hashed_password)
    except Exception:
        logger.exception("Password hash verification failed")
        return False


def get_password_hash(password: str) -> str:
    """Genera hash bcrypt de contraseña"""
    return pwd_context.hash(password)


def _create_token(data: dict, expires_at: datetime, token_type: str) -> str:
    """Build and encode JWT token payload with a fixed expiration and type."""
    payload = data.copy()
    payload.update({"exp": expires_at, "type": token_type})
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """Crea JWT access token"""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    return _create_token(data=data, expires_at=expire, token_type="access")


def create_refresh_token(data: dict) -> str:
    """Crea JWT refresh token"""
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    return _create_token(data=data, expires_at=expire, token_type="refresh")


def verify_token(token: str, expected_type: str = "access") -> dict:
    """Verifica y decodifica token"""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        token_type: str = payload.get("type")
        
        if token_type != expected_type:
            raise ValueError(f"Invalid token type. Expected {expected_type}, got {token_type}")
        
        return payload
    except JWTError as e:
        raise ValueError(f"Invalid token: {str(e)}")
