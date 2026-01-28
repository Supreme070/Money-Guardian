"""Celery application configuration."""

from celery import Celery

from app.core.config import settings

# Create Celery app
celery_app = Celery(
    "money_guardian",
    broker=str(settings.redis_url),
    backend=str(settings.redis_url),
    include=[
        "app.tasks.banking_tasks",
        "app.tasks.email_tasks",
        "app.tasks.notification_tasks",
    ],
)

# Celery configuration
celery_app.conf.update(
    # Task settings
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    # Task execution
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
    # Result backend
    result_expires=3600,  # 1 hour
    # Retry settings
    task_default_retry_delay=60,  # 1 minute
    task_max_retries=3,
)

# Beat schedule for periodic tasks
celery_app.conf.beat_schedule = {
    # Sync bank transactions every 4 hours
    "sync-all-bank-transactions": {
        "task": "app.tasks.banking_tasks.sync_all_transactions",
        "schedule": 4 * 60 * 60,  # 4 hours
    },
    # Refresh bank balances every hour
    "refresh-all-bank-balances": {
        "task": "app.tasks.banking_tasks.refresh_all_balances",
        "schedule": 60 * 60,  # 1 hour
    },
    # Scan emails for subscriptions daily
    "scan-all-emails": {
        "task": "app.tasks.email_tasks.scan_all_email_connections",
        "schedule": 24 * 60 * 60,  # 24 hours
    },
    # Send upcoming charge notifications daily at 8 AM (checked hourly)
    "send-upcoming-charge-notifications": {
        "task": "app.tasks.notification_tasks.send_upcoming_charge_notifications",
        "schedule": 6 * 60 * 60,  # Every 6 hours
    },
    # Check for overdraft risks daily
    "send-overdraft-warnings": {
        "task": "app.tasks.notification_tasks.send_overdraft_warnings",
        "schedule": 12 * 60 * 60,  # Every 12 hours
    },
}
