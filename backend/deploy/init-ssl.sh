#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# First-time SSL Certificate Setup — Money Guardian
#
# Prerequisites:
#   - Domain DNS pointing to this server's IP
#   - Port 80 open (UFW configured by setup-server.sh)
#   - No other service on port 80
#
# Usage:
#   bash deploy/init-ssl.sh api.moneyguardian.co admin.moneyguardian.co
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"

# Default domains
DOMAINS="${@:-api.moneyguardian.co admin.moneyguardian.co}"
EMAIL="${CERTBOT_EMAIL:-admin@moneyguardian.co}"

echo "=== SSL Certificate Setup ==="
echo "Domains: $DOMAINS"
echo "Email: $EMAIL"

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
    echo "[1/4] Installing certbot..."
    apt-get update
    apt-get install -y certbot
else
    echo "[1/4] certbot already installed"
fi

# Stop nginx if running (certbot needs port 80)
echo "[2/4] Stopping nginx if running..."
docker compose -f "$BACKEND_DIR/docker-compose.prod.yml" stop nginx 2>/dev/null || true

# Obtain certificate
echo "[3/4] Obtaining SSL certificate..."
DOMAIN_ARGS=""
for domain in $DOMAINS; do
    DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
done

certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    $DOMAIN_ARGS

# Copy certs to project directory for Docker volume mount
echo "[4/4] Setting up certificate directories..."
FIRST_DOMAIN=$(echo "$DOMAINS" | awk '{print $1}')
CERT_DIR="/etc/letsencrypt/live/$FIRST_DOMAIN"

mkdir -p "$BACKEND_DIR/certbot/conf"
ln -sf "$CERT_DIR/fullchain.pem" "$BACKEND_DIR/certbot/conf/fullchain.pem"
ln -sf "$CERT_DIR/privkey.pem" "$BACKEND_DIR/certbot/conf/privkey.pem"

# Create webroot for ACME challenges (used by renewal)
mkdir -p "$BACKEND_DIR/certbot/www"

# Setup auto-renewal cron
echo "[+] Setting up auto-renewal cron..."
CRON_CMD="0 4 * * 1 certbot renew --webroot -w $BACKEND_DIR/certbot/www --post-hook 'docker compose -f $BACKEND_DIR/docker-compose.prod.yml exec nginx nginx -s reload' >> /var/log/certbot-renew.log 2>&1"

# Add cron if not already present
(crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON_CMD") | crontab -

echo ""
echo "=== SSL Setup Complete ==="
echo "Certificates: $CERT_DIR/"
echo "Auto-renewal: Every Monday at 4 AM"
echo ""
echo "Now run: bash deploy/deploy.sh"
