import time
import pydbus


class BLEManager:
    BLUEZ_SERVICE = "org.bluez"

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
            dev = ifaces.get("org.bluez.Device1")
            if dev and dev.get("Address") == mac:
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
        Full deterministic BLE lifecycle:
        power -> discover -> connect -> wait for services
        """

        # Ensure adapter powered
        if not self.adapter.Powered:
            self.adapter.Powered = True

        # Start discovery
        self.adapter.StartDiscovery()

        if not self._wait_for_condition(lambda: self.adapter.Discovering, 5):
            raise RuntimeError("Discovery failed to start")

        # Wait for device discovery
        if not self._wait_for_condition(
            lambda: self._resolve_device(mac_address)
        ):
            self.adapter.StopDiscovery()
            raise RuntimeError("Device not discovered")

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

    def read_characteristic(self, uuid):
        if not self.device or not self.device.ServicesResolved:
            raise RuntimeError("Device not connected or services not resolved")

        char_path = self._get_characteristic_path(uuid)
        if not char_path:
            raise RuntimeError("Characteristic not found")

        char = self.bus.get(self.BLUEZ_SERVICE, char_path)
        #char.ReadValue({})
        return char 

    def disconnect(self):
        if self.device and self.device.Connected:
            self.device.Disconnect()
            self._wait_for_condition(lambda: not self.device.Connected, 5)