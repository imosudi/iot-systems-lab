#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
CERT_DIR="$PROJECT_DIR/tlscertsops"
MOSQ_DIR="$PROJECT_DIR/mosquitto"
CLIENT_DIR="$PROJECT_DIR/client"

DATA_DIR="$HOME/iot_storage"
LAB_DIR="$HOME/lab-storage"

echo "Setting up IoT lab environment..."

# ─────────────────────────────────────────────────────────────
# Directories
# ─────────────────────────────────────────────────────────────
mkdir -p \
  "$MOSQ_DIR/certs" \
  "$CLIENT_DIR/certs" \
  "$DATA_DIR/mosquitto-data-storage" \
  "$DATA_DIR/mosquitto-log-storage" \
  "$LAB_DIR"

# ─────────────────────────────────────────────────────────────
# Copy certificates
# ─────────────────────────────────────────────────────────────
cp "$CERT_DIR/mosquitto/"{ca.crt,mosquitto.crt,mosquitto.key} "$MOSQ_DIR/certs/"
cp "$CERT_DIR/client/"{ca.crt,client.crt,client.key} "$CLIENT_DIR/certs/"

# ─────────────────────────────────────────────────────────────
# podman-compose.yml
# ─────────────────────────────────────────────────────────────
cat > "$PROJECT_DIR/podman-compose.yml" <<EOF
version: "3"

services:

  ble:
    build: ble_engine
    volumes:
      - /run/dbus:/run/dbus:rw,z
    network_mode: host
    privileged: true

  mosquitto:
    build: mosquitto
    restart: unless-stopped
    environment:
      TZ: Europe/Vienna
    ports:
      - "8883:8883"
    volumes:
      - ${DATA_DIR}/mosquitto-data-storage:/mosquitto/data
      - ${DATA_DIR}/mosquitto-log-storage:/mosquitto/log
      - ./mosquitto/mosquitto.conf:/mosquitto/config/mosquitto.conf:Z

  client:
    build: client
    restart: unless-stopped
    depends_on:
      - mosquitto
EOF

# ─────────────────────────────────────────────────────────────
# mosquitto.conf
# ─────────────────────────────────────────────────────────────
cat > "$MOSQ_DIR/mosquitto.conf" <<'EOF'
persistence true
persistence_location /mosquitto/data

log_dest stdout
log_type error
log_type warning
log_type notice
log_type information

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
FROM docker.io/eclipse-mosquitto:latest

COPY certs/* /mosquitto/config/

RUN touch /mosquitto/config/passwd \
 && chmod 600 /mosquitto/config/* \
 && chown mosquitto:mosquitto /mosquitto/config/*
EOF

# ─────────────────────────────────────────────────────────────
# Client Containerfile
# ─────────────────────────────────────────────────────────────
cat > "$CLIENT_DIR/Containerfile" <<'EOF'
FROM debian:stable-slim

RUN apt-get update \
 && apt-get install -y python3 python3-paho-mqtt \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /client

COPY certs /client/certs
COPY main.py .

CMD ["python3", "main.py"]
EOF

# ─────────────────────────────────────────────────────────────
# MQTT client
# ─────────────────────────────────────────────────────────────
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

client.tls_insecure_set(True)

client.connect(BROKER, PORT)
client.loop_forever()
EOF

echo ""
echo "Setup complete."
echo ""
echo "Run:"
echo "  podman-compose up --build"