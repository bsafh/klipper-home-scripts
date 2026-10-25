#!/bin/bash
# configure-tailscale-x5sa.sh
# Configure Tailscale serve/funnel for X5SA specifically
# X5SA has: nginx (80, 443 on Tailscale IP), Moonraker (7125), ports 81/7136/8080/8081
# NO spoolman

set -euo pipefail

echo "=== Configuring Tailscale for X5SA ==="

# Check Tailscale is running
if ! tailscale status | grep -q "100\."; then
    echo "Tailscale not connected, attempting to connect..."
    if [[ -f /home/klipper/printer_data/config/tailscale-auth.key ]]; then
        AUTH_KEY=$(cat /home/klipper/printer_data/config/tailscale-auth.key)
        tailscale up --auth-key="$AUTH_KEY" --operator=klipper --ssh
    else
        tailscale up --operator=klipper --ssh
    fi
    sleep 5
fi

echo "Tailscale status:"
tailscale status | head -3

# Clear existing serve/funnel to avoid conflicts
echo "Clearing existing serve/funnel..."
tailscale serve --bg off 2>/dev/null || true
tailscale funnel off 2>/dev/null || true
sleep 2

# Configure SERVE (tailnet only)
echo "Configuring SERVE..."
# HTTP serve ports
for port in 80 81 7136 8080 8081; do
    echo "  serve $port -> $port"
    tailscale serve --bg --http "$port" "$port" 2>/dev/null || true
done

# HTTPS serve for port 443 (nginx is on Tailscale IP)
echo "  serve 443 (HTTPS) -> 443"
tailscale serve --bg --https 443 443 2>/dev/null || true

# Moonraker serve
echo "  serve 7125 -> 7125"
tailscale serve --bg --http 7125 7125 2>/dev/null || true

sleep 2

# Configure FUNNEL (public internet)
echo "Configuring FUNNEL..."
# Main HTTPS funnel (port 443 -> nginx 443)
echo "  funnel 443 -> 443"
tailscale funnel --bg --https 443 443 2>/dev/null || true

# Funnel port 444 -> 81 (alt web interface)
echo "  funnel 444 -> 81"
tailscale funnel --bg --https 444 81 2>/dev/null || true

# Funnel port 1000 -> 81
echo "  funnel 1000 -> 81"
tailscale funnel --bg --https 1000 81 2>/dev/null || true

# Funnel port 8443 -> 443 (HTTPS alternative)
echo "  funnel 8443 -> 443"
tailscale funnel --bg --https 8443 443 2>/dev/null || true

# Funnel Moonraker TCP
echo "  funnel 7125 (TCP) -> 7125"
tailscale funnel --bg --tcp 7125 7125 2>/dev/null || true

sleep 3

# Advertise services
echo "Advertising services..."
tailscale serve advertise "svc:klipper-x5sa-t630" 2>/dev/null || true
# No spoolman on X5SA

echo ""
echo "=== Final Status ==="
tailscale serve status
tailscale funnel status

echo ""
echo "=== Tailscale Status ==="
tailscale status | head -3