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




# ─────────────────────────────────────────────────────────────
