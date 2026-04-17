import re
from datetime import date
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator


_NAME_PATTERN = re.compile(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+")


def _normalize_email(value: object) -> object:
    if isinstance(value, str):
        return value.strip().lower()
    return value


def _normalize_person_name(value: object) -> object:
    if value is None:
        return None
    if not isinstance(value, str):
        return value
    compact = re.sub(r"\s+", " ", value.strip())
    if not compact:
        return None
    lowered = compact.lower()
    return _NAME_PATTERN.sub(
        lambda match: match.group(0)[0].upper() + match.group(0)[1:],
        lowered,
    )


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=256)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: object) -> object:
        return _normalize_email(value)


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
    display_name: str | None = Field(default=None, min_length=1, max_length=255)
    first_name: str | None = Field(default=None, min_length=1, max_length=120)
    last_name: str | None = Field(default=None, min_length=1, max_length=120)
    second_last_name: str | None = Field(default=None, max_length=120)
    birth_date: date | None = None
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=256)
    role: Literal["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO", "LECTOR"]
    invite_code: str = Field(..., min_length=1, max_length=256)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, value: object) -> object:
        return _normalize_email(value)

    @field_validator(
        "display_name",
        "first_name",
        "last_name",
        "second_last_name",
        mode="before",
    )
    @classmethod
    def normalize_names(cls, value: object) -> object:
        return _normalize_person_name(value)

    @model_validator(mode="after")
    def ensure_display_name(self):
        full_name = str(self.display_name or "").strip()
        if not full_name:
            parts = [
                str(self.first_name or "").strip(),
                str(self.last_name or "").strip(),
                str(self.second_last_name or "").strip(),
            ]
            full_name = " ".join(part for part in parts if part)
        if not full_name:
            raise ValueError("display_name or first_name/last_name is required")
        self.display_name = full_name
        return self


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


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(..., min_length=1, max_length=256)
    new_password: str = Field(..., min_length=8, max_length=256)
