#!/usr/bin/bash
# build.sh

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
echo "Building the BLE container..."
echo

cd ble_engine/

podman build . -t io24m006/ble