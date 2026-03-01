#!/usr/bin/bash

# start.sh
podman run --userns=keep-id -v \
    /run/dbus:/run/dbus:z \
    -it localhost/imosudi/ble_engine:latest 