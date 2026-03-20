from typing import Any

from pydantic import BaseModel, Field, model_validator


class OcrDetectedSummary(BaseModel):
    date: str | None = None
    attendees: list[str] = Field(default_factory=list)
    agreements: list[str] = Field(default_factory=list)
    next_steps: list[str] = Field(default_factory=list)
    key_points: list[str] = Field(default_factory=list)


class OcrExtractResponse(BaseModel):
    source_file_name: str
    source_type: str
    extraction_mode: str
    text: str
    text_length: int
    detected: OcrDetectedSummary


class OcrLinkRequest(BaseModel):
    project_id: str | None = None
    activity_id: str | None = None
    assistant_id: str | None = None
    assistant_name: str | None = None
    source_file_name: str | None = None
    extracted_text: str
    reviewed_text: str | None = None
    extracted_fields: dict[str, Any] | None = None

    @model_validator(mode="after")
    def validate_link_target(self) -> "OcrLinkRequest":
        has_activity = bool((self.activity_id or "").strip())
        has_assistant = bool((self.assistant_id or "").strip()) or bool(
            (self.assistant_name or "").strip()
        )
        if not has_activity and not has_assistant:
            raise ValueError("Provide activity_id or assistant_id/assistant_name")
        return self


class OcrLinkResponse(BaseModel):
    record_id: str
    linked_to: str
    message: str
