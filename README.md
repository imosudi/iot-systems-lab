# iot-systems-lab
---

## 1. Overview

This lab covers hands-on IoT projects spanning sensor node design, edge gateways, and cloud backends, built on Linux, Podman, and distributed communication protocols. The project demonstrates real-time data generation, communication, and visualisation using an ESP32 microcontroller and a DHT22 temperature/humidity sensor.


# What You Will Build

- ESP32 firmware (Arduino/FreeRTOS) that reads temperature and humidity from a DHT22 sensor
- Dual-channel data broadcast over UART serial and Bluetooth Low Energy (BLE)
- A containerised edge gateway running inside Podman on Linux

---

## 2. Hardware Requirements

### Components

- ESP32 development board (any variant with BLE support)
- DHT22 temperature and humidity sensor
- Jumper wires (female-to-female or female-to-male as needed)
- USB cable for programming and serial communication

### DHT22 Wiring

| DHT22 Pin         | ESP32 Pin | Notes                                     |
|-------------------|-----------|-------------------------------------------|
| DHT – (GND)       | GND       | Ground                                    |
| DHT + (VCC)       | +3V3      | 3.3 V supply (**do NOT use 5 V**)   |
| DHT Signal Wire (S) | Pin 21  | GPIO 21, data line                        |

> ⚠️ Ensure the +3V3 rail is used. Driving the DHT22 at 5 V may damage the ESP32 GPIO pin.

---

## 3. Firmware

The ESP32 firmware will be provided as an Arduino/FreeRTOS project in a subsequent lab release. I might also share an available firware if/when I am able to get permission. It performs the following tasks:

1. Initialises the DHT22 sensor on GPIO 21
2. Reads temperature (°C) and relative humidity (%) at a configurable interval
3. Broadcasts readings over UART serial (for wired debugging)
4. Advertises readings over BLE (for wireless edge gateway ingestion)

> Upload steps will be documented when the firmware is released. Ensure the Arduino IDE or PlatformIO toolchain is installed and the correct ESP32 board package is selected before flashing.

---

## 4. Software Setup

### Power On the ESP32

Connect the ESP32 to a USB port on your host machine. Confirm the device enumerates (e.g. `/dev/ttyUSB0` or `/dev/ttyACM0`) before proceeding. Complete the firware upload procedure, and allow the ESP32 to remain powered on.

### Clone the Repository

```bash
git clone https://github.com/imosudi/iot-systems-lab
cd iot-systems-lab
```

### Build and Start

Pull the latest changes, build the Podman container image, and start the gateway:

```bash
git pull && ./build.sh && ./start.sh
```

The build script constructs the container image. The start script launches the container with the necessary Bluetooth and serial device privileges.


---

## 5. Platform Compatibility

All devices must have Bluetooth hardware support.

| Platform                        | Status       | Notes                                                      |
|---------------------------------|--------------|------------------------------------------------------------|
| Ubuntu 24.04 (laptop/desktop)   | ✅ Tested    | Primary development platform                               |
| Raspberry Pi 5                  | ✅ Tested    | Full support                                               |
| Orange Pi                       | ✅ Tested    | Requires UID/GID mapping tools for rootless Podman         |
| Other SBCs                      | ⚠️ Expected  | Bluetooth support required                                 |



Note: This has been tested on Ubuntu 24.04 laptops (should work on desktops), Raspberry Pi 5, Orange Pi (this necessitated the inclussing of UID/GID mapping tools installation to o run Podman in rootless mode), It should work on similar single board computers. All devices must have bluetooth support

---


## 6. License

This project is licensed under the **BSD 3-Clause License** - see the [LICENSE](./LICENSE) file for details.

```
BSD 3-Clause License

Copyright (c) 2026, Mosudi Isiaka
All rights reserved.
```

---

## 7. 👤 Author

**Mosudi Isiaka O.**  
📧 [mosudi.isiaka@gmail.com](mailto:mosudi.isiaka@gmail.com)  | [FH Technikum Wiem email](mailto:io24m006@technikum-wien.at)  
🌐 [https://mioemi.com](https://mioemi.com)   
💻 [https://github.com/imosudi](https://github.com/imosudi)

---