# Heat Wave + Force Field — Design

Date: 2026-07-04
Status: approved (user confirmed parameters in chat)

## Summary

A recurring **heat wave** hazard strikes at random intervals of roughly one
per minute. A 10-second warning precedes each hit. The player counters it
with a deployable **force field globe** (R key): 5 seconds to set up, then
active for 5 seconds. Standing inside an active globe negates the wave AND
counts as full shade against normal sun drain. Caught outside a globe when the
wave hits, the player loses **half of their current health**.

## Gameplay rules

### Heat wave
- Scheduling: per run, next wave due at a random time in **[20 s, 40 s]**
  after the run starts / after the previous wave passes — averages one wave
  every 30 s. (Revised twice on 2026-07-04: [60,240] → [40,80] → [20,40].)
- Warning: **10 s** countdown — banner ("HEAT WAVE INCOMING — Ns"), an orange
  screen tint that intensifies as the hit approaches, a rising rumble
  (worm_rumble.ogg at 0.8 pitch, −24 dB → −4 dB), and a **visible wave wall**:
  a 500×60 m glowing translucent orange plane that spawns 250 m out in a
  random horizontal direction and closes in to arrive exactly at countdown
  zero. It tracks the player laterally so it always crosses the camera at the
  strike, then sweeps 120 m past (fading) during the 2 s passing phase.
- Impact (instant, at countdown zero):
  - Player inside an **active** force field → no damage, "PROTECTED!" flash.
  - Otherwise → `health = health * 0.5` (half of **current** health, so a
    wave never kills outright on its own; the drain that follows can).
  - Skipped entirely if `SunExposure.invincible` (menu/death state).
- Aftermath: **2 s** orange screen wash ("wave passing"), then reschedule.
  (Revised 2026-07-04 from 3 s; user asked for the wave to stay 2 seconds.)
- Pause/reset: all timers respect the scene pause (menu). `reset()` is called
  from `MainMenu._start_run()` so every run/retry starts a fresh schedule.

### Force field globe
- Input: **R** (`force_field` action registered alongside the existing
  defaults in `adventure_input_reader.gd`).
- Placement: ~2.5 m in front of the player's facing, snapped to the terrain
  via downward raycast. Radius ~2.5 m. No collision — walk in/out freely.
- Lifecycle: **BUILDING (5 s)** — globe grows/brightens, countdown label →
  **ACTIVE (5 s)** — full visual, protection live → **dissolve**.
  Dissolves early right after a wave passes ("absorbed").
- Sun protection: while the player's position is inside an ACTIVE globe,
  `SunExposure` treats them as fully shaded (no drain; normal shade healing
  applies). BUILDING globes protect from nothing.
- One globe at a time; R does nothing while one exists. No cooldown — the 5 s
  vulnerable deploy is the cost.
- Timing consequence (intended): with a 10 s warning and 5 s deploy, the
  player must press R within ~5 s of the siren to be covered.

## Architecture

New, self-contained pieces; minimal touches to shared files (the HUD script is
actively edited by concurrent sessions and is NOT modified).

| Piece | Type | Responsibility |
|---|---|---|
| `scripts/heat_wave_manager.gd` | `HeatWave` node at scene root | Scheduling, WARNING/PASSING states, protection check, damage via SunExposure, self-built CanvasLayer UI (banner + tint), `reset()` |
| `scripts/force_field_ability.gd` | `ForceFieldAbility` node under Player | R input, spawn/own the globe, one-at-a-time rule |
| `scripts/force_field.gd` | `ForceField` (Node3D), spawned at runtime | Globe visuals built in code (transparent cyan sphere + emission), BUILDING/ACTIVE timers, `is_active()` / `contains(point)`, `dissolve()`, registers in `force_fields` group |

Hooks in existing files:
- `sun_exposure.gd`: public `apply_flat_damage(amount)` (clamp, notify,
  death via the existing `_die()` path) + shade override: after ray sampling, if
  any active field contains the character, `shade_ratio = 1.0`.
- `adventure_input_reader.gd`: add `force_field` → R to the default action
  table.
- `main_menu.gd`: one line in `_start_run()` → `heat_wave.reset()`.

Wave/field interaction ordering on the impact frame: evaluate protection
BEFORE field expiry so a field that activates at t=5 of a 10 s warning still
covers the hit at its own 5 s boundary.

## Error handling
- Missing nodes (SunExposure, player, sun) → push_warning and idle; never
  crash the run loop.
- Ground raycast miss on placement → place at player's own Y.
- All state resets cleanly on `reset()`: cancels warnings, dissolves fields.

## Testing (probe-driven, as established in this repo)
1. Force a wave 12 s out; do nothing → assert health exactly halved.
2. Force a wave; deploy at once; stand inside → assert health unchanged +
   "PROTECTED!" shown.
3. Inside active globe in open sun → assert `shade_ratio == 1.0` (healing).
4. R spam while a globe exists → still exactly one globe.
5. Screenshots: warning banner, building globe, active globe, wave wash.
6. Zero debugger errors throughout.
