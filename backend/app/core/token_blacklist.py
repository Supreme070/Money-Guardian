"""Token blacklist using Redis for server-side JWT invalidation.

When a user logs out, their token is added to a Redis set with a TTL
matching the token's remaining lifetime. On every authenticated request,
the token is checked against this blacklist before being accepted.

This ensures that stolen or leaked tokens can be immediately invalidated
without waiting for natural expiry.
"""

import hashlib
import logging
from datetime import datetime, timezone

import redis.asyncio as redis

from app.core.config import settings

logger = logging.getLogger(__name__)

# Prefix for all blacklist keys in Redis
_BLACKLIST_PREFIX = "mg:token_blacklist:"

# Lazy-initialized async Redis connection pool
_redis_pool: redis.Redis | None = None


def _get_redis() -> redis.Redis:
    """Get or create the async Redis connection pool."""
    global _redis_pool
    if _redis_pool is None:
        _redis_pool = redis.from_url(
            str(settings.redis_url),
            decode_responses=True,
        )
    return _redis_pool


def _token_key(token: str) -> str:
    """
    Create a Redis key from a token.

    Uses SHA-256 hash of the token to avoid storing raw JWTs in Redis.
    """
    token_hash = hashlib.sha256(token.encode()).hexdigest()
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
    r = _get_redis()
    key = _token_key(token)

    # Calculate TTL: how many seconds until the token expires naturally
    now = int(datetime.now(timezone.utc).timestamp())
    ttl = expires_at - now

    if ttl <= 0:
        # Token already expired, no need to blacklist
        return

    try:
        await r.setex(key, ttl, "1")
        logger.debug("Token blacklisted with TTL=%d seconds", ttl)
    except redis.RedisError as e:
        # Log but don't fail the logout request if Redis is down.
        # The token will still expire naturally.
        logger.error("Failed to blacklist token in Redis: %s", e)


async def is_token_blacklisted(token: str) -> bool:
    """
    Check if a token has been blacklisted.

    Args:
        token: The raw JWT string to check.

    Returns:
        True if the token is blacklisted, False otherwise.
        Returns False if Redis is unavailable (fail-open for availability).
    """
    r = _get_redis()
    key = _token_key(token)

    try:
        result = await r.exists(key)
        return bool(result)
    except redis.RedisError as e:
        # If Redis is down, allow the request through.
        # The token is still validated by signature + expiry.
        logger.error("Failed to check token blacklist in Redis: %s", e)
        return False


async def close_blacklist_pool() -> None:
    """Close the Redis connection pool on shutdown."""
    global _redis_pool
    if _redis_pool is not None:
        await _redis_pool.aclose()
        _redis_pool = None
