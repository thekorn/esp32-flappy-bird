# ESP32-S3 experiments

A reproducible Linux development environment for an ESP32-S3 using
[ESP-IDF](https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/)
and Zig.

## Enter the environment

Install Nix with flakes enabled, then run:

```sh
nix develop
```

The shell contains the ESP32-S3 GCC toolchain, ESP-IDF, `idf.py`, Espressif's
OpenOCD, and a Zig compiler with the Espressif Xtensa backend. Both x86_64 and
ARM64 Linux hosts are supported. The lock file pins the complete toolchain.

The ESP32-S3 uses Xtensa. Upstream Zig does not currently support that target,
so this project deliberately uses the experimental
[`zig-espressif-bootstrap`](https://github.com/kassane/zig-espressif-bootstrap)
compiler rather than the ordinary Nixpkgs Zig package.

## Start an ESP-IDF experiment

Inside `nix develop`:

```sh
idf.py create-project blink --path experiments/blink
cd experiments/blink
idf.py set-target esp32s3
idf.py menuconfig
idf.py build
idf.py -p /dev/ttyACM0 flash monitor
```

Replace `/dev/ttyACM0` with the port shown when the board is connected. Exit
the serial monitor with `Ctrl-]`. `idf.py flash` will build first, so the
separate build command is optional after initial setup.

## Using Zig in firmware

The included Zig fork supports the ESP32-S3 target as:

```sh
zig build-obj source.zig -target xtensa-freestanding-none -mcpu=esp32s3
```

Zig-to-ESP-IDF integration is experimental. The practical approach is to
compile Zig into an object or static library, export a C ABI (`export fn`), and
link it from an ESP-IDF component. Keep the ESP-IDF entry point and hardware API
calls in a thin C component initially; this provides a stable boundary while
the Zig Xtensa toolchain evolves. A fuller reference integration is
[`zig-esp-idf-sample`](https://github.com/kassane/zig-esp-idf-sample).

## USB access on Linux

The Nix shell cannot grant device permissions. On non-NixOS Linux, add your
user to the serial-device group (usually `dialout`) and log in again:

```sh
sudo usermod -aG dialout "$USER"
```

If OpenOCD cannot access the ESP32-S3's built-in USB-JTAG interface, install
the udev rules documented by ESP-IDF or your board vendor.
