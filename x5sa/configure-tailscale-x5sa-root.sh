#!/bin/bash
# Root script for X5SA (192.168.80.53) - configure ALL tailscale serve/funnel from rc.local
# Run as root: sudo ./configure-tailscale-x5sa-root.sh

set -euo pipefail

# Reset any existing serve/funnel before re-configuring (prevents "already serving TCP")
tailscale serve reset || true
tailscale funnel reset || true

# Start services first (before tailscale), then ensure they are reachable
systemctl start klipper moonraker nginx
# X5SA: NO Spoolman (only on A30; service file starts with S)

echo "=== Configuring Tailscale for X5SA (klipper-x5sa) ==="

# Auth key from rc.local info source (do NOT run rc.local)
AUTH_KEY="tskey-auth-ka3K9Q7xy211CNTRL-Xjyu5nMPBM88SSbkSBJpL8FDUMggWXQk"

# Bring up Tailscale connection (NO --accept-routes; test showed it broke LAN)
echo "Bringing up Tailscale connection..."
tailscale up --reset --auth-key="$AUTH_KEY" --operator=klipper --hostname=klipper-x5sa-t630 --ssh

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
# Spoolman NOT on X5SA (only A30 - service file starts with S)
tailscale serve --bg --http 7125 7125     # Moonraker
tailscale serve --bg --http 7136 7136     # Klipper WebSocket
tailscale serve --bg --http 8080 8080     # Webcam/other
tailscale serve --bg --http 8081 8081     # Webcam/other

# Service-based serves
# no spoolman service on X5SA

# ADVERTISE services (make them discoverable)
echo "Advertising services..."
tailscale serve advertise svc:klipper-x5sa-t630

# Optional settings
tailscale set --update-check --report-posture --webclient --auto-update

echo "=== X5SA Tailscale configuration complete ==="
echo "Check status with: tailscale serve status && tailscale funnel status"