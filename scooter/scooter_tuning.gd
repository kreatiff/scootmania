class_name ScooterTuning
extends Resource
## Every number that shapes how the scooter rides. Real-world starting
## values; all of them are live sliders in the tuning panel.

@export_group("Mass")
@export_range(2.0, 10.0, 0.1, "suffix:kg") var scooter_mass := 4.0
## Phase 2: the rider is rigid ballast. Phase 3 gives them legs.
@export_range(30.0, 120.0, 1.0, "suffix:kg") var rider_mass := 70.0
## Rider centre of mass above the ground.
@export_range(0.5, 1.4, 0.01, "suffix:m") var rider_com_height := 1.0
## Rider centre of mass fore/aft of the deck centre (+ is toward the rear).
@export_range(-0.2, 0.2, 0.005, "suffix:m") var rider_com_offset := 0.02
## Resistance to rolling sideways and pitching (mostly the rider's body).
@export_range(5.0, 40.0, 0.5, "suffix:kg·m²") var inertia_roll_pitch := 17.5
@export_range(0.5, 5.0, 0.1, "suffix:kg·m²") var inertia_yaw := 1.5

@export_group("Geometry")
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
@export_range(0.1, 1.0, 0.05) var friction_relax := 0.5

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

@export_group("Balance (Phase 2 stand-in for the rider)")
## How firmly the lean is driven toward the stick's target.
## 1 = firmly; 0 = no help (you'll fall over).
@export_range(0.0, 1.0, 0.01) var assist_strength := 1.0
@export_range(0.0, 8000.0, 50.0, "suffix:N·m/rad") var assist_stiffness := 2500.0
@export_range(0.0, 3000.0, 25.0, "suffix:N·m·s/rad") var assist_damping := 700.0
## How fast the rider can shift into a new lean.
@export_range(20.0, 400.0, 5.0, "suffix:°/s") var lean_rate_deg := 90.0
## Strongest balance correction a rider could make. Without a cap, a full
## stick flick demands more sideways grip than the tyres have.
@export_range(50.0, 2000.0, 10.0, "suffix:N·m") var max_balance_torque := 450.0

@export_group("Debug")
## Length of drawn force arrows: metres per newton.
@export_range(0.0001, 0.005, 0.0001) var force_draw_scale := 0.001


func total_mass() -> float:
	return scooter_mass + rider_mass


## Combined centre of mass in the scooter's frame (origin on the ground,
## midway between the wheels).
func center_of_mass() -> Vector3:
	var scooter_com_height := 0.12
	var y := (scooter_mass * scooter_com_height + rider_mass * rider_com_height) / total_mass()
	var z := rider_mass * rider_com_offset / total_mass()
	return Vector3(0.0, y, z)


## Steering axis in the scooter's frame: up, tilted back toward the rear.
func headtube_axis() -> Vector3:
	var a := deg_to_rad(headtube_angle_deg)
	return Vector3(0.0, sin(a), cos(a))


func wheel_damping() -> float:
	return 2.0 * wheel_damping_ratio * sqrt(wheel_stiffness * total_mass() * 0.5)
