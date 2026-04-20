"""Authentication endpoints for login, refresh and profile retrieval."""

import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.api_errors import api_error
from app.core.rate_limit import enforce_rate_limit
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    verify_password,
    verify_token,
)
from app.core.enums import UserStatus
from app.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    RefreshRequest,
    SignupRequest,
    SignupResponse,
    TokenResponse,
    UpdatePinRequest,
)
from app.core.firestore import get_firestore_client
from app.schemas.user import UserResponse
from app.services.audit_service import canonicalize_role_name, write_firestore_audit_log
from app.services.firestore_identity_service import (
    create_firestore_user,
    get_firestore_user_by_id,
    get_firestore_user_by_email,
    list_firestore_users,
    update_last_login,
    update_last_logout,
)
from app.services.invitation_service import (
    mark_invitation_used,
    validate_user_invitation,
)
from app.services.role_permission_service import merge_role_permission_codes

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=SignupResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    payload: SignupRequest,
    http_request: Request,
) -> SignupResponse:
    enforce_rate_limit(
        http_request,
        scope="auth.signup",
        limit=settings.RATE_LIMIT_AUTH_SENSITIVE_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
        identifier=payload.email,
    )
    role_name = payload.role.upper().strip()
    invite_code = payload.invite_code.strip()
    email_normalized = payload.email.strip().lower()
    invitation_to_consume = None

    if role_name == "ADMIN":
        static_admin_code = (settings.ADMIN_INVITE_CODE or "").strip()
        if not static_admin_code or invite_code != static_admin_code:
            invitation_to_consume = validate_user_invitation(
                invite_code,
                role_name,
                email_normalized,
            )
            if invitation_to_consume is None:
                raise api_error(
                    status_code=status.HTTP_403_FORBIDDEN,
                    code="AUTH_INVALID_INVITE_CODE",
                    message="Invalid invite code",
                )
    else:
        static_signup_code = (settings.SIGNUP_INVITE_CODE or "").strip()
        if not static_signup_code or invite_code != static_signup_code:
            invitation_to_consume = validate_user_invitation(
                invite_code,
                role_name,
                email_normalized,
            )
            if invitation_to_consume is None:
                raise api_error(
                    status_code=status.HTTP_403_FORBIDDEN,
                    code="AUTH_INVALID_INVITE_CODE",
                    message="Invalid invite code",
                )
    if get_firestore_user_by_email(email_normalized):
        raise api_error(
            status_code=status.HTTP_409_CONFLICT,
            code="AUTH_EMAIL_ALREADY_REGISTERED",
            message="Email already registered",
        )

    first_name = payload.first_name.strip() if payload.first_name else None
    last_name = payload.last_name.strip() if payload.last_name else None
    second_last_name = (
        payload.second_last_name.strip() if payload.second_last_name else None
    )
    birth_date = payload.birth_date.isoformat() if payload.birth_date else None

    principal = create_firestore_user(
        email=email_normalized,
        full_name=payload.display_name.strip(),
        password_hash=get_password_hash(payload.password),
        roles=[role_name],
        project_ids=[],
        first_name=first_name,
        last_name=last_name,
        second_last_name=second_last_name,
        birth_date=birth_date,
    )
    if invitation_to_consume is not None:
        mark_invitation_used(invitation_to_consume.invite_id, email_normalized)

    return SignupResponse(
        user_id=str(principal.id),
        email=principal.email,
        role=role_name,
    )


@router.get("/roles", response_model=list[str])
async def list_signup_roles() -> list[str]:
    return ["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"]


@router.post("/login", response_model=TokenResponse)
async def login(
    credentials: LoginRequest,
    http_request: Request,
) -> TokenResponse:
    """Login con email/password. Devuelve access + refresh tokens"""
    enforce_rate_limit(
        http_request,
        scope="auth.login",
        limit=settings.RATE_LIMIT_AUTH_LOGIN_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
        identifier=credentials.email,
    )

    try:
        user = get_firestore_user_by_email(credentials.email)

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if user.status != UserStatus.ACTIVE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User account is inactive or locked"
            )

        password_hash = getattr(user, "password_hash", None)
        if not password_hash:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if not verify_password(credentials.password, password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )

        update_last_login(user.id)
        write_firestore_audit_log(
            action="LOGIN",
            entity="user",
            entity_id=str(user.id),
            actor=user,
        )

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
            "Unexpected error in POST /auth/login for email=%r.",
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

    firestore_user = get_firestore_user_by_id(user_id)
    if firestore_user is None or firestore_user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token_iat = payload.get("iat")
    if token_iat and firestore_user.last_logout_at:
        token_issued_at = datetime.fromtimestamp(token_iat, tz=timezone.utc)
        if token_issued_at < firestore_user.last_logout_at:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token",
                headers={"WWW-Authenticate": "Bearer"},
            )

    new_access_token = create_access_token({"sub": str(firestore_user.id)})
    new_refresh_token = create_refresh_token({"sub": str(firestore_user.id)})

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: Any = Depends(get_current_user)) -> UserResponse:
    """Obtener informaciÃ³n del usuario autenticado"""
    now = datetime.now(timezone.utc)
    roles = [
        canonicalize_role_name(role) or str(role).strip().upper()
        for role in (getattr(current_user, "roles", []) or [])
        if str(role).strip()
    ]
    permission_scopes = [
        {
            "permission_code": str(item.get("permission_code") or "").strip(),
            "project_id": (
                str(item.get("project_id") or "").strip().upper() or None
            ),
            "effect": (
                "deny"
                if str(item.get("effect") or "allow").strip().lower() == "deny"
                else "allow"
            ),
        }
        for item in (getattr(current_user, "permission_scopes", []) or [])
        if str(item.get("permission_code") or "").strip()
    ]
    payload = {
        "id": getattr(current_user, "id"),
        "email": getattr(current_user, "email"),
        "full_name": getattr(current_user, "full_name", ""),
        "status": getattr(current_user, "status", UserStatus.ACTIVE),
        "last_login_at": getattr(current_user, "last_login_at", None),
        "created_at": getattr(current_user, "created_at", now),
        "roles": roles,
        "permission_codes": merge_role_permission_codes(roles, permission_scopes),
        "permission_scopes": permission_scopes,
    }
    return UserResponse.model_validate(payload)


@router.post("/logout")
async def logout(
    current_user: object = Depends(get_current_user),
):
    update_last_logout(current_user.id)
    write_firestore_audit_log(
        action="LOGOUT",
        entity="user",
        entity_id=str(getattr(current_user, "id", "")),
        actor=current_user,
    )
    return {"ok": True}


@router.put("/me/password", status_code=status.HTTP_200_OK)
async def change_my_password(
    payload: ChangePasswordRequest,
    http_request: Request,
    current_user: object = Depends(get_current_user),
):
    """Cambiar contraseña del usuario autenticado."""
    enforce_rate_limit(
        http_request,
        scope="auth.password_change",
        limit=settings.RATE_LIMIT_AUTH_SENSITIVE_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
        identifier=str(getattr(current_user, "id", "")),
    )
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )

    get_firestore_client().collection("users").document(str(current_user.id)).set(
        {"password_hash": get_password_hash(payload.new_password)}, merge=True
    )
    write_firestore_audit_log(
        action="PASSWORD_CHANGED",
        entity="user",
        entity_id=str(getattr(current_user, "id", "")),
        actor=current_user,
    )
    return {"ok": True}


@router.put("/me/pin", status_code=status.HTTP_200_OK)
async def update_my_pin(
    payload: UpdatePinRequest,
    http_request: Request,
    current_user: object = Depends(get_current_user),
):
    enforce_rate_limit(
        http_request,
        scope="auth.pin_change",
        limit=settings.RATE_LIMIT_AUTH_SENSITIVE_PER_MINUTE,
        window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
        identifier=str(getattr(current_user, "id", "")),
    )
    get_firestore_client().collection("users").document(str(current_user.id)).set(
        {"pin_hash": get_password_hash(payload.pin)}, merge=True
    )
    return {"ok": True}


