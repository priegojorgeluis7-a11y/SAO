from pydantic import BaseModel, EmailStr, Field


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
