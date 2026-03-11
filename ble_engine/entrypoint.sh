#!/bin/bash
echo ""
echo ""
#entrypoint.sh
printf "MQTT [BLE Publisher] container started...\n"

exec python3 main.py
