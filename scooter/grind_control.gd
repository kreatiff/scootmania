class_name GrindControl
extends RefCounted
## Grinds: the deck's underside sliding along a steel edge (a rail, a
## ledge's angle iron, coping). skate.-style, it locks on:
## - It catches when the deck comes down onto an edge while moving along
##   it, lined up within grind_max_angle (forward or fakie).
## - A stiff support holds the deck on top of the edge (the legs push
##   against it as against the ground, so a normal pop hops off), a
##   sideways lock keeps it centred, and the scooter is turned to line up
##   with the edge and kept upright. The lock is an assist: its work is
##   counted in scooter.assist_work.
## - Steel friction (grind_friction × the support force) slows you; its
##   work goes in grind_work.
## - It ends off the end of the edge, when the deck lifts off it, or when
##   you've slowed to a stop.
## The wheels hover while grinding (on a real scooter they overhang).

var active := false
## Seconds into the current grind.
var time := 0.0
## Support force from the edge this tick, N.
var support := 0.0
## Where the deck touches the edge, and the edge's direction.
var point := Vector3.ZERO
var direction := Vector3.RIGHT
## Running total of the edge's work on the scooter (support and
## friction; the lock and alignment go in scooter.assist_work), J.
var grind_work := 0.0

var _edge: PhysicsBody3D
var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _off_time := 0.0
var _cooldown := 0.0
var _scooter: Scooter
# Last tick's forces and torques, to finish their work (see _finish_work):
# {"force" or "torque": Vector3, "at": local point, "v": velocity then,
# "assist": bool}.
var _last: Array[Dictionary] = []


## Before the wheels each tick: catch an edge, or hold on to the current
## one. Returns true while grinding (the wheels then hover).
func update(scooter: Scooter, tuning: ScooterTuning, delta: float) -> bool:
	_finish_work(scooter, delta)
	_cooldown -= delta
	if scooter.rider.bailed:
		_release()
		return false
	if not active and not _catch(scooter, tuning):
		return false

	var hit := _closest_on_deck(scooter, _a, _b)
	var t: float = hit[2]
	if t <= 0.0 or t >= 1.0:
		_release() # off the end
		return false
	var p: Vector3 = hit[0]
	var q: Vector3 = hit[1]
	direction = (_b - _a).normalized()
	var normal := (Vector3.UP - direction * direction.y).normalized()
	var lateral := direction.cross(normal)
	var com := scooter.global_transform * scooter.center_of_mass
	var v := scooter.linear_velocity + scooter.angular_velocity.cross(p - com)
	var along := v.dot(direction)

	# Support: a stiff spring holding the deck a few mm above the edge,
	# preloaded by the full weight so it doesn't sag into it. Only pushes.
	var m := tuning.unsprung_mass()
	var sag := tuning.total_mass() * Scooter.GRAVITY / tuning.grind_stiffness
	var gap := (p - q).dot(normal) - 0.004 - sag
	# Damped hard (critically, on the deck alone), so landing on the edge
	# doesn't bounce off it.
	var damping := 2.0 * sqrt(tuning.grind_stiffness * m)
	support = maxf(-tuning.grind_stiffness * gap - damping * v.dot(normal), 0.0)
	# Lifted well clear for a moment (a pop, or dropped past the edge):
	# let go. A landing's rebound doesn't last that long.
	if support == 0.0 and gap > 0.03 - sag:
		_off_time += delta
		if _off_time > 0.08:
			_release()
			return false
	else:
		_off_time = 0.0
	if absf(along) < tuning.grind_min_speed * 0.3:
		_release() # stalled out
		return false

	# Sideways lock and friction.
	var side_error := (p - q).dot(lateral)
	var lock := -(tuning.grind_lock_stiffness * side_error
			+ 2.0 * sqrt(tuning.grind_lock_stiffness * m) * v.dot(lateral))
	lock = clampf(lock, -tuning.grind_lock_max, tuning.grind_lock_max)
	var friction := -signf(along) * tuning.grind_friction * support
	var support_force := normal * support
	var lock_force := lateral * lock
	var friction_force := direction * friction
	scooter.add_tracked_force(support_force + lock_force + friction_force, p)
	var at := scooter.global_transform.affine_inverse() * p
	_last.append({"force": lock_force, "at": at, "v": v, "assist": true})
	_last.append({"force": support_force + friction_force, "at": at, "v": v, "assist": false})
	scooter.assist_work += lock_force.dot(v) * delta
	grind_work += (support_force + friction_force).dot(v) * delta
	_align(scooter, tuning, normal, delta)
	point = q
	time += delta
	return true


## Lines the deck up with the edge (forward or fakie) and keeps it upright,
## with a capped torque, like AirControl's landing assist.
func _align(scooter: Scooter, tuning: ScooterTuning, normal: Vector3, delta: float) -> void:
	var forward := -scooter.global_basis.z
	var along := direction if forward.dot(direction) >= 0.0 else -direction
	var target := Basis(normal.cross(-along).normalized(), normal, -along).orthonormalized()
	var q := Quaternion(target * scooter.global_basis.inverse())
	var angle := q.get_angle()
	if angle > PI:
		angle -= TAU
	var error := q.get_axis() * angle if absf(angle) > 1e-4 else Vector3.ZERO
	var inertia := scooter.get_inverse_inertia_tensor().inverse()
	var wanted := error / tuning.grind_align_time
	var torque := inertia * (wanted - scooter.angular_velocity) / 0.03
	torque = torque.limit_length(tuning.grind_max_torque)
	scooter.add_tracked_torque(torque)
	scooter.assist_work += torque.dot(scooter.angular_velocity) * delta
	_last.append({"torque": torque, "v": scooter.angular_velocity, "assist": true})


func _catch(scooter: Scooter, tuning: ScooterTuning) -> bool:
	if _cooldown > 0.0:
		return false # just let go: don't catch the same edge again at once
	var forward := -scooter.global_basis.z
	for body in scooter.get_tree().get_nodes_in_group("grind_edges"):
		var node := body as Node3D
		var top: float = node.get_meta("grind_top")
		var a: Vector3 = node.global_transform * (node.get_meta("grind_a") as Vector3) + Vector3.UP * top
		var b: Vector3 = node.global_transform * (node.get_meta("grind_b") as Vector3) + Vector3.UP * top
		var hit := _closest_on_deck(scooter, a, b)
		var t: float = hit[2]
		if t <= 0.02 or t >= 0.98:
			continue
		var p: Vector3 = hit[0]
		var q: Vector3 = hit[1]
		var dir := (b - a).normalized()
		var height := p.y - q.y
		var side := ((p - q) - dir * (p - q).dot(dir))
		side.y = 0.0
		var v := scooter.linear_velocity
		# A deck arriving a little low, still rising or at the top of a pop,
		# snaps up onto the edge (skate. is generous here too).
		var lowest := -tuning.grind_snap_up if v.y > -0.3 else -0.02
		if height < lowest or height > tuning.grind_catch_distance or side.length() > tuning.grind_catch_distance:
			continue
		if absf(v.dot(dir)) < tuning.grind_min_speed or v.y > 1.0:
			continue
		var flat := Vector3(forward.x, 0.0, forward.z).normalized()
		var flat_dir := Vector3(dir.x, 0.0, dir.z).normalized()
		if absf(flat.dot(flat_dir)) < cos(deg_to_rad(tuning.grind_max_angle_deg)):
			continue
		if scooter.global_basis.y.dot(Vector3.UP) < cos(deg_to_rad(40.0)):
			continue
		_a = a
		_b = b
		# The support above is the contact now: the physics engine's own
		# (with its friction) would brake the deck a second time.
		_edge = node as PhysicsBody3D
		if _edge:
			scooter.add_collision_exception_with(_edge)
		_scooter = scooter
		active = true
		time = 0.0
		_off_time = 0.0
		return true
	return false


func _release() -> void:
	if active:
		_cooldown = 0.25
	active = false
	support = 0.0
	if _edge and is_instance_valid(_edge) and is_instance_valid(_scooter):
		_scooter.remove_collision_exception_with(_edge)
	_edge = null


## Ends a grind without a result (a reset).
func clear() -> void:
	_release()
	time = 0.0
	_last.clear()


## Where the deck meets the edge a–b: the point on the edge under the
## deck's middle (you tip off an end when your weight passes it), and the
## point on the deck's underside nearest to it. Returns [point on deck,
## point on edge, parameter along the edge (0 at a, 1 at b; outside = the
## middle is past an end)].
static func _closest_on_deck(scooter: Scooter, a: Vector3, b: Vector3) -> Array:
	var half := scooter.tuning.wheelbase * 0.5 + 0.02
	var middle := scooter.global_transform * Vector3(0.0, Scooter.DECK_BOTTOM, 0.0)
	var d := b - a
	var t := (middle - a).dot(d) / d.dot(d)
	var on_edge := a + d * clampf(t, 0.0, 1.0)
	var along := -scooter.global_basis.z
	var s := clampf((on_edge - middle).dot(along), -half, half)
	return [middle + along * s, on_edge, t]


## Finishes last tick's work with the step's average velocity.
func _finish_work(scooter: Scooter, delta: float) -> void:
	var com := scooter.global_transform * scooter.center_of_mass
	for entry in _last:
		var extra := 0.0
		if entry.has("torque"):
			extra = (entry["torque"] as Vector3).dot(scooter.angular_velocity - (entry["v"] as Vector3))
		else:
			var point_now: Vector3 = scooter.global_transform * (entry["at"] as Vector3)
			var now := scooter.linear_velocity + scooter.angular_velocity.cross(point_now - com)
			extra = (entry["force"] as Vector3).dot(now - (entry["v"] as Vector3))
		if entry["assist"]:
			scooter.assist_work += 0.5 * extra * delta
		else:
			grind_work += 0.5 * extra * delta
	_last.clear()
