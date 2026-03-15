#!/bin/bash

podman-compose down
podman rm -f iot-systems-lab_ble_1
podman rm -f iot-systems-lab_mosquitto_1
podman rm -f iot-systems-lab_client_1
podman rm -f iot-systems-lab_influxdb_1
podman rm -f iot-systems-lab_backend_1
podman volume rm iot-systems-lab_mosquitto-data-storage >/dev/null 2>&1 || true
podman volume rm iot-systems-lab_mosquitto-log-storage >/dev/null 2>&1 || true
podman volume rm iot-systems-lab_influxdb-storage >/dev/null 2>&1 || true
podman volume rm iot-systems-lab_lab-storage >/dev/null 2>&1 || true
podman network rm iot-systems-lab_default >/dev/null 2>&1 || true