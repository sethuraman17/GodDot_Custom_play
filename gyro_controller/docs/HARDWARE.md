# Hardware & Board Notes

Reference for the physical setup and the non-obvious board quirks. These cost
real time to discover the first time — read this before touching a fresh board.

## Devices

| Thing | Value |
| ----- | ----- |
| Board | **Arduino UNO Q** (dual-brain: STM32U585 MCU + Qualcomm Linux SoC) |
| MCU FQBN | `arduino:zephyr:unoq` |
| adb device id | `215382934` (USB) |
| USB serial | `/dev/cu.usbmodem2153829342` (on the Mac) |
| Board web UI | `http://<board>:8090` → reach from host via `adb forward tcp:8090 tcp:8090` |

## Modulinos (Qwiic / I2C)

Connected on the Qwiic bus (daisy-chained). Detected and working:

| Modulino | Library class | Notable API |
| -------- | ------------- | ----------- |
| Movement (LSM6DSOX IMU) | `ModulinoMovement` | `getX/Y/Z()` = accel (g); `getRoll/Pitch/Yaw()` = **gyroscope** (deg/s), NOT orientation |
| Buttons (A/B/C) | `ModulinoButtons` | `update()`, `isPressed(0..2)`, `setLeds(a,b,c)` |
| Knob (rotary encoder + push) | `ModulinoKnob` | `get()` = abs position (int16), `isPressed()`, `getDirection()` |
| Buzzer | `ModulinoBuzzer` | `tone(freq, len_ms)`, `noTone()` |

> The Movement module's `getRoll/Pitch/Yaw` are misleadingly named — they are the
> raw gyro axes. Tilt (orientation) is computed on the Linux side from the
> accelerometer: `pitch = atan2(ax, hypot(ay,az))`, `roll = atan2(ay, az)`
> (unfolded ±180° — see ARCHITECTURE.md for why the hypot form is not used).

## Two brains, one bridge

The MCU and the Linux side talk over **Arduino RouterBridge**:

- Unix socket on Linux: `/var/run/arduino-router.sock`
- Protocol: **msgpack RPC**
  - Register for a topic: send `[0, 1, "$/register", ["<topic>"]]`
  - Notifications arrive as `[2, "<topic>", ["<payload string>"]]`
- MCU publishes with `Bridge.notify("<topic>", payload)`.
- Our topic: `modulino_controller`.

## USB-HID gadget quirks (IMPORTANT)

The Linux side exposes USB-HID gadget char devices to the host PC:

| Device | Role | **Report length** | Layout |
| ------ | ---- | ----------------- | ------ |
| `/dev/hidg0` | keyboard | **7 bytes** | `[modifiers, k1, k2, k3, k4, k5, k6]` — **no reserved byte** (non-standard!) |
| `/dev/hidg1` | mouse | **4 bytes** | `[buttons, x, y, scroll]` |

- Both devices are `crw-rw-rw-` (0666) → **no `sudo` needed** to write HID.
- The keyboard report has NO reserved byte, so a keycode goes in byte 1 (matches
  the sample `keyboard.py`). Up to 6 simultaneous keycodes + a modifier bitmask.
- Modifier bits: LeftShift = `0x02`. Keycodes: W=`0x1A` A=`0x04` S=`0x16`
  D=`0x07` Space=`0x2C`.
- Verified from configfs: `/sys/kernel/config/usb_gadget/g1/functions/hid.usb0/report_length`.

## Python environment on the board

- Python **3.13**, but **no `pip` and no `ensurepip`** (the board *does* have
  internet, but you can't `pip install` without bootstrapping pip).
- **Consequence:** prefer pure-stdlib code. `controller.py` bundles its own
  minimal msgpack encoder/decoder for exactly this reason — nothing to install.

## Arduino toolchain on the board

- `arduino-cli` **1.5.1** is preinstalled at `/usr/bin/arduino-cli`.
- **Libraries must be installed before first compile** (they sit cached in
  `.arduino15/internal` but aren't registered until installed):
  ```sh
  arduino-cli lib install Arduino_RouterBridge Arduino_Modulino
  ```
  `Arduino_Modulino` pulls deps (VL53L4CD/ED, LSM6DSOX, LPS22HB, …).
- Zephyr compile takes ~2 minutes.
- `arduino-cli upload` sometimes prints `Error: verify failed ... Adding extra
  erase range` yet still **exits 0 and succeeds** — re-run and trust the exit code.

## Common commands

```sh
adb devices                       # confirm board is attached
adb shell 'ls -l /dev/hidg*'      # confirm HID gadgets exist
adb shell 'ls -l /var/run/arduino-router.sock'
adb push gyro_controller /home/arduino/
adb shell 'cd /home/arduino/gyro_controller && arduino-cli compile -b arduino:zephyr:unoq .'
adb shell 'cd /home/arduino/gyro_controller && arduino-cli upload  -b arduino:zephyr:unoq .'
adb forward tcp:8090 tcp:8090
adb shell 'cd /home/arduino/gyro_controller && python3 controller.py'
adb shell 'pkill -f controller.py'   # stop it
```
