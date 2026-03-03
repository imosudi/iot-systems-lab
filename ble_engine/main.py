

# main.py - Main entry point for the BLE engine application
# Imports
import time
from gi.repository import GLib

from modules.blemanager import BLEManager
from modules.utility import Decoder, local_time, value_change_handler
from modules.artifacts import device_id, service_uuid, temp_uuid, hum_uuid

# Global definitions
"""device_id = '94:A9:90:1C:78:15'

service_uuid    = '00002a05-0000-1000-8000-00805f9b34fb'
temp_uuid       = '00002a6e-0000-1000-8000-00805f9b34fb'
hum_uuid        = '00002a6f-0000-1000-8000-00805f9b34fb'"""
local_timestamp = local_time() 

blemanager = BLEManager()
blemanager.ensure_connected(device_id)

decoder = Decoder()

# Read temperature
temperature_raw = blemanager.read_characteristic(temp_uuid)
temperature = decoder.decode_temperature(temperature_raw)

# Read humidity
humidity_raw = blemanager.read_characteristic(hum_uuid)
humidity =  decoder.decode_humidity(humidity_raw)

print(f"[{local_timestamp}]: {temperature}, {humidity}")

def notification_handler(uuid, properties):
    value = properties.get("Value")
    if value is None:
        return
    if uuid == service_uuid:
        print("GATT database changed. Rediscovering services...")
        blemanager.disconnect()
        blemanager.ensure_connected(device_id)

    
    value_bytes = bytes(value)

    if uuid == temp_uuid or uuid == hum_uuid:
        temperature = decoder.decode_temperature(value_bytes)
        humidity    = decoder.decode_humidity(value_bytes)
         
        print(f"[{local_timestamp}]: {temperature}, {humidity}")

# Notification handler subscription
blemanager.subscribe(temp_uuid, notification_handler)
blemanager.subscribe(hum_uuid, notification_handler)
blemanager.subscribe(service_uuid, notification_handler)


mainloop = GLib.MainLoop()
try:
    mainloop.run()
except KeyboardInterrupt:
    mainloop.quit()
    blemanager.disconnect()


    