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

## Build the Zig hello-world firmware

Inside `nix develop`:

```sh
idf.py build
idf.py -p /dev/ttyACM0 flash monitor
```

Replace `/dev/ttyACM0` with the port shown when the board is connected. Exit
the serial monitor with `Ctrl-]`. `idf.py flash` will build first, so the
separate build command is optional after initial setup. On boot, the firmware
logs `Hello, world from Zig on ESP32-S3!`.

The project is fixed to the ESP32-S3 target in its top-level `CMakeLists.txt`.
Its ESP-IDF `main` component compiles `main/hello.zig` to an Xtensa object with
the pinned Zig compiler, then links that object into the firmware. The C entry
point only calls the exported Zig function and passes its result to ESP-IDF's
logging API, keeping the boundary with ESP-IDF explicit and small.

To discard all generated configuration and build output before rebuilding:

```sh
idf.py fullclean
idf.py build
```

Zig-to-ESP-IDF integration and the Xtensa Zig backend are experimental. New
experiments can follow the same pattern: put portable logic behind exported C
ABI functions in Zig and keep calls into ESP-IDF in a thin C component.

## USB access on Linux

The Nix shell cannot grant device permissions. On non-NixOS Linux, add your
user to the serial-device group (usually `dialout`) and log in again:

```sh
sudo usermod -aG dialout "$USER"
```

If OpenOCD cannot access the ESP32-S3's built-in USB-JTAG interface, install
the udev rules documented by ESP-IDF or your board vendor.
