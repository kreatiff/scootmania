# Scootmania — Development Plan

A physics-driven stunt scooter game set in a skatepark. The references are
**skate.** (trick input and feel) and **Descenders** (weight, momentum,
bails). Controller first. Built in **Godot 4 + GDScript** with **Jolt** physics.

This plan covers the road from an empty repo to a **flat physics sandbox**
you can ride, pump, jump and do a first trick in. Everything past that is
listed at the end as out of scope for now.

---

## 1. Guiding principles

1. **Feel first, content later.** No art, menus, levels, scoring or audio
   until riding the sandbox is fun with placeholder shapes.
2. **Realistic riding, achievable tricks.** The split is deliberate:
   - **Riding and the world are simulated for real:** mass, momentum,
     suspension, tyre grip, weight transfer, pumping, and how you leave a
     ramp. Keeping the scooter upright is an *assist* with a slider.
   - **Tricks are designed like skate.:** a flick starts a trick, and the
     trick then plays out reliably. The skill is in the *inputs and the
     timing* (enough pop, enough airtime, landing straight), not in fighting
     the simulation. When fun and realism conflict on a trick, fun wins.
3. **Real units, real numbers.** Metres, kilograms, seconds. Start from
   measured values for a real scooter and rider, and tune from there.
4. **Make everything visible.** Every force is drawn as a debug line, and
   every tuning value is a live slider. If you can't see it, you can't tune it.
5. **Each phase ends with something playable.** A phase is done when its
   exit criteria are met in play, not when the code is written.

---

## 2. The key physics insight: the rider is the physics

| Component | Real-world value |
|---|---|
| Stunt scooter mass | ~3.5–4.5 kg |
| Rider mass | ~60–80 kg |
| Wheel diameter | 110–120 mm, solid polyurethane |
| Wheelbase | ~0.45–0.50 m |
| Bar height | ~0.80–0.90 m from the ground |
| Headtube angle | ~83° |
| Rolling resistance (PU on concrete) | Crr ≈ 0.01–0.02 (to be tuned) |

**The scooter is about 5% of the total mass.** What the system does is
mostly decided by where the rider's centre of mass is and how the rider's
legs push on the deck. Pumping, popping, carving and landing all come from
leg forces. So the rider can't be a decoration on top of a vehicle. The rider
*is* the vehicle, and the scooter is the interface to the ground.

**Stability consequence:** joining a 70 kg body to a 4 kg body with a
physics joint (a 17:1 mass ratio) makes iterative solvers jitter and explode.
So the physics is **one rigid body for scooter and rider combined**. The
rider is simulated *inside our own code* as a centre of mass on a sprung
"leg" that can lean and compress, and it applies forces to the body. This is
robust, and it's how most shipped riding games work.

**Tricks don't need a second physics body.** During a tailwhip the 4 kg deck
spins while the 70 kg rider barely moves, so the effect on the whole
system's motion is negligible. Barspins and tailwhips are therefore
*driven rotations* of the visual deck and bars about the **real headtube
axis**, while the physics body keeps flying its true trajectory. It looks
correct, it can be timed and tuned exactly, and it avoids the riskiest
piece of engineering in the project.

---

## 3. Architecture

### Engine settings
- Godot 4.7 (latest stable at the time of writing), version pinned in `project.godot`. It needs
  Jolt: in 4.4+ it's built in; choose it under
  *Project Settings → Physics → 3D → Physics Engine* if it isn't the default.
- **Physics tick: 120 Hz** to start (`physics/common/physics_ticks_per_second`),
  going up to 240 Hz if tyre forces jitter. Rendering is decoupled from
  physics, with physics interpolation turned on.
- Forward+ renderer. Web export isn't a goal for the sandbox.

### Project layout
```
scootmania/
├── project.godot
├── docs/                   # this plan, design notes, tuning logs
├── scenes/
│   ├── sandbox.tscn        # the test world
│   └── props/              # ramp, quarter pipe, box, rail, bank
├── scooter/
│   ├── scooter.tscn        # rigid body + wheels + rider
│   ├── scooter.gd          # applies all forces each physics tick
│   ├── wheel.gd            # shape-cast wheel: suspension + tyre model
│   ├── rider.gd            # rider centre of mass, legs, lean
│   └── scooter_tuning.tres # every tuning value, saved as a Resource
├── camera/
│   └── chase_camera.gd
├── input/
│   └── rider_input.gd      # gamepad → normalised intent (lean, stance, brake)
└── debug/
    ├── debug_draw.gd       # debug lines for forces and velocities
    ├── tuning_panel.gd   # live sliders bound to scooter_tuning.tres
    └── telemetry.gd        # graphs: speed, slip, suspension, energy
```

### Rules for how the code is structured
- **Input is read once per physics tick** and turned into an *intent* object
  (lean −1..1, stance −1..1, brake 0..1, kick bool, trick flick vector). The
  physics code never reads the gamepad directly. This makes input replays
  possible.
- **All forces are applied in `_physics_process`**, never in `_process`.
- **Tuning values live in one `Resource`**, so a feel you like can be saved,
  compared and committed.
- **Input replay.** Record the intent stream to a file and play it back. With
  the same build and machine, Jolt is deterministic enough that you can
  compare two tunings on *identical* input. This is the most valuable debug
  tool in the whole plan.

---

## 4. Controller layout (draft)

| Input | Grounded | Airborne |
|---|---|---|
| Left stick X | Lean → steer (body weight) | Body lean / spin input |
| Left stick Y | Weight forward/back | Pitch (nose up/down) |
| Right stick Y | Down = compress/pump, flick up = pop | Tuck / extend |
| Right stick flick | — | Tricks (Phase 7+) |
| Right trigger | Rear brake (fender brake) | — |
| A / Cross | Kick (foot push) | — |
| Start | Reset to spawn | Reset to spawn |
| Select / Back | Toggle tuning panel | Toggle tuning panel |

The Xbox and PlayStation layouts both go through Godot's built-in joypad
mapping. The input map is defined in the project, not hard-coded.

---

## 5. Phases

Effort is given as rough relative size (S ≈ a few evenings,
M ≈ 1–2 weeks part-time, L ≈ 2–4 weeks part-time). Physics tuning *always*
takes longer than expected, so treat these as optimistic.

### Phase 0 — Setup & debug tooling (S)
**Goal:** a project that runs, reads the gamepad and can show its internals.
- [x] Install Godot 4.x. Create the project and select Jolt, a 120 Hz tick
      and physics interpolation.
- [x] `.gitignore` for `.godot/` and import caches. Add `.gitattributes`
      for binary assets (Git LFS later if assets grow).
- [x] Input map for all actions in §4, with a deadzone on the sticks.
- [x] `rider_input.gd`: gamepad → intent. On-screen display of the raw and
      processed values.
- [x] `debug_draw.gd`: a helper for drawing arrows, lines and points in 3D
      each frame.
- [x] Tuning panel skeleton: sliders generated from the tuning Resource.
- [x] Input record/replay (intent stream → file → playback).

**Exit criteria:** moving the sticks updates the on-screen intent values
smoothly. A recorded input file plays back exactly.

### Phase 1 — Sandbox world (S)
**Goal:** a place to ride that makes speed and angles readable.
- [x] Large flat ground with a **grid texture** of 1 m squares. Without it,
      you can't perceive speed.
- [x] Props generated from parameters (profile → mesh + matching collider),
      all at real skatepark sizes:
  - [x] Flat bank (~20°)
  - [x] Kicker ramp (~0.5 m tall)
  - [x] Quarter pipe (1.2 m tall on a 1.8 m radius, with steel coping on the lip)
  - [x] Two quarter pipes facing each other (mini ramp) for pumping tests
  - [x] Flat box / manual pad (~0.3 m tall)
  - [x] Round rail (for grind tests later; it only needs a collider now)
- [x] Physics materials: concrete (high friction) and steel coping (low
      friction).
- [x] A simple fixed camera plus a free-fly debug camera.

**Exit criteria:** you can fly around the park, and every prop has a correct
collider (checked with *Debug → Visible Collision Shapes*, and automatically
by the ray-cast test in `tests/`).

### Phase 2 — The rolling scooter (M) ✅
**Goal:** a scooter-shaped rigid body that rolls, coasts and grips like
solid PU wheels on concrete.

*Decision:* a riderless 4 kg scooter can't be tested realistically (it
falls over, and every tyre force depends on the rider's weight), so Phase 2
uses the full 74 kg system with the rider as **rigid ballast**. Phase 3
gives the ballast legs.
- [x] `RigidBody3D` with real mass, centre of mass and inertia (scooter +
      ballast rider). Godot's default body damping turned off, because air
      drag and rolling resistance are modelled explicitly.
- [x] **Shape-cast wheels** (sphere, not a single ray). The cast's own hit
      distance is quantised (~1.5 mm steps, which made the spring jitter), so
      the exact distance is solved from the contact point and normal.
- [x] Wheel compliance: a stiff, damped spring (~5 mm under a standing
      rider) with a bump stop.
- [x] Tyre model: rolling resistance, rear-only brake, lateral grip
      that cancels sideways slip up to surface friction × load, then slides
      at reduced grip until it regrips (hysteresis). Grip comes from the
      surface: concrete 0.9, steel 0.3.
- [x] Steering about the **real headtube axis** (83°).
- [x] **Lean steers** (pulled forward from Phase 3): the stick sets the
      target lean, and the front wheel steers to whatever balances the
      current lean at the current speed. The first prototype steered
      directly and threw the rider off the outside of every turn, which is
      exactly what real physics does if you turn the bars without leaning.
- [x] Kick (A) pushes; air drag on the rider.

**Exit criteria (automated in `tests/scooter_tests.gd`):**
- [x] Sits still on flat ground: no jitter or creep, wheel loads match statics.
- [x] Coasts straight and stops where rolling resistance + drag predict (64.6 m from 5 m/s).
- [x] Rolls down the bank with a balanced energy audit (no energy created).
- [x] Turns: reaches the asked-for lean, the turn balances it, yaw rate
      within 10% of the bicycle model.
- [x] Concrete holds a 0.5 g carve that slides on steel.
- [ ] → Phase 3: rolls onto the kicker *without the rear wheel lifting*. A
      stiff-legged 74 kg body can't: on a 2 g transition the front wheel
      lifts the whole mass before the body can pitch. Real riders absorb
      this with their knees. The test runs and reports it as pending.

### Phase 3 — Rider mass, lean and balance (L)
**Goal:** a rideable scooter. This is the most important phase in the plan.
- [ ] Rider model (inside `rider.gd`): a centre-of-mass point above the deck,
      with a spring-damper leg along the rider's up axis. The leg can lean
      sideways and fore/aft within limits.
- [ ] Rider forces act on the scooter body where the feet are and where the
      hands hold the bars. Combined centre of mass and inertia are updated
      as the rider moves.
- [x] **Lean → steer** (done in Phase 2): steering follows the lean.
- [ ] **Rider weight shift replaces the balance torque**: the lean comes from
      the rider moving their centre of mass, not a torque applied to the
      body. The strength stays a slider, with 0 meaning full simulation.
- [ ] Rider legs absorb transitions, so the rear wheel stays down on the
      kicker (the pending Phase 2 test).
- [ ] **Kick**: pressing A applies a foot-push force for a short time,
      only when grounded and below a top kicking speed.
- [ ] Simple visuals: a capsule rider that leans and compresses with the
      simulation.

**Exit criteria:**
- The kicker test's pending checks pass: the rear wheel stays planted
  through the transition, and it leaves at the lip angle.
- Riding laps around the park at kicking speed feels controlled.
- Carving tight and wide turns is predictable.
- With assist at 0, riding is *hard but possible*. With the default assist,
  it's comfortable.
- Braking hard with the rear-only brake behaves believably.

### Phase 4 — Compression, pop and pumping (M)
**Goal:** the rider's legs add and remove energy, as they do in real life.
- [ ] Right stick down = compress the legs (lower centre of mass). Release
      or flick up = extend with force (pop).
- [ ] **Pop**: extending quickly while grounded produces a small hop.
      Scooter riders do this with the deck, like a bunny hop.
- [ ] **Pumping**: compressing into a transition and extending out of it
      raises the rider's centre of mass against centripetal force, which
      adds kinetic energy. It isn't scripted: it emerges from the leg forces
      in Phase 3.
- [ ] Energy telemetry: plot kinetic + potential energy over time so
      you can *see* pumping gain energy and friction lose it.

**Exit criteria:** you can keep going back and forth on the mini ramp
**without kicking**, using pumping alone. Energy telemetry shows the
gain on each pump.

### Phase 5 — Airs, landings and bails (M)
**Goal:** leaving the ground, controlling the air, and landing or bailing.
- [ ] Airborne detection (both wheels without contact for more than N ticks).
- [ ] **Air control, skate.-style.** Physically, a rider can't start a spin
      in mid-air (angular momentum is conserved). We keep the flavour of that
      but favour playability:
  - Takeoff matters: leaning and winding up on the lip sets most of the
    spin and flip, which rewards good riding.
  - The left stick adds a moderate amount of air torque on top, so you can
    always correct and adjust. Its strength is a slider.
- [ ] **Landing assist**: in the last fraction of a second before
      touchdown, gently rotate the scooter toward the landing surface when
      it's already close. It's skate.'s hidden helper and a big part of why
      landings feel fair. Its strength and the maximum angle it can correct
      are sliders.
- [ ] Landing evaluation, *after* the assist: angle between the deck and
      the ground normal, spread in wheel contact timing, and impact speed.
      Clean / sketchy / bail thresholds are tuning values, with generous
      defaults.
- [ ] **Bail, stage 1**: when a bail is detected, slow motion for ~0.5 s,
      a camera cut, then respawn at the last safe spot. (Basic recovery
      already exists: standing up after a fall, by button or automatically.)
- [ ] Coping behaviour: the quarter pipe lip must launch you straight up
      and let you land back in, which is the classic hard case for
      shape-cast wheels.

**Exit criteria:**
- Airs out of the quarter pipe land back in reliably when done well.
- Kicker jumps land cleanly when done well and bail when done badly, and
  the difference matches what you'd expect.
- Nothing launches you wildly across the park (no physics explosions).

### Phase 6 — Chase camera (S–M)
**Goal:** a camera that makes the riding readable and feel fast.
- [ ] Follow with a spring (position lag) and look-ahead in the direction
      of travel.
- [ ] Separate handling for the air: don't follow the scooter's rotation,
      so flips and spins read clearly.
- [ ] Transition-aware framing: when riding up a quarter pipe, keep the
      lip and the landing in view.
- [ ] Collision avoidance with props.
- [ ] Every value (distance, height, lag, FOV, look-ahead) in the tuning
      panel.

**Exit criteria:** a full session of riding with no moment where the
camera hides the landing or makes you feel sick.

### Phase 7 — First tricks (M)
**Goal:** barspins and tailwhips that feel as achievable as skate.'s flip
tricks.
- [ ] Split the scooter *visuals* into deck and bars+fork+front wheel nodes,
      pivoting about the real headtube axis. The physics body is unchanged.
- [ ] **Flick recognition** on the right stick: direction + speed,
      with generous tolerances (skate.'s flicks are forgiving). Show the
      recognised gesture on the debug HUD so tolerances can be tuned.
- [ ] **Trick playback**: once triggered, the part rotates 360° along a
      tuned curve (quick start, smooth settle) over a fixed duration.
      There's no mid-trick physics to fight.
- [ ] **Barspin**: the bars rotate. **Tailwhip**: the deck rotates around
      the headtube axis while the rider holds the bars.
- [ ] **Where the skill is**: the trick needs airtime. If you land before
      it finishes, you bail. So the skill is in the pop and the timing,
      exactly like skate.
- [ ] **Feedback**: a clear "too early / landed / bailed" read. Optional
      slow-mo on the first land of a new trick.
- [ ] Trick duration, flick tolerance and the "almost finished" grace
      window are all sliders.

**Exit criteria:** after a few minutes of practice, a new player can land a
barspin and a tailwhip off the kicker. Failures read as *their* mistake
(not enough air, bad landing), never as the game's.

---

## 6. Out of scope for now (in rough later order)

1. Grinds and stalls on coping and rails (special contact handling).
2. Manuals, meaning balance on one wheel. This is a genuine inverted
   pendulum, so it's a good fit for the realism goal.
3. More tricks: 180s/360s, bri flips, whip variations, combos.
4. Rider character model, IK for hands and feet, animation blending.
5. Ragdoll bails (stage 2: a single tumbling body; stage 3: a jointed ragdoll).
6. Audio: wheel roll on different surfaces, coping hits, landings.
7. A real park level, and maybe a park builder.
8. Scoring, sessions, progression.
9. Web export demo, and Steam builds.
10. Multiplayer (probably never).

---

## 7. Risks and how they're handled

| Risk | Mitigation |
|---|---|
| Physics jitter or explosions from the rider/scooter mass ratio | Single-body model with an internal rider simulation. Tricks are visual-only rotations, so no second body is ever needed. A higher tick rate if needed. |
| Wheels catching on coping or box edges | Sphere shape-casts, not raycasts. Test props specifically for this. |
| Realistic riding turns out not to be fun | Every assist is a slider. Decide by playing, not by arguing. Tricks are already on the fun side of the line. |
| Tuning goes round in circles | Input replay plus committed tuning Resources. Keep a tuning log in `docs/`. |
| Scope creep into art and content | §1 rule 1. Placeholder shapes until Phase 7 exits. |
| Beginner stalls on a hard phase | Each phase has a playable exit. If stuck for over 2 weeks, simplify the model and move on. |

---

## 8. Definition of done for the sandbox

With a controller, in the flat sandbox, a player can: kick up to speed,
carve around, pump the mini ramp without kicking, air out of a quarter
pipe, land a barspin and a tailwhip, bail believably when they get it
wrong, and respawn. All of this uses placeholder shapes, and it's
**fun to do for ten minutes straight.**
