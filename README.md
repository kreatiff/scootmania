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
| Lean (steers) / in the air: pitch and spin | Left stick | WASD |
| Crouch / extend (pop, pump) | Right stick down / up | Arrow keys |
| Rear brake | Right trigger | Shift |
| Foot plant (tight turns, stop) | Left trigger (hold) | Ctrl |
| Kick | A / Cross | Space |
| Stand up where you are (tap) | Start | R |
| Back to the spawn point (hold ¾ s) | Start | R |
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

## The scooter and rider

Two physics bodies, split the way a real body splits:
- **Scooter** (15 kg): the scooter plus the rider's shins, which move with
  the deck. Two sphere-cast wheels apply all ground forces: a stiff sprung
  compliance, rolling resistance, a rear-only brake and sideways grip that
  slides past the surface's friction (concrete grips about three times
  harder than steel).
- **Rider** (59 kg, the blue capsule): hips, torso, arms. It rides on
  **legs** (a spring the right stick lengthens or shortens) and is held
  over the deck by the **hips**. On ramps, the legs soak up the transition
  while the scooter follows the ramp.

**Legs: crouch, pop, pump.** Right stick down crouches; up extends.
- **Pop:** crouch, then flick up. The legs push off and lift the scooter
  (~30 cm from rolling). No crouch, no pop.
- **Pump:** on a ramp, push up (extend) as you go up the transition and
  crouch as you come back down. You gain speed without kicking; the
  "energy" graph (top right) shows it.

**Lean steers, with countersteering.** The left stick sets how far you
lean. To lean in, the bars flick the other way for a moment, then steer
into the turn to balance the lean, the way a real rider balances a bike
or scooter. Full stick means "turn as hard as you can": it leans only as
far as the turn can hold you up at this speed and on this surface (about
26° on concrete, 9° on steel), so steering alone never tips you over.
Riding onto steel mid-carve still slides you out. At walking pace it steers
directly.

**Foot plant (hold left trigger).** Your pushing foot comes down beside the
rear wheel, on the inside of the turn. It holds you up, so the bars go to
full lock and you turn far tighter than you can carve: at 2.5 m/s, a
0.65 m radius instead of 2.2 m. The foot scuffs, so it costs speed (at
speed it's mostly a brake), and you can't kick while it's down. When
you're nearly stopped the foot goes down by itself to keep you upright,
without scuffing.

**Airs.** Once both wheels leave the ground, the left stick controls the
scooter in the air: forward/back pitches the nose down/up, sideways spins.
Stick centred holds the pitch, and any spin you took off with carries on.
Just before landing, a **landing assist** lines the scooter up with the
ground if it's already within 60° (its strength is a slider). Each landing
is graded CLEAN, sketchy or BAIL, from the tilt against the ground and how
sideways you are to your direction of travel (landing fakie is fine). On a
bail the rider lets go and the game drops into slow motion.

To air out of a quarter pipe, crouch on the way in and extend up the
transition. Rolling in passively, your knees soak up the ramp and you stall
below the lip. The park's quarter pipe has a 70° lip, which throws you onto
the deck unless you spin around.

**Falling over:** tipped past 60° (or hung up: wheels off the ground and
stopped), the rider lets go. After 1.5 s the
scooter stands itself up where it came to rest (the delay is a slider;
0 turns it off). Tap Start / R to stand up at once, or hold it to go back
to the spawn point.

All values are sliders in the tuning panel (Tab / Back).

Debug lines on the scooter: green = wheel load, orange = grip force (red
when sliding), cyan = rolling direction, yellow cross = scooter centre of
mass, red cross = combined centre of mass, white = velocity.

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
- **Graphs** (top right): any value passed to `DebugDraw.plot()`, over
  the last ~10 s. The scooter plots its total energy and leg force.
- **DebugDraw** (autoload): `DebugDraw.arrow()`, `.line()`, `.point()`,
  `.axes()` from any `_physics_process`.

## Tests

```sh
godot --headless --fixed-fps 240 --path . res://tests/test_runner.tscn
```

`--fixed-fps 240` runs one physics tick per frame as fast as possible
instead of in real time. Exits with 0 on success. It includes:
- an end-to-end check that a recorded replay drives a rigid body to the
  *identical* final transform;
- a collider check that casts rays down across every park prop and
  compares each hit with the height the prop's own profile predicts,
  including steel versus concrete;
- scooter physics checked against hand-calculated values: statics at rest,
  coast distance, energy audits (bank, kicker) covering both bodies and the
  rider's muscle work, the rear wheel staying planted on the kicker,
  bicycle-model steering, grip on concrete versus steel, and recovery;
- legs: pop height (with and without a crouch), popping off the kicker,
  and pumping a mini ramp for 20 s with an energy audit;
- turning: full stick at every speed from 0.5 to 8 m/s never falls or
  slides; the foot plant turns in less than 60% of the carving radius at
  walking pace, scuffs at the expected rate, and blocks kicking;
- airs: kicker landings with and without the assist, air control (pitch
  hold, nose down, spin), a bad landing that bails and recovers, an air
  back into a vert quarter pipe, and slow motion.

"note" lines report measurements without pass/fail.
