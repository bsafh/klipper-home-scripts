#!/bin/bash
# Eddy NG Auto-Homing Helper Script (Moonraker API Version)
# Speichere als: /home/klipper/eddy_ng_homing.sh
# Mache ausführbar mit: chmod +x /home/klipper/eddy_ng_homing.sh

BED_X=${1:-164.5}
BED_Y=${2:-165}
MOONRAKER_URL="http://localhost:7125"

echo "Eddy NG Auto-Homing gestartet (Moonraker API Version)..."

# Prüfe ob curl und jq installiert sind
if ! command -v curl &> /dev/null; then
    echo "FEHLER: 'curl' ist nicht installiert!"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "WARNUNG: 'jq' nicht installiert, verwende grep/sed fallback"
    USE_JQ=0
else
    USE_JQ=1
fi

# Funktion zum Senden von GCode via Moonraker API
send_gcode() {
    curl -s -X POST "$MOONRAKER_URL/printer/gcode/script" \
         -H "Content-Type: application/json" \
         -d "{\"script\":\"$1\"}" > /dev/null
    sleep 0.3
}

# Funktion zum Auslesen von PEPS via Moonraker API
get_peps_value() {
    # Sende PEPS Befehl
    send_gcode "PEPS"
    sleep 0.6
    
    # Hole probe Status von Moonraker
    RESPONSE=$(curl -s "$MOONRAKER_URL/printer/objects/query?probe")
    
    if [ $USE_JQ -eq 1 ]; then
        # Mit jq parsen (sauberer)
        HEIGHT=$(echo "$RESPONSE" | jq -r '.result.status.probe.last_z_result // empty' 2>/dev/null)
    else
        # Fallback mit grep/sed
        HEIGHT=$(echo "$RESPONSE" | grep -o '"last_z_result":[^,}]*' | sed 's/"last_z_result"://g' | tr -d ' ')
    fi
    
    # Prüfe ob wir einen gültigen Wert haben
    if [[ "$HEIGHT" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$HEIGHT > 0" | bc -l) )); then
        echo "$HEIGHT"
        return 0
    else
        return 1
    fi
}

# Schritt 1: Home X und Y Achsen (funktioniert ohne Z-Home)
echo "=== Schritt 1: Home X und Y Achsen ==="
send_gcode "G28 X Y"
sleep 1.0

# Schritt 2: Fahre zur Bed-Mitte
echo "=== Schritt 2: Fahre zur Bed-Mitte (X=$BED_X Y=$BED_Y) ==="
send_gcode "G0 X$BED_X Y$BED_Y F6000"
sleep 0.8

# Schritt 3: Erster PEPS-Check um ungefähre Höhe zu ermitteln
echo "=== Schritt 3: Prüfe initiale Höhe ==="
INITIAL_HEIGHT=$(get_peps_value)

if [ $? -eq 0 ] && [ ! -z "$INITIAL_HEIGHT" ]; then
    echo "✓ Kopf ist bereits niedrig genug bei Z=$INITIAL_HEIGHT"
    echo "Setze Position direkt auf gemessene Höhe"
    send_gcode "SET_KINEMATIC_POSITION X=$BED_X Y=$BED_Y Z=$INITIAL_HEIGHT"
    echo "Auto-Homing erfolgreich abgeschlossen (Direct Mode)!"
    exit 0
fi

echo "✗ Kopf zu hoch für direkte Messung, starte Recovery-Modus"

# ============================================================================
# WICHTIGE SICHERHEITSHINWEISE FÜR PHASE 1 SCHRITTWEITE
# ============================================================================
# Die Schrittweite in Phase 1 muss KLEINER sein als:
#   (Eddy_Max_Detection_Height - Minimum_Safety_Clearance)
#
# Eddy NG Detektionshöhen (druckerabhängig!):
#   - Von OBEN (runter tastend): ~6.5-7mm (KRITISCH!)
#   - Von UNTEN (hoch tastend): ~15mm
#
# Die maximale Detektionshöhe hängt STARK ab von:
#   1. Montagehöhe des Eddy relativ zur Düsenspitze
#   2. Bed-Material und Temperatur
#   3. Individuelle Sensor-Kalibrierung
#
# WARNUNG: Bei falscher Schrittweite kann der Kopf ins Bett fahren!
#
# Beispielrechnung für dieses Script:
#   - Eddy Max (von oben): ~6.8mm (bei diesem Drucker getestet)
#   - Gewünschter Sicherheitsabstand: 2.3mm
#   - Max. sichere Schrittweite: 6.8 - 2.3 = 4.5mm
#   - Verwendete Schrittweite: 4.5mm (sicher!)
#   - Worst Case bei Z=6.8mm Start: landet bei 2.3mm (OK!)
#
# EMPFEHLUNG: Teste die maximale Detektionshöhe deines Druckers!
#   1. Positioniere Kopf bei verschiedenen Höhen (6mm, 7mm, 8mm, ...)
#   2. Führe PEPS aus und notiere ab welcher Höhe es funktioniert
#   3. Setze PHASE1_STEP = (Max_Height - 2mm) für Sicherheit
# ============================================================================

# Phase 1: Schnelle Annäherung mit 4.5mm Schritten von oben
echo "=== Phase 1: Schnelle Annäherung (4.5mm Schritte von Z=250mm) ==="
PHASE1_START=250
PHASE1_STEP=4.5  # Konservativ für Sicherheit (bei 6.8mm Eddy-Max → 2.3mm Endposition)
PHASE1_MAX=60    # Deckt 250mm ab (250 ÷ 4.5 ≈ 56 Schritte)

send_gcode "SET_KINEMATIC_POSITION Z=$PHASE1_START"
sleep 0.5

CURRENT_Z=$PHASE1_START
FOUND_RANGE=0

for ((i=1; i<=PHASE1_MAX; i++)); do
    echo "Phase 1 - Versuch $i/$PHASE1_MAX bei Z=$CURRENT_Z"
    
    HEIGHT=$(get_peps_value)
    
    if [ $? -eq 0 ] && [ ! -z "$HEIGHT" ]; then
        echo "✓ PEPS Reichweite erreicht bei ~Z=$HEIGHT"
        FOUND_RANGE=1
        PHASE2_START=$HEIGHT
        break
    fi
    
    # Fahre 5mm runter
    if [ $i -lt $PHASE1_MAX ]; then
        CURRENT_Z=$(echo "$CURRENT_Z - $PHASE1_STEP" | bc -l)
        if (( $(echo "$CURRENT_Z < 0" | bc -l) )); then
            echo "WARNUNG: Phase 1 erreicht Z=0"
            break
        fi
        send_gcode "G91"
        send_gcode "G1 Z-${PHASE1_STEP} F3000"
        send_gcode "G90"
        sleep 0.2
    fi
done

if [ $FOUND_RANGE -eq 0 ]; then
    echo "FEHLER: Keine gültige Höhe in Phase 1 gefunden!"
    exit 1
fi

# Phase 2: Präzise Positionierung mit gemessenem Wert
echo "=== Phase 2: Setze präzise Position ==="
echo "✓ Gültige Höhe gefunden: Z=$PHASE2_START"
send_gcode "SET_KINEMATIC_POSITION X=$BED_X Y=$BED_Y Z=$PHASE2_START"
sleep 0.3

echo "Auto-Homing erfolgreich abgeschlossen!"
exit 0

