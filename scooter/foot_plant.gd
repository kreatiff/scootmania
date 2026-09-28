class_name FootPlant
extends RefCounted
## The pushing foot on the ground. Held on the left trigger, it plants beside
## the rear wheel on the inside of the turn, and:
## - holds the rider up, so the scooter can turn tighter than a balanced
##   lean allows: the bars go to full lock at walking pace;
## - scuffs, so it costs speed (at speed it's mostly a brake);
## - can't kick while it's on the ground.
## Near standstill the foot also goes down on its own, holding you up
## (the "stand assist"), without scuffing, so you can still kick off.
##
## The foot's push is an outside force on the rider, like the ground's.

## Foot on the ground this tick (held or automatic).
var planted := false
## Held on the trigger: the full plant, with scuffing and full lock.
var held := false
## +1 = right of the deck, -1 = left.
var side := -1.0
## Where the foot touches the ground (for drawing).
var point := Vector3.ZERO

var _last_force := Vector3.ZERO
var _last_velocity := Vector3.ZERO


## Decides whether the foot is down, before lean and steering.
func update(scooter: Scooter, tuning: ScooterTuning, intent: RiderIntent, speed: float) -> void:
	var down := scooter.is_grounded() and not scooter.rider.bailed
	held = down and intent.foot
	planted = held or (down and absf(speed) < tuning.stand_assist_speed and tuning.stand_assist > 0.0)
	if absf(intent.lean.x) > 0.2:
		side = signf(intent.lean.x)
	if not planted:
		return
	var heading := Scooter._flat(-scooter.global_basis.z)
	var right := heading.cross(Vector3.UP) if heading != Vector3.ZERO else scooter.global_basis.x
	var rear := scooter.rear_wheel.contact_point if scooter.rear_wheel.in_contact else scooter.global_position
	point = rear + right * side * tuning.foot_offset + heading * 0.1


## Steering angle (at the bars) while the foot is held: straight from the
## stick up to full lock, but never more than the tyres can turn at this
## speed.
func steer_target(scooter: Scooter, tuning: ScooterTuning, intent: RiderIntent, speed: float) -> float:
	var limit := deg_to_rad(tuning.foot_steer_deg)
	var v2 := speed * speed
	if v2 > 1e-4:
		var grip := tuning.grip_scale * scooter.surface_grip() * tuning.foot_grip_margin
		var ground_tan := tuning.wheelbase * grip * Scooter.GRAVITY / v2
		limit = minf(limit, atan(ground_tan / sin(deg_to_rad(tuning.headtube_angle_deg))))
	return clampf(intent.lean.x * deg_to_rad(tuning.foot_steer_deg), -limit, limit)


## Lean while the foot is held: whatever balances the turn the steering
## makes, capped; the foot holds up the rest.
func lean_target(scooter: Scooter, tuning: ScooterTuning, speed: float) -> float:
	var ground_tan := tan(scooter.steer_angle) * sin(deg_to_rad(tuning.headtube_angle_deg))
	var lateral := speed * speed * ground_tan / tuning.wheelbase
	var limit := deg_to_rad(tuning.foot_max_lean_deg)
	return clampf(atan(lateral / Scooter.GRAVITY), -limit, limit)


## The scuff: friction at the foot against the rider's sliding over the
## ground, up to foot_scuff_force. Like static friction it can hold you
## still. Its work goes into scooter.assist_work.
func apply_scuff(scooter: Scooter, tuning: ScooterTuning, delta: float) -> void:
	var rider := scooter.rider
	scooter.assist_work += 0.5 * _last_force.dot(rider.linear_velocity - _last_velocity) * delta
	_last_force = Vector3.ZERO
	if not held:
		return
	var v := rider.linear_velocity
	var v_flat := Vector3(v.x, 0.0, v.z)
	var stop := -v_flat * (rider.mass + scooter.mass) / delta
	var force := stop.limit_length(tuning.foot_scuff_force)
	rider.apply_central_force(force)
	scooter.assist_work += force.dot(v) * delta
	_last_force = force
	_last_velocity = v
