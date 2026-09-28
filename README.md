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
| Lean (steers) / weight | Left stick | WASD |
| Pose (compress / extend, tricks) | Right stick | Arrow keys |
| Rear brake | Right trigger | Shift |
| Kick | A / Cross | Space |
| Reset | Start | R |
| Tuning panel | Back / Select | Tab |
| Camera: chase → overview → fly | D-pad up | F2 |
| Fly camera move / look | Left / right stick | WASD / hold right mouse |
| Fly camera down / up | LB / RB | Q / E (wheel: speed) |
| Debug lines on/off | — | F3 |
| Record input / stop | — | F5 (in game) |
| Replay last recording | — | F6 (in game) |

When running from the editor, F5/F6 are also editor shortcuts, but they go
to the game while the game window has focus.

## The park

`scenes/park.tscn` holds the props, all at real skatepark sizes. Each prop
is generated from a few parameters (height, radius, angle…), so select one
in the editor and change it in the Inspector: the mesh *and* the collider
rebuild together. Concrete and steel are separate bodies, because Godot
sets friction per body. Coping, rails and box edges are also on collision
layer 2 ("grindable").

| Prop | Size |
|---|---|
| Kicker | 0.5 m tall, 33° lip |
| Quarter pipe | 1.2 m tall on a 1.8 m radius, 60 mm coping |
| Mini ramp | two 0.9 m quarter pipes, 2.5 m flat bottom |
| Bank | 1.0 m at 20° |
| Manual pad | 0.3 m tall, 4 m long, steel edges |
| Rail | 0.35 m tall, 50 mm round |

## The scooter

One rigid body: a 4 kg scooter plus, for now, a 70 kg rigid "ballast"
rider (the see-through capsule). Two sphere-cast wheels apply all ground
forces: a stiff sprung compliance, rolling resistance, a rear-only brake
and sideways grip that slides past the surface's friction (concrete grips
about three times harder than steel).

**Lean steers.** The left stick sets how far you lean. The front wheel then
steers to whatever angle balances that lean at your speed, the way a
bike's front wheel falls into a lean. At walking pace it steers directly.
All values are sliders in the tuning panel (Tab / Back).

Debug lines on the scooter: green = wheel load, orange = grip force (red
when sliding), cyan = rolling direction, yellow cross = centre of mass,
white = velocity.

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
godot --headless --fixed-fps 120 --path . res://tests/test_runner.tscn
```

`--fixed-fps 120` runs one physics tick per frame as fast as possible
instead of in real time. Exits with 0 on success. It includes:
- an end-to-end check that a recorded replay drives a rigid body to the
  *identical* final transform;
- a collider check that casts rays down across every park prop and
  compares each hit with the height the prop's own profile predicts,
  including steel versus concrete;
- scooter physics checked against hand-calculated values: statics at rest,
  coast distance, an energy audit down the bank, bicycle-model steering,
  and grip on concrete versus steel. "note" lines report criteria that
  belong to a later phase.
