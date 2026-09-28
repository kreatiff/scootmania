class_name Scooter
extends RigidBody3D
## The scooter, carrying the rider's shins, as one rigid body; the rider's
## upper body is a second body on sprung legs (see Rider).
##
## Frame: origin on the ground midway between the wheels, forward -Z, up +Y,
## right +X. The wheels apply all ground forces (see ScooterWheel). This
## script adds lean and steering, push, brake and air drag, and runs the
## rider.
##
## Lean steers, as on a real scooter or bike: the left stick sets the lean
## you want, and each tick the front wheel steers to whatever angle balances
## the *current* lean at the current speed (the way a bike's front wheel
## falls into a lean). Steering without leaning would throw a rider off the
## outside of the turn, and a first prototype that steered directly did
## exactly that. Full stick asks only for as much lean as the turn can hold
## up at this speed and on this surface (holdable_lean).
##
## "Lean" means the whole system's lean: where the combined centre of mass
## sits over the wheels' contact line. Near standstill, where nobody can
## balance by steering, and when the left trigger plants the foot, the foot
## on the ground holds the rider up (FootPlant).

## A landing was graded (AirControl.Landing).
signal landed(grade: int)
## The rider let go: a crash or a bailed landing.
signal bailed
## An air with tricks ended: e.g. "TAILWHIP + BARSPIN", and whether it was
## landed or the result says why not ("BARSPIN — too early").
signal trick_finished(result: String, landed: bool)

## Scooter collision sits on its own layer and only hits the world.
const LAYER_SCOOTER := 4
const AIR_DENSITY := 1.2
const GRAVITY := 9.81

@export var tuning: ScooterTuning = preload("res://scooter/scooter_tuning.tres")
## When false, the scooter ignores RiderInput and uses `manual_intent`
## (tests, or while the fly camera has the sticks).
@export var use_live_input := true

var manual_intent := RiderIntent.new()
var steer_angle := 0.0
## Positive = leaning right, radians.
var lean_angle := 0.0
var target_lean := 0.0
## Rate of change of lean_angle, rad/s (smoothed).
var lean_rate := 0.0
## Last balance torque applied, N·m (+ leans right). For telemetry and tests.
var balance_torque := 0.0
## Running total of work done by the balance assist (an outside force), J.
var assist_work := 0.0
## Running total of work done by air control torques, J.
var air_work := 0.0
var air := AirControl.new()
var foot := FootPlant.new()
var tricks := Tricks.new()
var _last_assist_force := Vector3.ZERO
var _last_assist_velocity := Vector3.ZERO
## How long the scooter has been tipped past fallen_angle_deg, s.
var fallen_time := 0.0

## Sum of forces (and their torque about the centre of mass) applied to this
## body so far in the current tick, gravity included.
var pending_force := Vector3.ZERO
var pending_torque := Vector3.ZERO

var front_wheel := ScooterWheel.new()
var rear_wheel := ScooterWheel.new()
var rider := Rider.new()

var _push_time_left := 0.0
var _kick_was_down := false
var _steering_visual := Node3D.new()
var _deck_visual := Node3D.new()
var _last_surface_grip := 0.9
var _leg_visual := MeshInstance3D.new()
var _foot_visual := MeshInstance3D.new()
var _plot_tick := 0
var _spawn_transform := Transform3D()
var _reset_held_time := 0.0
var _respawned_this_hold := false


func _ready() -> void:
	collision_layer = LAYER_SCOOTER
	collision_mask = PropMaterials.LAYER_WORLD
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	continuous_cd = true # small, fast wheels over thin coping
	can_sleep = false
	# Godot damps every body by default (0.1/s) to settle generic scenes.
	# Drag and rolling resistance are modelled explicitly here, so that
	# extra, unphysical damping must be off.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	var body_material := PhysicsMaterial.new()
	body_material.friction = 0.4 # deck and bars scraping
	physics_material_override = body_material
	_apply_mass_properties()
	_build()
	_spawn_transform = global_transform
	rider.name = "Rider"
	add_child(rider)
	_build_rider_visuals()
	rider.place_on(self, tuning)


func _physics_process(delta: float) -> void:
	_apply_mass_properties()
	var intent := RiderInput.intent if use_live_input else manual_intent
	if _handle_recovery(intent, delta):
		return # teleported this tick; forces resume next tick
	var speed := -linear_velocity.dot(global_basis.z)

	foot.update(self, tuning, intent, speed)
	_update_lean(intent, speed, delta)
	_update_steering(intent, speed, delta)
	front_wheel.steer_angle = steer_angle
	rear_wheel.brake = intent.brake

	# Every force on the scooter body this tick is tallied (gravity first),
	# so the wheels can predict the slip they must cancel. The wheels go
	# last because they react to everything else.
	pending_force = Vector3.DOWN * GRAVITY * mass * gravity_scale
	pending_torque = Vector3.ZERO
	var grounded := is_grounded() # from last tick's contacts
	if is_fallen():
		bail() # let go; stood back up by recovery
	rider.simulate(self, tuning, intent, lean_angle, lean_rate, target_lean)
	_apply_push(intent, speed, grounded, delta)
	_apply_drag()
	foot.apply_scuff(self, tuning, delta)
	# Finish last tick's assist work with the step's average velocity.
	assist_work += 0.5 * _last_assist_force.dot(rider.linear_velocity - _last_assist_velocity) * delta
	_last_assist_force = Vector3.ZERO
	if grounded:
		_apply_balance_torque(speed)
	front_wheel.simulate(self, tuning, delta)
	rear_wheel.simulate(self, tuning, delta)
	if front_wheel.in_contact and rear_wheel.in_contact:
		rider.follow_ramp(self, _ramp_normal(), _ramp_curvature(), speed, tuning.leg_axis_response, delta)
	var landing := air.update(self, tuning, intent, delta)
	if tricks.update(self, tuning, intent, delta):
		landing = AirControl.Landing.BAIL # came down mid-trick
		air.last_landing = landing
	if landing == AirControl.Landing.BAIL:
		tricks.fail_landing()
	if tricks.just_resolved:
		trick_finished.emit(tricks.last_result, tricks.last_landed)
	if landing != AirControl.Landing.NONE:
		landed.emit(landing)
		if landing == AirControl.Landing.BAIL:
			bail()

	_update_trick_visuals()
	_draw_debug(speed)


## Applies a force at a world point and adds it to this tick's tally.
func add_tracked_force(force: Vector3, point: Vector3) -> void:
	apply_force(force, point - global_position)
	pending_force += force
	pending_torque += (point - global_transform * center_of_mass).cross(force)


func add_tracked_torque(torque: Vector3) -> void:
	apply_torque(torque)
	pending_torque += torque


## The rider lets go (once), and the scooter is stood back up by recovery.
func bail() -> void:
	if rider.bailed:
		return
	rider.bailed = true
	bailed.emit()


func is_grounded() -> bool:
	return front_wheel.in_contact or rear_wheel.in_contact


## Tipped over: on the wheels but tipped against the surface under them;
## off the wheels, rolled onto its side. Riding up a vert wall (pitched
## vertical) and pitching in the air (airs, later flips) aren't fallen;
## landings are graded separately.
func is_fallen() -> bool:
	var limit := deg_to_rad(tuning.fallen_angle_deg)
	if is_grounded():
		var normal := Vector3.ZERO
		for wheel in [front_wheel, rear_wheel]:
			if wheel.in_contact:
				normal += wheel.contact_normal
		return global_basis.y.dot(normal.normalized()) < cos(limit)
	return absf(global_basis.x.y) > sin(limit)


## Hung up: wheels off the ground and not moving, e.g. resting on the deck
## across a ramp. Not tipped far enough to count as fallen, but not riding.
func is_stuck() -> bool:
	return not is_grounded() and linear_velocity.length() < 0.3 \
			and rider.linear_velocity.length() < 0.3


## Stands the scooter up where it is: on the surface below, facing the way
## it was heading, stopped. Wherever that is, both wheels need level ground
## at the same height: on a slope too steep to stand on it moves down the
## fall line (the way a fallen rider slides down), and if it's high-centred
## on something it moves off it, to the nearest spot that works.
func recover_in_place() -> void:
	var heading := _flat(-global_basis.z)
	if heading == Vector3.ZERO:
		heading = _flat(linear_velocity)
	if heading == Vector3.ZERO:
		heading = _flat(global_basis.y) # lying on its nose or tail
	var hit := _ground_below(global_position)
	if hit.is_empty():
		_place(global_position, Vector3.UP, heading)
		return
	var normal: Vector3 = hit["normal"]
	if normal.y > 0.9 and _can_stand_at(hit["position"], heading):
		_place(hit["position"], normal, heading)
		return
	var directions: Array[Vector3] = []
	if normal.y <= 0.9:
		directions.append(_flat(normal)) # downhill first
	var side := heading.cross(Vector3.UP)
	directions.append_array([-heading, heading, side, -side])
	for step in range(1, 17):
		for direction in directions:
			var spot := _ground_below(global_position + direction * step * 0.25)
			if not spot.is_empty() and _can_stand_at(spot["position"], heading):
				_place(spot["position"], Vector3.UP, heading)
				return
	_place(hit["position"] + Vector3.UP * 0.5, Vector3.UP, heading)


## Both wheels on level ground at this spot, at the same height.
func _can_stand_at(point: Vector3, heading: Vector3) -> bool:
	var half := heading * tuning.wheelbase * 0.5
	var front := _ground_below(point + half)
	var rear := _ground_below(point - half)
	if front.is_empty() or rear.is_empty():
		return false
	return front["normal"].y > 0.9 and rear["normal"].y > 0.9 \
			and absf(front["position"].y - rear["position"].y) < 0.05 \
			and absf(front["position"].y - point.y) < 0.05


func _ground_below(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 1.5, point + Vector3.DOWN * 4.0,
			PropMaterials.LAYER_WORLD, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


func respawn() -> void:
	_place(_spawn_transform.origin, Vector3.UP, _flat(-_spawn_transform.basis.z))


## Tap reset: stand up in place. Hold it: back to the spawn point. Fallen
## for auto_recover_delay: stand up in place automatically.
## Returns true if the scooter was moved this tick.
func _handle_recovery(intent: RiderIntent, delta: float) -> bool:
	if intent.reset:
		var pressed_now := _reset_held_time == 0.0
		_reset_held_time += delta
		if pressed_now:
			recover_in_place()
			return true
		if _reset_held_time >= tuning.respawn_hold_time and not _respawned_this_hold:
			_respawned_this_hold = true
			respawn()
			return true
	else:
		_reset_held_time = 0.0
		_respawned_this_hold = false

	if is_fallen() or is_stuck() or rider.bailed:
		fallen_time += delta
		var delay := tuning.auto_recover_delay
		if delay > 0.0:
			DebugDraw.watch("fallen", "standing up in %.1f s (or press Start / R)" % maxf(delay - fallen_time, 0.0))
			if fallen_time >= delay:
				recover_in_place()
				return true
	else:
		fallen_time = 0.0
		DebugDraw.watches.erase("fallen")
	return false


func _place(ground: Vector3, up: Vector3, heading: Vector3) -> void:
	var forward := (heading - up * heading.dot(up)).normalized()
	if forward == Vector3.ZERO:
		forward = Vector3.FORWARD
	var back := -forward
	var xform_basis := Basis(up.cross(back), up, back)
	# Sit at the static wheel compression so it doesn't drop or bounce.
	var sink := tuning.total_mass() * GRAVITY * 0.5 / tuning.wheel_stiffness
	global_transform = Transform3D(xform_basis, ground - up * sink)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steer_angle = 0.0
	target_lean = 0.0
	lean_angle = 0.0
	lean_rate = 0.0
	fallen_time = 0.0
	_push_time_left = 0.0
	front_wheel.sliding = false
	rear_wheel.sliding = false
	tricks.clear()
	_update_trick_visuals()
	DebugDraw.watches.erase("fallen")
	reset_physics_interpolation()
	rider.place_on(self, tuning)


static func _flat(v: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length_squared() > 1e-4 else Vector3.ZERO


func _apply_mass_properties() -> void:
	mass = tuning.unsprung_mass()
	center_of_mass = tuning.scooter_center_of_mass()
	inertia = Vector3(tuning.inertia_roll_pitch, tuning.inertia_yaw, tuning.inertia_roll_pitch)
	var half := tuning.wheelbase * 0.5
	front_wheel.position = Vector3(0, tuning.wheel_radius, -half)
	rear_wheel.position = Vector3(0, tuning.wheel_radius, half)


## The stick asks for a lean, never more than the turn can hold up
## (holdable_lean): full stick is "turn as hard as you can", so steering
## alone never tips you over. Too much lean still happens, from outside:
## riding onto steel mid-carve, or a sketchy landing.
func _update_lean(intent: RiderIntent, speed: float, delta: float) -> void:
	var previous := lean_angle
	lean_angle = system_lean()
	lean_rate = lerpf(lean_rate, (lean_angle - previous) / delta, 0.3)
	var wanted := intent.lean.x * holdable_lean(absf(speed))
	if foot.held:
		wanted = foot.lean_target(self, tuning, speed)
	target_lean = move_toward(target_lean, wanted, deg_to_rad(tuning.lean_rate_deg) * delta)


## The furthest lean a turn can hold up at this speed, radians: limited by
## the tyres' grip (tan(lean) = sideways g) and by how tight the steering
## can turn, each with a margin, and by max_lean_deg.
func holdable_lean(speed: float) -> float:
	var grip := tuning.grip_scale * surface_grip() * tuning.lean_grip_margin
	var steer_tan := tan(_steer_limit(speed)) * sin(deg_to_rad(tuning.headtube_angle_deg))
	var turn := speed * speed * steer_tan / tuning.wheelbase / GRAVITY * tuning.lean_steer_margin
	return minf(atan(minf(grip, turn)), deg_to_rad(tuning.max_lean_deg))


## The slipperiest surface under the wheels (it
## decides when the turn lets go). Keeps the last value while airborne.
func surface_grip() -> float:
	var mu := INF
	for wheel in [front_wheel, rear_wheel]:
		if wheel.in_contact:
			mu = minf(mu, wheel.surface_friction)
	if mu != INF:
		_last_surface_grip = mu
	return _last_surface_grip


func _steer_limit(speed: float) -> float:
	var t := clampf(speed / tuning.steer_fast_speed, 0.0, 1.0)
	return deg_to_rad(lerpf(tuning.max_steer_slow_deg, tuning.max_steer_fast_deg, t))


## Steering is how a rider balances and turns, as on a bike:
## - Balance: steer so the turn's sideways acceleration holds up the current
##   lean, a = g·tan(lean).
## - Countersteer: to lean further right, briefly steer left so the wheels
##   run out from under you, and the reverse. Plus damping on the lean rate.
## The acceleration becomes a steering angle through the bicycle model,
## tan(ground steer) = wheelbase · a / v². At walking pace that blows up, so
## it blends to steering directly from the stick. The result is limited by
## speed and by steering rate.
##
## Balancing is a stable loop: the lean error decays like a spring with
## ω² ≈ g·countersteer_gain / height.
func _update_steering(intent: RiderIntent, speed: float, delta: float) -> void:
	var v := absf(speed)
	var direct := intent.lean.x * deg_to_rad(tuning.max_steer_slow_deg)
	var balance := 0.0
	if v > 0.1:
		var correction := tuning.countersteer_gain * (lean_angle - target_lean) \
				+ tuning.countersteer_damping * lean_rate
		var lateral := GRAVITY * (tan(lean_angle) + correction)
		var ground_tan := tuning.wheelbase * lateral / (v * v)
		# Same sign rolling backwards (fakie): steering right still curves
		# the path toward the scooter's right, since a = v²·tan(steer)/L.
		balance = atan(ground_tan / sin(deg_to_rad(tuning.headtube_angle_deg)))
	var blend := clampf(inverse_lerp(tuning.lean_steer_min_speed, tuning.lean_steer_full_speed, v), 0.0, 1.0)
	var limit := _steer_limit(v)
	var target := clampf(lerpf(direct, balance, blend), -limit, limit)
	if foot.held:
		target = foot.steer_target(self, tuning, intent, v)
	steer_angle = move_toward(steer_angle, target, deg_to_rad(tuning.steer_rate_deg) * delta)


## A kick is a short forward push, started on the button press.
func _apply_push(intent: RiderIntent, speed: float, grounded: bool, delta: float) -> void:
	if intent.kick and not _kick_was_down:
		_push_time_left = tuning.push_duration
	_kick_was_down = intent.kick
	if foot.held:
		_push_time_left = 0.0 # the kicking foot is on the ground
	if _push_time_left <= 0.0:
		return
	_push_time_left -= delta
	if not grounded or speed > tuning.push_max_speed:
		return
	var normal := rear_wheel.contact_normal if rear_wheel.in_contact else Vector3.UP
	var forward := -global_basis.z
	forward = (forward - normal * forward.dot(normal)).normalized()
	add_tracked_force(forward * tuning.push_force, global_transform * center_of_mass)


## Air drag acts on the rider, who is nearly all of the frontal area.
func _apply_drag() -> void:
	var v := rider.linear_velocity
	rider.apply_central_force(-0.5 * AIR_DENSITY * tuning.drag_area * v.length() * v)


## Optional help on top of the rider's weight shift: full strength near
## standstill (standing in for a foot put down), assist_strength at speed.
## Like a foot on the ground, it's an outside force, applied sideways at
## the rider's hips so it tips the whole system rather than just the deck.
func _apply_balance_torque(speed: float) -> void:
	var t := clampf(inverse_lerp(tuning.stand_assist_speed, tuning.stand_assist_speed * 2.0, absf(speed)), 0.0, 1.0)
	var strength := lerpf(tuning.stand_assist, tuning.assist_strength, t)
	var limit := tuning.max_balance_torque
	if foot.held:
		strength = 1.0
		limit = tuning.foot_max_torque
	var torque := tuning.assist_stiffness * (target_lean - lean_angle) - tuning.assist_damping * lean_rate
	torque = clampf(torque, -limit, limit)
	balance_torque = torque * strength
	var heading := _flat(-global_basis.z)
	if heading == Vector3.ZERO or balance_torque == 0.0:
		return
	# Push square to the rider's path, not the deck's heading: in a tight
	# turn the rider's path cuts inside the heading, and a push along the
	# heading's side would also drive them forward (a foot on the ground can
	# hold you up, not propel you).
	var side := heading.cross(Vector3.UP)
	var v := rider.linear_velocity
	if Vector2(v.x, v.z).length() > 0.3:
		var across := _flat(v).cross(Vector3.UP)
		side = across if across.dot(side) > 0.0 else -across
	var height := maxf(rider.global_position.y - global_position.y, 0.3)
	var force := side * balance_torque / height
	rider.apply_central_force(force)
	assist_work += force.dot(rider.linear_velocity) * get_physics_process_delta_time()
	_last_assist_force = force
	_last_assist_velocity = rider.linear_velocity


## Steering and tricks turn parts of the scooter about the headtube, which
## meets the front axle: the bars (and front wheel) for steering and
## barspins, the deck (and rear wheel) for tailwhips. Visual only.
func _update_trick_visuals() -> void:
	var axis := tuning.headtube_axis().normalized()
	var pivot := Vector3(0, tuning.wheel_radius, -tuning.wheelbase * 0.5)
	_steering_visual.transform = Tricks.pivot_transform(tricks.bars_angle - steer_angle, axis, pivot) \
			* Transform3D(Basis(), pivot)
	front_wheel.visual_pivot = Tricks.pivot_transform(tricks.bars_angle, axis, pivot)
	_deck_visual.transform = Tricks.pivot_transform(tricks.deck_angle, axis, pivot)
	rear_wheel.visual_pivot = _deck_visual.transform


## Average of the wheels' contact normals, within the pitch plane.
func _ramp_normal() -> Vector3:
	var right := global_basis.x
	var n := front_wheel.contact_normal + rear_wheel.contact_normal
	n -= right * n.dot(right)
	return n.normalized() if n.length_squared() > 1e-4 else global_basis.y


## Curvature of the surface along the direction of travel, from how much
## the contact normal turns between the wheels: 1/m, + for a concave ramp
## (curving up ahead, like a transition), − for a crest.
func _ramp_curvature() -> float:
	var right := global_basis.x
	var front := front_wheel.contact_normal - right * front_wheel.contact_normal.dot(right)
	var rear := rear_wheel.contact_normal - right * rear_wheel.contact_normal.dot(right)
	if front.length_squared() < 1e-4 or rear.length_squared() < 1e-4:
		return 0.0
	var angle := front.angle_to(rear)
	# Concave: the front normal is tilted back relative to the rear one.
	var sign := -1.0 if (front.normalized() - rear.normalized()).dot(-global_basis.z) > 0.0 else 1.0
	return sign * angle / tuning.wheelbase


## Lean of the whole system: the angle, seen along the direction of travel,
## between vertical and the line from the wheels' contact line to the
## combined centre of mass. + is leaning right.
func system_lean() -> float:
	var com := system_center_of_mass()
	var base := global_position
	if front_wheel.in_contact and rear_wheel.in_contact:
		base = (front_wheel.contact_point + rear_wheel.contact_point) * 0.5
	var heading := _flat(-global_basis.z)
	if heading == Vector3.ZERO:
		heading = Vector3.FORWARD
	var right := heading.cross(Vector3.UP)
	var d := com - base
	return atan2(d.dot(right), d.dot(Vector3.UP))


## Kinetic + gravitational energy of scooter and rider, J (height measured
## from y = 0). Rises when the rider pumps, falls to friction and drag.
func system_energy() -> float:
	var inertia := get_inverse_inertia_tensor().inverse()
	var own := global_transform * center_of_mass
	return 0.5 * mass * linear_velocity.length_squared() \
			+ 0.5 * angular_velocity.dot(inertia * angular_velocity) \
			+ mass * GRAVITY * own.y \
			+ 0.5 * rider.mass * rider.linear_velocity.length_squared() \
			+ rider.mass * GRAVITY * rider.global_position.y


func system_center_of_mass() -> Vector3:
	var own := global_transform * center_of_mass
	return (own * mass + rider.global_position * rider.mass) / (mass + rider.mass)


func _draw_debug(speed: float) -> void:
	front_wheel.draw_debug(tuning)
	rear_wheel.draw_debug(tuning)
	var com := global_transform * center_of_mass
	DebugDraw.point(com, Color.YELLOW, 0.06)
	DebugDraw.arrow(com, linear_velocity * 0.2, Color.WHITE)
	DebugDraw.watch("speed", "%.1f km/h  (%.2f m/s)" % [speed * 3.6, speed])
	DebugDraw.watch("lean", "%+.1f° (target %+.1f°)   steer %+.1f°   balance %+.0f N·m"
			% [rad_to_deg(lean_angle), rad_to_deg(target_lean), rad_to_deg(steer_angle), balance_torque])
	DebugDraw.watch("wheels", "F %s   R %s" % [_wheel_text(front_wheel), _wheel_text(rear_wheel)])
	if air.airborne:
		var eta := "" if air.time_to_landing == INF else "   landing in %.2f s%s" % [
				air.time_to_landing, "  ASSIST" if air.assist_active else ""]
		DebugDraw.watch("air", "%.2f s%s" % [air.air_time, eta])
	else:
		DebugDraw.watches.erase("air")
	if air.last_landing != AirControl.Landing.NONE:
		DebugDraw.watch("landing", "%s  (tilt %.0f°, sideways %.0f°)" % [
				AirControl.landing_name(air.last_landing), rad_to_deg(air.last_tilt), rad_to_deg(air.last_sideways)])
	var flick := "flick %s %.1f s ago" % [tricks.last_flick, tricks.last_flick_age] if tricks.last_flick_age < 5.0 else "no flick"
	DebugDraw.watch("tricks", "%s   %s   manual pitch %+.0f° (%.1f s)   last: %s" % [
			"%s %.0f%%" % [Tricks.trick_name(tricks.active), tricks.progress * 100.0] if tricks.active != Tricks.Trick.NONE else "—",
			flick, rad_to_deg(rider.manual_pitch), tricks.manual_time, tricks.last_result])
	DebugDraw.watch("foot", "HELD (scuffing, full lock)" if foot.held else ("down (standing)" if foot.planted else "on the deck"))
	DebugDraw.watch("rider", "legs %.2f m (%+.0f N)   hips %+.2f / %+.2f m"
			% [rider.leg_length, rider.leg_force, rider.hip_shift.x, rider.hip_shift.y])
	DebugDraw.point(system_center_of_mass(), Color.ORANGE_RED, 0.08)
	_plot_tick += 1
	if _plot_tick % 4 == 0: # 600 samples ≈ 10 s at 240 Hz
		DebugDraw.plot("energy J", system_energy())
		DebugDraw.plot("leg force N", rider.leg_force)


static func _wheel_text(wheel: ScooterWheel) -> String:
	if not wheel.in_contact:
		return "air"
	return "%4.0f N %4.1f mm%s" % [wheel.normal_force, wheel.compression * 1000.0, " SLIDE" if wheel.sliding else ""]


## Placeholder geometry: deck, stem, bars, wheels, and a see-through
## capsule where the rider ballast is.
func _build() -> void:
	var r := tuning.wheel_radius
	var half := tuning.wheelbase * 0.5
	var deck_bottom := 0.04
	var deck_size := Vector3(0.12, 0.045, tuning.wheelbase + 0.04)
	var deck_center := Vector3(0, deck_bottom + deck_size.y * 0.5, 0)

	var deck_shape := BoxShape3D.new()
	deck_shape.size = deck_size
	_add_collision(deck_shape, Transform3D(Basis(), deck_center))

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.14)
	dark.roughness = 0.6
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.95, 0.35, 0.1)
	accent.roughness = 0.4
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color(0.9, 0.85, 0.2)
	wheel_material.roughness = 0.7

	var deck_mesh := BoxMesh.new()
	deck_mesh.size = deck_size
	add_child(_deck_visual)
	_add_mesh(_deck_visual, deck_mesh, accent, Transform3D(Basis(), deck_center))

	# Steering assembly pivots about the headtube, at the front of the deck.
	var axis := tuning.headtube_axis().normalized()
	var stem_base := Vector3(0, r, -half)
	_steering_visual.position = stem_base
	add_child(_steering_visual)
	var stem_length := 0.85 / axis.y
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.016
	stem_mesh.bottom_radius = 0.016
	stem_mesh.height = stem_length
	var stem_basis := Basis(Vector3.RIGHT, acos(axis.y)) # tilt back (toward +Z) to the headtube angle
	_add_mesh(_steering_visual, stem_mesh, dark, Transform3D(stem_basis, axis * stem_length * 0.5))
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = 0.014
	bar_mesh.bottom_radius = 0.014
	bar_mesh.height = 0.56
	_add_mesh(_steering_visual, bar_mesh, dark, Transform3D(Basis(Vector3.BACK, PI * 0.5), axis * stem_length))

	var stem_shape := CylinderShape3D.new()
	stem_shape.radius = 0.02
	stem_shape.height = stem_length
	_add_collision(stem_shape, Transform3D(stem_basis, stem_base + axis * stem_length * 0.5))

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = r
	wheel_mesh.bottom_radius = r
	wheel_mesh.height = 0.024
	wheel_mesh.radial_segments = 24
	front_wheel.name = "FrontWheel"
	front_wheel.is_front = true
	rear_wheel.name = "RearWheel"
	add_child(front_wheel)
	add_child(rear_wheel)
	_apply_mass_properties()
	front_wheel.setup(self, wheel_mesh, wheel_material)
	rear_wheel.setup(self, wheel_mesh, wheel_material)



## The rider's torso (on the rider body) and a leg from deck to hips,
## redrawn every frame so you can see the knees work.
func _build_rider_visuals() -> void:
	var torso := CapsuleMesh.new()
	torso.radius = 0.17
	torso.height = 0.75
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.35, 0.6, 0.95)
	skin.roughness = 0.8
	_add_mesh(rider, torso, skin, Transform3D(Basis(), Vector3(0, 0.2, 0)))
	var leg := CylinderMesh.new()
	leg.top_radius = 0.06
	leg.bottom_radius = 0.05
	leg.height = 1.0
	_leg_visual.mesh = leg
	_leg_visual.material_override = skin
	_leg_visual.top_level = true
	_leg_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_leg_visual)
	_foot_visual.mesh = leg
	_foot_visual.material_override = skin
	_foot_visual.top_level = true
	_foot_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_foot_visual.visible = false
	add_child(_foot_visual)


func _process(_delta: float) -> void:
	var feet_local := Vector3(0, tuning.deck_top, tuning.rider_com_offset)
	if tricks.active == Tricks.Trick.TAILWHIP:
		feet_local.y += 0.18 # feet tucked up while the deck whips round
	var feet := get_global_transform_interpolated() * feet_local
	var hips := rider.get_global_transform_interpolated().origin
	_place_limb(_leg_visual, feet, hips)
	_foot_visual.visible = foot.planted
	if foot.planted:
		# The foot point moves with the scooter; offset it by the same
		# interpolation the scooter gets, so it doesn't lag a frame.
		var shift := get_global_transform_interpolated().origin - global_position
		_place_limb(_foot_visual, foot.point + shift, hips)


## Stretches a unit cylinder between two points.
static func _place_limb(limb: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.01:
		return
	var y := along / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	limb.global_transform = Transform3D(Basis(x, y * length, x.cross(y)), (from + to) * 0.5)


func _add_collision(shape: Shape3D, xform: Transform3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = xform
	add_child(collision)


static func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, xform: Transform3D) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = xform
	parent.add_child(instance)
