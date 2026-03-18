# modules/main.py

from gi.repository import GLib
import time

from modules.blemanager import BLEManager
from modules.utility import Decoder, local_time
from artifacts import device_id, temp_uuid, hum_uuid, service_uuid
import paho.mqtt.client as mqtt

ble = BLEManager()
ble.ensure_connected(device_id)


BROKER = "mosquitto"
PORT   = 8883

CA_CERT  = "/ble_certs/certs/ca.crt"
CRT_FILE = "/ble_certs/certs/ble.crt"
KEY_FILE = "/ble_certs/certs/ble.key"


TOPIC_TEMPERATURE = "sensor/temperature"
TOPIC_HUMIDITY    = "sensor/humidity"


# ── MQTT callbacks ────────────────────────────────────────────────

def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code == 0:
        print("[mqtt] BLE Connected successfully")
    else:
        print(f"[mqtt] BLE Connection failed: {reason_code}")


def on_disconnect(client, userdata, flags, reason_code, properties):
    print(f"[mqtt] Disconnected (reason code: {reason_code})")



# ── MQTT client initialisation ────────────────────────────────────

mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

mqtt_client.on_connect    = on_connect
mqtt_client.on_disconnect = on_disconnect

mqtt_client.tls_set(
    ca_certs=CA_CERT,
    certfile=CRT_FILE,
    keyfile=KEY_FILE
)

# Required when using self-signed CA
mqtt_client.tls_insecure_set(True)

#mqtt_client.connect(BROKER, PORT, 60)
while True:
    try:
        mqtt_client.connect(BROKER, PORT, 60)
        break
    except Exception:
        print("Waiting for MQTT broker...")
        time.sleep(2)

mqtt_client.loop_start()

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
            print(f"[{local_time()}] {latest_temperature:.2f} °C, {latest_humidity:.2f} %")
            mqtt_client.publish(
                TOPIC_TEMPERATURE,
                f"{latest_temperature:.2f}",
                qos=1,
                retain=False
            )

    elif uuid == hum_uuid:
        new_hum = Decoder.decode_humidity(value)
        if new_hum != latest_humidity:
            latest_humidity = new_hum
            updated = True
            print(f"[{local_time()}] {latest_temperature:.2f} °C, {latest_humidity:.2f} %")
            mqtt_client.publish(
                TOPIC_HUMIDITY,
                f"{latest_humidity:.2f}",
                qos=1,
                retain=False
            )

    elif uuid == service_uuid:
        print(f"[{local_time()}] Service changed — reconnecting")
        ble.disconnect()
        ble.ensure_connected(device_id)
        return

ble.subscribe(temp_uuid, notification_handler)
ble.subscribe(hum_uuid, notification_handler)
ble.subscribe(service_uuid, notification_handler)

loop = GLib.MainLoop()

try:
    loop.run()
except KeyboardInterrupt:
    loop.quit()
    ble.disconnect()