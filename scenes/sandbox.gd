extends Node3D
## The test world: the park, the scooter, debug tools and cameras.
## F2 / D-pad up cycles chase → overview → fly camera.

@onready var _tuning_panel: TuningPanel = $TuningPanel
@onready var _scooter: Scooter = $Scooter
@onready var _chase: ChaseCamera = $ChaseCamera
@onready var _overview: Camera3D = $OverviewCamera
@onready var _fly: FlyCamera = $FlyCamera


func _ready() -> void:
	_tuning_panel.bind(_scooter.tuning, "Scooter")
	_tuning_panel.bind(RiderInput.tuning, "Input")
	_chase.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("debug_camera"):
		_cycle_camera()


func _cycle_camera() -> void:
	if _chase.current:
		_overview.make_current()
	elif _overview.current:
		_fly.copy_view(_overview)
		_fly.make_current()
	else:
		_chase.make_current()
	# While flying, the sticks move the camera, so the scooter coasts.
	_scooter.use_live_input = not _fly.current
