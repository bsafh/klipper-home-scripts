#!/usr/bin/env bash
# =============================================================================
#  fix_spool2klipper.sh  —  Reparatur für spool2klipper.service
# -----------------------------------------------------------------------------
#  Ziel:   spool2klipper.service wieder gesund bekommen, ohne Root-Zwang.
#          Erkennt die zwei bekannten Fehlerbilder automatisch:
#            (A) Unit zeigt auf User/Pfad eines ANDEREN Kontos (z.B. 'pi')
#                statt des echten Nutzers                             -> 217/USER
#            (B) moonraker_url auf 'localhost', Moonraker bindet aber nur auf
#                einer anderen Adresse (z.B. Tailscale-IP)            -> ConnRefused
#  Sicher: Ändert NICHT automatisch, was Root braucht. Root-Anteile werden
#          nur VORBEREITET und als sudo-Befehle ausgegeben (kein passwordless
#          sudo vorausgesetzt). User-Dateien (config) werden direkt gefixt.
#  Idempotent: mehrmaliges Ausführen ist unbedenklich.
#
#  Ausführen:  bash fix_spool2klipper.sh            (Diagnose ONLY — sicher, ändert nichts)
#              bash fix_spool2klipper.sh --fix        (Diagnose + User-Datei-Fixes; Root-Schritte
#                                                      werden nur als sudo-Befehle ausgegeben)
#              bash fix_spool2klipper.sh --dry-run    (identisch zur sicheren Voreinstellung)
# =============================================================================
set -u

MODE="${1:---dry-run}"   # sichere Voreinstellung: nur Diagnose. --fix für echte Änderung
SVC="spool2klipper.service"
REAL_USER="$(id -un)"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
CFG="$REAL_HOME/.config/spool2klipper/spool2klipper.cfg"
UNIT="/etc/systemd/system/$SVC"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
drl()   { if [ "$MODE" = "--dry-run" ]; then printf '  [dry] '; fi; "$@"; }

echo "=============================================================================="
echo " fix_spool2klipper.sh  —  user=$REAL_USER  home=$REAL_HOME  mode=$MODE"
echo "=============================================================================="

# ---- [1] Service-Zustand --------------------------------------------------------
printf '\n[1] Service-Zustand\n'
if systemctl is-active --quiet "$SVC"; then green "  $SVC : active"; else red "  $SVC : $(systemctl is-active $SVC 2>/dev/null || echo unknown)"; fi
systemctl show "$SVC" -p StatusText,ExecStart,User 2>/dev/null | sed 's/^/  /'

# ---- [2] Fehlerbild A: Unit zeigt auf falschen User/Pfad ------------------------
printf '\n[2] Unit-Datei auf User/Pfad-Konsistenz prüfen\n'
GREP_HIT=0
UNIT_USER="$(systemctl show "$SVC" -p User --value 2>/dev/null)"
# A1: expliziter Unit-User, der nicht der echte Nutzer ist
if [ -n "$UNIT_USER" ] && [ "$UNIT_USER" != "$REAL_USER" ]; then
  yellow "  Unit-User = '$UNIT_USER' (echter Nutzer: '$REAL_USER')  -> Fehlerbild A"
  GREP_HIT=1
fi
# A2: ExecStart zeigt in das HOME eines anderen Kontos (/home/pi, /home/root, ...)
#     Nur alarmieren, wenn der Zielpfad NICHT das echte Home ist.
if [ -f "$UNIT" ] && grep -nE "ExecStart=.*/home/[^/]+" "$UNIT" >/dev/null 2>&1; then
  # alle im ExecStart vorkommenden /home/<who>/ Pfade sammeln
  BAD_PATHS="$(grep -oE '/home/[^/]+' "$UNIT" | sort -u | grep -v "^/home/$REAL_USER$" || true)"
  if [ -n "$BAD_PATHS" ]; then
    yellow "  ExecStart verweist auf Fremd-Home(s): $(echo $BAD_PATHS | tr '\n' ' ')  -> Fehlerbild A"
    GREP_HIT=1
  else
    green "  alle ExecStart-Pfade liegen im echten Home ($REAL_HOME)"
  fi
fi
[ "$GREP_HIT" = "0" ] && green "  kein Fehlerbild A (User/Pfade konsistent)"

# ---- [3] Fehlerbild B: moonraker_url vs. tatsächliche Bind-Adresse ---------------
printf '\n[3] moonraker_url vs. Moonraker-Bind-Adresse\n'
MOON_URL=""
[ -f "$CFG" ] && MOON_URL="$(grep -E '^\s*moonraker_url\s*=' "$CFG" | head -1 | sed -E 's/^\s*moonraker_url\s*=\s*//; s/"//g')"
[ -z "$MOON_URL" ] && MOON_URL="(unbekannt / nicht gesetzt)"
echo "  config moonraker_url = $MOON_URL"

# Lokale(n) Bind-Adresse(n) auf Port 7125 ermitteln (Adresse + Ports sauber trennen)
BIND_RAW="$( (ss -tlnH 2>/dev/null || netstat -tlnp 2>/dev/null) | awk '/:7125/{print $4}' )"
if [ -n "$BIND_RAW" ]; then
  echo "  Moonraker lauscht auf: $(echo $BIND_RAW | tr '\n' ' ')"
  # Extrahiere nur die Host-Komponenten (ohne Port), z.B. '100.88.8.78', 'fd7a:...', '*'
  BIND_HOSTS="$(printf '%s\n' "$BIND_RAW" | sed -E '
      s/^\[([0-9a-fA-F:]+)\]:[0-9]+$/\1/;   # [ipv6]:port   -> ipv6
      s/^([0-9.]+):[0-9]+$/\1/;             # 1.2.3.4:port  -> 1.2.3.4
      s/^0\.0\.0\.0$/\0/;                    # any
      s/^\*$/\*/' | sort -u | tr '\n' ' ')"
  echo "  Bind-Host(s): $(echo $BIND_HOSTS)"
  case "$MOON_URL" in
    *"://localhost:"*|*"://127.0.0.1:"*|*"://::1:"*)
      LOCAL_BOUND="$(echo "$BIND_HOSTS" | grep -E '127\.0\.0\.1|\[::1\]|\*|0\.0\.0\.0' >/dev/null && echo yes || echo no)"
      if [ "$LOCAL_BOUND" = "yes" ]; then
        green "  Redirect auf localhost ist OK (Moonraker bindet auch auf localhost/any)"
      else
        yellow "  config zeigt auf localhost, Moonraker bindet aber nur woanders  -> Fehlerbild B"
        GREP_HIT=2
      fi
      ;;
  esac
else
  red "  PORT 7125 wird NICHT abgehört — Moonraker läuft evtl. nicht. Bitte erst Moonraker starten."
fi

if [ "$GREP_HIT" = "0" ]; then
  printf '\n==> Kein bekanntes Fehlerbild gefunden.\n'
  exit 0
fi

# ---- [4] Reparatur ---------------------------------------------------------------
printf '\n[4] Reparatur\n'
case "$GREP_HIT" in
  1)
    echo "  Gefunden: Unit zeigt auf falschen User/Pfad."
    if [ "$MODE" = "--dry-run" ]; then
      echo "  (dry-run) Keine Änderung."
    elif sudo -n true 2>/dev/null; then
      echo "  Passwordless sudo verfügbar -> korrigiere $UNIT"
      drl sudo sed -i -E \
        "s|User=[^[:space:]]+|User=$REAL_USER|; s|/home/[^/]+/spool2klipper|$REAL_HOME/spool2klipper|g" \
        "$UNIT"
      drl sudo systemctl daemon-reload
      drl sudo systemctl restart "$SVC"
    else
      yellow "  Kein passwordless sudo — Root-Schritt kann nicht automatisch laufen."
      echo "  Führe BITTE einmalig manuell aus, danach erneut dieses Script:"
      echo
      echo "    sudo sed -i -E \"s|User=[^[:space:]]+|User=$REAL_USER|; s|/home/[^/]+/spool2klipper|$REAL_HOME/spool2klipper|g\" $UNIT"
      echo "    sudo systemctl daemon-reload"
      echo "    sudo systemctl restart $SVC"
      echo
    fi
    ;;
  2)
    # User-Datei (config) — darf ohne Root gefixt werden.
    NEW_HOST="$(echo "$BIND_HOSTS" | awk '{print $1}')"
    case "$NEW_HOST" in
      "*"|"0.0.0.0"|"::") NEW_HOST="127.0.0.1" ;;
    esac
    [ -z "$NEW_HOST" ] && NEW_HOST="127.0.0.1"
    if [ "$MODE" = "--dry-run" ]; then
      echo "  (dry-run) würden moonraker_url auf ws://$NEW_HOST:7125/websocket setzen"
    else
      if [ -f "$CFG" ]; then
        echo "  Setze moonraker_url -> ws://$NEW_HOST:7125/websocket"
        backup="$CFG.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$CFG" "$backup" && echo "  Backup: $backup"
        drl sed -i -E "s|^(\s*moonraker_url\s*=\s*)\"[^\"]*\"|\1\"ws://$NEW_HOST:7125/websocket\"|" "$CFG"
      else
        echo "  config fehlt: $CFG — lege sie an"
        mkdir -p "$(dirname "$CFG")"
        cat > "$CFG" <<EOF
[spool2klipper]
moonraker_url = "ws://$NEW_HOST:7125/websocket"
spoolman_url = "http://localhost:7912/api"
klipper_spool_set_macro_prefix = "_SPOOLMAN_SET_FIELD_"
klipper_spool_clear_macro = "_SPOOLMAN_CLEAR_SPOOL"
klipper_spool_done = "_SPOOLMAN_DONE"
EOF
      fi
      if systemctl can-restart "$SVC" 2>/dev/null | grep -q yes; then
        drl systemctl restart "$SVC"
      fi
    fi
    ;;
esac

# ---- [5] Ergebnis prüfen -----------------------------------------------------------
printf '\n[5] Ergebnis nach kurzer Wartezeit\n'
sleep 3
if systemctl is-active --quiet "$SVC"; then
  green "  OK: $SVC ist jetzt active."
  exit 0
else
  red "  $SVC ist weiterhin: $(systemctl is-active $SVC 2>/dev/null)"
  echo "  Letzte Log-Einträge:"
  journalctl -u "$SVC" -n 8 --no-pager 2>/dev/null | sed 's/^/    /'
  exit 1
fi
