class_name ScooterTuning
extends Resource
## Every number that shapes how the scooter rides. Real-world starting
## values; all of them are live sliders in the tuning panel.

@export_group("Mass")
@export_range(2.0, 10.0, 0.1, "suffix:kg") var scooter_mass := 4.0
@export_range(30.0, 120.0, 1.0, "suffix:kg") var rider_mass := 70.0
## Part of the rider that moves with the deck (feet and shins, ~15% of body
## mass). The rest rides on the legs.
@export_range(2.0, 25.0, 0.5, "suffix:kg") var rider_leg_mass := 11.0
## Rider's centre of mass above the ground when standing.
@export_range(0.5, 1.4, 0.01, "suffix:m") var rider_com_height := 1.0
## Where the rider stands, fore/aft of the deck centre (+ is toward the rear).
@export_range(-0.2, 0.2, 0.005, "suffix:m") var rider_com_offset := 0.02
## Scooter body (scooter + shins) resistance to rolling and pitching.
@export_range(0.2, 5.0, 0.05, "suffix:kg·m²") var inertia_roll_pitch := 1.5
@export_range(0.05, 2.0, 0.05, "suffix:kg·m²") var inertia_yaw := 0.3

@export_group("Geometry")
## Height of the deck's top surface above the ground.
@export_range(0.05, 0.15, 0.005, "suffix:m") var deck_top := 0.085
## 110 mm wheels.
@export_range(0.04, 0.08, 0.001, "suffix:m") var wheel_radius := 0.055
@export_range(0.35, 0.6, 0.005, "suffix:m") var wheelbase := 0.47
## Angle of the steering axis from horizontal. 90 = vertical.
@export_range(70.0, 90.0, 0.5, "suffix:°") var headtube_angle_deg := 83.0

@export_group("Wheels")
## Solid PU barely compresses; this is kept a bit soft for stability and
## to smooth the facets of curved ramps. ~5 mm under a standing rider.
@export_range(10000.0, 300000.0, 1000.0, "suffix:N/m") var wheel_stiffness := 80000.0
@export_range(0.1, 2.0, 0.05) var wheel_damping_ratio := 0.8
## How far a wheel can be pushed up before the bump stop.
@export_range(0.01, 0.06, 0.001, "suffix:m") var wheel_travel := 0.03
## Bump stop stiffness, as a multiple of wheel_stiffness, in the last 20%.
@export_range(1.0, 30.0, 0.5) var bump_stiffness_scale := 10.0

@export_group("Tyres")
## Multiplies the surface's friction (concrete 0.9, steel 0.3).
@export_range(0.0, 2.0, 0.01) var grip_scale := 1.0
## Once sliding, grip drops to this fraction of peak until it regrips.
@export_range(0.3, 1.0, 0.01) var slide_ratio := 0.7
## PU on smooth concrete, bearings included.
@export_range(0.0, 0.05, 0.001) var rolling_resistance := 0.015
## How much of the lateral velocity each wheel cancels per tick. Lower is
## softer and more stable, higher is stiffer.
@export_range(0.1, 1.0, 0.05) var friction_relax := 1.0

@export_group("Brake, push, air")
## Rear fender brake friction against the wheel.
@export_range(0.0, 1.5, 0.05) var brake_mu := 0.8
@export_range(0.0, 800.0, 10.0, "suffix:N") var push_force := 300.0
@export_range(0.05, 0.6, 0.01, "suffix:s") var push_duration := 0.25
## Kicking stops helping above this speed.
@export_range(1.0, 12.0, 0.5, "suffix:m/s") var push_max_speed := 6.0
## Drag coefficient × frontal area of a standing rider.
@export_range(0.0, 1.5, 0.05, "suffix:m²") var drag_area := 0.5

@export_group("Lean and steering")
## Lean at full stick, at most. On concrete, the grip margin below
## limits it to about 26° first.
@export_range(10.0, 50.0, 1.0, "suffix:°") var max_lean_deg := 35.0
## Full stick never leans further than the turn can hold up: this fraction
## of the tyres' grip. The rest is headroom for settling into the lean,
## which overshoots by up to ~6°; past the grip, the tyres slide out.
@export_range(0.3, 1.0, 0.01) var lean_grip_margin := 0.55
## ...and this fraction of the tightest turn the steering allows at the
## current speed.
@export_range(0.3, 1.0, 0.01) var lean_steer_margin := 0.6
## Below this speed the stick steers directly; above lean_steer_full_speed
## the steering only follows the lean.
@export_range(0.0, 3.0, 0.1, "suffix:m/s") var lean_steer_min_speed := 0.5
@export_range(0.5, 5.0, 0.1, "suffix:m/s") var lean_steer_full_speed := 2.0
@export_range(5.0, 45.0, 1.0, "suffix:°") var max_steer_slow_deg := 30.0
@export_range(2.0, 20.0, 0.5, "suffix:°") var max_steer_fast_deg := 6.0
## Speed at which the steering limit reaches max_steer_fast_deg.
@export_range(2.0, 15.0, 0.5, "suffix:m/s") var steer_fast_speed := 8.0
@export_range(30.0, 720.0, 10.0, "suffix:°/s") var steer_rate_deg := 240.0
## Countersteer per radian of lean error (in g of sideways acceleration).
## Higher leans in faster.
@export_range(0.0, 5.0, 0.05) var countersteer_gain := 2.5
## Steering against the lean rate, so leans settle without wobbling.
@export_range(0.0, 2.0, 0.05, "suffix:s") var countersteer_damping := 0.9

@export_group("Legs")
## Spring toward the chosen leg length. Lower is softer knees.
@export_range(2000.0, 40000.0, 250.0, "suffix:N/m") var leg_stiffness := 9000.0
@export_range(0.1, 2.0, 0.05) var leg_damping_ratio := 0.35
## Strongest push the legs can make (about 3× body weight).
@export_range(500.0, 5000.0, 50.0, "suffix:N") var leg_max_push := 2000.0
## Strongest pull, through the arms on the bars.
@export_range(0.0, 1500.0, 25.0, "suffix:N") var leg_max_pull := 400.0
## How far a full crouch lowers the hips.
@export_range(0.1, 0.5, 0.01, "suffix:m") var crouch_depth := 0.35
## Straight-legged is this much longer than standing.
@export_range(0.0, 0.2, 0.01, "suffix:m") var extend_range := 0.08
## Arms and ankles resist the deck pitching quickly under the rider (so it
## doesn't flop nose-down off a lip). A damper, so on transitions the deck
## still follows the ramp.
@export_range(0.0, 200.0, 1.0, "suffix:N·m·s/rad") var deck_pitch_damping := 60.0
## How quickly the body lines up with the ground's push (time constant).
@export_range(0.01, 0.5, 0.01, "suffix:s") var leg_axis_response := 0.05
## The knee and hip joints' hard limits.
@export_range(10000.0, 200000.0, 1000.0, "suffix:N/m") var leg_stop_stiffness := 60000.0

@export_group("Hips (weight shift)")
## Holds the hips over the deck sideways and fore/aft.
@export_range(2000.0, 40000.0, 250.0, "suffix:N/m") var hip_stiffness := 15000.0
@export_range(0.1, 2.0, 0.05) var hip_damping_ratio := 0.7
## Hip shift toward the lean you want, per radian of lean error. 0 by
## default: shoving the hips sideways kicks the light scooter the other way,
## so riders (and this model) lean by countersteering instead.
@export_range(0.0, 3.0, 0.05, "suffix:m/rad") var hip_lean_gain := 0.0
## Hip shift against the lean rate, to settle without overshoot.
@export_range(0.0, 1.0, 0.01, "suffix:m·s/rad") var hip_lean_damping := 0.0
@export_range(0.05, 0.5, 0.01, "suffix:m") var max_hip_shift := 0.3
## Weight forward/back at full left-stick up/down. Far enough back
## lifts the front wheel (a manual); forward lifts the rear (a nose manual).
@export_range(0.0, 0.6, 0.01, "suffix:m") var max_hip_fore_aft := 0.4
## How fast the hips move fore/aft.
@export_range(0.2, 5.0, 0.05, "suffix:m/s") var hip_fore_aft_rate := 1.2

@export_group("Manuals")
## Help balancing a manual: 0 = raw physics, 1 = full help.
@export_range(0.0, 1.0, 0.01) var manual_assist := 0.3
## Deck angle the assist balances a manual at (nose manual: the same, down).
@export_range(3.0, 35.0, 0.5, "suffix:°") var manual_balance_deg := 14.0
@export_range(0.0, 2000.0, 10.0, "suffix:N·m/rad") var manual_stiffness := 600.0
@export_range(0.0, 300.0, 5.0, "suffix:N·m·s/rad") var manual_damping := 80.0
## Counts as a manual past this deck angle, held at least this long.
@export_range(1.0, 15.0, 0.5, "suffix:°") var manual_min_deg := 4.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var manual_min_time := 0.5

@export_group("Balance assist")
## Help from a torque on top of the rider's own weight shift, at speed.
## 0 = none: the rider balances by themselves.
@export_range(0.0, 1.0, 0.01) var assist_strength := 0.0
## Help when nearly stopped, standing in for a foot put down. Fades out
## between stand_assist_speed and twice that.
@export_range(0.0, 1.0, 0.01) var stand_assist := 1.0
@export_range(0.2, 3.0, 0.1, "suffix:m/s") var stand_assist_speed := 1.0
@export_range(0.0, 8000.0, 50.0, "suffix:N·m/rad") var assist_stiffness := 2500.0
@export_range(0.0, 3000.0, 25.0, "suffix:N·m·s/rad") var assist_damping := 700.0
## How fast the rider can shift into a new lean.
@export_range(20.0, 400.0, 5.0, "suffix:°/s") var lean_rate_deg := 90.0
## Strongest balance correction a rider could make. Without a cap, a full
## stick flick demands more sideways grip than the tyres have.
@export_range(50.0, 2000.0, 10.0, "suffix:N·m") var max_balance_torque := 450.0

@export_group("Foot plant")
## Steering lock with the foot down (left trigger), at walking pace.
@export_range(10.0, 60.0, 1.0, "suffix:°") var foot_steer_deg := 45.0
## With the foot down, the steering still never asks the tyres for more
## than this fraction of their grip.
@export_range(0.3, 1.0, 0.01) var foot_grip_margin := 0.7
## Friction of the foot scuffing along the ground. 60 N slows the rider
## by about 0.8 m/s every second.
@export_range(0.0, 500.0, 5.0, "suffix:N") var foot_scuff_force := 60.0
## Furthest the rider leans onto the foot.
@export_range(0.0, 60.0, 1.0, "suffix:°") var foot_max_lean_deg := 12.0
## How hard the foot can push the rider upright.
@export_range(50.0, 3000.0, 10.0, "suffix:N·m") var foot_max_torque := 900.0
## Foot position: this far to the side of the deck.
@export_range(0.1, 0.6, 0.01, "suffix:m") var foot_offset := 0.3

@export_group("Air and landing")
## Both wheels off the ground this long counts as airborne (short hops over
## bumps don't).
@export_range(0.02, 0.5, 0.01, "suffix:s") var airborne_min_time := 0.12
## Scales every air rotation rate below. 0 = no air control at all.
@export_range(0.0, 1.0, 0.01) var air_control_strength := 1.0
## Nose down/up rate at full left stick forward/back.
@export_range(0.0, 720.0, 10.0, "suffix:°/s") var air_pitch_rate_deg := 200.0
## Spin rate at full left stick left/right.
@export_range(0.0, 1080.0, 10.0, "suffix:°/s") var air_spin_rate_deg := 360.0
## How quickly the rider levels the scooter in roll (1/s), and how firmly.
@export_range(0.0, 20.0, 0.5, "suffix:1/s") var air_level_rate := 4.0
@export_range(0.0, 1.0, 0.01) var air_level_strength := 1.0
## Time to reach a new rotation rate. Lower is snappier.
@export_range(0.02, 0.5, 0.01, "suffix:s") var air_control_response := 0.08
## Strongest twist the rider can put on the scooter in the air.
@export_range(10.0, 1000.0, 10.0, "suffix:N·m") var air_max_torque := 250.0
## Rotates the scooter to meet the landing, shortly before touchdown.
@export_range(0.0, 1.0, 0.01) var landing_assist_strength := 1.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var landing_assist_window := 0.3
## Only helps when already this close to lined up.
@export_range(0.0, 90.0, 1.0, "suffix:°") var landing_assist_max_deg := 60.0
## Landing grades: tilt against the ground, and how sideways to the
## direction of travel (fakie counts as straight).
@export_range(0.0, 45.0, 1.0, "suffix:°") var landing_clean_deg := 15.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var landing_sketchy_deg := 35.0
@export_range(0.0, 45.0, 1.0, "suffix:°") var landing_sideways_clean_deg := 20.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var landing_sideways_sketchy_deg := 50.0
## Slow motion when bailing: game speed and how long it lasts (real time).
@export_range(0.05, 1.0, 0.05) var bail_slowmo_scale := 0.3
@export_range(0.0, 3.0, 0.1, "suffix:s") var bail_slowmo_time := 0.6

@export_group("Pop")
## How high a pop lifts you (the whole body).
@export_range(0.1, 1.0, 0.01, "suffix:m") var pop_height := 0.45
## A pop: the right stick rising past pop_threshold from at least 0.4
## below it, within pop_window. Slower is just extending the legs.
@export_range(0.2, 0.95, 0.01) var pop_threshold := 0.5
@export_range(0.05, 0.5, 0.01, "suffix:s") var pop_window := 0.2
## Still pops this long after rolling off the ground (a late pop at a lip).
@export_range(0.0, 0.3, 0.01, "suffix:s") var pop_grace := 0.12
## The legs tuck up after a pop, pulling the scooter up under you.
@export_range(0.0, 0.8, 0.01, "suffix:s") var pop_tuck_time := 0.3

@export_group("Grinds")
## Steel under a scooter deck. Real steel is ~0.3; waxed coping and rails
## run slicker, and longer grinds are more fun.
@export_range(0.0, 0.5, 0.01) var grind_friction := 0.12
## Catches an edge this far below the deck's underside (while coming
## down: grind_catch_above)...
@export_range(0.01, 0.2, 0.005, "suffix:m") var grind_catch_distance := 0.06
@export_range(0.0, 0.8, 0.01, "suffix:m") var grind_catch_above := 0.35
## ...or coming down this far short of its start (along it)...
@export_range(0.0, 1.5, 0.05, "suffix:m") var grind_catch_before := 0.6
## ...and up to this far to the side of it (the lock slides you over)...
@export_range(0.02, 0.5, 0.01, "suffix:m") var grind_catch_side := 0.25
## A deck this far below the edge's top, still rising or at the top of
## its pop, snaps up onto it.
@export_range(0.0, 0.1, 0.005, "suffix:m") var grind_snap_up := 0.04
## ...moving along it at least this fast...
@export_range(0.2, 4.0, 0.1, "suffix:m/s") var grind_min_speed := 1.0
## ...and lined up with it within this angle (forward or fakie).
@export_range(5.0, 60.0, 1.0, "suffix:°") var grind_max_angle_deg := 30.0
## The edge holding the deck up: stiffness of the contact.
@export_range(5000.0, 80000.0, 500.0, "suffix:N/m") var grind_stiffness := 30000.0
## The sideways lock (an assist), as an acceleration of scooter and rider
## together: how quickly it closes the gap (critically damped), and its
## strongest pull.
@export_range(0.0, 40.0, 0.5, "suffix:1/s") var grind_lock_rate := 12.0
@export_range(0.0, 60.0, 0.5, "suffix:m/s²") var grind_lock_max_accel := 20.0
## Turning to line up with the edge: time to close the gap, strongest torque.
@export_range(0.03, 1.0, 0.01, "suffix:s") var grind_align_time := 0.12
@export_range(0.0, 1500.0, 10.0, "suffix:N·m") var grind_max_torque := 400.0
## Ankles holding the deck's roll under the rider's legs on the edge. Soft
## on purpose: stiffer fights the hips into a wobble.
@export_range(0.0, 2000.0, 10.0, "suffix:N·m/rad") var grind_roll_stiffness := 300.0
@export_range(0.0, 200.0, 1.0, "suffix:N·m·s/rad") var grind_roll_damping := 30.0

@export_group("Tricks")
## Time for a whole barspin / tailwhip. Longer needs more air.
@export_range(0.15, 1.0, 0.01, "suffix:s") var barspin_time := 0.35
@export_range(0.15, 1.0, 0.01, "suffix:s") var tailwhip_time := 0.45
## Landing with this much of the spin left (as it looks: the spin eases
## out) still counts: it snaps round. 25° is reached ~70% of the way
## through the trick's time.
@export_range(0.0, 120.0, 1.0, "suffix:°") var trick_grace_deg := 25.0
## A flick: the right stick from inside flick_centre to past flick_edge
## within flick_max_time.
@export_range(0.05, 0.6, 0.01) var flick_centre := 0.3
@export_range(0.5, 1.0, 0.01) var flick_edge := 0.85
@export_range(0.03, 0.5, 0.01, "suffix:s") var flick_max_time := 0.15

@export_group("Recovery")
## Tipped further than this counts as fallen.
@export_range(30.0, 90.0, 1.0, "suffix:°") var fallen_angle_deg := 60.0
## Stand back up automatically after being fallen this long. 0 = never.
@export_range(0.0, 5.0, 0.1, "suffix:s") var auto_recover_delay := 1.5
## Holding reset this long returns to the spawn point.
@export_range(0.3, 2.0, 0.05, "suffix:s") var respawn_hold_time := 0.75

@export_group("Debug")
## Length of drawn force arrows: metres per newton.
@export_range(0.0001, 0.005, 0.0001) var force_draw_scale := 0.001


func total_mass() -> float:
	return scooter_mass + rider_mass


## Scooter plus shins: the physics body the wheels hold up.
func unsprung_mass() -> float:
	return scooter_mass + rider_leg_mass


## Hips, torso, arms and head: the rider body on the legs.
func sprung_rider_mass() -> float:
	return rider_mass - rider_leg_mass


## Centre of mass of the scooter body (scooter + shins), in its own frame
## (origin on the ground, midway between the wheels).
func scooter_center_of_mass() -> Vector3:
	var shin_height := deck_top + 0.25
	var y := (scooter_mass * 0.12 + rider_leg_mass * shin_height) / unsprung_mass()
	var z := rider_leg_mass * rider_com_offset / unsprung_mass()
	return Vector3(0.0, y, z)


## Centre of mass of everything, standing, in the scooter's frame.
func center_of_mass() -> Vector3:
	var scooter_com := scooter_center_of_mass()
	var hips := Vector3(0.0, deck_top + stand_leg_length(), rider_com_offset)
	return (scooter_com * unsprung_mass() + hips * sprung_rider_mass()) / total_mass()


## Hips above the feet when standing, chosen so the whole rider's centre of
## mass sits at rider_com_height.
func stand_leg_length() -> float:
	var shin_height := deck_top + 0.25
	var hips_height := (rider_com_height * rider_mass - rider_leg_mass * shin_height) / sprung_rider_mass()
	return hips_height - deck_top


func max_leg_length() -> float:
	return stand_leg_length() + extend_range


## Steering axis in the scooter's frame: up, tilted back toward the rear.
func headtube_axis() -> Vector3:
	var a := deg_to_rad(headtube_angle_deg)
	return Vector3(0.0, sin(a), cos(a))


## Damping for each wheel's spring, from the mass it carries directly (the
## rider's upper body is carried through the legs, with its own damping).
func wheel_damping() -> float:
	return 2.0 * wheel_damping_ratio * sqrt(wheel_stiffness * unsprung_mass() * 0.5)
