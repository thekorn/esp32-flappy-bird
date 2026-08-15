# ESP32-S3 Zig + LVGL hello world

An interactive graphical hello world written in Zig for the Waveshare
ESP32-S3-Touch-LCD-1.47.

## Current state

The firmware:

- renders `hello world` in the center of the display with LVGL;
- changes the label to `touched` when the screen is pressed;
- restores `hello world` after two seconds; and
- polls the capacitive touch controller over I²C.

It builds with the pinned toolchain, has been flashed to the real board, and
boots stably with its 8 MB PSRAM detected. The display and touch hardware were
exercised with the original C application; after moving the application state
machine to Zig, the resulting firmware build and boot were validated again.

The application entry point and UI state machine live in
[`main/main.zig`](main/main.zig). [`main/platform.c`](main/platform.c) is a thin
adapter around the C APIs provided by ESP-IDF and LVGL: it initializes the
display and touch buses, flushes LVGL draw buffers, reads the touch controller,
and exposes timing and label operations to Zig.

The build uses:

- ESP-IDF 5.5.2;
- the experimental Xtensa Zig 0.17.0 toolchain from
  [`zig-espressif-bootstrap`](https://github.com/kassane/zig-espressif-bootstrap);
  and
- LVGL 8.4.0 from the ESP Component Registry.

## Hardware

The target is the **Waveshare ESP32-S3-Touch-LCD-1.47**, standard version
without pre-soldered pinheaders (**SKU 31202**):

- ESP32-S3R8, dual-core Xtensa LX7 at up to 240 MHz;
- 16 MB flash and 8 MB octal PSRAM;
- 1.47-inch 172×320 IPS display;
- JD9853 display controller using 4-wire SPI;
- AXS5106L capacitive touch controller using I²C; and
- native USB Serial/JTAG over USB-C.

Official references:

- [Waveshare product page](https://www.waveshare.com/esp32-s3-touch-lcd-1.47.htm)
- [Waveshare documentation](https://docs.waveshare.com/ESP32-S3-Touch-LCD-1.47)

This is **not** the similarly named non-touch `ESP32-S3-LCD-1.47`. That board
uses an ST7789 display controller and a different pinout.

### Display and touch connections

| Function | GPIO |
| --- | ---: |
| LCD SPI clock | 38 |
| LCD SPI MOSI | 39 |
| LCD reset | 40 |
| LCD chip select | 21 |
| LCD data/command | 45 |
| LCD backlight | 46 |
| Touch I²C SCL | 41 |
| Touch I²C SDA | 42 |
| Touch reset | 47 |
| Touch interrupt | 48 |

The touch interrupt is wired but the current firmware polls the controller.
The GPIO assignments and JD9853 initialization sequence follow Waveshare's
official schematic and demo.

## Build and run

### Prerequisites

Install [Nix](https://nixos.org/download/) with flakes enabled. The flake
supports x86_64 and ARM64 Linux and supplies ESP-IDF, the ESP32-S3 GCC
toolchain, esptool, OpenOCD, and the Xtensa Zig compiler.

Enter the development environment from the repository root:

```sh
nix develop
```

The first build downloads the pinned LVGL managed component. Build the
firmware with:

```sh
idf.py build
```

Connect the board over USB-C, then flash it and open the serial monitor:

```sh
idf.py -p /dev/ttyACM0 flash monitor
```

Replace `/dev/ttyACM0` with the port assigned to the board. Flashing resets
the board and starts the firmware automatically. Exit the monitor with
`Ctrl-]`.

After startup, the display should show `hello world`. Touch the display to see
`touched`; it changes back after two seconds.

To remove generated configuration and build output before rebuilding:

```sh
idf.py fullclean
idf.py build
```

## USB permissions on Linux

The Nix shell cannot grant device permissions. On non-NixOS Linux, add your
user to the serial-device group (usually `dialout`) and log in again:

```sh
sudo usermod -aG dialout "$USER"
```

If USB-JTAG access fails, install the ESP-IDF udev rules for your system.
