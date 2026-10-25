#!/bin/bash
# /home/klipper/deepseek_eddy_recovery.sh
# Automatische Recovery für Eddy NG Probleme

LOGFILE="/home/klipper/printer_data/logs/eddy_recovery.log"
KLIPPY_SOCKET="/home/klipper/printer_data/comms/klippy.sock"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

send_gcode() {
    echo "$1" | nc -U "$KLIPPY_SOCKET" 2>/dev/null
    sleep 1
}

# Prüfe auf Fehler im Klipper Log
check_errors() {
    if tail -n 50 /home/klipper/printer_data/logs/klippy.log | grep -q "Couldn't get any valid samples\|Sensor error\|No samples received"; then
        return 0
    fi
    return 1
}

# Automatische Recovery Prozedur
perform_recovery() {
    log "Starte Eddy NG Recovery Prozedur"
    
    # Homing erzwingen
    send_gcode "G28"
    sleep 2
    
    # Zur Mitte bewegen
    send_gcode "G90"
    send_gcode "G0 X164.5 Y165 F6000"
    
    # PEPS Versuche
    for i in {1..10}; do
        log "PEPS Versuch $i"
        send_gcode "peps"
        sleep 0.5
        
        # Prüfe Antwort (vereinfacht)
        send_gcode "_CLIENT_LINEAR_MOVE Z=-1 F=1500"
        sleep 0.3
    done
    
    # Finales Homing
    send_gcode "G0 Z4 F1500"
    send_gcode "G28"
    send_gcode "PROBE_EDDY_NG_TAP"
    
    log "Recovery abgeschlossen"
}

# Hauptprogramm
if check_errors; then
    log "Eddy NG Fehler erkannt, starte Recovery"
    perform_recovery
else
    log "Keine Fehler erkannt"
fi
