class_name FlyCamera
extends Camera3D
## Free-fly debug camera. Only moves while it's the current camera.
##
## Gamepad: left stick move, right stick look, LB/RB down/up.
## Keyboard/mouse: WASD move, hold right mouse to look, Q/E down/up,
## mouse wheel changes speed.
##
## Reads Input directly: it's a debug tool, not part of the replayed intent.

@export_range(0.5, 30.0, 0.5, "suffix:m/s") var speed := 6.0
@export_range(30.0, 360.0, 5.0, "suffix:°/s") var stick_look_speed := 150.0
@export_range(0.01, 0.5, 0.01) var mouse_sensitivity := 0.15

var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	# Moved every rendered frame in _process, so don't interpolate it too.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_sync_angles()


## Match another camera's view, e.g. when switching to fly mode.
func copy_view(from: Camera3D) -> void:
	global_transform = from.global_transform
	fov = from.fov
	_sync_angles()


func _unhandled_input(event: InputEvent) -> void:
	if not current:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= deg_to_rad(event.relative.x * mouse_sensitivity)
		_pitch -= deg_to_rad(event.relative.y * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = minf(speed * 1.25, 30.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = maxf(speed / 1.25, 0.5)


func _process(delta: float) -> void:
	if not current:
		return
	var look := Input.get_vector("pose_left", "pose_right", "pose_down", "pose_up")
	_yaw -= deg_to_rad(look.x * stick_look_speed * delta)
	_pitch += deg_to_rad(look.y * stick_look_speed * delta)
	_pitch = clampf(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))

	var move := Input.get_vector("lean_left", "lean_right", "lean_back", "lean_forward")
	var vertical := Input.get_axis("fly_down", "fly_up")
	var velocity := basis * Vector3(move.x, 0.0, -move.y) + Vector3.UP * vertical
	position += velocity * speed * delta


func _sync_angles() -> void:
	var euler := basis.get_euler()
	_pitch = euler.x
	_yaw = euler.y
