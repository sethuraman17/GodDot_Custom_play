# Gyro / Tilt HID Game Controller (Arduino UNO Q + Modulinos)

Turns the UNO Q + Modulinos into a USB game controller for the host PC:

| Modulino            | Action                                             |
| ------------------- | -------------------------------------------------- |
| **Movement** (IMU)  | Tilt board fwd/back/left/right → **W / S / A / D**  |
| Movement (tilt depth) | Deeper tilt → **faster run** (analog sprint, in 10% steps) |
| Movement (gyro)     | Fast **flick** → momentary WASD nudge (hybrid)     |
| **Buttons** – A     | **Space** (jump)                                   |
| Buttons – B         | **R** (deploy heat-wave force field)               |
| Buttons – C         | **E** (interact)                                   |
| **Knob** – rotate   | **Camera peek** left/right (holds `,`/`.`) or scroll zoom (`knob_mode`) |
| Knob – press        | **I** (inventory)                                  |
| **Buzzer**          | Beeps on button press (local haptic feedback)      |

The mapping matches the `arduino_summer_game` Godot input map: W/A/S/D
movement, Space jump, E interact, I inventory. **Run speed is analog** — the
deeper you tilt in the travel direction, the faster you run: the controller
reports a 0–1 sprint factor (10% steps, 0 at `tilt_on`, full at `sprint_full`
degrees) which the game polls over HTTP (`GET /speed`) and uses to scale
walk→sprint speed. Holding keyboard Shift still forces full sprint for
board-less testing. The game's camera auto-follows behind the player; rotating
the knob holds the game's `peek_left`/`peek_right` actions (`,`/`.`) to glance
sideways, easing back when the knob stops (`knob_mode="peek"`, the default).

A web dashboard (served from the board) lets you **watch the live inputs**,
**tune thresholds on the fly**, and **arm/disarm real HID output** with a master
switch.

## Documentation (read these first in a new session)

| Doc | What's in it |
| --- | ------------ |
| [`docs/HARDWARE.md`](docs/HARDWARE.md) | Board, Modulinos, **gadget quirks**, adb workflow, gotchas |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Data flow, RouterBridge protocol, mapping logic, config params |
| [`docs/CALIBRATION.md`](docs/CALIBRATION.md) | How to calibrate + **the unresolved axis finding** |
| [`docs/SESSION_LOG.md`](docs/SESSION_LOG.md) | What happened each session and **exactly where to resume** |
| `tools/calib_capture.py` | Sample the live stream to measure tilt ranges |

> **Current status (2026-07-04, second session):** fully recalibrated after
> the sensors were re-mounted. Calibrated defaults are **baked into
> `controller.py`** (`swap_axes=on`, no inverts, neutral offsets) — nothing to
> re-apply after a restart. Verified: neutral/W/A/S/D all resolve correctly
> with HID off. A dashboard **Recenter neutral** button re-zeros the tilt axes
> on the current grip. Live in-game HID test still pending.

## Architecture

```
Modulinos --I2C/Qwiic--> MCU (gyro_controller.ino)
                              |  RouterBridge notify "modulino_controller"
                              v
                     Linux side (controller.py)
                       ├─ maps raw data -> HID reports
                       │     /dev/hidg0 (keyboard, 7-byte)
                       │     /dev/hidg1 (mouse, 4-byte)   -> host PC
                       └─ HTTP + SSE web UI (port 8090)
```

The MCU only streams **raw** sensor values; all mapping/threshold logic lives in
`controller.py`, so you can retune from the dashboard **without reflashing**.
No third-party Python packages are required (a minimal msgpack coder is bundled),
which matters because the board has no `pip`.

## Quick start

From your host (Mac/Linux) with the UNO Q connected over USB and `adb devices`
showing the board:

```sh
./deploy.sh          # push + compile + upload sketch + run controller
```

Then open <http://localhost:8090> (the script sets up `adb forward` for you).

- The **HID output** switch starts **OFF** — move the board around and confirm
  the on-screen WASD pad reacts before you arm it.
- Flip the switch **ON** to send real keystrokes to your computer. Focus a game
  or a text field to see it. Flip **OFF** (or `Ctrl+C` the script) to regain
  full control — all keys are released on disable/exit.

Already flashed once? Skip the slow compile step:

```sh
./deploy.sh run
```

## Tuning (dashboard)

| Control          | Meaning                                                         |
| ---------------- | -------------------------------------------------------------- |
| Tilt ON          | degrees of tilt required to start pressing a direction         |
| Tilt OFF         | release angle (keep below ON for smooth hysteresis)            |
| Gyro flick       | rotation rate (deg/s) that triggers a momentary flick          |
| Flick hold       | how long a flick keeps the key down (ms)                       |
| Scroll step      | mouse-wheel ticks per knob detent                              |
| invert F/B, L/R  | flip a movement axis if your board is mounted differently      |
| swap axes        | swap which physical tilt axis drives F/B vs L/R                |
| invert zoom      | flip knob rotation direction for zoom                          |

## Files

- `gyro_controller.ino` — MCU sketch (reads Modulinos, streams raw values)
- `controller.py`       — Linux side: mapping + HID + web UI (no deps)
- `deploy.sh`           — push/compile/upload/run helper
- `README.md`           — this file

## Manual run (without deploy.sh)

```sh
adb push gyro_controller /home/arduino
adb shell 'cd /home/arduino/gyro_controller && arduino-cli compile -b arduino:zephyr:unoq . && arduino-cli upload -b arduino:zephyr:unoq .'
adb forward tcp:8090 tcp:8090
adb shell 'cd /home/arduino/gyro_controller && python3 controller.py'
```

> **Safety:** HID keystrokes go to whatever window is focused on the host. Keep
> the master switch OFF until you are ready, and `Ctrl+C` to stop.
