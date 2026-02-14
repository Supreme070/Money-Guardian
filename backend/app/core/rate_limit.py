"""Rate limiting configuration.

Separated from main.py to avoid circular imports when endpoint
modules need to reference the limiter instance.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.config import settings

limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.rate_limit_per_minute}/minute"],
    storage_uri=str(settings.redis_url),
)
