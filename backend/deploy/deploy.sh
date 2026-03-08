#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# Deploy Money Guardian — Hetzner Production
#
# Usage:
#   bash deploy/deploy.sh
#
# What this does:
#   1. Pulls latest code
#   2. Builds Docker images
#   3. Runs database migrations
#   4. Starts/restarts services
#   5. Verifies health
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE="docker compose -f $BACKEND_DIR/docker-compose.prod.yml"

echo "=== Deploying Money Guardian ==="
echo "Directory: $BACKEND_DIR"

# 1. Pull latest code
echo "[1/5] Pulling latest code..."
cd "$BACKEND_DIR/.."
git pull origin main

# 2. Build images
echo "[2/5] Building Docker images..."
cd "$BACKEND_DIR"
$COMPOSE build

# 3. Run database migrations
echo "[3/5] Running database migrations..."
$COMPOSE run --rm api alembic upgrade head

# 4. Start/restart services
echo "[4/5] Starting services..."
$COMPOSE up -d

# 5. Health check
echo "[5/5] Verifying deployment..."
echo "Waiting 15 seconds for services to start..."
sleep 15

# Check health endpoint
HEALTH_URL="http://localhost:8000/health/ready"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "=== Deployment Successful ==="
    echo "Health check: OK (HTTP $HTTP_CODE)"
    $COMPOSE ps
else
    echo ""
    echo "=== Deployment WARNING ==="
    echo "Health check returned HTTP $HTTP_CODE"
    echo ""
    echo "API logs (last 30 lines):"
    $COMPOSE logs --tail=30 api
    echo ""
    echo "Check all logs with: $COMPOSE logs -f"
    exit 1
fi
