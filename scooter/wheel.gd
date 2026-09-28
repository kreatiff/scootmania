class_name ScooterWheel
extends Node3D
## One wheel: sphere-cast ground contact, a stiff sprung "compliance", and
## the tyre model. This node sits at the wheel centre when unloaded, in the
## scooter's frame. The scooter calls `simulate()` once per physics tick.
##
## Tyre model, per tick:
## 1. Normal force N from the spring (compression) and damper.
## 2. Rolling direction on the contact plane; the front wheel is steered
##    about the headtube axis.
## 3. Friction needed to cancel the wheel's sideways sliding (and, along
##    the rolling direction, just rolling resistance + brake).
## 4. If that exceeds grip (surface friction × N), the wheel slides with
##    reduced grip until the demand falls back under the sliding level.

const CONTACT_EPSILON := 0.002

var is_front := false
## Steering angle in radians, + is right. Only used on the front wheel.
var steer_angle := 0.0
var brake := 0.0

# State from the last simulate(), for debug drawing, telemetry and tests.
var in_contact := false
var compression := 0.0
var normal_force := 0.0
var contact_point := Vector3.ZERO
var contact_normal := Vector3.UP
var rolling_dir := Vector3.FORWARD
var surface_friction := 0.0
var sliding := false
var tangential_force := Vector3.ZERO
## Total force (normal + tangential) this wheel applied this tick.
var applied_force := Vector3.ZERO
## Speed along the rolling direction, m/s.
var rolling_speed := 0.0
## Running total of work this wheel's forces have done on the body, J.
## Negative = energy taken out (damping, rolling resistance, sliding).
var work_done := 0.0

# Last tick's applied force, where on the body (local), and that point's
# velocity when applied: to count its work with the step's average velocity.
var _last_force := Vector3.ZERO
var _last_local_point := Vector3.ZERO
var _last_velocity := Vector3.ZERO

var _cast := ShapeCast3D.new()
var _sphere := SphereShape3D.new()
var _visual := Node3D.new()
var _spin := 0.0


func setup(body: RigidBody3D, visual_mesh: Mesh, visual_material: Material) -> void:
	_cast.shape = _sphere
	_cast.enabled = false # updated manually, exactly once per tick
	_cast.collision_mask = PropMaterials.LAYER_WORLD
	_cast.max_results = 4
	_cast.add_exception(body)
	add_child(_cast)

	var mesh := MeshInstance3D.new()
	mesh.mesh = visual_mesh
	mesh.material_override = visual_material
	mesh.rotation = Vector3(0, 0, PI * 0.5) # cylinder axis Y -> X (the axle)
	_visual.add_child(mesh)
	add_child(_visual)


## Computes and applies this wheel's forces to `body` for one tick.
func simulate(body: Scooter, tuning: ScooterTuning, delta: float) -> void:
	_finish_work(body, delta)
	var radius := tuning.wheel_radius
	var travel := tuning.wheel_travel
	var up := body.global_basis.y
	_sphere.radius = radius

	# Cast from the top of the travel down to just below the unloaded position.
	var reach := travel + CONTACT_EPSILON
	_cast.position = Vector3(0, travel, 0)
	_cast.target_position = Vector3(0, -reach, 0)
	_cast.force_shapecast_update()

	in_contact = _cast.is_colliding()
	sliding = sliding and in_contact
	if not in_contact:
		compression = 0.0
		normal_force = 0.0
		tangential_force = Vector3.ZERO
		applied_force = Vector3.ZERO
		_update_visual(0.0, delta)
		return

	var distance := _exact_contact_distance(up, radius, reach)
	compression = travel - distance
	var center := _cast.global_position - up * distance
	contact_point = center - contact_normal * radius
	surface_friction = _surface_friction()

	var com := body.global_transform * body.center_of_mass
	var r := contact_point - com
	var v := body.linear_velocity + body.angular_velocity.cross(r)
	var inv_inertia := body.get_inverse_inertia_tensor()

	# 1. Normal force: spring + damper, with a stiff bump stop near the end.
	var x := maxf(compression, 0.0)
	var bump_start := travel * 0.8
	var spring := tuning.wheel_stiffness * x
	if x > bump_start:
		spring += tuning.wheel_stiffness * tuning.bump_stiffness_scale * (x - bump_start)
	var closing_speed := -v.dot(contact_normal)
	normal_force = maxf(spring + tuning.wheel_damping() * closing_speed, 0.0)

	# 2. Rolling direction on the contact plane.
	var forward := -body.global_basis.z
	if is_front:
		var axis := body.global_basis * tuning.headtube_axis()
		forward = forward.rotated(axis.normalized(), -steer_angle)
	rolling_dir = (forward - contact_normal * forward.dot(contact_normal)).normalized()
	var lateral_dir := contact_normal.cross(rolling_dir).normalized()
	rolling_speed = v.dot(rolling_dir)

	# Contact velocity at the end of this tick from every force already
	# applied (gravity, rider, push, the other wheel) plus this wheel's own
	# normal force. Cancelling that, instead of the current velocity, keeps
	# the wheel from slipping a tick behind on a light body.
	var force := body.pending_force + contact_normal * normal_force
	var torque := body.pending_torque + r.cross(contact_normal * normal_force)
	var v_next := v + (force / body.mass + (inv_inertia * torque).cross(r)) * delta
	var lateral_speed := v_next.dot(lateral_dir)
	var predicted_rolling := v_next.dot(rolling_dir)

	# 3. Friction demand: cancel sideways slip; resist rolling only by
	#    rolling resistance and brake. Both act like static friction, so a
	#    stopped scooter doesn't creep.
	var relax := tuning.friction_relax
	var lat_demand := -lateral_speed * _effective_mass(body, r, lateral_dir) / delta * relax
	var roll_demand := -predicted_rolling * _effective_mass(body, r, rolling_dir) / delta * relax
	var roll_limit := tuning.rolling_resistance * normal_force
	if not is_front:
		roll_limit += brake * tuning.brake_mu * normal_force
	var long_force := clampf(roll_demand, -roll_limit, roll_limit)
	var demand := Vector2(long_force, lat_demand)

	# 4. Grip limit, with hysteresis between gripping and sliding.
	var grip := surface_friction * tuning.grip_scale * normal_force
	var slide_grip := grip * tuning.slide_ratio
	if sliding:
		sliding = demand.length() > slide_grip
	else:
		sliding = demand.length() > grip
	if sliding:
		demand = demand.normalized() * slide_grip

	tangential_force = rolling_dir * demand.x + lateral_dir * demand.y
	var total := contact_normal * normal_force + tangential_force
	body.add_tracked_force(total, contact_point)
	applied_force = total
	work_done += total.dot(v) * delta
	_last_force = total
	_last_local_point = body.global_transform.affine_inverse() * contact_point
	_last_velocity = v
	_update_visual(compression, delta)


## Work was counted with the velocity at the start of the step; the physics
## step then moved at the end velocity. Adding half the difference counts
## it with the average, which is exact for a force held over the step.
## (Without this, big fast-changing forces drift an energy audit by tens
## of joules per second.)
func _finish_work(body: RigidBody3D, delta: float) -> void:
	if _last_force == Vector3.ZERO:
		return
	var point := body.global_transform * _last_local_point
	var com := body.global_transform * body.center_of_mass
	var v_now := body.linear_velocity + body.angular_velocity.cross(point - com)
	work_done += 0.5 * _last_force.dot(v_now - _last_velocity) * delta
	_last_force = Vector3.ZERO


## Elastic energy currently stored in the wheel's spring, J.
func spring_energy(tuning: ScooterTuning) -> float:
	var x := maxf(compression, 0.0)
	var bump := maxf(x - tuning.wheel_travel * 0.8, 0.0)
	return 0.5 * tuning.wheel_stiffness * (x * x + tuning.bump_stiffness_scale * bump * bump)


func draw_debug(tuning: ScooterTuning) -> void:
	if not in_contact:
		return
	var s := tuning.force_draw_scale
	DebugDraw.arrow(contact_point, contact_normal * normal_force, Color.GREEN, s)
	DebugDraw.arrow(contact_point, tangential_force, Color.RED if sliding else Color.ORANGE, s)
	DebugDraw.arrow(contact_point, rolling_dir * 0.25, Color.CYAN)


## Mass the body presents at point r (from the centre of mass) along dir.
static func _effective_mass(body: RigidBody3D, r: Vector3, dir: Vector3) -> float:
	var inv_inertia := body.get_inverse_inertia_tensor()
	var angular := (inv_inertia * r.cross(dir)).cross(r)
	return 1.0 / (1.0 / body.mass + dir.dot(angular))


## How far the sphere travels down the cast before touching, and sets
## `contact_normal`.
##
## The cast's own fraction is quantised (steps of ~1.5 mm here), which makes
## a stiff spring jitter. Instead, each reported contact (point + normal)
## defines the surface's tangent plane, and the distance at which the sphere
## touches that plane is solved exactly. The nearest contact wins.
func _exact_contact_distance(up: Vector3, radius: float, reach: float) -> float:
	var start := _cast.global_position
	var best := INF
	for i in _cast.get_collision_count():
		var n := _cast.get_collision_normal(i)
		var facing := n.dot(up)
		if facing < 0.05:
			continue # a wall beside the wheel; it can't hold the wheel up
		var d := ((start - _cast.get_collision_point(i)).dot(n) - radius) / facing
		if d < best:
			best = d
			contact_normal = n
	if best == INF:
		contact_normal = up
		return _cast.get_closest_collision_safe_fraction() * reach
	return clampf(best, 0.0, reach)


func _surface_friction() -> float:
	var collider := _cast.get_collider(0) as StaticBody3D
	if collider and collider.physics_material_override:
		return collider.physics_material_override.friction
	return 0.9 # untagged surfaces behave like concrete


func _update_visual(shown_compression: float, delta: float) -> void:
	_visual.position = Vector3(0, shown_compression, 0)
	_visual.rotation = Vector3.ZERO
	if is_front:
		# Visual steering; the tiny tilt from the headtube angle is ignored.
		_visual.rotate_y(-steer_angle)
	var radius := _sphere.radius
	if in_contact and radius > 0.0:
		_spin -= rolling_speed / radius * delta
	_visual.rotate_object_local(Vector3.RIGHT, _spin)
