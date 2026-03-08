"""Redis-based deduplication for webhooks and background tasks.

Provides a simple check-and-set pattern to prevent duplicate processing.
Mirrors the proven pattern from notification_tasks.py.

Fail-open: if Redis is unavailable, duplicates are allowed rather than
blocking legitimate requests. Database-level constraints provide a
secondary layer of protection.
"""

import logging

import redis.asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger(__name__)

_DEFAULT_TTL = 86_400  # 24 hours


async def is_duplicate(
    key: str,
    *,
    prefix: str = "mg:dedup:",
    ttl: int = _DEFAULT_TTL,
) -> bool:
    """Check if a key was already processed. If not, mark it as processed.

    Uses Redis SETNX (set-if-not-exists) for atomic check-and-set.

    Args:
        key: Unique identifier for the operation (e.g., event ID).
        prefix: Redis key prefix for namespacing.
        ttl: Time-to-live in seconds for the dedup entry.

    Returns:
        True if this key was already processed (duplicate).
        False if this is the first time (not a duplicate).
    """
    full_key = f"{prefix}{key}"
    try:
        r = aioredis.from_url(str(settings.redis_url), decode_responses=True)
        try:
            # SETNX returns True if key was set (first time), False if exists
            was_set: bool = await r.set(full_key, "1", ex=ttl, nx=True)
            return not was_set  # True = duplicate (key already existed)
        finally:
            await r.aclose()
    except Exception as e:
        logger.warning("Dedup check failed for key=%s: %s", full_key, e)
        # Fail open: allow processing if Redis is down
        return False


async def mark_processed(
    key: str,
    *,
    prefix: str = "mg:dedup:",
    ttl: int = _DEFAULT_TTL,
) -> None:
    """Explicitly mark a key as processed.

    Use this when you want to mark after successful processing rather than
    at check time (e.g., for Stripe webhooks where you check first, then
    mark after the handler completes).

    Args:
        key: Unique identifier for the operation.
        prefix: Redis key prefix for namespacing.
        ttl: Time-to-live in seconds.
    """
    full_key = f"{prefix}{key}"
    try:
        r = aioredis.from_url(str(settings.redis_url), decode_responses=True)
        try:
            await r.setex(full_key, ttl, "1")
        finally:
            await r.aclose()
    except Exception as e:
        logger.warning("Dedup mark failed for key=%s: %s", full_key, e)
