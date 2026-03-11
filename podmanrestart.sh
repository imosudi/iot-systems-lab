#!/bin/bash

podman-compose down
podman rm -f iot-systems-lab_ble_1
podman rm -f iot-systems-lab_mosquitto_1
podman rm -f iot-systems-lab_client_1