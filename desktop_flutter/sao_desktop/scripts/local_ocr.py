import argparse
import io
import json
import logging
import os
import re
import sys
from pathlib import Path

# Suppress onnxruntime / OpenCV verbose output that can fill the stderr pipe.
os.environ.setdefault("ORT_LOGGING_LEVEL", "3")  # ERROR only
logging.getLogger("onnxruntime").setLevel(logging.ERROR)


MAX_UPLOAD_BYTES = 20 * 1024 * 1024
MAX_TEXT_CHARS = 120_000
SUPPORTED_IMAGE_EXT = {".png", ".jpg", ".jpeg", ".bmp", ".webp", ".tiff", ".tif"}


def normalize_text(text: str) -> str:
    lines = [line.strip() for line in text.splitlines()]
    compact = [line for line in lines if line]
    return "\n".join(compact)


def extract_pdf_text_native(raw_bytes: bytes) -> str:
    from pypdf import PdfReader

    reader = PdfReader(io.BytesIO(raw_bytes))
    chunks: list[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        if text.strip():
            chunks.append(text)
    return normalize_text("\n".join(chunks))


def extract_lines_from_rapidocr_result(result: object) -> list[str]:
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


def ocr_from_pil_images(images: list[object]) -> str:
    import numpy as np
    from rapidocr_onnxruntime import RapidOCR

    engine = RapidOCR()
    chunks: list[str] = []

    for image in images:
        ocr_result, _ = engine(np.array(image))
        lines = extract_lines_from_rapidocr_result(ocr_result)
        if lines:
            chunks.append("\n".join(lines))

    return normalize_text("\n\n".join(chunks))


def ocr_pdf_pages(raw_bytes: bytes, max_pages: int) -> str:
    import pypdfium2 as pdfium

    doc = pdfium.PdfDocument(raw_bytes)
    page_count = len(doc)
    pages_to_process = min(max(page_count, 0), max_pages)
    pil_images = []

    for idx in range(pages_to_process):
        page = doc[idx]
        bitmap = page.render(scale=2)
        pil_images.append(bitmap.to_pil())

    return ocr_from_pil_images(pil_images)


def ocr_image(raw_bytes: bytes) -> str:
    from PIL import Image

    image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    return ocr_from_pil_images([image])


def detect_summary(text: str) -> dict:
    normalized = normalize_text(text)
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
        if any(tag in line.lower() for tag in ("siguiente", "proxima", "prxima", "fecha compromiso"))
    ][:6]

    key_points = [line for line in lines if len(line) > 12][:8]

    return {
        "date": date_match.group(1) if date_match else None,
        "attendees": attendees,
        "agreements": agreements,
        "next_steps": next_steps,
        "key_points": key_points,
    }


def truncate_text(text: str, max_chars: int = MAX_TEXT_CHARS) -> tuple[str, bool]:
    if len(text) <= max_chars:
        return text, False
    return text[:max_chars], True


def run_local_ocr(file_path: str, max_pages: int) -> dict:
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"No existe archivo: {file_path}")

    raw = path.read_bytes()
    if not raw:
        raise ValueError("El archivo esta vacio")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise ValueError("Archivo demasiado grande (max 20MB)")

    suffix = path.suffix.lower()
    is_pdf = suffix == ".pdf"
    is_image = suffix in SUPPORTED_IMAGE_EXT

    if not is_pdf and not is_image:
        raise ValueError("Solo se soportan PDF e imagenes")

    source_type = "pdf" if is_pdf else "image"
    extraction_mode = ""
    text = ""

    max_pages = max(1, min(max_pages, 25))

    if is_pdf:
        native_text = extract_pdf_text_native(raw)
        if len(native_text.strip()) >= 120:
            text = native_text
            extraction_mode = "pdf_text"
        else:
            ocr_text = ocr_pdf_pages(raw, max_pages=max_pages)
            merged = "\n\n".join(part for part in [native_text, ocr_text] if part.strip())
            text = normalize_text(merged)
            extraction_mode = "pdf_scanned_ocr"
    else:
        text = ocr_image(raw)
        extraction_mode = "image_ocr"

    if not text.strip():
        raise ValueError("No se encontro texto legible")

    final_text, was_truncated = truncate_text(text)

    return {
        "source_file_name": path.name,
        "source_type": source_type,
        "extraction_mode": extraction_mode,
        "text": final_text,
        "text_length": len(text),
        "output_truncated": was_truncated,
        "detected": detect_summary(final_text),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="SAO local OCR")
    parser.add_argument("--file", required=True, help="Ruta de archivo PDF/imagen")
    parser.add_argument("--max-pages", type=int, default=8, help="Maximo de paginas para OCR PDF")
    parser.add_argument("--output", required=False, default="", help="Ruta archivo JSON de salida (evita pipe stdout)")
    args = parser.parse_args()

    try:
        result = run_local_ocr(args.file, args.max_pages)
        json_text = json.dumps(result, ensure_ascii=False)
        if args.output:
            Path(args.output).write_text(json_text, encoding="utf-8")
        else:
            sys.stdout.write(json_text)
        return 0
    except Exception as exc:
        sys.stderr.write(str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
