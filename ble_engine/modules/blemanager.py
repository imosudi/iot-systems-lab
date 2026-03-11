

# modules/blemanager.py

import time
import pydbus
from typing import Callable, Dict, Any



class BLEManager:
    BLUEZ_SERVICE = "org.bluez"
    GATT_CHAR_IFACE = "org.bluez.GattCharacteristic1"

    def __init__(self, adapter="hci0", timeout=20):
        self.adapter_path = f"/org/bluez/{adapter}"
        self.timeout = timeout

        self.bus = pydbus.SystemBus()
        self.mngr = self.bus.get(self.BLUEZ_SERVICE, "/")
        self.adapter = self.bus.get(self.BLUEZ_SERVICE, self.adapter_path)

        self.device_path = None
        self.device = None


    def _wait_for_condition(self, condition_fn, timeout=None, interval=0.2):
        timeout = timeout or self.timeout
        start = time.time()
        while time.time() - start < timeout:
            if condition_fn():
                return True
            time.sleep(interval)
        return False

    def _get_device_path(self, mac):
        objects = self.mngr.GetManagedObjects()
        for path, ifaces in objects.items():
            dev = ifaces.get(f"{self.BLUEZ_SERVICE}.Device1")
            if dev and dev.get("Address") == mac:
                #print(f"Found device at {path}"); #time.sleep(100)
                return path
        return None

    def _get_characteristic_path(self, uuid):
        objects = self.mngr.GetManagedObjects()
        for path, ifaces in objects.items():
            char = ifaces.get("org.bluez.GattCharacteristic1")
            if char and char.get("UUID") == uuid and path.startswith(self.device_path):
                return path
        return None

    def ensure_connected(self, mac_address):
        """
        Full deterministic BLE lifecycle: power on -> discover -> connect -> wait for services
        """

        # Ensure adapter powered
        if not self.adapter.Powered:
            self.adapter.Powered = True

        # Start discovery
        self.adapter.StartDiscovery()

        if not self._wait_for_condition(lambda: self.adapter.Discovering, 5):
            raise RuntimeError("Discovery failed to start")

        # Wait for device discovery
        print(f"Searching for device with MAC address: {mac_address}...")
        while True:
            if self._wait_for_condition(
                lambda: self._resolve_device(mac_address), timeout=5
            ):
                break
            print(f"Alert: Device with MAC address {mac_address} is not reachable/available. Continuing to wait...")
            print("Press Ctrl+C to stop the application")

        # Stop discovery
        self.adapter.StopDiscovery()
        self._wait_for_condition(lambda: not self.adapter.Discovering, 5)

        # Connect
        if not self.device.Connected:
            self.device.Connect()

        if not self._wait_for_condition(lambda: self.device.Connected):
            raise RuntimeError("Connection failed")

        # Wait for services
        if not self._wait_for_condition(lambda: self.device.ServicesResolved):
            raise RuntimeError("Services not resolved")

        return self.device

    def _resolve_device(self, mac):
        self.device_path = self._get_device_path(mac)
        if self.device_path:
            self.device = self.bus.get(self.BLUEZ_SERVICE, self.device_path)
            return True
        return False

    def write_characteristic(self, uuid, value_bytes):
        if not self.device or not self.device.ServicesResolved:
            raise RuntimeError("Device not connected or services not resolved")

        char_path = self._get_characteristic_path(uuid) #31
        if not char_path:
            raise RuntimeError("Characteristic not found")

        char = self.bus.get(self.BLUEZ_SERVICE, char_path)
        char.WriteValue(value_bytes, {})

    def read_characteristic_alt(self, uuid):
        if not self.device or not self.device.ServicesResolved:
            raise RuntimeError("Device not connected or services not resolved")

        char_path = self._get_characteristic_path(uuid)
        if not char_path:
            raise RuntimeError("Characteristic not found")
        #print(f"Reading characteristic at {char_path}")
        #print(f"self.BLUEZ_SERVICE: {self.BLUEZ_SERVICE}")
        char = self.bus.get(self.BLUEZ_SERVICE, char_path)
        props = char.GetAll(f"{self.BLUEZ_SERVICE}.GattCharacteristic1")

        #print(f"char: {char.GetAll('org.bluez.GattCharacteristic1')}")
        #time.sleep(100)
        if 'read' not in props.get('Flags', []):
            #raise RuntimeError(
            print(
                f"Characteristic {uuid} does not support read (flags: {props['Flags']})"
            )
            return props, char
        try:
            char.ReadValue({})
        except Exception as e:
            print(f"Error reading characteristic: {e}")
            #raise

        return char 
 
    def read_characteristic(self, uuid):
        if not self.device or not self.device.ServicesResolved:
            raise RuntimeError("Device not connected or services not resolved")

        char_path = self._get_characteristic_path(uuid)
        if not char_path:
            raise RuntimeError("Characteristic not found")

        char = self.bus.get(self.BLUEZ_SERVICE, char_path)

        value = char.ReadValue({}); time.sleep(4)
        #print(f"Raw value for {uuid}: {value}")
        return bytes(value)

    def subscribe(self, uuid: str, callback: Callable[[str, Dict[str, Any]], None]):
        """
        Subscribe to notifications for a characteristic.
        """
        if not self.device or not self.device.ServicesResolved:
            raise RuntimeError("Device not connected or services not resolved")

        char_path = self._get_characteristic_path(uuid)
        if not char_path:
            raise RuntimeError(f"Characteristic {uuid} not found")

        char = self.bus.get(self.BLUEZ_SERVICE, char_path)
        

        """char = self._get_char_proxy(uuid)
        flags = char.GetAll(self.GATT_CHAR_IFACE).get("Flags", [])"""

        # Check if characteristic supports notifications
        props = char.GetAll(self.GATT_CHAR_IFACE)
        flags = props.get("Flags", [])
        
        if "notify" not in flags and "indicate" not in flags:
            raise RuntimeError(f"Characteristic {uuid} does not support notifications")

        # Define a wrapper that includes the UUID in the callback
        """def value_change_handler(iface, prop_changed, prop_removed):
            if 'Value' in prop_changed:
                print(f"Value: {prop_changed['Value']}")"""
                
        def value_change_handler(iface, prop_changed, prop_removed):
            if iface == self.GATT_CHAR_IFACE:
                # Check if this is a notification (Value present)
                if "Value" in prop_changed:
                    callback(uuid, prop_changed)

        #char.onPropertiesChanged = callback
        
        # Connect to the PropertiesChanged signal
        char.onPropertiesChanged = value_change_handler
        
        # Start notifications
        char.StartNotify()
        
        return char
    
    def disconnect(self):
        if self.device and self.device.Connected:
            self.device.Disconnect()
            self._wait_for_condition(lambda: not self.device.Connected, 5)


