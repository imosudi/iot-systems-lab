

# modules/utility.py


from datetime import datetime, timezone
from typing import Iterable


def _normalise_bytes(value: Iterable[int] | bytes | bytearray) -> bytes:
    """
    DBus/pydbus value to bytes.
    """
    if isinstance(value, (bytes, bytearray)):
        return bytes(value)
    return bytes(value)


def value_change_handler(iface: str, changed: dict, invalidated: list):
    """
    DBus handler for BlueZ GATT characteristics.
    """
    value = changed.get("Value")
    if value is not None:
        print(f"Notification received: {bytes(value)}")

def local_time():
    """ Generate local timestamp """
    #timestamp = datetime.now(timezone.utc).isoformat()
    timestamp = datetime.now().astimezone().isoformat()
    return timestamp


class Decoder_alt:
    def decode_temperature(self, value: list[int]) -> float:
        """Returns temperature in °C"""
        raw = int.from_bytes(value, byteorder='little', signed=True)
        return f"{raw / 100.0:.2f} °C"

    def decode_humidity(self, value: list[int]) -> float:
        """Returns relative humidity in %"""
        raw = int.from_bytes(value, byteorder='little', signed=False)
        return f"{raw / 100.0:.2f} %"

class Decoder:
    """Decoder for BLE characteristic values."""
    def decode_temperature(self, value) -> str:
        raw = int.from_bytes(bytes(value), byteorder='little', signed=True)
        return f"{raw / 100:.2f} °C"

    def decode_humidity(self, value) -> str:
        raw = int.from_bytes(bytes(value), byteorder='little', signed=False)
        return f"{raw / 100:.2f} %"
    
    