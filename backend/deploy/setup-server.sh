#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
# Hetzner CX32 Server Setup — Money Guardian
#
# Run once on a fresh Ubuntu 24.04 server:
#   ssh root@YOUR_IP 'bash -s' < deploy/setup-server.sh
#
# What this does:
#   1. Updates system packages
#   2. Installs Docker CE + Docker Compose plugin
#   3. Creates a non-root user (moneyguardian)
#   4. Configures firewall (UFW)
#   5. Installs fail2ban for SSH protection
#   6. Sets up swap, log rotation, auto-updates
# ────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "=== Money Guardian Server Setup ==="

# 1. System updates
echo "[1/8] Updating system packages..."
apt-get update && apt-get upgrade -y
apt-get install -y curl git ufw fail2ban unattended-upgrades apt-transport-https ca-certificates gnupg lsb-release

# 2. Install Docker
echo "[2/8] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Verify Docker Compose plugin
docker compose version || {
    echo "ERROR: Docker Compose plugin not found"
    exit 1
}

# 3. Create application user
echo "[3/8] Creating moneyguardian user..."
if ! id -u moneyguardian &> /dev/null; then
    useradd -m -s /bin/bash -G docker moneyguardian
    echo "Created user: moneyguardian"
else
    usermod -aG docker moneyguardian
    echo "User moneyguardian already exists, added to docker group"
fi

# 4. Create directory structure
echo "[4/8] Creating directory structure..."
mkdir -p /opt/moneyguardian/{app,backups}
chown -R moneyguardian:moneyguardian /opt/moneyguardian

# 5. Configure firewall
echo "[5/8] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP (for ACME + redirect)
ufw allow 443/tcp  # HTTPS
ufw --force enable
echo "Firewall enabled: SSH (22), HTTP (80), HTTPS (443)"

# 6. Configure fail2ban
echo "[6/8] Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'FAIL2BAN'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
FAIL2BAN
systemctl enable fail2ban
systemctl restart fail2ban

# 7. Setup swap (2GB)
echo "[7/8] Setting up swap..."
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    # Optimize swappiness for a server
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    sysctl -p
    echo "2GB swap created"
else
    echo "Swap already exists"
fi

# 8. Configure unattended security upgrades
echo "[8/8] Enabling auto security updates..."
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AUTOUPGRADE'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
AUTOUPGRADE

# Configure Docker log rotation globally
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKERLOG'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
DOCKERLOG
systemctl restart docker

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Clone your repo:  su - moneyguardian -c 'git clone <repo> /opt/moneyguardian/app'"
echo "  2. Copy env file:    cp .env.production.example /opt/moneyguardian/app/backend/.env"
echo "  3. Edit secrets:     nano /opt/moneyguardian/app/backend/.env"
echo "  4. Get SSL cert:     bash /opt/moneyguardian/app/backend/deploy/init-ssl.sh"
echo "  5. Deploy:           bash /opt/moneyguardian/app/backend/deploy/deploy.sh"
