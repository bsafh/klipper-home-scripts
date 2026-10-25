#!/bin/bash
# Run this manually on X5SA as klipper user:
#   sudo ~/fix-x5sa-moonraker-manual.sh
# (will prompt for klipper's sudo password)

cat << 'EOF' | sudo tee /etc/systemd/system/moonraker.service > /dev/null
[Unit]
Description=API Server for Klipper SV1
Documentation=https://moonraker.readthedocs.io/
Requires=network-online.target tailscaled.service
After=network-online.target tailscaled.service

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=klipper
SupplementaryGroups=moonraker-admin
RemainAfterExit=yes
WorkingDirectory=/home/klipper/moonraker
EnvironmentFile=/home/klipper/printer_data/systemd/moonraker.env
ExecStart=/home/klipper/moonraker-env/bin/python $MOONRAKER_ARGS
Restart=always
RestartSec=10
EOF

sudo systemctl daemon-reload
sudo systemctl restart moonraker

echo "Done. Verify with:"
echo "  ss -tlnp | grep 7125"
echo "  systemctl status moonraker --no-pager"