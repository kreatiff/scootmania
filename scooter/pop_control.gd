class_name PopControl
extends RefCounted
## The pop (ollie): the jump nearly every trick starts from, so it's made
## forgiving, skate.-style.
## - Any quick upward move of the right stick pops: a flick from the
##   centre, from a crouch, or a sloppy diagonal. (A slow push up just
##   extends the legs, for pumping ramps.)
## - It leaves the ground at once, with a set strength: rider and scooter
##   get the same upward kick, along the ground's normal. It's the legs'
##   work (counted in rider.work_done).
## - Just rolled off a lip? A pop up to pop_grace after leaving the ground
##   still counts.
## - After the pop the legs tuck, pulling the scooter up under the rider.

## Seconds left of the post-pop tuck (the rider reads it for leg length).
var tuck_left := 0.0
## Popped this tick (for tests and effects).
var popped := false

var _low_y := 0.0 # lowest stick y in the recent window
var _low_age := INF # seconds since the stick was last that low
var _was_up := false
var _air_time := 0.0
var _used := false # already popped since last on the ground


func update(scooter: Scooter, tuning: ScooterTuning, intent: RiderIntent, delta: float) -> void:
	popped = false
	tuck_left = maxf(tuck_left - delta, 0.0)
	var y := intent.pose.y

	# Recent low point of the stick: a pop is the stick rising past
	# pop_threshold from well below it within pop_window.
	_low_age += delta
	if y <= _low_y or _low_age > tuning.pop_window:
		_low_y = y
		_low_age = 0.0
	var up := y >= tuning.pop_threshold
	var flicked := up and not _was_up and _low_y <= tuning.pop_threshold - 0.4
	_was_up = up

	var grounded := scooter.is_grounded() or scooter.grind.active
	if grounded:
		_air_time = 0.0
		_used = false
	else:
		_air_time += delta
	if not flicked or _used or scooter.rider.bailed or _air_time > tuning.pop_grace:
		return
	_pop(scooter, tuning)


func _pop(scooter: Scooter, tuning: ScooterTuning) -> void:
	_used = true
	popped = true
	if scooter.grind.active:
		scooter.grind.pop_off()
	tuck_left = tuning.pop_tuck_time
	var normal := Vector3.ZERO
	for wheel in [scooter.front_wheel, scooter.rear_wheel]:
		if wheel.in_contact:
			normal += wheel.contact_normal
	normal = normal.normalized() if normal != Vector3.ZERO else scooter.global_basis.y
	var kick := normal * sqrt(2.0 * Scooter.GRAVITY * tuning.pop_height)
	# Only add what's missing: popping while already rising (a ramp lip)
	# doesn't stack beyond the pop's own speed.
	var rider := scooter.rider
	var system_v := (scooter.linear_velocity * scooter.mass + rider.linear_velocity * rider.mass) \
			/ (scooter.mass + rider.mass)
	var along := system_v.dot(normal)
	var add := kick * clampf(1.0 - maxf(along, 0.0) / kick.length(), 0.35, 1.0)
	var before := _kinetic(scooter)
	scooter.linear_velocity += add
	rider.linear_velocity += add
	rider.work_done += _kinetic(scooter) - before


static func _kinetic(scooter: Scooter) -> float:
	return 0.5 * scooter.mass * scooter.linear_velocity.length_squared() \
			+ 0.5 * scooter.rider.mass * scooter.rider.linear_velocity.length_squared()


func clear() -> void:
	tuck_left = 0.0
	_used = false
	_was_up = false
