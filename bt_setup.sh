#!/usr/bin/env bash
# bt_setup.sh
#  - scans for a Bluetooth LE device by MAC address
#  - connects to it and displays GATT service/characteristic UUIDs
#  - supports dynamic service/characteristic discovery

set -euo pipefail

# Target device MAC to discover/connect
DEVICE_MAC="$1"
# Maximum total scan time (seconds)
MAX_WAIT=120
# Poll interval to check scan log (seconds)
SCAN_INTERVAL=5

if [ -z "${DEVICE_MAC:-}" ]; then
  echo "Usage: $0 <device_mac>"
  exit 1
fi

if ! [[ "$DEVICE_MAC" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
  echo "[-] Invalid MAC address format"
  exit 1
fi

echo "[*] Target: $DEVICE_MAC"
rfkill unblock bluetooth || true
sudo modprobe btusb || true
sudo systemctl restart bluetooth
sleep 2

SESSION_LOG=$(mktemp)
PIPE_FILE=$(mktemp -u)
BLEUUID_FILE="$(pwd)/bleuuids.txt"
# Store service/characteristic UUID mappings
: > "$BLEUUID_FILE"
mkfifo "$PIPE_FILE"

# Cleanup ensures bluetoothctl process and temporary files are removed in all exit cases.
cleanup() {
  echo "[*] Cleaning up..."
  if [ -n "${BT_PID:-}" ] && kill -0 "$BT_PID" 2>/dev/null; then
    echo "[*] Stopping scan and exiting bluetoothctl"
    if [ -n "${BT_IN:-}" ]; then
      echo "scan off" >&"$BT_IN" || true
      echo "exit" >&"$BT_IN" || true
    fi
    sleep 1
    kill "$BT_PID" 2>/dev/null || true
  fi
  if [ -n "${BT_IN:-}" ]; then
    exec {BT_IN}>&- || true
  fi
  rm -f "$PIPE_FILE"
  rm -f "$SESSION_LOG"
}
trap cleanup EXIT INT TERM

# Start bluetoothctl using a FIFO for commands and log output.
bluetoothctl <"$PIPE_FILE" >"$SESSION_LOG" 2>&1 &
BT_PID=$!
exec {BT_IN}>"$PIPE_FILE"

send_cmd() {
  local cmd="$1"
  echo "[*] btctl> $cmd"
  echo "$cmd" >&"$BT_IN"
}

# Initialize bluetoothctl state and start scanning for devices.
send_cmd "power on"
send_cmd "agent on"
send_cmd "default-agent"
send_cmd "scan on"

echo "[*] Scanning for ${MAX_WAIT}s in a single session..."

ELAPSED=0
FOUND=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  if grep -iq "$DEVICE_MAC" "$SESSION_LOG" 2>/dev/null; then
    echo "[+] Device appeared after ${ELAPSED}s"
    FOUND=1
    break
  fi
  sleep $SCAN_INTERVAL
  ELAPSED=$((ELAPSED + SCAN_INTERVAL))
  echo "[*] ${ELAPSED}s elapsed..."
done

if [ $FOUND -eq 0 ]; then
  echo "[-] Device not found within ${MAX_WAIT}s"
  exit 1
fi

send_cmd "scan off"
sleep 2

echo "[*] Connecting to $DEVICE_MAC..."
send_cmd "connect $DEVICE_MAC"

# Wait for connection result
CONN_OK=0
for i in $(seq 1 30); do
  if [ -f "$SESSION_LOG" ] && grep -Eq "(Connection successful|Failed to connect|Connection failed)" "$SESSION_LOG"; then
    if grep -iq "Connection successful" "$SESSION_LOG"; then
      CONN_OK=1
    fi
    break
  fi
  sleep 1
done

if [ $CONN_OK -eq 1 ]; then
  echo "[+] Connected successfully"
  send_cmd "info $DEVICE_MAC"
  sleep 2

  echo "[*] Service characteristics summary:"
  if [ -f "$SESSION_LOG" ]; then
    declare -A service_names
    declare -A service_short
    declare -A char_names
    declare -A char_short
    declare -A char_service
    services=()
    chars=()
    current_entity=""
    current_uuid_full=""
    current_uuid_short=""
    current_name=""
    last_service_uuid=""

    while IFS= read -r log_line; do
      line=$(echo "$log_line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      [ -z "$line" ] && continue

      case "$line" in
        *Primary\ Service*)
          current_entity="service"
          current_uuid_full=""
          current_uuid_short=""
          current_name=""
          continue
          ;;
        *Characteristic*)
          current_entity="char"
          current_uuid_full=""
          current_uuid_short=""
          current_name=""
          continue
          ;;
        */org/bluez/*)
          # skipping path lines
          continue
          ;;
      esac

      if [[ "$line" =~ ^([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})$ ]]; then
        uuid_full="${BASH_REMATCH[1]}"
        if [[ "$uuid_full" =~ ^0000([0-9A-Fa-f]{4})-0000-1000-8000-00805[fF]9b34fb$ ]]; then
          current_uuid_short="0x${BASH_REMATCH[1]}"
        else
          current_uuid_short=""
        fi
        current_uuid_full="$uuid_full"
        continue
      fi

      if [ -n "$current_entity" ] && [ -n "$current_uuid_full" ]; then
        current_name="$line"

        if [ "$current_entity" = "service" ]; then
          services+=("$current_uuid_full")
          service_names["$current_uuid_full"]="$current_name"
          service_short["$current_uuid_full"]="$current_uuid_short"
          last_service_uuid="$current_uuid_full"
        else
          chars+=("$current_uuid_full")
          char_names["$current_uuid_full"]="$current_name"
          char_short["$current_uuid_full"]="$current_uuid_short"
          char_service["$current_uuid_full"]="$last_service_uuid"
        fi

        current_entity=""
        current_uuid_full=""
        current_uuid_short=""
        current_name=""
      fi
    done < "$SESSION_LOG"

    if [ ${#services[@]} -eq 0 ] && [ ${#chars[@]} -eq 0 ]; then
      echo "[!] No services/characteristics found in session log"
    else
      for svc in "${services[@]}"; do
        svc_short="${service_short[$svc]:-}"
        svc_name="${service_names[$svc]:-unknown}"
        svc_key=$(echo "$svc_name" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '_' | sed -e 's/^_*//' -e 's/_*$//')

        if [ -n "$svc_short" ]; then
          echo "Service: $svc_short ($svc) - $svc_name"
          echo "${svc_key}_id16=$svc_short" >> "$BLEUUID_FILE"
        else
          echo "Service: $svc - $svc_name"
        fi
        echo "${svc_key}_id128=$svc" >> "$BLEUUID_FILE"

        for ch in "${chars[@]}"; do
          if [ "${char_service[$ch]:-}" = "$svc" ]; then
            ch_short="${char_short[$ch]:-}"
            ch_name="${char_names[$ch]:-unknown}"
            ch_key=$(echo "$ch_name" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '_' | sed -e 's/^_*//' -e 's/_*$//')

            if [ -n "$ch_short" ]; then
              echo "  Characteristic: $ch_short ($ch) - $ch_name"
              echo "${ch_key}_id16=$ch_short" >> "$BLEUUID_FILE"
            else
              echo "  Characteristic: $ch - $ch_name"
            fi
            echo "${ch_key}_id128=$ch" >> "$BLEUUID_FILE"
          fi
        done
      done
    fi

  else
    echo "[!] Session log missing; cannot parse services"
  fi
else
  echo "[-] Connection failed"
  if [ -f "$SESSION_LOG" ]; then
    grep -E "(Failed to connect|Connection failed|org.bluez.Error)" "$SESSION_LOG" || true
  else
    echo "[!] Session log missing; cannot dump error details"
  fi
  exit 1
fi

# Optional graceful disconnect
#if [ $CONN_OK -eq 1 ]; then
#  echo "[*] Disconnecting from $DEVICE_MAC"
#  send_cmd "disconnect $DEVICE_MAC"
#  sleep 2
#fi

# Exit bluetoothctl session
send_cmd "exit"

# cleanup trap will run on exit
