# modules/main.py

from gi.repository import GLib

from modules.blemanager import BLEManager
from modules.utility import Decoder, local_time
from artifacts import device_id, temp_uuid, hum_uuid, service_uuid
#import artifacts

ble = BLEManager()
ble.ensure_connected(device_id)

# Initial read
latest_temperature = Decoder.decode_temperature(
    ble.read_characteristic(temp_uuid)
)

latest_humidity = Decoder.decode_humidity(
    ble.read_characteristic(hum_uuid)
)

print(f"[{local_time()}] {latest_temperature:.2f} °C, {latest_humidity:.2f} %")


def notification_handler(uuid, properties):
    global latest_temperature, latest_humidity

    value = properties.get("Value")
    if value is None:
        return

    updated = False

    if uuid == temp_uuid:
        new_temp = Decoder.decode_temperature(value)
        if new_temp != latest_temperature:
            latest_temperature = new_temp
            updated = True

    elif uuid == hum_uuid:
        new_hum = Decoder.decode_humidity(value)
        if new_hum != latest_humidity:
            latest_humidity = new_hum
            updated = True

    elif uuid == service_uuid:
        print(f"[{local_time()}] Service changed — reconnecting")
        ble.disconnect()
        ble.ensure_connected(device_id)
        return

    if updated:
        print(f"[{local_time()}] {latest_temperature:.2f} °C, {latest_humidity:.2f} %")


ble.subscribe(temp_uuid, notification_handler)
ble.subscribe(hum_uuid, notification_handler)
ble.subscribe(service_uuid, notification_handler)

loop = GLib.MainLoop()

try:
    loop.run()
except KeyboardInterrupt:
    loop.quit()
    ble.disconnect()