# Session Log

Chronological record so context survives across sessions. Newest session on top.

---

## 2026-07-04 (later) — Full recalibration after sensor re-mount

### Context
The user physically moved the sensors on the controller → all prior axis
findings were stale. Recalibrated everything from scratch.

### Key discovery: the roll fold
In the new mounting, the neutral grip rests at **roll ≈ +85°** (gravity almost
entirely on the sensor's Y axis). The stock formula
`atan2(ay, hypot(ax, az))` only spans ±90°, so a forward tilt crosses vertical
and **folds back** — forward read the same as back, and a pure left tilt
contaminated the folded roll reading. This also retroactively explains the
previous session's "unresolved axis finding".

### Measured (unfolded roll = atan2(ay, az), full ±180°)
| Pose | pitch | unfolded roll | Δ from neutral |
| ---- | ----- | ------------- | -------------- |
| neutral | −1° | ~85° | — |
| forward | +2° | 132° | **+47° roll** |
| back | +1° | 33° | **−52° roll** |
| left | **−46°** | 87° | −45° pitch |
| right | **+53°** | 79° | +52° pitch |

Noise floor < 2°. F/B = roll (swap_axes **true** — the old suspicion was
right), L/R = pitch, no inverts needed once offsets are subtracted.

### Code changes (`controller.py`)
- Roll formula → **unfolded** `atan2(ay, az)`.
- New config params `pitch_offset` / `roll_offset`, subtracted before routing.
- New **`POST /recenter`** endpoint + dashboard button: zero both axes on the
  current pose (folds residual into the offsets).
- Baked calibrated defaults: `swap_axes=true, invert_fb=false, invert_lr=false,
  tilt_on=22, tilt_off=13, pitch_offset=-1.1, roll_offset=84.7`.
- Dashboard axis labels swapped to match (Roll = fwd/back, Pitch = left/right).
- New `tools/calib_capture2.py`: like calib_capture.py but also reports raw
  ax/ay/az and the unfolded roll.

### Verified (HID off, key-timeline sweep over SSE)
Neutral → no keys (±4°); forward → W; back → S; left → A; right → D;
diagonals resolve; roll tracks past ±90° without folding; gyro-flick signs
correct. **Live HID test in a real game: NOT yet done this session.**

### State at end of session
- Controller **running** on the board, `adb forward tcp:8090` up, HID **off**.
- Calibrated defaults are in the file — safe across restarts.
- Next: arm HID and playtest; use the dashboard **Recenter** button whenever
  the grip changes.

---

## 2026-07-04 — Build + first calibration pass

### Goal
Turn the Arduino UNO Q + Modulinos (Movement/Buttons/Knob/Buzzer) into a USB-HID
game controller. Movement → WASD (tilt + gyro hybrid), and a GUI to test it.

### Agreed mapping (from the user)
- Movement: **tilt + gyro hybrid** → WASD
- Button A → **Space** (jump), Button B → **Shift** (sprint), Button C → unused
- Knob → **zoom** (mouse scroll)
- Buzzer → beep on button press
- GUI: **both** a tuning dashboard and a live input visualizer

### Built & verified working
- `gyro_controller.ino` — reads Modulinos, streams raw CSV @ 50 Hz, local buzzer.
- `controller.py` — mapping + HID + self-contained web UI (bundled msgpack, no
  external deps). HID master switch defaults **OFF**.
- Deployed end-to-end and **confirmed live**: router `connected: true`, real IMU
  data (gravity reads correct), knob detected, buttons reporting, dashboard
  renders (screenshot verified), `/config` + `/hid` endpoints round-trip.
- Installed board libs: `Arduino_RouterBridge`, `Arduino_Modulino`.

### User feedback during testing
- Needed **`invert_fb=on`** and **`invert_lr=on`**; **`swap_axes` left off**.
- Reported the controller "works well" with that config.

### Calibration (partial)
- Applied the user's invert config to the running instance.
- Captured **neutral** and **forward** holds (see CALIBRATION.md for numbers).
- **Finding:** forward tilt moved **roll ≈ -33°** but **pitch only +3.5°** →
  suggests forward/back is physically on the ROLL axis, which conflicts with
  `swap_axes=false`. **UNRESOLVED.**
- **back** hold was requested but NOT captured — session stopped here.

### State at end of session
- Controller process on the board: **STOPPED** (`pkill -f controller.py`).
- `adb forward tcp:8090` : **removed**.
- Sketch is flashed on the MCU (still there).
- Running config was `tilt_on=18, tilt_off=10, gyro_flick=120, flick_hold_ms=120,
  invert_fb=true, invert_lr=true, swap_axes=false` (in-memory only — resets to
  file defaults on next `controller.py` start; defaults have invert_fb/lr FALSE).

### ▶ Resume here next session
1. Restart: `./deploy.sh run` (skips recompile), open http://localhost:8090.
2. Re-apply the user's inverts (or bake them into `controller.py` CONFIG defaults
   once axis routing is confirmed).
3. **Resolve the axis question** (CALIBRATION.md): with the user, re-capture
   forward AND back holds, watch which key lights up per motion, decide
   `swap_axes`. Then set `tilt_on`/`tilt_off` from the measured range.
4. Optional polish ideas raised but not done: map Button C, a recenter/calibrate
   button, an on-screen "which way is forward" helper.
