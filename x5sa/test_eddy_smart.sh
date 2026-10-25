#!/usr/bin/bash
# test_eddy_smart.sh - Testet die Eddy-NG Integration

SOCKET="/home/klipper/printer_data/comms/klippy.sock"

echo "=== Testing Eddy-NG Smart G28 ==="
echo "_EDDY_SMART_G28" | socat - UNIX-CONNECT:"$SOCKET"

echo ""
echo "=== Testing debug function ==="
echo "EDDY_DEBUG" | socat - UNIX-CONNECT:"$SOCKET"

echo ""
echo "=== Testing static probe ==="
echo "PROBE_EDDY_NG_PROBE_STATIC HOME_Z=1" | socat - UNIX-CONNECT:"$SOCKET"
