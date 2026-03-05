from pydantic import BaseModel, EmailStr, Field
from typing import Literal
from pydantic import field_validator


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=256)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    # Bug fix: Flutter necesita expires_in para activar el refresh proactivo.
    # Sin este campo, TokenData.expiresAt es null y isExpired/shouldRefresh
    # siempre retornan false — el único refresh que funciona es el reactivo (401).
    expires_in: int  # segundos hasta que expira el access_token


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=1)


class SignupRequest(BaseModel):
    display_name: str = Field(..., min_length=1, max_length=255)
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=256)
    role: Literal["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"]
    invite_code: str = Field(..., min_length=1, max_length=256)


class SignupResponse(BaseModel):
    user_id: str
    email: EmailStr
    role: str


class UpdatePinRequest(BaseModel):
    pin: str = Field(..., min_length=4, max_length=6)

    @field_validator("pin")
    @classmethod
    def validate_pin_digits(cls, value: str) -> str:
        if not value.isdigit():
            raise ValueError("PIN must contain only digits")
        return value
