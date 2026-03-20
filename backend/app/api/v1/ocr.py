import io
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status

from app.api.deps import require_any_role
from app.core.config import settings
from app.core.firestore import get_firestore_client
from app.services.audit_service import write_firestore_audit_log
from typing import Any
from app.schemas.ocr import (
    OcrDetectedSummary,
    OcrExtractResponse,
    OcrLinkRequest,
    OcrLinkResponse,
)

router = APIRouter(prefix="/ocr", tags=["ocr"])

_MAX_UPLOAD_BYTES = 20 * 1024 * 1024
_SUPPORTED_IMAGE_EXT = {".png", ".jpg", ".jpeg", ".bmp", ".webp", ".tiff"}


def _normalize_text(text: str) -> str:
    lines = [line.strip() for line in text.splitlines()]
    compact = [line for line in lines if line]
    return "\n".join(compact)


def _extract_pdf_text_native(raw_bytes: bytes) -> str:
    try:
        from pypdf import PdfReader
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Missing dependency pypdf for PDF text extraction",
        ) from exc

    reader = PdfReader(io.BytesIO(raw_bytes))
    chunks: list[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        if text.strip():
            chunks.append(text)
    return _normalize_text("\n".join(chunks))


def _extract_lines_from_rapidocr_result(result: object) -> list[str]:
    lines: list[str] = []
    if not isinstance(result, list):
        return lines

    for row in result:
        if not isinstance(row, (list, tuple)) or len(row) < 2:
            continue
        maybe_text = row[1]
        if isinstance(maybe_text, str):
            text = maybe_text.strip()
        elif isinstance(maybe_text, (list, tuple)) and maybe_text:
            text = str(maybe_text[0]).strip()
        else:
            text = ""
        if text:
            lines.append(text)
    return lines


def _ocr_from_pil_images(images: list[object]) -> str:
    try:
        import numpy as np
        from rapidocr_onnxruntime import RapidOCR
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Missing OCR dependencies: numpy + rapidocr-onnxruntime",
        ) from exc

    engine = RapidOCR()
    chunks: list[str] = []

    for image in images:
        ocr_result, _ = engine(np.array(image))
        lines = _extract_lines_from_rapidocr_result(ocr_result)
        if lines:
            chunks.append("\n".join(lines))

    return _normalize_text("\n\n".join(chunks))


def _ocr_pdf_pages(raw_bytes: bytes, max_pages: int) -> str:
    try:
        import pypdfium2 as pdfium
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Missing dependency pypdfium2 for scanned PDF OCR",
        ) from exc

    doc = pdfium.PdfDocument(raw_bytes)
    page_count = len(doc)
    pages_to_process = min(max(page_count, 0), max_pages)
    pil_images = []
    for idx in range(pages_to_process):
        page = doc[idx]
        bitmap = page.render(scale=2)
        pil_images.append(bitmap.to_pil())

    return _ocr_from_pil_images(pil_images)


def _ocr_image(raw_bytes: bytes) -> str:
    try:
        from PIL import Image
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Missing dependency pillow for image OCR",
        ) from exc

    image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    return _ocr_from_pil_images([image])


def _detect_summary(text: str) -> OcrDetectedSummary:
    normalized = _normalize_text(text)
    lines = normalized.splitlines()
    lower_lines = [line.lower() for line in lines]

    date_match = re.search(
        r"\b(\d{1,2}[\/-]\d{1,2}[\/-]\d{2,4}|\d{4}[\/-]\d{1,2}[\/-]\d{1,2})\b",
        normalized,
    )
    if not date_match:
        date_match = re.search(
            r"\b(\d{1,2}\s+de\s+"
            r"(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|"
            r"septiembre|setiembre|octubre|noviembre|diciembre)"
            r"\s+de\s+\d{4})\b",
            normalized.lower(),
        )

    attendees: list[str] = []
    for idx, line in enumerate(lower_lines):
        if line.startswith("asistentes") or line.startswith("participantes"):
            source = lines[idx]
            part = source.split(":", 1)[1] if ":" in source else source
            for token in re.split(r"[,;]", part):
                value = token.strip()
                if value:
                    attendees.append(value)

    marker_patterns = ("acuerdo", "compromiso", "pendiente", "tarea", "responsable")
    agreements = [line for line in lines if any(tag in line.lower() for tag in marker_patterns)][:8]

    next_steps = [
        line
        for line in lines
        if any(tag in line.lower() for tag in ("siguiente", "proxima", "pr\u00f3xima", "fecha compromiso"))
    ][:6]

    key_points = [line for line in lines if len(line) > 12][:8]

    return OcrDetectedSummary(
        date=date_match.group(1) if date_match else None,
        attendees=attendees,
        agreements=agreements,
        next_steps=next_steps,
        key_points=key_points,
    )


@router.post("/extract", response_model=OcrExtractResponse)
async def extract_minuta_text(
    file: UploadFile = File(...),
    max_pages: int = Form(8),
    _user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    file_name = (file.filename or "archivo").strip() or "archivo"
    suffix = Path(file_name).suffix.lower()
    content_type = (file.content_type or "").lower()
    raw = await file.read()

    if not raw:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty")
    if len(raw) > _MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File too large (max 20MB)",
        )

    max_pages = max(1, min(max_pages, 25))

    is_pdf = suffix == ".pdf" or content_type == "application/pdf"
    is_image = suffix in _SUPPORTED_IMAGE_EXT or content_type.startswith("image/")

    if not is_pdf and not is_image:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF and image files are supported",
        )

    text = ""
    extraction_mode = ""
    source_type = "pdf" if is_pdf else "image"

    if is_pdf:
        native_text = _extract_pdf_text_native(raw)
        if len(native_text.strip()) >= 120:
            text = native_text
            extraction_mode = "pdf_text"
        else:
            ocr_text = _ocr_pdf_pages(raw, max_pages=max_pages)
            merged = "\n\n".join(part for part in [native_text, ocr_text] if part.strip())
            text = _normalize_text(merged)
            extraction_mode = "pdf_scanned_ocr"
    else:
        text = _ocr_image(raw)
        extraction_mode = "image_ocr"

    if not text.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No readable text found in file",
        )

    detected = _detect_summary(text)
    return OcrExtractResponse(
        source_file_name=file_name,
        source_type=source_type,
        extraction_mode=extraction_mode,
        text=text,
        text_length=len(text),
        detected=detected,
    )


@router.post("/link", response_model=OcrLinkResponse)
def link_minuta_to_entity(
    body: OcrLinkRequest,
    current_user: Any = Depends(require_any_role(["ADMIN", "COORD", "SUPERVISOR", "OPERATIVO"])),
):
    now = datetime.now(timezone.utc)
    minute_id = str(uuid4())
    reviewed_text = (body.reviewed_text or "").strip() or body.extracted_text.strip()
    linked_to = (
        (body.activity_id or "").strip()
        or (body.assistant_id or "").strip()
        or (body.assistant_name or "").strip()
    )

    details = {
        "project_id": (body.project_id or "").strip() or None,
        "activity_id": (body.activity_id or "").strip() or None,
        "assistant_id": (body.assistant_id or "").strip() or None,
        "assistant_name": (body.assistant_name or "").strip() or None,
        "source_file_name": (body.source_file_name or "").strip() or None,
        "text_length": len(reviewed_text),
        "preview": reviewed_text[:500],
        "extracted_fields": body.extracted_fields or {},
    }

    client = get_firestore_client()
    client.collection("ocr_minutes").document(minute_id).set(
        {
            "id": minute_id,
            "created_at": now,
            "actor_id": str(getattr(current_user, "id", "")),
            "actor_email": getattr(current_user, "email", ""),
            "project_id": details["project_id"],
            "activity_id": details["activity_id"],
            "assistant_id": details["assistant_id"],
            "assistant_name": details["assistant_name"],
            "source_file_name": details["source_file_name"],
            "reviewed_text": reviewed_text,
            "extracted_fields": details["extracted_fields"],
        }
    )
    write_firestore_audit_log(
        action="OCR_MINUTE_LINKED",
        entity="ocr_minute",
        entity_id=minute_id,
        actor=current_user,
        details=details,
    )

    return OcrLinkResponse(
        record_id=minute_id,
        linked_to=linked_to,
        message="Minuta OCR vinculada correctamente",
    )

