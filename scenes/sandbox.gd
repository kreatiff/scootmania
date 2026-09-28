extends Node3D
## The test world. In Phase 0 it only hosts the debug tools and draws the
## rider intent in 3D, to prove input and DebugDraw work end to end.

@onready var _tuning_panel: TuningPanel = $TuningPanel


func _ready() -> void:
	_tuning_panel.bind(RiderInput.tuning, "Input")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()


func _physics_process(_delta: float) -> void:
	var intent := RiderInput.intent
	var origin := Vector3(0, 0.02, 0)
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
