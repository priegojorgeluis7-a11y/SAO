"""Authentication endpoints for login, refresh and profile retrieval."""

import logging
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.rate_limit import enforce_rate_limit
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    verify_password,
    verify_token,
)
from app.models.role import Role
from app.models.user import User, UserStatus
from app.models.user_role_scope import UserRoleScope
from app.schemas.auth import (
    LoginRequest,
    RefreshRequest,
    SignupRequest,
    SignupResponse,
    TokenResponse,
    UpdatePinRequest,
)
from app.schemas.user import UserResponse
from app.services.audit_service import write_audit_log

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=SignupResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    payload: SignupRequest,
    db: Session = Depends(get_db),
) -> SignupResponse:
    role_name = payload.role.upper().strip()
    invite_code = payload.invite_code.strip()

    if role_name == "ADMIN":
        if not settings.ADMIN_INVITE_CODE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="ADMIN signup is disabled",
            )
        if invite_code != settings.ADMIN_INVITE_CODE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid invite code",
            )
    else:
        if not settings.SIGNUP_INVITE_CODE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Signup is disabled",
            )
        if invite_code != settings.SIGNUP_INVITE_CODE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid invite code",
            )

    existing_user = db.query(User).filter(User.email == payload.email).first()
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    role = db.query(Role).filter(Role.name == role_name).first()
    if role is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Role {role_name} is not configured",
        )

    user = User(
        email=payload.email,
        password_hash=get_password_hash(payload.password),
        full_name=payload.display_name.strip(),
        status=UserStatus.ACTIVE,
    )

    db.add(user)
    db.flush()

    scope = UserRoleScope(
        user_id=user.id,
        role_id=role.id,
        project_id=None,
        front_id=None,
        location_id=None,
        assigned_by_id=None,
    )
    db.add(scope)
    db.commit()
    db.refresh(user)

    return SignupResponse(
        user_id=str(user.id),
        email=user.email,
        role=role_name,
    )


@router.get("/roles", response_model=list[str])
async def list_signup_roles(db: Session = Depends(get_db)) -> list[str]:
    roles = db.query(Role).order_by(Role.name.asc()).all()
    return [role.name for role in roles]


@router.post("/login", response_model=TokenResponse)
async def login(
    credentials: LoginRequest,
    http_request: Request,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """Login con email/password. Devuelve access + refresh tokens"""
    enforce_rate_limit(
        http_request,
        scope="auth.login",
        limit=settings.RATE_LIMIT_AUTH_LOGIN_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
    )

    try:
        # Buscar usuario
        user = db.query(User).filter(User.email == credentials.email).first()

        if not user or not verify_password(credentials.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Verificar estado
        if user.status != UserStatus.ACTIVE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User account is inactive or locked"
            )

        # Actualizar last_login
        user.last_login_at = datetime.now(timezone.utc)
        db.commit()

        # Generar tokens
        access_token = create_access_token({"sub": str(user.id)})
        refresh_token = create_refresh_token({"sub": str(user.id)})

        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )
    except HTTPException:
        raise
    except Exception:
        logger.exception(
            "Unexpected error in POST /auth/login for email=%r. "
            "Likely cause: DB schema inconsistency (enum case mismatch) or "
            "missing migration. Check alembic_version and pg_enum.userstatus.",
            credentials.email,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error — check server logs for details",
        )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    body: RefreshRequest,
    http_request: Request,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """Renovar access token usando refresh token"""
    enforce_rate_limit(
        http_request,
        scope="auth.refresh",
        limit=settings.RATE_LIMIT_AUTH_REFRESH_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
    )

    try:
        payload = verify_token(body.refresh_token, expected_type="refresh")
        user_id_raw: str | None = payload.get("sub")
        if not user_id_raw:
            raise ValueError("Invalid token payload: missing subject")
        user_id = UUID(user_id_raw)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    new_access_token = create_access_token({"sub": str(user.id)})
    new_refresh_token = create_refresh_token({"sub": str(user.id)})

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)) -> UserResponse:
    """Obtener información del usuario autenticado"""
    return UserResponse.model_validate(current_user)


@router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    write_audit_log(
        db,
        action="AUTH_LOGOUT",
        entity="auth",
        entity_id=str(current_user.id),
        actor=current_user,
        details={"message": "User logged out"},
    )
    db.commit()
    return {"ok": True}


@router.put("/me/pin", status_code=status.HTTP_200_OK)
async def update_my_pin(
    payload: UpdatePinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.pin_hash = get_password_hash(payload.pin)
    db.add(current_user)
    db.commit()

    write_audit_log(
        db,
        action="AUTH_PIN_UPDATED",
        entity="auth",
        entity_id=str(current_user.id),
        actor=current_user,
        details={"message": "User updated offline PIN"},
    )
    db.commit()
    return {"ok": True}
