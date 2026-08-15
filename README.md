# ESP32-S3 LVGL hello world

This project targets the **Waveshare ESP32-S3-Touch-LCD-1.47**, standard
version without pre-soldered pinheaders (SKU 31202). Waveshare's
[product page](https://www.waveshare.com/esp32-s3-touch-lcd-1.47.htm) and
[documentation](https://docs.waveshare.com/ESP32-S3-Touch-LCD-1.47) confirm
the board has:

- an ESP32-S3R8 with 16 MB flash and 8 MB octal PSRAM;
- a 1.47-inch, 172×320 IPS display driven by a JD9853 over SPI; and
- an AXS5106L capacitive touch controller connected over I²C.

This is not the similarly named, non-touch `ESP32-S3-LCD-1.47`, which uses a
different display controller and pinout.

The firmware renders `hello world` in the center of the display using LVGL.
Touching the display changes the label to `touched` for two seconds, then
restores `hello world`. The LCD initialization and GPIO assignments follow
Waveshare's official schematic and demo.

## Build and flash

Install Nix with flakes enabled, then enter the pinned ESP-IDF environment:

```sh
nix develop
```

Build and flash the board:

```sh
idf.py build
idf.py -p /dev/ttyACM0 flash monitor
```

Replace `/dev/ttyACM0` if the board appears on another port. Exit the serial
monitor with `Ctrl-]`. The first build downloads the pinned LVGL 8.4.0 managed
component.

To discard generated configuration and build output before rebuilding:

```sh
idf.py fullclean
idf.py build
```

## USB access on Linux

The Nix shell cannot grant device permissions. On non-NixOS Linux, add your
user to the serial-device group (usually `dialout`) and log in again:

```sh
sudo usermod -aG dialout "$USER"
```
