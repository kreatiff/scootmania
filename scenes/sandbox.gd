extends Node3D
## The test world: the park, the scooter, debug tools and cameras.
## F2 / D-pad up cycles chase → overview → fly camera.

@onready var _tuning_panel: TuningPanel = $TuningPanel
@onready var _scooter: Scooter = $Scooter
@onready var _chase: ChaseCamera = $ChaseCamera
@onready var _overview: Camera3D = $OverviewCamera
@onready var _fly: FlyCamera = $FlyCamera


var _slow_motion := SlowMotion.new()


func _ready() -> void:
	add_child(_slow_motion)
	_scooter.bailed.connect(func() -> void:
		_slow_motion.play(_scooter.tuning.bail_slowmo_scale, _scooter.tuning.bail_slowmo_time))
	_tuning_panel.bind(_scooter.tuning, "Scooter")
	_tuning_panel.bind(RiderInput.tuning, "Input")
	_chase.make_current()


func _unhandled_input(event: InputEvent) -> void:
	# Reset (Start / R) is handled by the scooter through RiderInput, so
	# replays reproduce it.
	if event.is_action_pressed("debug_camera"):
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
