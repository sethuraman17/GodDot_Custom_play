# Architecture

## Data flow

```
 Modulinos (Movement / Buttons / Knob / Buzzer)
     │  I2C / Qwiic
     ▼
 MCU  ── gyro_controller.ino ──────────────────────────────────┐
     │  reads sensors @ ~50 Hz                                  │
     │  Bridge.notify("modulino_controller", "<csv>")           │
     │  drives Buzzer locally on button press (haptic)          │
     ▼  RouterBridge (msgpack over /var/run/arduino-router.sock)│
 Linux side ── controller.py ─────────────────────────────────┐│
     │  1. subscribe to topic, parse raw CSV                    ││
     │  2. map tilt+gyro → WASD, buttons → Space/Shift,         ││
     │     knob → mouse scroll (all logic lives HERE)           ││
     │  3. write HID reports:                                   ││
     │        /dev/hidg0 (keyboard, 7-byte)                     ││
     │        /dev/hidg1 (mouse, 4-byte)  ─────────────────────►┘│  → host PC
     │  4. serve web UI over HTTP + SSE (port 8090)             │
     ▼                                                          │
 Browser (host) ── dashboard + live input visualizer ◄─────────┘
                    (adb forward tcp:8090 tcp:8090)
```

**Key design choice:** the MCU streams only *raw* sensor values. All mapping,
thresholds and hysteresis live in `controller.py`, so you can re-tune live from
the web dashboard **without reflashing the MCU**.

## Files

| File | Runs on | Purpose |
| ---- | ------- | ------- |
| `gyro_controller.ino` | MCU | Read Modulinos, stream raw CSV, local buzzer haptics |
| `controller.py` | Board Linux | Mapping + HID output + web UI (zero external deps) |
| `deploy.sh` | Host | push / compile / upload / run helper |
| `tools/calib_capture.py` | Host | Sample the live SSE stream and print tilt stats |
| `docs/*.md` | — | Reference (this folder) |

## MCU payload format

CSV string published on topic `modulino_controller` every ~20 ms:

```
ax,ay,az,gx,gy,gz,bA,bB,bC,kpos,kp
```

- `ax,ay,az` accelerometer (g)
- `gx,gy,gz` gyroscope (deg/s) — from `getRoll/Pitch/Yaw`
- `bA,bB,bC` button states (0/1)
- `kpos` knob absolute position (int16)
- `kp` knob pressed (0/1)

## Mapping logic (`controller.py`)

Tilt angles from accel (degrees):
`pitch = atan2(ax, hypot(ay,az))`, `roll = atan2(ay, az)` — roll is the
**unfolded** form with a full ±180° range, because the user's neutral grip
rests near +85° roll and a forward tilt crosses vertical (the folded
`hypot` form would read forward the same as back). After computing, the
neutral offsets `pitch_offset`/`roll_offset` are subtracted; `POST /recenter`
(dashboard "Recenter neutral" button) re-zeros them on the current pose.

Axis routing (config-driven):
- `swap_axes=false`: forward/back = **pitch**, left/right = **roll**
- `swap_axes=true` : forward/back = **roll**, left/right = **pitch**
- `invert_fb` / `invert_lr` flip a direction's sign.
- Gyro axis pairs with its tilt axis (`gy` with pitch, `gx` with roll) for flicks.

Per axis, direction is resolved with **latching hysteresis**:
- press positive once tilt > `tilt_on`; release once it falls below `tilt_off`
  (and symmetrically for negative). `tilt_off < tilt_on` prevents chatter.

**Gyro flick (hybrid):** if the axis's gyro rate exceeds `gyro_flick` (deg/s),
that direction is force-held for `flick_hold_ms` — gives fast turns without
waiting for the tilt to build up.

Resolved directions → keys (matches the `arduino_summer_game` Godot input map):
- forward → **W**, back → **S**, right → **D**, left → **A**
- Button A → **Space** (jump), Button B → **R** (deploy the heat-wave force
  field), Button C → **E** (interact), knob press → **I** (inventory).
- **Analog sprint:** the deeper the tilt of whichever axis is driving movement
  (magnitude past `tilt_on`, normalized to `sprint_full`), the higher a 0–1
  `sprint` factor, quantized to 10% steps. It is NOT a keyboard key — the game
  polls `GET /speed` and scales walk→sprint speed by it. No Shift is sent.
- Knob rotation delta → per `knob_mode`:
  - `"peek"` (default): holds **`,`** (left) / **`.`** (right) while detents
    keep coming (+0.35 s linger) — the game camera peeks that way and eases
    back when released
  - `"scroll"`: **mouse scroll** ticks (zoom), scaled by `scroll_step`
  - either mode flipped by `invert_scroll`.

Keyboard reports are only sent on a **change** of the pressed set (USB HID holds
a key down until a new report clears it). On disable / exit, an all-zero report
releases everything so no key gets stuck.

## Web UI endpoints (`controller.py`)

| Method / path | Purpose |
| ------------- | ------- |
| `GET /` | dashboard + visualizer (single self-contained HTML page) |
| `GET /events` | Server-Sent-Events stream of live state (~25 Hz) |
| `GET /config` | current config JSON |
| `GET /speed` | `{"sprint": 0..1}` analog run-speed factor (game polls ~20 Hz) |
| `POST /config` | patch tuning params (any subset; `enabled` ignored here) |
| `POST /hid` | `{"enabled": true|false}` master HID arm/disarm |
| `POST /recenter` | zero both tilt axes on the current pose (updates offsets) |

## Config parameters

Defaults below were calibrated 2026-07-04 for the current sensor mounting
(see CALIBRATION.md):

| Key | Default | Meaning |
| --- | ------- | ------- |
| `tilt_on` | 22.0° | tilt to start a direction |
| `tilt_off` | 13.0° | release angle (hysteresis floor) |
| `gyro_flick` | 120 dps | rotation rate that triggers a flick |
| `flick_hold_ms` | 120 | flick key hold time |
| `invert_fb` | false | flip forward/back |
| `invert_lr` | false | flip left/right |
| `swap_axes` | **true** | F/B = roll, L/R = pitch (calibrated) |
| `pitch_offset` | −1.1° | neutral-pose pitch, subtracted (`POST /recenter`) |
| `roll_offset` | 84.7° | neutral-pose roll, subtracted (`POST /recenter`) |
| `knob_mode` | "peek" | knob holds camera-peek keys (`,`/`.`) or "scroll" zoom |
| `sprint_full` | 45.0° | tilt depth past `tilt_on` that reports full sprint (factor 1.0) |
| `scroll_step` | 1 | scroll ticks per knob detent (scroll mode) |
| `invert_scroll` | false | flip knob direction (both modes) |
| `enabled` | false | HID master switch (starts OFF for safety) |
