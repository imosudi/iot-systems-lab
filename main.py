# Imports
import time
from gi.repository import GLib

from modules.blemanager import BLEManager
from modules.utility import value_change_handler


# Global definitions
#bluez_service = 'org.bluez'
#adapter_path = '/org/bluez/hci0'
#dev_id = '3C:84:27:DC:47:55'
device_id = '94:A9:90:1C:78:15'
led_uuid = '1ab6a9d3-abd6-41ea-b01a-e880761f692c'
btn_uuid = '45ae2763-c261-484d-be42-8ad2757b3439'

# BLE code
#bus = pydbus.SystemBus()
#mngr = bus.get(bluez_service, '/')
#adapter = bus.get(bluez_service, adapter_path)
#device_path = f"{adapter_path}/dev_{dev_id.replace(':', '_')}"
#device_path = f"{adapter_path}/dev_{device_id.replace(':', '_')}"
#device = bus.get(bluez_service, device_path)
#device.Connect()

blemanager = BLEManager()
device = blemanager.ensure_connected(device_id)
blemanager.ensure_connected(device_id)



#led_char_path = get_characteristic_path(device._path, led_uuid)
#led = bus.get(bluez_service, led_char_path)
#new_value = int(1).to_bytes(1, byteorder='little')
#led.WriteValue(new_value, {})
#time.sleep(5)
#new_value = int(0).to_bytes(1, byteorder='little')
#led.WriteValue(new_value, {})
#time.sleep(1)

led_char_path = blemanager._get_characteristic_path(led_uuid)
new_value = int(1).to_bytes(1, byteorder='little')
#led = blemanager.write_characteristic(led_uuid, new_value); time.sleep(5)
blemanager.write_characteristic(led_uuid, new_value); time.sleep(5)

new_value = int(0).to_bytes(1, byteorder='little')
#led = blemanager.write_characteristic(led_uuid, new_value); time.sleep(1)
blemanager.write_characteristic(led_uuid, new_value); time.sleep(1)

#btn_char_path = get_characteristic_path(device._path, btn_uuid)
#btn = bus.get(bluez_service, btn_char_path)
#print(btn.ReadValue({}))

btn_char_path = blemanager._get_characteristic_path(btn_uuid)
btn = blemanager.read_characteristic(btn_uuid)
print(btn.ReadValue({}))

btn.onPropertiesChanged = value_change_handler
btn.StartNotify()

# Mainloop code
mainloop = GLib.MainLoop()
try:
    mainloop.run()
except KeyboardInterrupt:
    mainloop.quit()
    btn.StopNotify()
    device.Disconnect()