#!/bin/bash
# Eddy NG Auto-Homing Helper Script
# Speichere als: /home/klipper/eddy_ng_homing.sh
# Mache ausführbar mit: chmod +x /home/klipper/eddy_ng_homing.sh

BED_X=${1:-164.5}
BED_Y=${2:-165}
KLIPPER_SOCKET="/home/klipper/printer_data/comms/klippy.sock"
KLIPPER_LOG="/home/klipper/printer_data/logs/klippy.log"
MAX_ATTEMPTS=15
STEP_SIZE=1.0
INITIAL_Z=25

echo "Eddy NG Auto-Homing gestartet..."

# Funktion zum Senden von GCode Befehlen
send_gcode() {
    echo "$1" > "$KLIPPER_SOCKET"
    sleep 0.2
}

# Funktion zum Auslesen von PEPS
get_peps_value() {
    # Sende PEPS Befehl und capture Output
    echo "PEPS" > "$KLIPPER_SOCKET"
    sleep 0.5
    
    # Lese Klipper Log für letzten PEPS Output
    # Suche nach Pattern: "Probed X.XXX (avg=..."
    PEPS_LINE=$(tail -n 20 /tmp/klippy.log | grep "Probed" | tail -n 1)
    
    if [[ $PEPS_LINE =~ Probed\ ([0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    else
        return 1
    fi
}

# Hauptlogik
echo "Setze initiale Position: X=$BED_X Y=$BED_Y Z=$INITIAL_Z"
send_gcode "SET_KINEMATIC_POSITION X=$BED_X Y=$BED_Y Z=$INITIAL_Z"

CURRENT_Z=$INITIAL_Z
FOUND_HEIGHT=0

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    echo "Versuch $i/$MAX_ATTEMPTS bei Z=$CURRENT_Z"
    
    # Versuche PEPS auszulesen
    HEIGHT=$(get_peps_value)
    
    if [ $? -eq 0 ] && [ ! -z "$HEIGHT" ]; then
        echo "✓ Gültige Höhe gefunden: Z=$HEIGHT"
        FOUND_HEIGHT=1
        
        # Setze kinematische Position auf gemessene Höhe
        send_gcode "SET_KINEMATIC_POSITION X=$BED_X Y=$BED_Y Z=$HEIGHT"
        echo "Position auf Z=$HEIGHT gesetzt"
        
        break
    else
        echo "✗ Keine gültigen PEPS Werte bei Z=$CURRENT_Z"
        
        # Fahre 1mm nach unten für nächsten Versuch
        if [ $i -lt $MAX_ATTEMPTS ]; then
            CURRENT_Z=$(echo "$CURRENT_Z - $STEP_SIZE" | bc)
            send_gcode "_CLIENT_LINEAR_MOVE Z=-$STEP_SIZE F=1500"
            sleep 0.3
        fi
    fi
done

if [ $FOUND_HEIGHT -eq 0 ]; then
    echo "FEHLER: Keine gültige Höhe gefunden nach $MAX_ATTEMPTS Versuchen!"
    exit 1
fi

echo "Auto-Homing erfolgreich abgeschlossen!"
exit 0

