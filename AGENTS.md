# Project guidance

## Project and architecture

- This repository targets the Waveshare ESP32-S3-Touch-LCD-1.47, standard
  version without pinheaders (SKU 31202). It has an ESP32-S3R8, 16 MB flash,
  8 MB octal PSRAM, a 172×320 JD9853 LCD, and an AXS5106L touch controller.
- Keep the application implementation in Zig. `main/main.zig` owns
  `app_main`, UI state, and application behavior.
- Keep `main/platform.c` as the thin C interoperability and hardware adapter
  for ESP-IDF and LVGL APIs. Do not move application behavior back into C just
  because the vendor and ESP-IDF examples are written in C.
- LVGL is an ESP-IDF managed component pinned in `main/idf_component.yml`.
  Do not edit generated content under `managed_components/`.
- Put durable ESP-IDF configuration defaults in `sdkconfig.defaults`. Treat
  `sdkconfig` and `build/` as generated build state unless a task specifically
  requires otherwise.

## Development and verification

- Use the Nix flake development environment; do not rely on globally installed
  ESP-IDF or Zig versions.
- Build with `nix develop -c idf.py build`.
- Use `nix flake check --no-build` when changing the flake.
- For firmware changes, verify the build first. Test on real hardware when the
  behavior depends on the LCD, touch controller, boot configuration, or other
  peripherals. Report build verification separately from physical-device
  verification.

## Real hardware

- Real-device access must use the Amp runner named `thekorn-server-2`; the
  board is expected to be connected there. Do not try to access ESP32 hardware
  from an orb or a different runner.
- Resolve the live runner by name immediately before starting hardware work;
  runner IDs are ephemeral.
- Prefer the stable `/dev/serial/by-id/` path over `/dev/ttyACM0` when flashing
  or monitoring. Detect the actual path rather than assuming a serial number.
- The connected target should identify as an Espressif native USB Serial/JTAG
  device and as an ESP32-S3. Do not flash if the detected target does not match.
- If `thekorn-server-2` is unavailable or the expected board is not connected,
  ask the user to start the runner or connect the device. Do not silently use
  another machine, and do not claim hardware validation without the board.
- Flash using the artifacts and parameters produced by `idf.py`; avoid
  hard-coded offsets or flash parameters when ESP-IDF can supply them. Capture
  startup serial output and check for `app_main`, errors, panics, and reset
  loops. For display or touch changes, serial output alone is not sufficient:
  ask for or obtain confirmation of the physical UI behavior.

See `README.md` for the hardware pin map and normal build, flash, and monitor
commands.
