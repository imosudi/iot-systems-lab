#!/usr/bin/bash
# start.sh

set -e

MISSING=()

echo "Checking dependencies..."

# Check BlueZ
if command -v bluetoothctl &>/dev/null; then
    echo "BlueZ installed"
else
    echo "BlueZ missing!"
    MISSING+=("bluez")
fi

if command -v python3 &>/dev/null; then
    echo "Python3 installed"
else
    echo "Python3 missing"
    MISSING+=("python3")
fi

# Check python3-pydbus
if python3 -c "import pydbus" &>/dev/null; then
    echo "python3-pydbus installed"
else
    echo "python3-pydbus missing!"
    MISSING+=("python3-pydbus")
fi


# Check Podman
if command -v podman &>/dev/null; then
    echo "Podman installed"
else
    echo "Podman missing!"
    MISSING+=("podman")
fi

# Install missing packages
if [ ${#MISSING[@]} -eq 0 ]; then
    echo ""
    echo "All dependencies are satisfied."
else
    echo ""
    echo "Installing missing packages: ${MISSING[*]}"
    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get install -y "${MISSING[@]}"
    echo ""
    echo "Done. All dependencies installed."
fi

echo ""
echo "Starting the BLE container..."
echo

podman run --userns=keep-id -v \
    /run/dbus:/run/dbus:z \
    -it io24m006/ble:latest 