extends Node3D
## The test world: the park, debug tools and cameras. Until the scooter
## exists (Phase 2), the rider intent is drawn at the spawn point.

@onready var _tuning_panel: TuningPanel = $TuningPanel
@onready var _spawn: Marker3D = $Spawn
@onready var _overview: Camera3D = $OverviewCamera
@onready var _fly: FlyCamera = $FlyCamera


func _ready() -> void:
	_tuning_panel.bind(RiderInput.tuning, "Input")
	_overview.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("debug_camera"):
		_toggle_fly_camera()


func _toggle_fly_camera() -> void:
	if _fly.current:
		_overview.make_current()
	else:
		_fly.copy_view(get_viewport().get_camera_3d())
		_fly.make_current()


func _physics_process(_delta: float) -> void:
	if _fly.current:
		return # the sticks are flying the camera, not riding
	var intent := RiderInput.intent
	var origin := _spawn.global_position + Vector3(0, 0.02, 0)
	DebugDraw.axes(Transform3D(Basis(), origin), 0.5)
	# Lean: stick forward points down -Z, Godot's forward.
	DebugDraw.arrow(origin, Vector3(intent.lean.x, 0, -intent.lean.y), Color.AQUA)
	# Pose: y is extend (up) / compress (down), x shifts sideways.
	var pose_origin := origin + Vector3(1.5, 1.0, 0)
	DebugDraw.point(pose_origin, Color(1, 1, 1, 0.4), 0.1)
	DebugDraw.arrow(pose_origin, Vector3(intent.pose.x, intent.pose.y, 0) * 0.8, Color.MAGENTA)
	# Brake: a bar that grows with trigger pressure.
	var brake_origin := origin + Vector3(-1.5, 0, 0)
	DebugDraw.line(brake_origin, brake_origin + Vector3.UP * intent.brake * 1.5, Color.ORANGE)
	if intent.kick:
		DebugDraw.point(origin + Vector3(0, 0.5, 0.5), Color.GREEN, 0.2)
