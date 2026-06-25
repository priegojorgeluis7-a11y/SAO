"""Simple in-memory cache with TTL for Firestore data.

This module provides a lightweight caching layer to reduce repeated
Firestore reads for frequently accessed data like users and catalogs.
"""

import asyncio
import logging
import time
from collections import OrderedDict
from dataclasses import dataclass, field
from typing import Any, Callable, TypeVar

logger = logging.getLogger(__name__)

T = TypeVar("T")


@dataclass
class CacheEntry:
    """Single cache entry with value and expiration time."""
    value: Any
    expires_at: float


class TTLCache:
    """Thread-safe TTL cache with optional size limit.
    
    Automatically evicts expired entries and optionally enforces
    a maximum size using LRU eviction.
    """
    
    def __init__(self, default_ttl_seconds: float = 60.0, max_size: int = 1000):
        self._cache: OrderedDict[str, CacheEntry] = OrderedDict()
        self._default_ttl = default_ttl_seconds
        self._max_size = max_size
        self._lock = asyncio.Lock() if asyncio.get_event_loop().is_running() else None
        self._sync_lock = False
    
    def _is_expired(self, entry: CacheEntry) -> bool:
        return time.monotonic() >= entry.expires_at
    
    def get(self, key: str) -> Any | None:
        """Get value from cache if not expired."""
        entry = self._cache.get(key)
        if entry is None:
            return None
        if self._is_expired(entry):
            del self._cache[key]
            return None
        # Move to end (LRU)
        self._cache.move_to_end(key)
        return entry.value
    
    def set(self, key: str, value: Any, ttl: float | None = None) -> None:
        """Set value in cache with optional TTL override."""
        if len(self._cache) >= self._max_size:
            # Remove oldest entry
            self._cache.popitem(last=False)
        
        expires_at = time.monotonic() + (ttl if ttl is not None else self._default_ttl)
        self._cache[key] = CacheEntry(value=value, expires_at=expires_at)
        self._cache.move_to_end(key)
    
    def delete(self, key: str) -> bool:
        """Delete key from cache. Returns True if existed."""
        if key in self._cache:
            del self._cache[key]
            return True
        return False
    
    def clear(self) -> int:
        """Clear all entries. Returns count of cleared entries."""
        count = len(self._cache)
        self._cache.clear()
        return count
    
    def cleanup_expired(self) -> int:
        """Remove all expired entries. Returns count of removed entries."""
        removed = 0
        expired_keys = [
            key for key, entry in self._cache.items()
            if self._is_expired(entry)
        ]
        for key in expired_keys:
            del self._cache[key]
            removed += 1
        return removed
    
    def stats(self) -> dict[str, Any]:
        """Return cache statistics."""
        now = time.monotonic()
        expired = sum(1 for e in self._cache.values() if self._is_expired(e))
        return {
            "size": len(self._cache),
            "max_size": self._max_size,
            "expired": expired,
            "ttl_seconds": self._default_ttl,
        }


# Global cache instances with different TTLs for different data types
_users_cache: TTLCache | None = None
_catalogs_cache: TTLCache | None = None
_projects_cache: TTLCache | None = None


def get_users_cache() -> TTLCache:
    """Get or create the users cache (60 second TTL)."""
    global _users_cache
    if _users_cache is None:
        _users_cache = TTLCache(default_ttl_seconds=60.0, max_size=100)
    return _users_cache


def get_catalogs_cache() -> TTLCache:
    """Get or create the catalogs cache (5 minute TTL)."""
    global _catalogs_cache
    if _catalogs_cache is None:
        _catalogs_cache = TTLCache(default_ttl_seconds=300.0, max_size=50)
    return _catalogs_cache


def get_projects_cache() -> TTLCache:
    """Get or create the projects cache (5 minute TTL)."""
    global _projects_cache
    if _projects_cache is None:
        _projects_cache = TTLCache(default_ttl_seconds=300.0, max_size=20)
    return _projects_cache


def cached_query(
    cache: TTLCache,
    key_parts: tuple[str, ...],
    ttl: float | None = None,
) -> Callable[[Callable[..., T]], Callable[..., T]]:
    """Decorator for caching Firestore query results.
    
    Usage:
        @cached_query(get_users_cache(), ("users", "list"))
        def get_users():
            return firestore_get_all_users()
    """
    cache_key = ":".join(str(p) for p in key_parts)
    
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        def wrapper(*args, **kwargs) -> T:
            cached = cache.get(cache_key)
            if cached is not None:
                logger.debug(f"Cache HIT: {cache_key}")
                return cached
            
            logger.debug(f"Cache MISS: {cache_key}")
            result = func(*args, **kwargs)
            cache.set(cache_key, result, ttl=ttl)
            return result
        
        return wrapper
    return decorator


# Sync-safe cache access for non-async contexts
class SyncCache:
    """Synchronous wrapper for TTLCache operations."""
    
    def __init__(self, cache: TTLCache):
        self._cache = cache
    
    def get(self, key: str) -> Any | None:
        return self._cache.get(key)
    
    def set(self, key: str, value: Any, ttl: float | None = None) -> None:
        self._cache.set(key, value, ttl)
    
    def delete(self, key: str) -> bool:
        return self._cache.delete(key)
    
    def invalidate_prefix(self, prefix: str) -> int:
        """Invalidate all keys starting with prefix."""
        removed = 0
        keys_to_remove = [
            k for k in self._cache._cache.keys()
            if k.startswith(prefix)
        ]
        for key in keys_to_remove:
            self._cache.delete(key)
            removed += 1
        return removed


# Global sync cache instances
_users_sync_cache: SyncCache | None = None
_catalogs_sync_cache: SyncCache | None = None
_projects_sync_cache: SyncCache | None = None


def get_users_sync_cache() -> SyncCache:
    global _users_sync_cache
    if _users_sync_cache is None:
        _users_sync_cache = SyncCache(get_users_cache())
    return _users_sync_cache


def get_catalogs_sync_cache() -> SyncCache:
    global _catalogs_sync_cache
    if _catalogs_sync_cache is None:
        _catalogs_sync_cache = SyncCache(get_catalogs_cache())
    return _catalogs_sync_cache


def get_projects_sync_cache() -> SyncCache:
    global _projects_sync_cache
    if _projects_sync_cache is None:
        _projects_sync_cache = SyncCache(get_projects_cache())
    return _projects_sync_cache
