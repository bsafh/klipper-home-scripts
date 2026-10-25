#!/bin/bash
# Root script for A30 (192.168.80.47) - configure ALL tailscale serve/funnel from rc.local
# Run as root: sudo ./configure-tailscale-a30-root.sh

set -euo pipefail

# Reset any existing serve/funnel before re-configuring (prevents "already serving TCP")
tailscale serve reset || true
tailscale funnel reset || true

# Start services first (before tailscale), then ensure they are reachable
systemctl start klipper moonraker nginx
# A30 only: Spoolman service file starts with capital S
if [ -f /etc/systemd/system/Spoolman.service ] || [ -f /usr/lib/systemd/system/Spoolman.service ]; then
    systemctl start Spoolman || true
fi

# Wait until nginx and klipper services respond (local LAN check)
echo "Waiting for services (nginx, moonraker, klipper)..."
for i in $(seq 1 30); do
    (curl -sf http://localhost/ > /dev/null 2>&1 || curl -sf http://localhost:81/ > /dev/null 2>&1) && break
    sleep 1
done

echo "=== Configuring Tailscale for A30 (klipper-a30) ==="

# Auth key from rc.local info source (do NOT run rc.local)
AUTH_KEY="tskey-auth-ka3K9Q7xy211CNTRL-Xjyu5nMPBM88SSbkSBJpL8FDUMggWXQk"

# Bring up Tailscale connection (NO --accept-routes; test showed it broke LAN on X5SA)
echo "Bringing up Tailscale connection..."
tailscale up --reset --auth-key="$AUTH_KEY" --operator=klipper --hostname=klipper-a30 --ssh

# Ensure operator is set for klipper user (allows non-root serve/funnel)
tailscale set --operator=klipper

# FUNNELS (expose to internet via Tailscale)
echo "Configuring funnels..."
tailscale funnel --bg --https 443 80      # nginx HTTPS -> port 80
tailscale funnel --bg --https 444 81      # nginx HTTPS -> port 81
tailscale funnel --bg --https 1000 81     # nginx HTTPS -> port 81 (alt)

# SERVES (expose within tailnet)
echo "Configuring serves..."
tailscale serve --bg --http 80 80         # nginx HTTP
tailscale serve --bg --http 81 81         # nginx HTTP alt
tailscale serve --bg --http 7125 7125     # Moonraker
tailscale serve --bg --http 7136 7136     # Klipper WebSocket
tailscale serve --bg --http 8080 8080     # Webcam/other
tailscale serve --bg --http 8081 8081     # Webcam/other

# Service-based serves
tailscale serve --bg --service=svc:spoolman --http 7912 7912

# ADVERTISE services (make them discoverable)
echo "Advertising services..."
tailscale serve advertise svc:klipper-a30
tailscale serve advertise svc:spoolman

# Optional settings
tailscale set --update-check --report-posture --webclient --auto-update

echo "=== A30 Tailscale configuration complete ==="
echo "Check status with: tailscale serve status && tailscale funnel status"