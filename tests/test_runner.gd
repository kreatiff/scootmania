extends Node3D
## Headless tests. Run from the project folder with:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 0 when everything passes, 1 otherwise.
##
## The replay test records synthetic input that pushes a rigid body, plays it
## back, and requires the body to end in *exactly* the same place. Replays
## reload this scene, so progress between reloads lives in static vars.

const TEST_REPLAY := "user://replays/test.replay"
const RECORD_TICKS := 240

enum Stage { UNIT, RECORDING, PLAYBACK }

static var stage := Stage.UNIT
static var failures := 0
static var recorded_intents: Array[PackedFloat64Array] = []
static var played_intents: Array[PackedFloat64Array] = []
static var recorded_final := Transform3D()

var _tick := 0

@onready var _body: RigidBody3D = $Body


func _ready() -> void:
	match stage:
		Stage.UNIT:
			_run_unit_tests()
			stage = Stage.RECORDING
			RiderInput.start_recording()
		Stage.PLAYBACK:
			pass


func _physics_process(_delta: float) -> void:
	# The body is driven by intent, exactly as the scooter will be.
	var intent := RiderInput.intent
	_body.apply_central_force(Vector3(intent.lean.x, 0, -intent.lean.y) * 400.0)
	if intent.kick:
		_body.apply_central_impulse(Vector3.UP * 2.0)

	match stage:
		Stage.RECORDING:
			if RiderInput.mode != RiderInput.Mode.RECORDING:
				return
			recorded_intents.append(intent.to_array())
			_tick += 1
			_drive_synthetic_input(_tick)
			if _tick >= RECORD_TICKS:
				_release_input()
				recorded_final = _body.global_transform
				check(RiderInput.stop_recording(TEST_REPLAY) == OK, "replay saved")
				stage = Stage.PLAYBACK
				check(RiderInput.start_playback(TEST_REPLAY) == OK, "replay loaded")
		Stage.PLAYBACK:
			if RiderInput.mode == RiderInput.Mode.PLAYBACK:
				played_intents.append(intent.to_array())
				# The replay ends after its last tick is consumed; the tick
				# that consumed it is the last one appended above.
				if RiderInput.replay_tick >= RiderInput.replay_length:
					_finish_replay_test()


func _finish_replay_test() -> void:
	check(played_intents.size() == recorded_intents.size(),
			"played %d ticks, recorded %d" % [played_intents.size(), recorded_intents.size()])
	var mismatch := -1
	for i in mini(played_intents.size(), recorded_intents.size()):
		if played_intents[i] != recorded_intents[i]:
			mismatch = i
			break
	check(mismatch == -1, "intents identical on every tick (first mismatch: %d)" % mismatch)
	var moved := recorded_final.origin.length()
	check(moved > 0.5, "input actually moved the body (%.3f m)" % moved)
	check(_body.global_transform == recorded_final,
			"body ends in the identical transform\n    rec  %s\n    play %s"
			% [recorded_final, _body.global_transform])
	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures))
	get_tree().quit(1 if failures else 0)


## Deterministic, varied input: sweeps the left stick and taps kick.
func _drive_synthetic_input(tick: int) -> void:
	var t := tick / 120.0
	_press_axis("lean_right", "lean_left", sin(t * 5.0) * 0.9)
	_press_axis("lean_forward", "lean_back", cos(t * 3.0) * 0.9)
	if tick % 60 < 3:
		Input.action_press("kick")
	else:
		Input.action_release("kick")


func _press_axis(positive: String, negative: String, value: float) -> void:
	Input.action_release(positive)
	Input.action_release(negative)
	if value > 0.0:
		Input.action_press(positive, value)
	elif value < 0.0:
		Input.action_press(negative, -value)


func _release_input() -> void:
	for action in ["lean_right", "lean_left", "lean_forward", "lean_back", "kick"]:
		Input.action_release(action)


func _run_unit_tests() -> void:
	var tuning := InputTuning.new()
	tuning.stick_deadzone = 0.2
	tuning.stick_outer_deadzone = 0.9
	tuning.stick_curve = 1.0
	check(tuning.shape_stick(Vector2(0.15, 0.0)) == Vector2.ZERO, "stick inside deadzone is zero")
	check(is_equal_approx(tuning.shape_stick(Vector2(0.0, 0.95)).y, 1.0), "stick past outer deadzone is 1")
	var diag := tuning.shape_stick(Vector2(0.4, 0.4))
	check(is_equal_approx(diag.x, diag.y), "stick shaping keeps direction")
	check(tuning.shape_trigger(0.02) == 0.0, "trigger inside deadzone is zero")
	check(is_equal_approx(tuning.shape_trigger(1.0), 1.0), "full trigger is 1")

	var intent := RiderIntent.new()
	intent.lean = Vector2(0.3, -0.7)
	intent.pose = Vector2(-1.0, 0.25)
	intent.brake = 0.6
	intent.kick = true
	check(RiderIntent.from_array(intent.to_array()).equals(intent), "intent survives array round trip")

	var frames := PackedFloat64Array([0.1, 0.2, 0.3, 0.4, 0.5, 1.0])
	check(RiderInput.save_replay(TEST_REPLAY, frames) == OK, "replay file written")
	check(RiderInput.load_replay(TEST_REPLAY) == frames, "replay file round trip")


func check(condition: bool, description: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + description)
	if not condition:
		failures += 1
