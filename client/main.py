import paho.mqtt.client as mqtt

BROKER = "mosquitto"
PORT = 8883

TOPICS = [
    "sensor/temperature",
    "sensor/humidity"
]

CA_CERT = "/client/certs/ca.crt"
CERT = "/client/certs/client.crt"
KEY = "/client/certs/client.key"


def on_connect(client, userdata, flags, reason_code, properties):
    print("Connected:", reason_code)
    for t in TOPICS:
        client.subscribe(t)
        print("Subscribed:", t)


def on_message(client, userdata, msg):
    print(f"[{msg.topic}] {msg.payload.decode()}")


client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

client.on_connect = on_connect
client.on_message = on_message

client.tls_set(
    ca_certs=CA_CERT,
    certfile=CERT,
    keyfile=KEY
)

client.tls_insecure_set(True)

client.connect(BROKER, PORT)
client.loop_forever()
