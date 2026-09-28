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
## Lean at full stick. 35° is a hard carve.
@export_range(10.0, 50.0, 1.0, "suffix:°") var max_lean_deg := 35.0
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
@export_range(0.0, 5.0, 0.05) var countersteer_gain := 1.6
## Steering against the lean rate, so leans settle without wobbling.
@export_range(0.0, 2.0, 0.05, "suffix:s") var countersteer_damping := 0.6

@export_group("Legs")
## Spring toward the chosen leg length. Lower is softer knees.
@export_range(2000.0, 40000.0, 250.0, "suffix:N/m") var leg_stiffness := 9000.0
@export_range(0.1, 2.0, 0.05) var leg_damping_ratio := 0.6
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
## Weight forward/back at full left-stick up/down.
@export_range(0.0, 0.3, 0.01, "suffix:m") var max_hip_fore_aft := 0.12

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
