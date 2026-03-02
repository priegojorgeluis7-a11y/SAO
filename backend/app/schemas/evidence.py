from datetime import datetime
from uuid import UUID

from pydantic import AliasChoices, BaseModel, ConfigDict, Field


class UploadInitRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    activityId: UUID = Field(
        ...,
        validation_alias=AliasChoices("activityId", "activity_id"),
    )
    mimeType: str = Field(
        ...,
        min_length=3,
        max_length=255,
        validation_alias=AliasChoices("mimeType", "mime_type"),
    )
    sizeBytes: int = Field(
        ...,
        ge=1,
        validation_alias=AliasChoices("sizeBytes", "size_bytes"),
    )
    fileName: str = Field(
        ...,
        min_length=1,
        max_length=255,
        validation_alias=AliasChoices("fileName", "file_name"),
    )


class UploadInitResponse(BaseModel):
    evidenceId: str
    objectPath: str
    signedUrl: str
    expiresAt: datetime


class UploadCompleteRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    evidenceId: str = Field(
        ...,
        min_length=1,
        validation_alias=AliasChoices("evidenceId", "evidence_id"),
    )


class UploadCompleteResponse(BaseModel):
    ok: bool = True


class DownloadUrlResponse(BaseModel):
    signedUrl: str
    expiresAt: datetime
