#!/usr/bin/env bash
# containersmgt.sh - Setup and management of IoT lab containers

set -euo pipefail

PROJECT_DIR="$(pwd)"
CERT_DIR="$PROJECT_DIR/tlscertsops"

MOSQ_DIR="$PROJECT_DIR/mosquitto"
CLIENT_DIR="$PROJECT_DIR/client"
BLE_DIR="$PROJECT_DIR/ble_engine"

INFLUX_DIR="$PROJECT_DIR/influxdb"
BACKEND_DIR="$PROJECT_DIR/backend"

DATA_DIR="$PROJECT_DIR/iot_storage"
LAB_DIR="$PROJECT_DIR/lab-storage"

echo "Setting up IoT lab environment..."

# ─────────────────────────────────────────────
# Directory structure
# ─────────────────────────────────────────────
mkdir -p \
  "$MOSQ_DIR/certs" \
  "$CLIENT_DIR/certs" \
  "$BLE_DIR/certs" \
  "$INFLUX_DIR/certs" \
  "$BACKEND_DIR/certs" \
  "$DATA_DIR/mosquitto-data-storage" \
  "$DATA_DIR/mosquitto-log-storage" \
  "$DATA_DIR/influxdb-storage" \
  "$LAB_DIR"

# ─────────────────────────────────────────────
# Copy TLS certificates
# ─────────────────────────────────────────────

echo "Copying TLS certificates..."

cp "$CERT_DIR/mosquitto/"{ca.crt,mosquitto.crt,mosquitto.key} "$MOSQ_DIR/certs/"
cp "$CERT_DIR/client/"{ca.crt,client.crt,client.key} "$CLIENT_DIR/certs/"
cp "$CERT_DIR/ble/"{ca.crt,ble.crt,ble.key} "$BLE_DIR/certs/"
cp "$CERT_DIR/influxdb/"{ca.crt,influxdb.crt,influxdb.key} "$INFLUX_DIR/certs/"
cp "$CERT_DIR/backend/"{ca.crt,backend.crt,backend.key} "$BACKEND_DIR/certs/"

# ─────────────────────────────────────────────
# podman-compose.yml
# ─────────────────────────────────────────────

cat > "$PROJECT_DIR/podman-compose.yml" <<EOF
version: "3.9"

services:

  ble:
    build: ble_engine
    privileged: true
    volumes:
      - /run/dbus:/run/dbus:rw,z
    healthcheck:
      test: ["CMD", "pgrep", "-f", "python3 main.py"]
      interval: 5s
      retries: 5
      start_period: 5s

  mosquitto:
    build: mosquitto
    restart: unless-stopped
    depends_on:
      ble:
        condition: service_healthy
    environment:
      TZ: Europe/Vienna
    ports:
      - "8883:8883"
    volumes:
      - ./iot_storage/mosquitto-data-storage:/mosquitto/data
      - ./iot_storage/mosquitto-log-storage:/mosquitto/log
      - ./mosquitto/mosquitto.conf:/mosquitto/config/mosquitto.conf:Z
    healthcheck:
      test: ["CMD", "mosquitto_sub", "-h", "localhost", "-t", "test", "-C", "1"]
      interval: 5s
      retries: 5
      start_period: 5s

  client:
    build: client
    restart: unless-stopped
    depends_on:
      mosquitto:
        condition: service_healthy

  influxdb:
    image: docker.io/library/influxdb:2.7
    container_name: influxdb
    restart: unless-stopped
    ports:
      - "8086:8086"
    environment:
      - TZ=Europe/Vienna
    volumes:
      - ./iot_storage/influxdb-storage:/var/lib/influxdb2
      - ./influxdb/certs:/certs:ro

  backend:
    image: docker.io/nodered/node-red:3.1.0
    container_name: backend
    restart: unless-stopped
    ports:
      - "1880:1880"
    volumes:
      - ./backend:/data
      - ./backend/certs:/certs:ro
    environment:
      - TZ=Europe/Vienna
    depends_on:
      mosquitto:
        condition: service_healthy
      influxdb:
        condition: service_started
EOF

# ─────────────────────────────────────────────
# mosquitto.conf
# ─────────────────────────────────────────────

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

# ─────────────────────────────────────────────
# Mosquitto Containerfile
# ─────────────────────────────────────────────

cat > "$MOSQ_DIR/Containerfile" <<'EOF'
FROM docker.io/eclipse-mosquitto:latest

COPY certs/* /mosquitto/config/

RUN touch /mosquitto/config/passwd \
 && chmod 600 /mosquitto/config/* \
 && chown mosquitto:mosquitto /mosquitto/config/*
EOF

# ─────────────────────────────────────────────
# MQTT client container
# ─────────────────────────────────────────────

cat > "$CLIENT_DIR/Containerfile" <<'EOF'
FROM docker.io/library/debian:stable-slim

RUN apt-get update \
 && apt-get install -y python3 python3-paho-mqtt \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /client

COPY certs /client/certs
COPY entrypoint.sh .
COPY main.py .

RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
EOF

# ─────────────────────────────────────────────
# MQTT Client Entrypoint
# ─────────────────────────────────────────────

cat > "$CLIENT_DIR/entrypoint.sh" <<'EOF'
#!/bin/bash
echo ""
echo "MQTT Client container started..."
echo ""

exec python3 -u main.py
EOF

# ─────────────────────────────────────────────
# MQTT client code
# ─────────────────────────────────────────────

cat > "$CLIENT_DIR/main.py" <<'EOF'
import paho.mqtt.client as mqtt

BROKER = "mosquitto"
PORT = 8883

TOPICS = [
    "sensor/temperature",
    "sensor/humidity"
]

CA_CERT = "/client/certs/ca.crt"
CERT = "/client/certs/client.crt"
KEY = "/client/certs/client.key"

def on_connect(client, userdata, flags, reason_code, properties):
    print("Connected:", reason_code)
    for t in TOPICS:
        client.subscribe(t)
        print("Subscribed:", t)

def on_message(client, userdata, msg):
    print(f"[{msg.topic}] {msg.payload.decode()}")

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

client.on_connect = on_connect
client.on_message = on_message

client.tls_set(
    ca_certs=CA_CERT,
    certfile=CERT,
    keyfile=KEY
)

client.tls_insecure_set(False)

client.connect(BROKER, PORT)
client.loop_forever()
EOF

echo ""
echo "--------------------------------------"
echo "IoT Lab Environment Setup Complete"
echo "--------------------------------------"
echo ""
echo "Start containers with:"
echo ""
echo "   podman-compose up --build"
echo ""
echo "Node-RED UI:"
echo "   http://localhost:1880"
echo ""
echo "InfluxDB UI:"
echo "   http://localhost:8086"
echo ""