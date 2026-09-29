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
- **Physics tick: 240 Hz** (`physics/common/physics_ticks_per_second`).
  It started at 120 Hz. Phase 3 made the scooter body light (the rider's
  upper body became its own body), and stiff wheel springs on a light body
  need the smaller step. Rendering is decoupled from
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
| Right stick flick | — | Sideways: tailwhip. Up/down: barspin |
| Right trigger | Rear brake (fender brake) | — |
| Left trigger | Foot plant (tight turns) | — |
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

### Phase 3 — Rider mass, lean and balance (L) ✅
**Goal:** a rideable scooter. This is the most important phase in the plan.

*Change from the plan:* the rider isn't a point simulated inside the
scooter. Phase 2 showed the tyres need a real physics body carrying most
of the load, so the model is **two bodies** joined by forces we compute:
the scooter plus the rider's shins (15 kg), and the rider's upper body
(59 kg). This split is how a real body divides: shins move with the deck,
everything above the knees rides on the legs.
- [x] **Legs:** a spring-damper along the leg axis. Muscles carry body
      weight, the right stick sets leg length (crouch / extend), and there
      are joint limits. The leg axis follows the scooter's roll but stays
      vertical in pitch, so the hips stay over the feet on ramps.
- [x] **Hips:** hold the torso over the deck. Sideways, the reaction goes
      into the scooter at hip height (the scooter rolls with the rider).
      Fore/aft it goes through the feet (the scooter pitches freely).
- [x] **Arms and ankles** damp the deck's pitch rate, so the deck doesn't
      flop nose-down off a lip.
- [x] **Lean → steer**, now with **countersteering**: to lean in, the bars
      flick the other way first, then the steering balances the lean. This
      replaced the balance torque. (Weight-shifting the hips was tried first:
      with a light scooter, shoving the hips sideways kicks the scooter out
      the other way and tips you over. It's a slider, off by default.)
- [x] **Stand assist:** near standstill, where nobody balances by
      steering, a sideways force stands in for putting a foot down.
- [x] **Wheel tyres anticipate** every force on the scooter body this tick
      (gravity, rider, push, other wheel), so a light body doesn't slip a
      tick behind. This removed ~17% understeer.
- [x] **Bail:** tipped past 60°, the rider lets go and falls as a free body
      until recovery.
- [x] Kick; visuals (torso capsule, a leg that visibly compresses).

**Exit criteria:**
- [x] The kicker's rear wheel stays planted through the transition
      (automated), and the energy audits still balance with two bodies.
- [x] Countersteered turns reach the asked-for lean; the turn balances it;
      yaw rate matches the bicycle model.
- [ ] Riding laps around the park feels controlled *(needs you, with a
      controller)*.
- [ ] Braking hard with the rear-only brake behaves believably *(same)*.

### Phase 4 — Compression, pop and pumping (M) ✅
**Goal:** the rider's legs add and remove energy, as they do in real life.
- [x] Right stick down = crouch (shorter legs), up = extend. Built in
      Phase 3; the legs are real forces, so everything below emerges.
- [x] **Pop**: crouch, then flick up. The legs push at up to 2,000 N, lock
      straight and lift the scooter with the body. Clears ~0.34 m from
      rolling, and **nothing without the crouch** (skate.-style).
- [x] **Pumping**: extending up the transitions and crouching elsewhere
      keeps a mini ramp going without kicking. Not scripted: it comes from
      the leg forces. Leg damping lowered (0.35) so active pushing isn't
      taxed by the damper.
- [x] **Fakie**: the mini ramp is ridden backwards on every other wall.
      Balance steering keeps the same sign rolling backwards (a sign flip
      I tried first made fakie fall over).
- [x] **Energy graph** on the HUD (top right): total mechanical energy and
      leg force over the last 10 s.
- [x] Energy audits made exact: work is counted with each step's average
      velocity. Counting with the start velocity drifted ~25 J/s under
      pumping.

Fixes found along the way:
- A sideways hip-force instability when the scooter is steeply pitched
  and airborne (yaw wobble at ±30 rad/s): the reaction now acts on the
  scooter's own upright axis, and damping is sized for the effective mass.
- The bank's sharp top edge caught the deck between the wheels: it now has
  a rounded edge (`top_radius`, 0 = sharp).
- A scooter hung up on its deck (not tipped, wheels off the ground,
  stopped) now counts as down for recovery, and recovery finds a spot with
  level ground for both wheels instead of standing you back on a box.

**Exit criteria (automated):**
- [x] Pop clears the ground from a crouch, not without one, and lands upright.
- [x] Popping at the kicker's lip flies higher and longer than rolling off.
- [x] Pumping keeps the mini ramp going for 20 s without kicking (a passive
      rider stops), and the energy audit shows the gain comes from the legs.
- [ ] Pumping the mini ramp by hand, with a controller, feels right *(you)*.

### Phase 5 — Airs, landings and bails (M) ✅
**Goal:** leaving the ground, controlling the air, and landing or bailing.
- [x] Airborne detection: both wheels off for more than
      `airborne_min_time` (0.12 s) counts as a jump. Air *control* starts
      the moment both wheels leave; only the grading waits.
- [x] **Air control, skate.-style.** Rate control rather than raw torque:
      the stick sets a pitch rate (forward = nose down) and a spin rate;
      a torque (capped, slider) drives the scooter toward it.
  - Stick centred **holds the pitch** (hands on the bars) and lets any
    spin you took off with carry on. So spin off a lip rewards takeoff;
    pitch doesn't carry over, because the rider's arms hold it in reality
    too.
  - The rider keeps the scooter level in roll.
  - All air torque is counted as work, so the energy audits still balance.
- [x] **Landing assist**: within 0.3 s of the predicted touchdown (the
      ballistic path is ray-cast ahead), if the scooter is within 60° of
      lined up, it's rotated to meet the surface: up along the normal, deck
      along the travel direction, forward or fakie.
- [x] Landing grade, *after* the assist: tilt against the landing surface
      and how sideways the deck is to the travel direction.
      Clean < 15° / 20° sideways, bail > 35° / 50°. Wheel-timing spread and
      impact speed aren't used yet, and weren't needed.
- [x] **Bail, stage 1**: the rider lets go, the `bailed` signal fires, 0.6 s
      of slow motion (0.3×), then the existing recovery stands you up where
      you stopped. The camera cut waits for Phase 6. Respawning at the last
      safe spot was dropped: standing up where you fell is what skate. does,
      and it's less disorienting.
- [x] Coping: airs out of a vertical-lipped quarter pipe land back in
      (test: 0.31 m above the coping, clean, rides away fakie).

**What we learned:**
- **The legs pushed the scooter off the wall.** The leg force used to act
  below the scooter's centre of mass, so every push pitched it. It now acts
  *at* the centre of mass.
- **The leg axis follows the ramp geometry, not the measured ground
  force.** Following the force made a feedback loop that shook the rider
  off vert. The axis now turns toward "gravity + centripetal" computed from
  the ramp's normal and curvature (`Rider.follow_ramp`).
- **"Fallen" on vert is relative to the ground.** The fallen check used
  world up, so riding up a vertical wall counted as a fall. On the ground
  it now measures tilt against the contact normal; in the air, only roll.
- **The coping stuck out 4.5 cm** and caught the wheels. It's now 6 mm
  proud, like real coping.
- **The landing prediction started inside the wall** it had just left. It
  now starts above the deck and ignores surfaces facing away.
- **Pumping, done badly, throws you off the wall.** Extending all the way
  up the transition fully stretches the legs near the top, which yanks the
  scooter off the ramp. Extend through the lower transition, then hold.
- **The park quarter pipe's 70° lip throws you onto the deck** unless you
  spin. That's real (it's why riders do 180s on those ramps), but to air
  straight back in, you need a vertical lip.
- **Vert airs have to be pumped.** Rolling in passively, the knees soak up
  the transition and you stall below the lip. Crouch on the way in, then
  extend through the transition.

**Exit criteria:**
- [x] Airs out of the quarter pipe land back in reliably when done well
      (vert test).
- [x] Kicker jumps land cleanly when done well and bail when done badly
      (60° nose-high bails), and the difference matches what you'd expect.
- [ ] Nothing launches you wildly across the park. The tests don't catch
      anything, but this needs hands-on play to confirm.
- [ ] Hands-on: does the assist feel fair rather than like autopilot?

### Turning rework (between Phases 5 and 6) ✅
Pulling the stick hard to one side tipped the rider over. Measured cause:
- **Below ~2.5 m/s**, the steering can't turn tight enough to hold a 35°
  lean (at 2 m/s the bars' limit holds ~21°), so you fall into the turn.
- **Above that**, the lean overshot its target while still falling in;
  catching it asked the tyres for ~1.1 g against concrete's 0.9, the
  front slid, grip dropped to 0.63 g, and it slid out from under you.

Changes:
- [x] **Full stick = "turn as hard as you can".** The stick asks for at most
      the lean the turn can hold: 55% of the surface's grip (so about 26°
      on concrete, 9° on steel) and 60% of the tightest turn the steering
      allows at this speed. Countersteer gain 1.6 → 2.5 and damping
      0.6 → 0.9 lean in faster, with less overshoot. Tested at every speed
      from 0.5 to 8 m/s: never falls, no tyre slides.
- [x] **Foot plant (hold left trigger).** The foot holds you up (an outside
      force on the rider, like the ground's), the bars go to full lock
      (45°, limited by what the tyres can turn at the current speed), the
      lean onto the foot is capped at 12°, the foot scuffs (60 N), and
      you can't kick with it down. Near standstill it goes down by itself,
      without scuffing: this replaces the invisible stand assist with a
      visible foot.

**What we learned:**
- **A hold-you-up force must push square to your path, not to the deck.**
  In a tight pivot the rider's path cuts inside the scooter's heading, so
  a sideways push along the heading also drove them forward. The first
  foot plant sped the rider up from 1.5 to 2.2 m/s while scuffing. Found
  with the energy audit. (It also has to use the *flat* speed: near the
  top of a ramp wall the path points almost anywhere.)
- **Leaning onto the foot feeds speed back in.** Leaning 40° into a pivot
  drops the centre of mass ~20 cm, which comes out as speed and widens
  the turn. Real riders stay fairly upright and let the foot take it.
- **Known bug, not fixed yet:** in long airs (> ~0.8 s) with some roll or
  yaw, the sideways hip spring and air control's roll levelling feed each
  other into a growing wobble. It shows up as ~15 W of unexplained energy
  in airborne ticks. The pumping audit now only fails on energy *created*,
  and reports the loss.

### Phase 6 — Chase camera (S–M) — accepted as is
The basic chase camera from Phase 1 felt fine in play, so this phase is
parked. Revisit if big airs or vert make the camera hard to read.
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

### Phase 7 — First tricks (M) ✅
**Goal:** barspins and tailwhips that feel as achievable as skate.'s flip
tricks.
- [x] Scooter visuals split into the bars assembly (stem, bars, front
      wheel) and the deck (with the rear wheel), both pivoting about the
      real headtube axis, which meets the front axle. The physics body is
      unchanged.
- [x] **Flick recognition** on the right stick: from inside 0.3 to past 0.85
      within 0.15 s. Holding it out doesn't repeat; it re-arms back at the
      centre. The last flick shows on the debug HUD.
- [x] **Trick playback**: a 360° turn along an ease-out curve (quick start,
      smooth settle). Tailwhip 0.45 s, barspin 0.35 s. No physics during
      the trick.
- [x] **Barspin** (flick up/down) and **tailwhip** (flick sideways, feet
      tucked up while the deck goes round). Tricks chain: flick again once
      one finishes.
- [x] **Where the skill is**: land with more than 25° of the spin still to
      go (as it looks) and you bail, "too early". That's about 70% of the
      trick's time, so a tailwhip needs ~0.32 s of air after the flick.
- [x] **Feedback**: a callout at the top of the screen (green when landed,
      red with the reason when not), and slow motion the first time you
      land each trick.
- [x] Trick durations, grace angle and flick thresholds are sliders.

**What we learned:**
- **Grace has to be judged by what the player sees.** The first version
  measured the grace in *time* left. With the ease-out, the spin looks
  nearly done well before the time runs out, so the rule didn't match the
  screen.

**Exit criteria:**
- [ ] Hands-on: after a few minutes of practice, a new player lands a
      barspin and a tailwhip off the kicker, and failures read as their
      mistake. (Tests: both land when flicked after the pop, and a late
      flick bails.)

### Manuals ✅
- [x] **Weight goes where the rider puts it.** The legs' push square to the
      deck is applied under the rider's chosen fore/aft shift, not at the
      scooter's centre of mass, so weight back loads the rear wheel. Past
      the deck's end, the arms on the bars carry the rest. The shift, not
      the measured body position, and only with a wheel down: on ramps
      the body lags the leg line under load, and levering the deck from
      that broke vert and the kicker (the Phase 5 problem).
- [x] Hips travel ±0.4 m fore/aft (was ±0.12 m), at up to 1.2 m/s.
- [x] **Manual balance assist.** Raw, a manual is an inverted pendulum
      with a ~0.3 s time constant: a simulated player reacting 0.25 s
      late couldn't hold it. While you ask for a manual (stick back with
      only the rear wheel down, or forward with only the front), the arms
      pull the deck toward 14° with a soft spring, at 0.3 strength. At
      0.45 and above it held the manual by itself at almost any stick
      position (no skill left); at 0.3, no fixed stick position holds it,
      full back loops out, and the late player balances it.
- [x] Manuals are timed and called out ("MANUAL 2.4 s", "— looped out").
      A wheel skipping for a tick doesn't end one.

**Exit criteria:**
- [ ] Hands-on: holding a manual across the flat feels like balancing,
      learnable in a few minutes, and looping out reads as pulling too
      hard.

### Grinds ✅ (50-50s)
- [x] Every steel part (rail, ledge angle iron, coping) records its edge
      line; GrindControl finds them.
- [x] **Lock on** when the deck comes down onto an edge (or arrives up to
      4 cm low while rising: a snap-up), moving along it at ≥ 1 m/s,
      lined up within 30° forward or fakie.
- [x] **On the edge:** a stiff, critically damped support (preloaded so it
      doesn't sag) holds the deck on top. The legs push against it like
      the ground, so a normal pop hops off. An assisted sideways lock and
      alignment keep you centred and lined up, and steel friction
      (0.12, "waxed") slows you. The physics engine's own contact with
      that edge is switched off while grinding, or it brakes twice. The
      wheels hover (they overlap the rail a little at the ends).
- [x] **Off:** past the end (when the deck's middle passes it), lifted clear
      for 0.08 s (a pop), or slowed to a stop. No re-catch for 0.25 s.
- [x] Called out live and chained into tricks ("50-50 1.2 s + TAILWHIP").

**What we learned:**
- **The first grind stopped dead:** 538 J vanished. The support sagged
  2.4 cm under the rider, so the engine's box-on-cylinder contact (with
  its own friction) joined in. With that contact off and the support
  preloaded, speed out matches the friction model within 3% and the
  energy audit balances to 0.1 J.
- **Ends are judged at the deck's middle.** Using the deck's front end
  released the grind while half the deck was still on the rail, and it
  re-caught for a phantom "0.0 s" grind.
- **Landing on the rail bounced off it.** With the support only half
  damped, an early pop's landing rebounded past the lift-off test. Now
  critically damped, with a longer lift-off test: every early pop grinds.

**Exit criteria:**
- [ ] Hands-on: popping onto the park rail and ledge feels learnable; the
      lock feels like help, not autopilot.
- Later: stalls on coping, and other grinds (feeble, smith) with balance.

---

## 6. Out of scope for now (in rough later order)

1. ~~Grinds~~ (50-50s done, see above). Stalls and other grinds next.
2. ~~Manuals~~ (done, see above).
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
