"""Tests para el incremento atómico de sync_version en assignments (Bug V).

Verifica que _next_project_sync_version:
- Usa firestore.Increment en lugar de READ-THEN-WRITE
- Devuelve el valor guardado en el documento contador
- Hace fallback al escaneo de actividades si el contador falla
- Devuelve 1 si project_id está vacío
"""

import os

os.environ.setdefault("DATA_BACKEND", "firestore")
os.environ.setdefault("JWT_SECRET", "test-secret-for-ci-tests-minimum32chars!")
os.environ.setdefault("FIRESTORE_PROJECT_ID", "test-project")
os.environ.setdefault("GCS_BUCKET", "test-bucket")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:3000")

from types import SimpleNamespace
from unittest.mock import MagicMock, call

import pytest

from app.api.v1.assignments import _next_project_sync_version
from google.cloud.firestore_v1 import Increment as FSIncrement


# ── Helpers ─────────────────────────────────────────────────────────────────


class _FakeCounterRef:
    """Simula un document reference del contador de sync_version."""

    def __init__(self, current_value: int):
        self._value = current_value
        self.set_calls: list[dict] = []

    def set(self, data: dict, merge: bool = False):
        # Simular Increment: sumamos 1 al valor almacenado
        increment_val = None
        if "sync_version" in data:
            inc = data["sync_version"]
            if isinstance(inc, FSIncrement):
                increment_val = inc._value  # atributo interno del Increment
            elif isinstance(inc, int):
                increment_val = inc
        if increment_val is not None:
            self._value += increment_val
        self.set_calls.append({"data": data, "merge": merge})

    def get(self):
        snap = SimpleNamespace()
        snap.to_dict = lambda: {"sync_version": self._value}
        return snap


class _FakeCounterCollection:
    def __init__(self, refs: dict):
        self._refs = refs

    def document(self, doc_id: str):
        if doc_id not in self._refs:
            self._refs[doc_id] = _FakeCounterRef(0)
        return self._refs[doc_id]


class _FakeActivityCollection:
    def __init__(self, items: list[dict]):
        self._items = items

    def where(self, *a, **kw):
        return self

    def order_by(self, *a, **kw):
        return self

    def limit(self, n):
        return self

    def stream(self):
        docs = []
        for item in self._items:
            doc = SimpleNamespace()
            doc.to_dict = lambda i=item: dict(i)
            docs.append(doc)
        return iter(docs)


class _FakeClient:
    def __init__(self, counter_refs: dict | None = None, activity_items: list | None = None):
        self._counter_refs = counter_refs or {}
        self._activity_items = activity_items or []

    def collection(self, name: str):
        if name == "project_sync_counters":
            return _FakeCounterCollection(self._counter_refs)
        if name == "activities":
            return _FakeActivityCollection(self._activity_items)
        return _FakeActivityCollection([])


# ── Tests ────────────────────────────────────────────────────────────────────


def test_empty_project_id_returns_one():
    """Sin project_id no se hace consulta alguna y devuelve 1."""
    client = _FakeClient()
    assert _next_project_sync_version(client, "") == 1
    assert _next_project_sync_version(client, "  ") == 1
    assert _next_project_sync_version(client, None) == 1


def test_first_call_increments_from_zero_to_one():
    """El primer increment sobre un contador en 0 devuelve 1."""
    client = _FakeClient(counter_refs={"PROJ1": _FakeCounterRef(0)})
    result = _next_project_sync_version(client, "PROJ1")
    assert result == 1


def test_subsequent_calls_return_increasing_values():
    """Llamadas sucesivas devuelven versiones crecientes."""
    counter = _FakeCounterRef(5)
    client = _FakeClient(counter_refs={"PROJ1": counter})
    result = _next_project_sync_version(client, "PROJ1")
    assert result == 6


def test_project_id_is_normalized_uppercase():
    """El project_id en minúsculas debe usarse como UPPERCASE para el contador."""
    counter = _FakeCounterRef(0)
    client = _FakeClient(counter_refs={"PROJ-X": counter})
    result = _next_project_sync_version(client, "proj-x")
    assert result == 1
    assert counter._value == 1  # se incrementó el contador PROJ-X


def test_uses_increment_transform_not_read_first():
    """El SET debe contener un FSIncrement, no un valor leído previamente."""
    counter = _FakeCounterRef(10)
    client = _FakeClient(counter_refs={"PROJ1": counter})
    _next_project_sync_version(client, "PROJ1")
    # Verificar que la llamada a set() usó FSIncrement
    assert len(counter.set_calls) == 1
    data_written = counter.set_calls[0]["data"]
    assert "sync_version" in data_written
    assert isinstance(data_written["sync_version"], FSIncrement), (
        "El valor enviado al contador debe ser FSIncrement, no un int leído"
    )


def test_fallback_to_activity_scan_on_counter_error(monkeypatch):
    """Si el contador falla, se escanean las actividades para el max sync_version."""

    class _ErrorRef:
        def set(self, data, merge=False):
            raise RuntimeError("Firestore counter unavailable")

        def get(self):
            raise RuntimeError("Firestore counter unavailable")

    class _ErrorCounterCol:
        def document(self, doc_id):
            return _ErrorRef()

    class _ClientWithError:
        def collection(self, name):
            if name == "project_sync_counters":
                return _ErrorCounterCol()
            return _FakeActivityCollection([
                {"sync_version": 7, "project_id": "PROJ1"},
                {"sync_version": 3, "project_id": "PROJ1"},
            ])

    result = _next_project_sync_version(_ClientWithError(), "PROJ1")
    assert result == 8  # max(7,3) + 1


def test_fallback_returns_one_when_no_activities(monkeypatch):
    """Si el contador falla y no hay actividades, devuelve 1."""

    class _ErrorRef:
        def set(self, data, merge=False):
            raise RuntimeError("Firestore counter unavailable")

        def get(self):
            raise RuntimeError("Firestore counter unavailable")

    class _ErrorCounterCol:
        def document(self, doc_id):
            return _ErrorRef()

    class _ClientEmpty:
        def collection(self, name):
            if name == "project_sync_counters":
                return _ErrorCounterCol()
            return _FakeActivityCollection([])

    result = _next_project_sync_version(_ClientEmpty(), "PROJ2")
    assert result == 1
