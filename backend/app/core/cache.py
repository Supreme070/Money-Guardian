"""Redis cache-aside utility for Money Guardian.

Provides get/set/delete operations with key prefixing and TTL support.
Uses the same redis.asyncio pattern as token_blacklist.py.
"""

import logging
from typing import Final

import orjson
import redis.asyncio as redis

from app.core.config import settings

logger = logging.getLogger(__name__)

_CACHE_PREFIX: Final[str] = "mg:cache:"

# Lazy-initialized Redis pool (shared with application)
_redis_pool: redis.Redis | None = None


def _get_redis() -> redis.Redis:
    """Get or create the async Redis connection pool for caching."""
    global _redis_pool
    if _redis_pool is None:
        _redis_pool = redis.from_url(
            str(settings.redis_url),
            decode_responses=False,  # We handle encoding via orjson
        )
    return _redis_pool


async def cache_get(key: str) -> bytes | None:
    """Get a cached value by key. Returns None on miss or Redis error.

    Fail-open: any error (Redis down, event loop issues in tests, etc.)
    returns None so the caller falls through to the database.
    """
    try:
        r = _get_redis()
        result: bytes | None = await r.get(f"{_CACHE_PREFIX}{key}")
        return result
    except Exception as e:
        logger.warning("Cache GET failed for key=%s: %s", key, e)
        return None


async def cache_set(key: str, value: object, ttl: int) -> None:
    """Set a cache value with TTL in seconds. Serializes via orjson.

    Fail-open: silently drops writes when Redis is unavailable.
    """
    try:
        r = _get_redis()
        data = orjson.dumps(value)
        await r.setex(f"{_CACHE_PREFIX}{key}", ttl, data)
    except Exception as e:
        logger.warning("Cache SET failed for key=%s: %s", key, e)


async def cache_delete(key: str) -> None:
    """Delete a single cache key. Fail-open on errors."""
    try:
        r = _get_redis()
        await r.delete(f"{_CACHE_PREFIX}{key}")
    except Exception as e:
        logger.warning("Cache DELETE failed for key=%s: %s", key, e)


async def cache_delete_pattern(pattern: str) -> None:
    """Delete all cache keys matching a pattern (e.g., 'pulse:tenant_id:*').

    Fail-open on errors.
    """
    try:
        r = _get_redis()
        full_pattern = f"{_CACHE_PREFIX}{pattern}"
        cursor: int = 0
        while True:
            cursor, keys = await r.scan(cursor, match=full_pattern, count=100)
            if keys:
                await r.delete(*keys)
            if cursor == 0:
                break
    except Exception as e:
        logger.warning("Cache DELETE PATTERN failed for pattern=%s: %s", pattern, e)


def _reset_pool() -> None:
    """Reset the pool reference so the next call creates a fresh connection."""
    global _redis_pool
    _redis_pool = None


async def close_cache_pool() -> None:
    """Close the Redis cache connection pool on shutdown."""
    global _redis_pool
    if _redis_pool is not None:
        try:
            await _redis_pool.aclose()
        except Exception:
            pass
        _redis_pool = None
