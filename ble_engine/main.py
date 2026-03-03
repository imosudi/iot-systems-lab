# modules/main.py

from gi.repository import GLib

from modules.blemanager import BLEManager
from modules.utility import Decoder, local_time

DEVICE_ID = "94:A9:90:1C:78:15"

SERVICE_UUID = "00002a05-0000-1000-8000-00805f9b34fb"
TEMP_UUID = "00002a6e-0000-1000-8000-00805f9b34fb"
HUM_UUID = "00002a6f-0000-1000-8000-00805f9b34fb"


ble = BLEManager()
ble.ensure_connected(DEVICE_ID)

# Initial read
latest_temperature = Decoder.decode_temperature(
    ble.read_characteristic(TEMP_UUID)
)

latest_humidity = Decoder.decode_humidity(
    ble.read_characteristic(HUM_UUID)
)

print(f"[{local_time()}] {latest_temperature:.2f} °C, {latest_humidity:.2f} %")


def notification_handler(uuid, properties):
    global latest_temperature, latest_humidity

    value = properties.get("Value")
    if value is None:
        return

    updated = False

    if uuid == TEMP_UUID:
        new_temp = Decoder.decode_temperature(value)
        if new_temp != latest_temperature:
            latest_temperature = new_temp
            updated = True

    elif uuid == HUM_UUID:
        new_hum = Decoder.decode_humidity(value)
        if new_hum != latest_humidity:
            latest_humidity = new_hum
            updated = True

    elif uuid == SERVICE_UUID:
        print(f"[{local_time()}] Service changed — reconnecting")
        ble.disconnect()
        ble.ensure_connected(DEVICE_ID)
        return

    if updated:
        print(f"[{local_time()}] {latest_temperature:.2f} °C, {latest_humidity:.2f} %")


ble.subscribe(TEMP_UUID, notification_handler)
ble.subscribe(HUM_UUID, notification_handler)
ble.subscribe(SERVICE_UUID, notification_handler)

loop = GLib.MainLoop()

try:
    loop.run()
except KeyboardInterrupt:
    loop.quit()
    ble.disconnect()