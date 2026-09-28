extends Node3D
## The test world: the park, the scooter, debug tools and cameras.
## F2 / D-pad up cycles chase → overview → fly camera.

@onready var _tuning_panel: TuningPanel = $TuningPanel
@onready var _scooter: Scooter = $Scooter
@onready var _chase: ChaseCamera = $ChaseCamera
@onready var _overview: Camera3D = $OverviewCamera
@onready var _fly: FlyCamera = $FlyCamera


## The first landing of each trick plays in slow motion, as a reward.
const FIRST_TRICK_SLOWMO_SCALE := 0.4
const FIRST_TRICK_SLOWMO_TIME := 0.7

var _slow_motion := SlowMotion.new()
var _trick_hud := TrickHud.new()
var _tricks_landed := {}


func _ready() -> void:
	add_child(_slow_motion)
	_scooter.bailed.connect(func() -> void:
		_slow_motion.play(_scooter.tuning.bail_slowmo_scale, _scooter.tuning.bail_slowmo_time))
	$Hud.add_child(_trick_hud)
	_scooter.trick_finished.connect(_on_trick_finished)
	_tuning_panel.bind(_scooter.tuning, "Scooter")
	_tuning_panel.bind(RiderInput.tuning, "Input")
	_chase.make_current()


func _on_trick_finished(result: String, landed: bool) -> void:
	_trick_hud.show_result(result, landed)
	if landed and not _tricks_landed.has(result):
		_tricks_landed[result] = true
		_slow_motion.play(FIRST_TRICK_SLOWMO_SCALE, FIRST_TRICK_SLOWMO_TIME)


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
