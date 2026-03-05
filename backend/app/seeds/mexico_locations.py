"""Seed helpers for national Mexico states and municipalities catalog."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen

from sqlalchemy.orm import Session

from app.models.location import Location

MX_LOCATIONS_SOURCE_URLS = (
    "https://raw.githubusercontent.com/cisnerosnow/json-estados-municipios-mexico/master/estados-municipios.json",
)

_STATE_ALIASES = {
    "México": "Estado de México",
    "Mexico": "Estado de México",
    "Distrito Federal": "Ciudad de México",
}


def _normalize_state_name(value: str) -> str:
    cleaned = " ".join((value or "").strip().split())
    return _STATE_ALIASES.get(cleaned, cleaned)


def _normalize_municipio_name(value: str) -> str:
    return " ".join((value or "").strip().split())


def _iter_state_municipio_pairs(payload: Any):
    if isinstance(payload, dict):
        for state_name, municipios in payload.items():
            if not isinstance(municipios, list):
                continue
            for municipio in municipios:
                if isinstance(municipio, str):
                    yield state_name, municipio
        return

    if isinstance(payload, list):
        for item in payload:
            if not isinstance(item, dict):
                continue
            state_name = item.get("estado") or item.get("state") or item.get("name")
            municipios = item.get("municipios") or item.get("municipalities")
            if not isinstance(state_name, str) or not isinstance(municipios, list):
                continue
            for municipio in municipios:
                if isinstance(municipio, str):
                    yield state_name, municipio
        return

    raise ValueError("Unsupported Mexico locations dataset format")


def _load_dataset_text() -> str:
    local_file = os.getenv("MX_LOCATIONS_DATA_FILE")
    if local_file:
        file_path = Path(local_file)
        if not file_path.exists() or not file_path.is_file():
            raise FileNotFoundError(f"MX_LOCATIONS_DATA_FILE does not exist: {file_path}")
        return file_path.read_text(encoding="utf-8")

    last_error: Exception | None = None
    for source_url in MX_LOCATIONS_SOURCE_URLS:
        try:
            request = Request(source_url, headers={"User-Agent": "sao-backend-seeder/1.0"})
            with urlopen(request, timeout=30) as response:
                return response.read().decode("utf-8")
        except Exception as exc:  # pragma: no cover - network fallback path
            last_error = exc

    raise RuntimeError("Unable to fetch Mexico locations dataset") from last_error


def seed_mexico_locations_catalog(db: Session) -> tuple[int, int]:
    """Populate national locations catalog (32 states and municipalities)."""
    payload = json.loads(_load_dataset_text())

    existing = {
        (estado, municipio)
        for estado, municipio in db.query(Location.estado, Location.municipio).all()
    }

    inserted = 0
    processed = 0

    for state_name, municipio_name in _iter_state_municipio_pairs(payload):
        estado = _normalize_state_name(state_name)
        municipio = _normalize_municipio_name(municipio_name)
        if not estado or not municipio:
            continue

        processed += 1
        key = (estado, municipio)
        if key in existing:
            continue

        db.add(Location(estado=estado, municipio=municipio))
        existing.add(key)
        inserted += 1

    db.commit()
    return processed, inserted
