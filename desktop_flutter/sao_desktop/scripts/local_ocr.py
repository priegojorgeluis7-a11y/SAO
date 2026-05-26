from __future__ import annotations

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


def _is_good_quality_text(text: str) -> bool:
    """Return True if native PDF text is readable enough to skip OCR.

    Scanned PDFs sometimes embed garbled glyph data that looks like lots of
    characters but contains almost no real words.  We measure chars-per-word:
    normal Spanish prose is ~4-7 chars/word.  If the ratio exceeds 8 the text
    is too sparse/garbled and we should fall back to pixel-level OCR instead.
    """
    stripped = text.strip()
    if len(stripped) < 120:
        return False
    words = re.findall(r"[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]{3,}", stripped)
    if not words:
        return False
    return (len(stripped) / len(words)) < 8.0


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


def _preprocess_for_ocr(image: object) -> object:
    """Convert to grayscale and boost contrast to improve OCR accuracy."""
    from PIL import Image, ImageEnhance, ImageFilter

    img = image.convert("L")  # grayscale
    img = ImageEnhance.Contrast(img).enhance(2.0)  # increase contrast
    img = img.filter(ImageFilter.SHARPEN)  # sharpen edges
    return img.convert("RGB")  # RapidOCR expects 3-channel


def ocr_from_pil_images(images: list[object]) -> str:
    import numpy as np
    from rapidocr_onnxruntime import RapidOCR

    engine = RapidOCR()
    chunks: list[str] = []

    for image in images:
        processed = _preprocess_for_ocr(image)
        ocr_result, _ = engine(np.array(processed))
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
        bitmap = page.render(scale=4)  # ~288 DPI — significantly better OCR quality
        pil_images.append(bitmap.to_pil())

    return ocr_from_pil_images(pil_images)


def ocr_image(raw_bytes: bytes) -> str:
    from PIL import Image

    image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    return ocr_from_pil_images([image])


_MONTH_NAMES = (
    "enero|febrero|marzo|abril|mayo|junio|julio|agosto|"
    "septiembre|setiembre|octubre|noviembre|diciembre"
)

# Abbreviated/OCR-noise month map (RapidOCR often compresses month names)
_MONTH_OCR_VARIANTS = {
    "ene": "enero", "feb": "febrero", "mar": "marzo", "abr": "abril",
    "may": "mayo",  "jun": "junio",  "jul": "julio", "ago": "agosto",
    "sep": "septiembre", "set": "septiembre", "oct": "octubre",
    "nov": "noviembre",  "dic": "diciembre",
    # common OCR corruptions seen in scanned minutas
    "nuy": "mayo",   # "mayo" read as "Nuy" (m→N, a→u, y→y, o→dropped)
    "muy": "mayo",   # "mayo" read as "Muy6" (a→u, o→6)
    "mcyo": "mayo",  # "mayo" read as "mcyo" (a→c)
    "cayo": "mayo",  # "mayo" read as "cayo"
    "maco": "marzo", # "marzo" read as "maco"
}


def _fix_ocr_date(raw: str) -> str:
    """Attempt to normalise a date string that may contain OCR noise."""
    lower = raw.lower()
    for abbr, full in _MONTH_OCR_VARIANTS.items():
        # Use case-insensitive replacement without strict word boundaries so
        # compact forms like "9denuy6de76" (= "9 de mayo de 2026") are handled.
        lower = re.sub(re.escape(abbr), full, lower, flags=re.IGNORECASE)
    # Common OCR digit-character confusions in year/day positions:
    # 'o'/'O' → '0' between digit-like chars  (2o26 → 2026)
    lower = re.sub(r'(?<=[0-9])[oO](?=[0-9oOgGzZ])', '0', lower)
    lower = re.sub(r'(?<=[oO0])[oO](?=[0-9gGzZ])', '0', lower)
    # 'G'/'g' → '6' after a digit  (202G → 2026)
    lower = re.sub(r'(?<=[0-9])[gG](?=\b|\s|[^a-zA-Z])', '6', lower)
    # 'Z'/'z' at word start followed by digits  (Z026 → 2026)
    lower = re.sub(r'\b[Zz](?=[0-9])', '2', lower)
    # 'I'/'l' before digits that look like '1x' day  (IS → 15, l5 → 15)
    lower = re.sub(r'\b[Il](?=[0-9])', '1', lower)
    return lower


def _try_extract_date(text: str) -> str | None:
    """Return a date string from *text* (after OCR normalisation) or None."""
    fixed = _fix_ocr_date(text)
    # Numeric separator form: DD/MM/YYYY or YYYY-MM-DD
    m = re.search(
        r"\b(\d{1,2}[\/-]\d{1,2}[\/-]\d{2,4}|\d{4}[\/-]\d{1,2}[\/-]\d{1,2})\b",
        fixed,
    )
    if m:
        return m.group(1)
    # Written form (spaces may be absent after OCR): "15demayo2026"
    m = re.search(
        r"(\d{1,2}\s*de\s*(?:" + _MONTH_NAMES + r")\s*(?:de\s*)?\d{4})",
        fixed,
    )
    if m:
        return m.group(1)
    # Loose form: day + (noise) + month + (noise) + year  (handles "mcyo6de76")
    m = re.search(
        r"(\d{1,2}).{0,12}((?:" + _MONTH_NAMES + r")).{0,15}(\d{2,4})",
        fixed,
    )
    if m:
        day, month, year = m.group(1), m.group(2), m.group(3)
        if len(year) == 2:
            year = "20" + year
        return f"{day} de {month} de {year}"
    # Day + month only (year too corrupted): "15 de mayo" — still useful
    m = re.search(
        r"(\d{1,2}).{0,12}((?:" + _MONTH_NAMES + r"))",
        fixed,
    )
    if m:
        return f"{m.group(1)} de {m.group(2)}"
    return None


# Known section headers in canonical display order for structured output.
# Each tuple: (display_label, detection_regex)
_KNOWN_SECTIONS: list[tuple[str, re.Pattern]] = [
    ("INSTITUCIÓN",          re.compile(r"desarrollo\s*territorial", re.I)),
    ("TEMA DE LA REUNIÓN",   re.compile(r"tema\s*(de\s*(la\s*)?)?reuni[oó]n", re.I)),
    ("RESPONSABLE MINUTA",   re.compile(r"responsable\s*(de\s*la?\s*)?minuta", re.I)),
    ("FECHA Y HORA",         re.compile(r"fecha.*hora.*reuni", re.I)),
    ("LUGAR",                re.compile(r"^lugar\s*:?\s*$|^lugar\s*:", re.I)),
    ("EVENTO",               re.compile(r"^evento\s*:?\s*$|^evento\s*:", re.I)),
    ("ORDEN DEL DÍA",        re.compile(r"orden\s*del\s*d[ií]a", re.I)),
    ("ASISTENTES",           re.compile(r"^asistentes\s*:?|^participantes\s*:?", re.I)),
    ("ACTIVIDAD / ACUERDOS", re.compile(r"actividad\s*/?\s*acuerdos?", re.I)),
    ("SIGUIENTES PASOS",     re.compile(r"siguientes?\s*pasos?|pr[oó]xima\s*reuni[oó]n", re.I)),
]

# Lines matching these patterns are section headers and must not be used as
# extracted field values (they appear as blank labeled fields in the form).
_VALUE_BLACKLIST = re.compile(
    r"^(fecha\s*y\s*hora|orden\s*del\s*d[ií]a|asistentes|participantes|"
    r"actividad\s*/?\s*acuerdos?|siguientes?\s*pasos?|nombre\b|dependencia|"
    r"responsable\s*(minuta|de\s*la\s*minuta)?|"
    r"tema\s*(de\s*(la\s*)?)?reuni|^lugar\b|^evento\b|p[aá]gina\s*\d)",
    re.IGNORECASE,
)

# ── Formato de Contacto (Tren San Luis-Saltillo / afectaciones) ──────────────

_KNOWN_SECTIONS_CONTACTO: list[tuple[str, re.Pattern]] = [
    ("ESTADO",              re.compile(r"^estado\s*:", re.I)),
    ("MUNICIPIO",           re.compile(r"^municipio\s*:", re.I)),
    ("PROYECTO",            re.compile(r"^proyecto\s*:", re.I)),
    ("LOCALIDAD/EJIDO",     re.compile(r"^localidad.*ejido|^ejido\s*:", re.I)),
    ("POLÍGONO",            re.compile(r"pol[ií]gono", re.I)),
    ("ENTREVISTADOR",       re.compile(r"nombre\s*del\s*entrevistador", re.I)),
    ("PERSONA QUE ATIENDE", re.compile(r"persona\s*que\s*atiende|nombre\s*de\s*la\s*persona", re.I)),
    ("DUEÑO/POSEEDOR",      re.compile(r"nombre\s*del\s*due[ñn]o|poseedor", re.I)),
    ("TELÉFONO",            re.compile(r"^tel[eé]fono\s*:", re.I)),
    ("INSTRUMENTO",         re.compile(r"instrumento\s*que\s*exhibe", re.I)),
    ("DATOS DEL DOCUMENTO", re.compile(r"datos\s*del\s*documento", re.I)),
    ("OBSERVACIONES",       re.compile(r"^observaciones\s*:?", re.I)),
    ("FIRMA",               re.compile(r"firma\s*(de\s*consentimiento|y?\s*sello)?", re.I)),
]

_VALUE_BLACKLIST_CONTACTO = re.compile(
    r"^(estado\b|municipio\b|proyecto\b|localidad|pol[ií]gono|"
    r"nombre\s*del\s*(entrevistador|due[ñn]o|poseedor|notario)|"
    r"nombre\s*de\s*la\s*persona|tel[eé]fono\b|"
    r"instrumento\s*que\s*exhibe|datos\s*del\s*documento|"
    r"datos\s*de\s*inscripci[oó]n|observaciones\b|"
    r"firma\s*(de|y)|escritura\s*p[uú]blica|documento\s*privado|"
    r"n[uú]mero\s*(de)?\s*notario|acto\b|fecha\b|n[uú]mero\b|"
    r"p[aá]gina\s*\d)",
    re.IGNORECASE,
)


def _detect_document_type(text: str) -> str:
    """Identify whether the document is a SEDATU minuta or a formato de contacto."""
    lower = text.lower()
    if re.search(r"orden\s*del\s*d[ií]a|tema\s*(de\s*(la\s*)?)?reuni[oó]n|actividad\s*/?\s*acuerdos?", lower):
        return "minuta_sedatu"
    if re.search(r"formato\s*de\s*contacto|pol[ií]gono|entrevistador|nombre\s*del\s*due[ñn]o", lower):
        return "formato_contacto"
    return "unknown"


def _is_noise_line(line: str) -> bool:
    """Return True if this line is mostly OCR noise and not useful content."""
    stripped = line.strip()
    if len(stripped) <= 2:
        return True
    alpha = sum(1 for c in stripped if c.isalpha())
    if alpha == 0:
        return True
    # Short lines with <25% alphabetic chars are typically symbol/noise garbage
    if len(stripped) < 40 and alpha / len(stripped) < 0.25:
        return True
    # Lines with many special symbols (backslashes, tildes, Unicode dingbats, etc.)
    special = sum(1 for c in stripped if not c.isalnum() and c not in ' ,.;:!?()/\'\-éíóúáüñÉÍÓÚÁÜÑ')
    if special / len(stripped) > 0.20:
        return True
    # Lines dominated by repeated dashes or tildes (separator/divider garbage)
    if stripped.count('~') >= 3 or stripped.count('-') / max(len(stripped), 1) > 0.30:
        return True
    return False


def _restructure_text(text: str, doc_type: str = "unknown") -> str:
    """Reorganise raw OCR text into labelled sections, filter noise, deduplicate pages."""
    sections = _KNOWN_SECTIONS_CONTACTO if doc_type == "formato_contacto" else _KNOWN_SECTIONS
    lines = normalize_text(text).splitlines()
    section_content: dict[str, list[str]] = {}
    seen_sections: list[str] = []
    current_section: str | None = None

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        matched: str | None = None
        for label, pattern in sections:
            if pattern.search(stripped):
                matched = label
                break

        if matched:
            current_section = matched
            if matched not in section_content:
                section_content[matched] = []
                seen_sections.append(matched)
            # Don't add the header line itself as content
        elif current_section is not None:
            if not _is_noise_line(stripped):
                # For FECHA Y HORA: accumulate lines and try combined date extraction
                if current_section == "FECHA Y HORA":
                    section_content[current_section].append(stripped)
                    # Try to extract date from all accumulated content joined
                    combined = " ".join(section_content[current_section])
                    d = _try_extract_date(combined)
                    if d:
                        # Replace accumulated content with clean date
                        section_content[current_section] = [d]
                elif len(section_content[current_section]) < 10:
                    section_content[current_section].append(stripped)

    if not section_content:
        return text  # fallback: nothing structured detected

    # Reconstruct in canonical order, deduplicating repeated content across pages
    parts: list[str] = []
    canonical_order = [label for label, _ in sections if label in section_content]
    for label in canonical_order:
        parts.append(f"── {label} ──")
        seen: set[str] = set()
        for content_line in section_content[label]:
            key = content_line.lower().strip()
            if key not in seen:
                parts.append(content_line)
                seen.add(key)
        parts.append("")

    return "\n".join(parts).strip()


def _extract_labeled_value(
    lines: list[str],
    label_pattern: str,
    blacklist: re.Pattern | None = None,
) -> str | None:
    """Return the value for a labeled field.

    Looks for a line matching *label_pattern*, then returns either:
    - text after the colon on the same line (if non-empty), or
    - the next non-empty line that doesn't look like another label.
    """
    bl = blacklist if blacklist is not None else _VALUE_BLACKLIST
    for idx, raw_line in enumerate(lines):
        if not re.search(label_pattern, raw_line, re.IGNORECASE):
            continue
        # Value after colon on the same line
        if ":" in raw_line:
            after = raw_line.split(":", 1)[1].strip()
            if (after and len(after) > 1
                    and sum(1 for c in after if c.isalpha()) >= 3
                    and not bl.search(after)):
                return after
        # Value on the next non-empty line (only the immediately next line to
        # avoid crossing into the next form field when the current one is blank)
        for next_line in lines[idx + 1: idx + 2]:
            stripped = next_line.strip()
            if (stripped
                    and len(stripped) >= 4
                    and sum(1 for c in stripped if c.isalpha()) >= 3
                    and not re.search(r"^\w[\w\s]{1,25}:", stripped)
                    and not bl.search(stripped)
                    and not _is_noise_line(stripped)):
                return stripped
        # Stop at first occurrence — don't search page 2/3 repetitions
        return None
    return None


def detect_summary(text: str, doc_type: str = "unknown") -> dict:
    normalized = normalize_text(text)
    lines = normalized.splitlines()
    lower_lines = [line.lower() for line in lines]

    detected_date: str | None = None

    # Pass 1: scan every line for a parseable date
    for raw_line in lines:
        d = _try_extract_date(raw_line)
        if d:
            detected_date = d
            break

    if not detected_date:
        # Pass 2: date may appear on the 1-2 lines AFTER "Fecha y Hora de Reunión"
        # (OCR sometimes splits "15 de" and "mayo de 2026" into separate lines)
        for idx, raw_line in enumerate(lines):
            if re.search(r"fecha.*hora.*reuni", raw_line.lower()) and idx + 1 < len(lines):
                next_line = lines[idx + 1]
                after_next = lines[idx + 2] if idx + 2 < len(lines) else ""
                detected_date = (_try_extract_date(next_line)
                                 or _try_extract_date(next_line + " " + after_next))
                break

    if not detected_date:
        # Pass 3: look inside any "Fecha:" line (skip header variants)
        for raw_line in lines:
            if re.search(r"fecha\s*[yY]?\s*(hora)?\s*[dD]e?\s*[rR]euni", raw_line.lower()):
                continue
            if re.search(r"^fecha", raw_line.lower()):
                detected_date = _try_extract_date(raw_line)
                if detected_date:
                    break

    # ── Formato de Contacto ──────────────────────────────────────────────────
    if doc_type == "formato_contacto":
        bl = _VALUE_BLACKLIST_CONTACTO
        topic = _extract_labeled_value(lines, r"^proyecto\s*:", bl)
        responsible = _extract_labeled_value(lines, r"nombre\s*del\s*entrevistador", bl)
        location = _extract_labeled_value(lines, r"^localidad.*ejido|^ejido\s*:", bl)
        return {
            "date": detected_date,
            "topic": topic,
            "responsible": responsible,
            "location": location,
            "time": None,
            "attendees": [],
            "agreements": [],
            "next_steps": [],
            "key_points": [],
        }

    # ── Minuta SEDATU (y unknown como fallback) ──────────────────────────────────
    # Tema de la reunión
    topic = _extract_labeled_value(lines, r"tema\s*(de\s*(la\s*)?)?reuni")

    # Responsable de minuta
    responsible = _extract_labeled_value(lines, r"responsable\s*(de\s*)?(la\s*)?minuta")

    # Lugar
    location = _extract_labeled_value(lines, r"^lugar\b")

    # Hora — extract HH:MM from lines containing "hora" or standalone time pattern
    detected_time: str | None = None
    for raw_line in lines:
        m = re.search(r"\b(\d{1,2}\s*:\s*\d{2})\b", raw_line)
        if m:
            candidate = m.group(1).replace(" ", "")
            detected_time = candidate
            break

    # ── Attendees: scan NOMBRE/ASISTENTES table rows ─────────────────────────
    _SKIP_ATTENDEE = re.compile(
        r"^(asistentes?|participantes?|se\s+soporta|lista\s+de\s+asistencia|"
        r"nombre(\s*(dependencia|puesto|/)|$)|dependencia\w*|correo\b|"
        r"tel[eé]fono\b|firma\b|puesto\b|cargo\b|p[aá]gina\s*\d)",
        re.IGNORECASE,
    )
    # All-caps institution codes like SEDENA, SDATU, WPZNC, ATPNPI (2-7 uppercase letters/digits)
    _INSTITUTION_CODE = re.compile(r"^[A-ZÁÉÍÓÚÑÜ0-9/\-]{2,8}$")
    attendees: list[str] = []
    in_attendees = False
    for idx, line in enumerate(lower_lines):
        # Trigger on "asistentes/participantes", on "nombre dependencia correo" in one
        # line, or on a standalone "nombre" header (OCR may split columns to own lines).
        if re.search(
            r"^asistentes|^participantes|nombre.*dependencia.*correo|nombre.*puesto",
            line,
        ) or (re.search(r"^nombre\s*$", line) and idx + 1 < len(lower_lines)
              and re.search(r"^dependencia|^correo|^puesto|^firma|^tel", lower_lines[idx + 1])):
            in_attendees = True
            continue
        if in_attendees:
            stripped = lines[idx].strip()
            if re.search(r"actividad\s*/?\s*acuerdos?|siguientes?\s*pasos?|orden\s*del", stripped, re.I):
                in_attendees = False  # reset — don't break, another trigger may come later
                continue
            if not stripped or _SKIP_ATTENDEE.search(stripped) or _is_noise_line(stripped):
                continue
            # Skip all-caps institution abbreviations, emails, pure numbers
            if _INSTITUTION_CODE.match(stripped):
                continue
            if "@" in stripped or stripped.replace(" ", "").isdigit():
                continue
            # Skip short tokens without spaces (OCR fragments with digits or ≤5 chars)
            if " " not in stripped and (any(c.isdigit() for c in stripped) or len(stripped) <= 5):
                continue
            # Skip mostly-uppercase short strings (institution codes with mixed case e.g. "SDAtU")
            alpha_chars = [c for c in stripped if c.isalpha()]
            upper_ratio = sum(1 for c in alpha_chars if c.isupper()) / len(alpha_chars) if alpha_chars else 0
            if upper_ratio > 0.7 and len(stripped.replace(" ", "")) <= 8:
                continue
            # Skip lines with multiple digit-containing tokens (OCR table row noise)
            digit_tokens = [t for t in stripped.split() if any(c.isdigit() for c in t)]
            if len(digit_tokens) > 1:
                continue
            alpha = sum(1 for c in stripped if c.isalpha())
            if alpha >= 4:
                attendees.append(stripped)
            if len(attendees) >= 12:
                break

    # ── Agreements: scan ACTIVIDAD/ACUERDOS section content ──────────────────
    _SKIP_AGREEMENT = re.compile(
        r"^(responsable\s*(minuta|\(s\)|de\s*la\s*minuta)?|"
        r"actividad\s*/?\s*acuerdos?|"
        r"fecha\s*,?\s*de(\s+(solicitud|compromiso))?|avance\b|"
        r"compromisol?\b|solicitud\b|nombre\b|dependencia\b|"
        r"correo\b|tel[eé]fono\b|firma\b|p[aá]gina\s*\d|"
        r"se\s+soporta|lista\s+de\s+asistencia)",
        re.IGNORECASE,
    )
    agreements: list[str] = []
    in_agreements = False
    for idx, line in enumerate(lower_lines):
        if re.search(r"actividad\s*/?\s*acuerdos?", line) and not in_agreements:
            in_agreements = True
            continue
        if in_agreements:
            stripped = lines[idx].strip()
            if re.search(r"siguientes?\s*pasos?|pr[oó]xima\s*reuni[oó]n|p[aá]gina\s*\d|nombre.*dependencia", stripped, re.I):
                break
            if not stripped or _SKIP_AGREEMENT.search(stripped) or _is_noise_line(stripped):
                continue
            alpha = sum(1 for c in stripped if c.isalpha())
            if alpha >= 4:
                agreements.append(stripped)
            if len(agreements) >= 10:
                break

    next_steps = [
        line
        for line in lines
        if any(tag in line.lower() for tag in ("siguiente paso", "proxima reunion", "prxima reunion"))
        and not _VALUE_BLACKLIST.search(line)
    ][:6]

    key_points = [
        line for line in lines
        if len(line) > 15 and not _VALUE_BLACKLIST.search(line) and not _is_noise_line(line)
    ][:6]

    return {
        "date": detected_date,
        "topic": topic,
        "responsible": responsible,
        "location": location,
        "time": detected_time,
        "attendees": attendees,
        "agreements": agreements,
        "next_steps": next_steps,
        "key_points": key_points,
    }


def truncate_text(text: str, max_chars: int = MAX_TEXT_CHARS) -> tuple[str, bool]:
    if len(text) <= max_chars:
        return text, False
    return text[:max_chars], True


def run_local_ocr(file_path: str, max_pages: int, force_ocr: bool = False) -> dict:
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
        if not force_ocr and _is_good_quality_text(native_text):
            text = native_text
            extraction_mode = "pdf_text"
        else:
            ocr_text = ocr_pdf_pages(raw, max_pages=max_pages)
            # Merge: OCR output is primary; append any native text that was readable
            parts = [ocr_text]
            if native_text.strip() and not _is_good_quality_text(native_text) and len(native_text.strip()) >= 120:
                # Keep native text as supplementary context even when low quality
                parts.append(native_text)
            text = normalize_text("\n\n".join(p for p in parts if p.strip()))
            extraction_mode = "pdf_scanned_ocr" + ("_forced" if force_ocr else "")
    else:
        text = ocr_image(raw)
        extraction_mode = "image_ocr"

    if not text.strip():
        raise ValueError("No se encontro texto legible")

    final_text, was_truncated = truncate_text(text)
    doc_type = _detect_document_type(final_text)
    structured = _restructure_text(final_text, doc_type=doc_type)

    return {
        "source_file_name": path.name,
        "source_type": source_type,
        "extraction_mode": extraction_mode,
        "text": final_text,
        "structured_text": structured,
        "doc_type": doc_type,
        "text_length": len(text),
        "output_truncated": was_truncated,
        "detected": detect_summary(final_text, doc_type=doc_type),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="SAO local OCR")
    parser.add_argument("--file", required=True, help="Ruta de archivo PDF/imagen")
    parser.add_argument("--max-pages", type=int, default=8, help="Maximo de paginas para OCR PDF")
    parser.add_argument("--output", required=False, default="", help="Ruta archivo JSON de salida (evita pipe stdout)")
    parser.add_argument("--force-ocr", action="store_true", help="Forzar OCR aunque el PDF tenga texto nativo")
    args = parser.parse_args()

    try:
        result = run_local_ocr(args.file, args.max_pages, force_ocr=args.force_ocr)
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
