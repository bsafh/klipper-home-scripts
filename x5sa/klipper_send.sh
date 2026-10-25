#!/usr/bin/bash
# klipper_send.sh - Send commands to Klipper via Unix Domain Socket

KLIPPY_SERIAL="/home/klipper/printer_data/comms/klippy.serial"
SOCKET="/home/klipper/printer_data/comms/klippy.sock"
COMMAND="$1"

if [ -z "$COMMAND" ]; then
    echo "Usage: $0 <gcode_command>"
    exit 1
fi

# Send command via socat

#echo "$COMMAND" | socat - UNIX-CONNECT:"$SOCKET" 
echo "Sending command '$COMMAND' to '$KLIPPY_SERIAL'"
echo "$COMMAND" > "$KLIPPY_SERIAL"

if [ $? -eq 0 ]; then
    echo "Command sent: $COMMAND"
else
    echo "Failed to send command: $COMMAND"
    exit 1
fi
