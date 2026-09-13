# Calibration

How to measure the user's real tilt range and set thresholds from data.

> **RESOLVED 2026-07-04 (second session):** the sensors were physically moved
> and everything below the "Procedure" section was recalibrated from scratch —
> see "Current calibration" below and SESSION_LOG.md. The old open question is
> kept at the bottom for history; its answer was the **roll fold** (the stock
> ±90° roll formula folded past vertical, making forward read like back).

## Current calibration (2026-07-04, sensor re-mount)

Neutral grip rests at **roll ≈ +85°** — near the ±90° limit of
`atan2(ay, hypot(ax,az))` — so `controller.py` now uses the **unfolded**
`atan2(ay, az)` (±180°) and subtracts per-axis neutral offsets.

Measured (unfolded roll):

| Pose | pitch | roll | Δ from neutral |
| ---- | ----- | ---- | -------------- |
| neutral | −1° | ~85° | — |
| forward | +2° | 132° | +47° roll |
| back | +1° | 33° | −52° roll |
| left | −46° | 87° | −45° pitch |
| right | +53° | 79° | +52° pitch |

→ F/B = **roll** (`swap_axes=true`), L/R = **pitch**, no inverts. Defaults in
`controller.py`: `tilt_on=22, tilt_off=13, pitch_offset=-1.1, roll_offset=84.7`.

**Recentering:** the dashboard's *Recenter neutral* button (`POST /recenter`)
zeroes both axes on the current pose — use it whenever the grip changes instead
of redoing a full capture. Use `tools/calib_capture2.py` (reports raw accel and
unfolded roll) for full recaptures; prefer it over the original capture tool.

## Procedure

1. Board flashed, `controller.py` running, `adb forward tcp:8090 tcp:8090` up.
2. Use `tools/calib_capture.py <label> <seconds>` to sample the live SSE stream
   while the user holds a pose. It reports min/max/mean/std/absmax of `pitch`
   and `roll`, plus peak gyro rates.
3. Capture at least: **neutral** (resting), **forward** hold, **back** hold
   (and **left**/**right** if tuning L/R too).
4. Derive thresholds:
   - `tilt_on`  ≈ 45–55% of the comfortable held angle (well above neutral noise)
   - `tilt_off` ≈ 55–65% of `tilt_on` (hysteresis; must clear neutral noise)
   - `gyro_flick` ≈ a bit below the peak gyro rate seen during a deliberate flick
5. Apply with `POST /config` (or the dashboard sliders) and re-test.

## Session data (2026-07-04)

Config in effect during capture: `invert_fb=true, invert_lr=true,
swap_axes=false`.

**Neutral (resting):**
```
pitch: mean 0.45°, range 0.2–0.6°, std 0.12   (rock steady)
roll : mean -1.91°, range -2.3 – -1.5°, std 0.19  (small mounting offset)
gyro noise: < 1 dps
```
→ Noise floor is tiny; thresholds can be set purely from comfortable range.
→ Roll has a ~-1.9° mounting offset (negligible, but note it).

**Forward hold (user tilted into their natural "walk forward" pose):**
```
pitch: mean +3.5°,  range 1.6 – 5.4°     <-- barely moved
roll : mean -33.5°, range -35.5 – -31.5° <-- moved a LOT
gy peak 8.1 dps, gx peak 6.5 dps (slow, deliberate tilt)
```

**Back hold:** the user got into position and said "ok" twice, but the session
was stopped before this window was captured. **NOT MEASURED.**

## ~~⚠️ Open question / unresolved finding~~ (RESOLVED — historical)

> **Answer:** the roll formula folded at ±90°. The user's neutral grip sits
> near +85° roll, so forward crossed vertical and read as a *smaller* angle,
> indistinguishable from back. Fixed by switching to unfolded
> `atan2(ay, az)` + neutral offsets. Original notes kept below.

The forward-hold data shows the user's forward/back motion lives almost entirely
on the **roll** axis (-33°), while **pitch** barely changed (+3.5°).

But the current working config has `swap_axes=false`, which routes forward/back
to **pitch**. With that routing, a forward tilt (pitch ≈ +3.5°) is far below any
sane `tilt_on`, so it would produce little/no W — yet the user reported earlier
that "it works well." These two facts conflict.

Possible explanations (to check next session):
1. The user held the board differently during this calibration than during their
   earlier "works well" test.
2. Forward/back genuinely belongs on the **roll** axis for how they hold it →
   `swap_axes` should be **ON**, and the earlier success was with a different
   motion or a different axis lighting up than expected.
3. The board's physical mounting/orientation changed between tests.

**Do not just flip `swap_axes` blindly.** Next session: re-confirm the board
orientation with the user, re-capture forward AND back holds, watch which
on-screen key (W/S vs A/D) lights up for each physical motion, and only then
decide axis routing + thresholds. The measurement tooling
(`tools/calib_capture.py`) and the live dashboard make this a 2-minute check.

## Suggested thresholds (pending axis resolution)

If forward/back ends up on the axis that swings ~33° at a comfortable hold:
- `tilt_on ≈ 15°`, `tilt_off ≈ 9°` → responsive but clears the <2° noise floor
  with wide margin. Re-derive once both forward AND back magnitudes are known
  (they may be asymmetric, in which case consider centering out the offset).
