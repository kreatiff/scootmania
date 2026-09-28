class_name ChaseCamera
extends Camera3D
## A basic follow camera so the scooter can be ridden. Phase 6 replaces it
## with a properly tuned one (look-ahead, air handling, ramp framing).

@export var target: Node3D
@export_range(1.0, 10.0, 0.1, "suffix:m") var distance := 3.2
@export_range(0.2, 4.0, 0.1, "suffix:m") var height := 1.5
@export_range(0.0, 2.0, 0.05, "suffix:m") var look_height := 0.8
## How quickly the camera catches up. Higher is tighter.
@export_range(0.5, 20.0, 0.5) var follow_rate := 5.0

var _heading := Vector3.FORWARD


func _ready() -> void:
	# Moved every rendered frame from the target's interpolated transform,
	# so it must not be interpolated again.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if target:
		_heading = _flat(-target.global_basis.z, Vector3.FORWARD)
		global_position = _desired_position(target.global_position)


func _process(delta: float) -> void:
	if target == null:
		return
	var xform := target.get_global_transform_interpolated()
	var body := target as RigidBody3D
	var velocity := body.linear_velocity if body else Vector3.ZERO
	# Follow the direction of travel when moving, otherwise where it faces.
	var wanted := _flat(velocity, Vector3.ZERO) if velocity.length() > 1.0 else Vector3.ZERO
	if wanted == Vector3.ZERO:
		wanted = _flat(-xform.basis.z, _heading)
	var blend := 1.0 - exp(-follow_rate * delta)
	_heading = _heading.slerp(wanted, blend).normalized()
	global_position = global_position.lerp(_desired_position(xform.origin), blend)
	look_at(xform.origin + Vector3.UP * look_height)


func _desired_position(target_position: Vector3) -> Vector3:
	return target_position - _heading * distance + Vector3.UP * height


static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length_squared() > 1e-6 else fallback
