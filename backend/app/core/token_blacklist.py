"""Token blacklist using Redis for server-side JWT invalidation.

When a user logs out, their token is added to a Redis set with a TTL
matching the token's remaining lifetime. On every authenticated request,
the token is checked against this blacklist before being accepted.

This ensures that stolen or leaked tokens can be immediately invalidated
without waiting for natural expiry.

Fail-closed: if Redis is down and the in-memory cache has no info,
the request is rejected with HTTP 503 rather than allowed through.
"""

import hashlib
import logging
import threading
from collections import OrderedDict
from datetime import datetime, timezone

import redis.asyncio as redis
from fastapi import HTTPException, status

from app.core.config import settings

logger = logging.getLogger(__name__)

# Prefix for all blacklist keys in Redis
_BLACKLIST_PREFIX = "mg:token_blacklist:"

# Lazy-initialized async Redis connection pool
_redis_pool: redis.Redis | None = None

# ---------------------------------------------------------------------------
# In-memory LRU cache fallback for when Redis is unavailable
# ---------------------------------------------------------------------------

_CACHE_MAX_SIZE = 10_000

_cache_lock = threading.Lock()


class _LRUBlacklistCache:
    """Thread-safe in-memory LRU cache of blacklisted token hashes.

    Stores token_hash -> expiry_timestamp so entries can be evicted
    once the underlying JWT would have expired naturally.
    """

    def __init__(self, max_size: int = _CACHE_MAX_SIZE) -> None:
        self._max_size = max_size
        self._store: OrderedDict[str, int] = OrderedDict()

    def add(self, token_hash: str, expires_at: int) -> None:
        with _cache_lock:
            if token_hash in self._store:
                self._store.move_to_end(token_hash)
                self._store[token_hash] = expires_at
            else:
                self._store[token_hash] = expires_at
                if len(self._store) > self._max_size:
                    self._store.popitem(last=False)

    def contains(self, token_hash: str) -> bool | None:
        """Check if a token hash is in the cache.

        Returns True if blacklisted, False if explicitly not blacklisted
        (we don't track non-blacklisted tokens), or None if we have
        no information about this token.
        """
        with _cache_lock:
            if token_hash in self._store:
                exp = self._store[token_hash]
                now = int(datetime.now(timezone.utc).timestamp())
                if now >= exp:
                    # Token expired naturally, remove from cache
                    del self._store[token_hash]
                    return None
                self._store.move_to_end(token_hash)
                return True
            return None

    def clear(self) -> None:
        with _cache_lock:
            self._store.clear()


_memory_cache = _LRUBlacklistCache()


def _get_redis() -> redis.Redis:
    """Get or create the async Redis connection pool."""
    global _redis_pool
    if _redis_pool is None:
        _redis_pool = redis.from_url(
            str(settings.redis_url),
            decode_responses=True,
        )
    return _redis_pool


def _token_hash(token: str) -> str:
    """Compute SHA-256 hash of the token."""
    return hashlib.sha256(token.encode()).hexdigest()


def _token_key(token_hash: str) -> str:
    """Create a Redis key from a token hash."""
    return f"{_BLACKLIST_PREFIX}{token_hash}"


async def blacklist_token(token: str, expires_at: int) -> None:
    """
    Add a token to the blacklist.

    Args:
        token: The raw JWT string to blacklist.
        expires_at: Unix timestamp when the token naturally expires.
                    The blacklist entry will be auto-removed after this time
                    since expired tokens are rejected anyway.
    """
    now = int(datetime.now(timezone.utc).timestamp())
    ttl = expires_at - now

    if ttl <= 0:
        # Token already expired, no need to blacklist
        return

    th = _token_hash(token)
    key = _token_key(th)

    # Always sync to in-memory cache
    _memory_cache.add(th, expires_at)

    r = _get_redis()
    try:
        await r.setex(key, ttl, "1")
        logger.debug("Token blacklisted with TTL=%d seconds", ttl)
    except redis.RedisError as e:
        # Log but don't fail the logout request if Redis is down.
        # The token is still in the in-memory cache.
        logger.error("Failed to blacklist token in Redis: %s", e)


async def is_token_blacklisted(token: str) -> bool:
    """
    Check if a token has been blacklisted.

    Fail-closed: if Redis is unavailable and the in-memory cache has
    no information about this token, raises HTTP 503 rather than
    allowing the request through.

    Args:
        token: The raw JWT string to check.

    Returns:
        True if the token is blacklisted, False if it is confirmed
        not blacklisted.

    Raises:
        HTTPException(503): If neither Redis nor the in-memory cache
        can confirm the token's status (fail-closed).
    """
    th = _token_hash(token)
    key = _token_key(th)
    r = _get_redis()

    try:
        result = await r.exists(key)
        return bool(result)
    except redis.RedisError as e:
        logger.error("Failed to check token blacklist in Redis: %s", e)

        # Fallback to in-memory cache
        cached = _memory_cache.contains(th)
        if cached is True:
            logger.warning("Redis down - token found in in-memory blacklist cache")
            return True
        if cached is None:
            # Neither Redis nor cache has info - fail closed
            logger.error(
                "Redis unavailable and token not in in-memory cache. "
                "Rejecting request (fail-closed)."
            )
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Authentication service temporarily unavailable",
            )
        # cached is None means no info; we already handled that above.
        # This branch won't be reached, but for clarity:
        return False  # pragma: no cover


async def close_blacklist_pool() -> None:
    """Close the Redis connection pool on shutdown."""
    global _redis_pool
    if _redis_pool is not None:
        await _redis_pool.aclose()
        _redis_pool = None
