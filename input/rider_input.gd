extends Node
## Autoload "RiderInput". Samples the gamepad once per physics tick into a
## RiderIntent, and can record that stream to disk and play it back.
##
## Replays restart the current scene before the first tick, for both
## recording and playback, so both runs start from identical state and
## receive identical intents on identical ticks.

signal mode_changed(mode: Mode)

enum Mode { LIVE, ARMED_RECORD, RECORDING, ARMED_PLAYBACK, PLAYBACK }

const REPLAY_DIR := "user://replays"
const LAST_REPLAY := REPLAY_DIR + "/last.replay"
const REPLAY_VERSION := 2 # 2: added reset
const STRIDE := 7 # floats per tick, see RiderIntent.to_array()

var tuning: InputTuning = preload("res://input/input_tuning.tres")

## The intent for the current physics tick. Read it, don't cache it.
var intent := RiderIntent.new()
## Unshaped stick values from this tick, for the HUD.
var raw_lean := Vector2.ZERO
var raw_pose := Vector2.ZERO
var mode := Mode.LIVE
## Ticks recorded or played so far in the current replay.
var replay_tick := 0
var replay_length := 0

var _frames := PackedFloat64Array()
var _armed_scene_id := 0


func _ready() -> void:
	# Run before every scene node's _physics_process so they all see this
	# tick's intent.
	process_physics_priority = -1000
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("replay_record"):
		if mode == Mode.RECORDING:
			stop_recording()
		else:
			start_recording()
	elif event.is_action_pressed("replay_play"):
		if mode == Mode.PLAYBACK:
			_set_mode(Mode.LIVE)
		else:
			start_playback(LAST_REPLAY)


func _physics_process(_delta: float) -> void:
	_arm_if_scene_ready()
	match mode:
		Mode.PLAYBACK:
			if replay_tick >= replay_length:
				_set_mode(Mode.LIVE)
				intent = _sample_live()
			else:
				var start := replay_tick * STRIDE
				intent = RiderIntent.from_array(_frames.slice(start, start + STRIDE))
				replay_tick += 1
		Mode.RECORDING:
			intent = _sample_live()
			_frames.append_array(intent.to_array())
			replay_tick += 1
			replay_length = replay_tick
		_:
			intent = _sample_live()


func start_recording() -> void:
	_frames = PackedFloat64Array()
	_restart_scene(Mode.ARMED_RECORD)


func stop_recording(path := LAST_REPLAY) -> Error:
	_set_mode(Mode.LIVE)
	return save_replay(path, _frames)


func start_playback(path: String) -> Error:
	var frames := load_replay(path)
	if frames.is_empty():
		push_warning("No replay at %s" % path)
		return ERR_FILE_NOT_FOUND
	_frames = frames
	replay_length = frames.size() / STRIDE
	_restart_scene(Mode.ARMED_PLAYBACK)
	return OK


static func save_replay(path: String, frames: PackedFloat64Array) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({
		"version": REPLAY_VERSION,
		"physics_ticks": Engine.physics_ticks_per_second,
		"frames": frames,
	})
	return OK


static func load_replay(path: String) -> PackedFloat64Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedFloat64Array()
	var data: Variant = file.get_var()
	if not data is Dictionary or data.get("version") != REPLAY_VERSION:
		push_warning("Unsupported replay format in %s" % path)
		return PackedFloat64Array()
	if data["physics_ticks"] != Engine.physics_ticks_per_second:
		push_warning("Replay recorded at %d Hz, running at %d Hz: it will not match."
				% [data["physics_ticks"], Engine.physics_ticks_per_second])
	return data["frames"]


func _sample_live() -> RiderIntent:
	var live := RiderIntent.new()
	raw_lean = Input.get_vector("lean_left", "lean_right", "lean_back", "lean_forward")
	raw_pose = Input.get_vector("pose_left", "pose_right", "pose_down", "pose_up")
	live.lean = tuning.shape_stick(raw_lean)
	live.pose = tuning.shape_stick(raw_pose)
	live.brake = tuning.shape_trigger(Input.get_action_strength("brake"))
	live.kick = Input.is_action_pressed("kick")
	live.reset = Input.is_action_pressed("reset")
	return live


func _restart_scene(armed_mode: Mode) -> void:
	var scene := get_tree().current_scene
	_armed_scene_id = scene.get_instance_id() if scene else 0
	replay_tick = 0
	_set_mode(armed_mode)
	# Deferred: this may be called from _ready, while the tree is busy.
	get_tree().reload_current_scene.call_deferred()


## Recording and playback both begin on the first tick after the reloaded
## scene exists, so they line up tick for tick.
func _arm_if_scene_ready() -> void:
	if mode != Mode.ARMED_RECORD and mode != Mode.ARMED_PLAYBACK:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.get_instance_id() == _armed_scene_id:
		return
	_set_mode(Mode.RECORDING if mode == Mode.ARMED_RECORD else Mode.PLAYBACK)


func _set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	mode_changed.emit(mode)
