"""Simple in-memory rate limiting helpers."""

from __future__ import annotations

import math
import threading
import time
from collections import defaultdict, deque
from typing import Deque

from fastapi import HTTPException, Request, status


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


def enforce_rate_limit(request: Request, *, scope: str, limit: int, window_seconds: int) -> None:
    key = f"{scope}:{_client_id(request)}"
    retry_after = rate_limiter.consume(key, limit=limit, window_seconds=window_seconds)
    if retry_after is None:
        return

    retry_after_seconds = max(1, math.ceil(retry_after))
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail="Rate limit exceeded. Please retry later.",
        headers={"Retry-After": str(retry_after_seconds)},
    )
