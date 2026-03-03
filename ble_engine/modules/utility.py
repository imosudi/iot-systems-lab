# modules/utility.py

from datetime import datetime
from typing import Iterable


def normalise_bytes(value: Iterable[int] | bytes | bytearray) -> bytes:
    if isinstance(value, (bytes, bytearray)):
        return bytes(value)
    return bytes(int(v) & 0xFF for v in value)


def local_time() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")

def value_change_handler(iface, prop_changed, prop_removed):
    if 'Value' in prop_changed:
        print(f"Value: {prop_changed['Value']}")

class Decoder:

    @staticmethod
    def decode_temperature(value) -> float:
        raw = int.from_bytes(value, "little", signed=True)
        return raw / 100.0

    @staticmethod
    def decode_humidity(value) -> float:
        raw = int.from_bytes(value, "little", signed=False)
        return raw / 100.0