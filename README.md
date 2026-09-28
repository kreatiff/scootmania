# Scootmania

A physics-driven stunt scooter game: realistic riding, skate.-style tricks.
Built with **Godot 4.7** (GDScript, Jolt physics). See
[`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md) for the roadmap.

## Running

1. Open Godot 4.7+, choose **Import**, and select `project.godot`.
2. Press **F5** (Run Project). It opens the sandbox.

## Controls

| Action | Gamepad | Keyboard fallback |
|---|---|---|
| Lean / weight | Left stick | WASD |
| Pose (compress / extend, tricks) | Right stick | Arrow keys |
| Rear brake | Right trigger | Shift |
| Kick | A / Cross | Space |
| Reset | Start | R |
| Tuning panel | Back / Select | Tab |
| Debug lines on/off | — | F3 |
| Record input / stop | — | F5 (in game) |
| Replay last recording | — | F6 (in game) |

When running from the editor, F5/F6 are also editor shortcuts, but they go
to the game while the game window has focus.

## Debug tools

- **HUD** (bottom left): raw stick position in grey, shaped intent in cyan,
  deadzone in red.
- **Tuning panel**: every `@export_range` value on a bound Resource becomes
  a live slider. **Save** writes it back to its `.tres`, so good tunings can
  be committed.
- **Input replay**: F5 restarts the scene and records every physics tick's
  intent. F5 again stops and saves to `user://replays/last.replay`. F6
  restarts the scene and replays it tick for tick. The physics is
  deterministic on the same build and machine, so a replay reproduces a run
  exactly. Use it to compare two tunings on identical input.
- **DebugDraw** (autoload): `DebugDraw.arrow()`, `.line()`, `.point()`,
  `.axes()` from any `_physics_process`.

## Tests

```sh
godot --headless --path . res://tests/test_runner.tscn
```

Exits with 0 on success. It includes an end-to-end check that a recorded
replay drives a rigid body to the *identical* final transform.
