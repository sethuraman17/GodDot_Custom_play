# Main Menu — Design Spec (2026-07-04)

## Goal

Give "Beat The Heat!" a minimal main menu so it feels like a complete game: start the game, pick a difficulty (which scales sunburn speed and water drain speed), and see best scores.

## Approach

In-scene overlay. The menu is a `CanvasLayer` (`MainMenu`) inside `scenes/main.tscn`, rendered above the HUD, with the live game world visible (paused) behind it. No scene switching, no autoloads.

- Script: `scripts/main_menu.gd` (new, `class_name MainMenu`). UI is built in code, matching the style helpers used by `adventure_hud.gd`'s results overlay (dark warm panels, orange accents).
- The menu node uses `process_mode = PROCESS_MODE_ALWAYS` and freezes the game with `get_tree().paused = true` while visible.

## Layout (minimal)

Full-screen dim `ColorRect`, centered panel containing:

1. Title: **BEAT THE HEAT** (+ one-line tagline)
2. Difficulty selector: three toggle buttons — EASY / NORMAL / HARD — the selected one highlighted; each shows its own best score (e.g. "Best 12,450" / "Best —")
3. **START** button (primary). Reads **RESUME** when opened mid-run via ESC.
4. Controls hint line: "WASD move · Shift sprint · Space jump · Esc menu"

## Difficulty

Multipliers applied to the two existing exports; base values captured once at load.

| Difficulty | `SunExposure.sun_damage_per_second` | `WaterSupply.drain_per_second` |
| ---------- | ----------------------------------- | ------------------------------ |
| Easy       | 0.6×                                | 0.6×                           |
| Normal     | 1.0×                                | 1.0×                           |
| Hard       | 1.75×                               | 1.75×                          |

Default selection: Normal. Last-chosen difficulty persists in the save file.

## Game flow

- **Boot:** tree starts paused, menu visible over the frozen world.
- **START:** applies difficulty multipliers, tells `RunScore` the active difficulty, resets the run (health full, water full, score/streak zeroed, player respawned at home), sets `SunExposure.invincible = false` (the scene currently defaults to invincible — the menu makes death real; the F3 debug toggle keeps working), unpauses, hides menu.
- **Death:** existing results overlay animation plays as-is (world briefly keeps running behind it); when it finishes (~4.8 s after `run_ended`), the menu reappears (paused) with refreshed best scores. Button reads START and begins a fresh run. During that results window the respawned player is made invincible and both drain rates are zeroed — otherwise a Hard-difficulty player burns ~84 HP (and could die again) before the menu returns; START restores the rates from the difficulty preset.
- **ESC mid-run:** opens the menu as a pause screen — button reads RESUME, difficulty buttons disabled (difficulty is per-run). ESC again (or RESUME) unpauses. ESC does nothing while the results animation is playing.

## Best scores (per difficulty)

`RunScore` changes:

- `difficulty: String` ("easy" | "normal" | "hard"), set by the menu before a run starts.
- Save file (`user://heatwave_score.cfg`, existing) keys become `score/best_easy`, `score/best_normal`, `score/best_hard` plus `settings/difficulty`. Legacy `score/best` migrates to `best_normal` on first load.
- `get_best(difficulty) -> int` for the menu; `run_ended`/`score_changed` keep reporting the active difficulty's best.
- New `reset_run()` to zero score/peak/multiplier when starting from the menu (death already resets internally).

`SunExposure` gains a small public `reset_run()` (respawn character at home, refill health, refill water) so the menu doesn't poke privates.

## Error handling

- Missing nodes (menu can't find Player/SunExposure/etc. via exported NodePaths): fail soft with `push_warning`, menu still shows, START just unpauses.
- Corrupt/missing save file: bests default to 0 and render as "Best —".

## Testing

Playtest in-engine: boot → menu shows paused world; start on Normal → HUD live, sun damage applies; die → results → menu returns with updated best; ESC pause/resume; difficulty multipliers verified via F3 debug panel rates on Easy vs Hard.
