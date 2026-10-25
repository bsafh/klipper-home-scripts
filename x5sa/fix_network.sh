#!/bin/bash
# Stop den Service, damit er nicht dazwischenfunkt
systemctl stop klipper-tailscale-init.service
# Tailscale mit sicherem Routing neu starten
# Das stellt die lokale Erreichbarkeit (.53) wieder her
tailscale up --reset --hostname=klipper-x5sa-t630 --accept-routes=false
# Funnel/Serve Konfiguration (Non-Blocking)
tailscale serve --bg 80
tailscale funnel on
tailscale serve --bg 81
tailscale serve --bg 444
tailscale serve --bg 7125
# Den permanenten Service wieder starten
systemctl start klipper-tailscale-init.service
echo "Netzwerk-Fix abgeschlossen."
