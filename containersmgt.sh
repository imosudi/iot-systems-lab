#!/usr/bin/env bash
#containersmgt.sh - Setup and management of IoT lab containers

set -euo pipefail

PROJECT_DIR="$(pwd)"
CERT_DIR="$PROJECT_DIR/tlscertsops"
MOSQ_DIR="$PROJECT_DIR/mosquitto"
CLIENT_DIR="$PROJECT_DIR/client"
BLE_DIR="$PROJECT_DIR/ble_engine"

DATA_DIR="$PROJECT_DIR/iot_storage"
LAB_DIR="$PROJECT_DIR/lab-storage"

echo "Setting up IoT lab environment..."

# ─────────────────────────────────────────────────────────────
# Certificate Directories
# ─────────────────────────────────────────────────────────────
# MQTT Broker: mosquitto
mkdir -p \
  "$MOSQ_DIR/certs" \
  "$CLIENT_DIR/certs" \
  "$BLE_DIR/certs" \
  "$DATA_DIR/mosquitto-data-storage" \
  "$DATA_DIR/mosquitto-log-storage" \
  "$LAB_DIR"




# ─────────────────────────────────────────────────────────────
# Copy certificates
# ─────────────────────────────────────────────────────────────
# mosquitto
cp "$CERT_DIR/mosquitto/"{ca.crt,mosquitto.crt,mosquitto.key} "$MOSQ_DIR/certs/"

# Test Client
cp "$CERT_DIR/client/"{ca.crt,client.crt,client.key} "$CLIENT_DIR/certs/"

# BLE
cp "$CERT_DIR/ble/"{ca.crt,ble.crt,ble.key} "$BLE_DIR/certs/"
chmod 644 "$BLE_DIR/certs/ble.crt"
chmod 644 "$BLE_DIR/certs/ca.crt"
chmod 644 "$BLE_DIR/certs/ble.key"



# ─────────────────────────────────────────────────────────────
# Container builds
#
# mosquitto
# ─────────────────────────────────────────────────────────────
# mosquitto.conf
# ─────────────────────────────────────────────────────────────
cat > "$MOSQ_DIR/mosquitto.conf" <<'EOF'
# Mosquitto MQTT broker configuration file with TLS support
persistence true
persistence_location /mosquitto/data

log_dest stdout

log_type error
log_type warning
log_type notice
log_type information
log_type subscribe
log_type unsubscribe
log_type websockets

connection_messages true
log_timestamp true

listener 8883

cafile /mosquitto/config/ca.crt
certfile /mosquitto/config/mosquitto.crt
keyfile /mosquitto/config/mosquitto.key

tls_version tlsv1.3

allow_anonymous false
password_file /mosquitto/config/passwd

require_certificate true
use_identity_as_username true
EOF

# ─────────────────────────────────────────────────────────────
# Mosquitto Containerfile
# ─────────────────────────────────────────────────────────────
cat > "$MOSQ_DIR/Containerfile" <<'EOF'
# Containerfile for Mosquitto MQTT broker with TLS support
FROM docker.io/eclipse-mosquitto:latest

COPY certs/* /mosquitto/config/

RUN touch /mosquitto/config/passwd \
 && chmod 600 /mosquitto/config/* \
 && chown mosquitto:mosquitto /mosquitto/config/*
EOF

# ─────────────────────────────────────────────────────────────
# Client Entrypoint
# ─────────────────────────────────────────────────────────────
cat > "$CLIENT_DIR/Containerfile" <<'EOF'
#!/bin/bash
echo ""
echo ""
#entrypoint.sh
printf "MQTT [BLE Subscriber] container started...\n"

exec python3 -u main.py
EOF

