#!/bin/bash
# GCP Compute Engine Startup Script for sora2api
# This script runs automatically when the VM starts

set -e

# Logging
exec > >(tee /var/log/sora2api-startup.log) 2>&1
echo "=== sora2api Startup Script Started at $(date) ==="

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    echo "Docker installed successfully"
fi

# Create application directory
mkdir -p /opt/sora2api/config
mkdir -p /opt/sora2api/data

# Create docker-compose.yml with WARP sidecar
cat > /opt/sora2api/docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  sora2api:
    image: thesmallhancat/sora2api:latest
    container_name: sora2api
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ./config:/app/config
      - ./data:/app/data
    environment:
      - TZ=Asia/Shanghai
    depends_on:
      warp:
        condition: service_healthy

  warp:
    image: caomingjun/warp:latest
    container_name: warp
    restart: unless-stopped
    ports:
      - "1080:1080"
    environment:
      - WARP_SLEEP=2
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv4.conf.all.src_valid_mark=1
    volumes:
      - ./warp-data:/var/lib/cloudflare-warp
    healthcheck:
      test: ["CMD", "curl", "-f", "--socks5", "localhost:1080", "https://www.cloudflare.com/cdn-cgi/trace"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
COMPOSE_EOF

# Create default config if not exists
if [ ! -f /opt/sora2api/config/setting.toml ]; then
    cat > /opt/sora2api/config/setting.toml << 'CONFIG_EOF'
[global]
api_key = "han1234"
admin_username = "admin"
admin_password = "admin"

[sora]
base_url = "https://sora.chatgpt.com/backend"
timeout = 120
max_retries = 3
poll_interval = 2.5
max_poll_attempts = 600

[server]
host = "0.0.0.0"
port = 8000

[debug]
enabled = false
log_requests = true
log_responses = true
mask_token = true

[cache]
enabled = false
timeout = 600
base_url = "http://127.0.0.1:8000"

[generation]
image_timeout = 300
video_timeout = 1500

[admin]
error_ban_threshold = 3

[proxy]
proxy_enabled = true
proxy_url = "socks5://warp:1080"

[watermark_free]
watermark_free_enabled = false
parse_method = "third_party"
custom_parse_url = ""
custom_parse_token = ""

[token_refresh]
at_auto_refresh_enabled = false
CONFIG_EOF
    echo "Default config created at /opt/sora2api/config/setting.toml"
fi

# Pull images and start services
cd /opt/sora2api
docker compose pull
docker compose up -d

echo "=== sora2api Startup Script Completed at $(date) ==="
echo "Service should be available at http://$(curl -s ifconfig.me):8000"
