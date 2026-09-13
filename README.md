# Beat The Heat!

Third-person desert survival: stay in the shade, keep the froggie hydrated, and run as far as you can before the sun wins.

<video src="Edit.mp4" controls playsinline width="100%" title="Beat The Heat gameplay demo">
  Your viewer does not play inline video. Open <a href="Edit.mp4">Edit.mp4</a> to watch the demo.
</video>

## How a run works

1. Pause on the live world. Pick a difficulty (**Easy / Normal / Hard**) — that scales sunburn and water drain.
2. Pick a character (**Robot / Wanderer / Srini**).
3. **Start**. Score is distance from home plus heat-streak multipliers. Dying from heat or dehydration ends the run and shows score + best.

**Sun** burns you in the open. Buildings, wrecks, and a deployed force field count as shade. **Water** drains over time; pick up drops and interact with world objects to stay alive. A **heat wave** can roll through — drop a force field (`R` / Field) to ride it out.

## Characters

All three share the same movement, camera, sun, water, and scoring. Only the body, collision, camera height, and animation set change.

| Menu | Who | Animations |
| --- | --- | --- |
| **ROBOT** | Default runner. Smaller capsule, full locomotion. | Idle, walk, run, jump, fall, land |
| **WANDERER** | Taller humanoid. Same clip set retargeted onto its rig. | Same as Robot |
| **SRINI** | Custom Mixamo avatar from `assets/third_person_adventure/characters/player_custom/`. | Idle, sprint, punch, dance — no walk / jump clips |

### Srini (custom avatar)

The playable mesh is `srini_idle.glb` (rig + idle). `srini.glb` is mesh-only and is not swapped in.

| Action | Clip | How |
| --- | --- | --- |
| Idle | `srini_idle.glb` | Standing still |
| Sprint | `srini_walking.glb` | Hold sprint and move. There is no separate walk cycle — slow WASD still uses this clip once you are moving. |
| Punch | `srini_punch.glb` | `F` or **Punch**. Plays once, then back to idle. |
| Dance | `srini_dance.glb` | `G` or **Dance**. Loops until you press Dance again, or you sprint / move. |
| Jump | — | Disabled for this character. |

On mobile, Srini hides Jump and shows **Sprint / Punch / Dance** (Use and Field stay). Robot and Wanderer keep Jump / Sprint / Use / Field.

## Controls

| Action | Keyboard | Mobile |
| --- | --- | --- |
| Move | WASD | Left stick |
| Look | Mouse | Right-side drag |
| Sprint | Shift | Sprint |
| Jump | Space | Jump (Robot / Wanderer only) |
| Interact | E | Use |
| Force field | R | Field |
| Punch | F | Punch (Srini only) |
| Dance | G | Dance (Srini only) |
| Pause / menu | Esc | Pause |
| Menu knob | `[` / `]` cycle, `\` confirm | Tap the difficulty / character buttons |

Optional Arduino gyro board (see `gyro_controller/README.md`) can drive tilt-to-move and analog sprint.

## Run it

Godot **4.7**, main scene `res://scenes/main.tscn`.

Open the project and press Play, or from a terminal:

```text
Godot_v4.7.2-stable_win64.exe --path .
```

Android export uses the presets in `export_presets.cfg`.
