"""Simple in-memory rate limiting helpers."""

from __future__ import annotations

import hashlib
import logging
import math
import threading
import time
from collections import defaultdict, deque
from datetime import datetime, timezone
from typing import Deque

from fastapi import HTTPException, Request, status
from google.cloud.firestore import transactional

from app.core.config import settings
from app.core.firestore import get_firestore_client

logger = logging.getLogger(__name__)


class InMemoryRateLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, Deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def consume(self, key: str, limit: int, window_seconds: int) -> float | None:
        if limit <= 0:
            return None

        now = time.time()
        with self._lock:
            bucket = self._hits[key]
            threshold = now - window_seconds
            while bucket and bucket[0] <= threshold:
                bucket.popleft()

            if len(bucket) >= limit:
                retry_after = (bucket[0] + window_seconds) - now
                return max(retry_after, 0.0)

            bucket.append(now)
            return None

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()


rate_limiter = InMemoryRateLimiter()


def _client_id(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        client = forwarded_for.split(",")[0].strip()
        if client:
            return client

    if request.client and request.client.host:
        return request.client.host

    return "unknown"


def _bucket_window(now: float, window_seconds: int) -> tuple[int, int]:
    window_start = int(now // window_seconds) * window_seconds
    return window_start, window_start + window_seconds


def _shared_rate_limit_key(scope: str, client_key: str, window_start: int) -> str:
    digest = hashlib.sha256(f"{scope}:{client_key}:{window_start}".encode("utf-8")).hexdigest()
    return f"{window_start}:{digest}"


def _shared_consume(client_key: str, *, scope: str, limit: int, window_seconds: int) -> float | None:
    now = time.time()
    window_start, window_end = _bucket_window(now, window_seconds)
    collection = get_firestore_client().collection("rate_limits")
    doc_ref = collection.document(_shared_rate_limit_key(scope, client_key, window_start))
    transaction = get_firestore_client().transaction()

    @transactional
    def _consume_in_transaction(txn):
        snapshot = doc_ref.get(transaction=txn)
        current_count = 0
        if snapshot.exists:
            current_count = int((snapshot.to_dict() or {}).get("count") or 0)
        if current_count >= limit:
            return max(window_end - now, 0.0)

        txn.set(
            doc_ref,
            {
                "scope": scope,
                "client_key_hash": hashlib.sha256(client_key.encode("utf-8")).hexdigest(),
                "count": current_count + 1,
                "window_start": datetime.fromtimestamp(window_start, tz=timezone.utc),
                "expires_at": datetime.fromtimestamp(window_end, tz=timezone.utc),
                "updated_at": datetime.now(timezone.utc),
            },
            merge=True,
        )
        return None

    try:
        return _consume_in_transaction(transaction)
    except Exception:
        logger.warning("Shared rate limiter fallback to in-memory storage", exc_info=True)
        return None


def enforce_rate_limit(
    request: Request,
    *,
    scope: str,
    limit: int,
    window_seconds: int,
    identifier: str | None = None,
) -> None:
    client_key = _client_id(request)
    if identifier:
        client_key = f"{client_key}:{identifier.strip().lower()}"

    retry_after = None
    if settings.FIRESTORE_PROJECT_ID:
        retry_after = _shared_consume(
            client_key,
            scope=scope,
            limit=limit,
            window_seconds=window_seconds,
        )
    if retry_after is None:
        key = f"{scope}:{client_key}"
        retry_after = rate_limiter.consume(key, limit=limit, window_seconds=window_seconds)
    if retry_after is None:
        return

    retry_after_seconds = max(1, math.ceil(retry_after))
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail="Rate limit exceeded. Please retry later.",
        headers={"Retry-After": str(retry_after_seconds)},
    )
