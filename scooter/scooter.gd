class_name Scooter
extends RigidBody3D
## The scooter and (for now) its rider as rigid ballast, as one rigid body.
##
## Frame: origin on the ground midway between the wheels, forward -Z, up +Y,
## right +X. The wheels apply all ground forces (see ScooterWheel). This
## script adds lean and steering, push, brake and air drag.
##
## Lean steers, as on a real scooter or bike: the left stick sets the lean
## you want, and each tick the front wheel steers to whatever angle balances
## the *current* lean at the current speed (the way a bike's front wheel
## falls into a lean). Steering without leaning would throw a rider off the
## outside of the turn, and a first prototype that steered directly did
## exactly that.
##
## Phase 2 stand-in, replaced in Phase 3: the rider is rigid ballast, and a
## balance torque moves the lean toward the target instead of the rider
## shifting their weight.

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
## Last balance torque applied, N·m (+ leans right). For telemetry and tests.
var balance_torque := 0.0

var front_wheel := ScooterWheel.new()
var rear_wheel := ScooterWheel.new()

var _push_time_left := 0.0
var _kick_was_down := false
var _steering_visual := Node3D.new()


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


func _physics_process(delta: float) -> void:
	_apply_mass_properties()
	var intent := RiderInput.intent if use_live_input else manual_intent
	var speed := -linear_velocity.dot(global_basis.z)

	_update_lean(intent, delta)
	_update_steering(intent, speed, delta)
	front_wheel.steer_angle = steer_angle
	rear_wheel.brake = intent.brake
	front_wheel.simulate(self, tuning, delta)
	rear_wheel.simulate(self, tuning, delta)
	var grounded := front_wheel.in_contact or rear_wheel.in_contact

	_apply_push(intent, speed, grounded, delta)
	_apply_drag()
	if grounded:
		_apply_balance_torque()

	_steering_visual.rotation = Vector3.ZERO
	_steering_visual.rotate_object_local(tuning.headtube_axis().normalized(), -steer_angle)
	_draw_debug(speed)


func is_grounded() -> bool:
	return front_wheel.in_contact or rear_wheel.in_contact


func _apply_mass_properties() -> void:
	mass = tuning.total_mass()
	center_of_mass = tuning.center_of_mass()
	inertia = Vector3(tuning.inertia_roll_pitch, tuning.inertia_yaw, tuning.inertia_roll_pitch)
	var half := tuning.wheelbase * 0.5
	front_wheel.position = Vector3(0, tuning.wheel_radius, -half)
	rear_wheel.position = Vector3(0, tuning.wheel_radius, half)


func _update_lean(intent: RiderIntent, delta: float) -> void:
	lean_angle = asin(clampf(-global_basis.x.y, -1.0, 1.0))
	var wanted := intent.lean.x * deg_to_rad(tuning.max_lean_deg)
	target_lean = move_toward(target_lean, wanted, deg_to_rad(tuning.lean_rate_deg) * delta)


## Steer to balance the current lean: in a steady turn, lateral grip must
## supply m·g·tan(lean), which for a bicycle-like wheelbase gives
## tan(ground steer) = wheelbase · g · tan(lean) / v².
## At walking pace that formula blows up, so it blends to steering directly
## from the stick. The result is limited by speed and by steering rate.
func _update_steering(intent: RiderIntent, speed: float, delta: float) -> void:
	var v := absf(speed)
	var direct := intent.lean.x * deg_to_rad(tuning.max_steer_slow_deg)
	var balance := 0.0
	if v > 0.1:
		var ground_tan := tuning.wheelbase * GRAVITY * tan(lean_angle) / (v * v)
		balance = atan(ground_tan / sin(deg_to_rad(tuning.headtube_angle_deg)))
	var blend := clampf(inverse_lerp(tuning.lean_steer_min_speed, tuning.lean_steer_full_speed, v), 0.0, 1.0)
	var t := clampf(v / tuning.steer_fast_speed, 0.0, 1.0)
	var limit := deg_to_rad(lerpf(tuning.max_steer_slow_deg, tuning.max_steer_fast_deg, t))
	var target := clampf(lerpf(direct, balance, blend), -limit, limit)
	steer_angle = move_toward(steer_angle, target, deg_to_rad(tuning.steer_rate_deg) * delta)


## A kick is a short forward push, started on the button press.
func _apply_push(intent: RiderIntent, speed: float, grounded: bool, delta: float) -> void:
	if intent.kick and not _kick_was_down:
		_push_time_left = tuning.push_duration
	_kick_was_down = intent.kick
	if _push_time_left <= 0.0:
		return
	_push_time_left -= delta
	if not grounded or speed > tuning.push_max_speed:
		return
	var normal := rear_wheel.contact_normal if rear_wheel.in_contact else Vector3.UP
	var forward := -global_basis.z
	forward = (forward - normal * forward.dot(normal)).normalized()
	apply_central_force(forward * tuning.push_force)


func _apply_drag() -> void:
	var v := linear_velocity
	apply_central_force(-0.5 * AIR_DENSITY * tuning.drag_area * v.length() * v)


## Moves the lean toward the target. Stands in for the rider shifting
## their weight until Phase 3; in a steady turn it does almost nothing,
## because the steering already balances the lean.
func _apply_balance_torque() -> void:
	var forward := -global_basis.z
	var roll_rate := angular_velocity.dot(forward)
	var torque := tuning.assist_stiffness * (target_lean - lean_angle) - tuning.assist_damping * roll_rate
	torque = clampf(torque, -tuning.max_balance_torque, tuning.max_balance_torque)
	balance_torque = torque * tuning.assist_strength
	apply_torque(forward * balance_torque)


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
	_add_mesh(self, deck_mesh, accent, Transform3D(Basis(), deck_center))

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

	var ballast := CapsuleMesh.new()
	ballast.radius = 0.18
	ballast.height = 1.7
	var ghost := StandardMaterial3D.new()
	ghost.albedo_color = Color(0.4, 0.7, 1.0, 0.25)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_mesh(self, ballast, ghost,
			Transform3D(Basis(), Vector3(0, deck_center.y + 0.85, tuning.rider_com_offset)))


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
