extends Node3D
## Headless tests. Run from the project folder with:
##   godot --headless --fixed-fps 240 --path . res://tests/test_runner.tscn
## (--fixed-fps runs one physics tick per frame as fast as possible, instead
## of in real time.) Exits with code 0 when everything passes, 1 otherwise.
##
## The replay test records synthetic input that pushes a rigid body, plays it
## back, and requires the body to end in *exactly* the same place. Replays
## reload this scene, so progress between reloads lives in static vars.

const TEST_REPLAY := "user://replays/test.replay"
const RECORD_TICKS := 240

enum Stage { SETUP, RECORDING, PLAYBACK }

static var stage := Stage.SETUP
static var failures := 0
static var recorded_intents: Array[PackedFloat64Array] = []
static var played_intents: Array[PackedFloat64Array] = []
static var recorded_final := Transform3D()

var _tick := 0

@onready var _body: RigidBody3D = $Body


func _ready() -> void:
	if stage != Stage.SETUP:
		return # reloaded for the replay test
	_run_unit_tests()

	var park: Node3D = preload("res://scenes/park.tscn").instantiate()
	add_child(park)
	# Colliders only exist in the physics space after a tick.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_run_prop_tests(park)
	park.queue_free()

	await ScooterTests.new(self).run()
	await PumpPopTests.new(self).run()
	await AirTests.new(self).run()
	await TurnTests.new(self).run()
	await TrickTests.new(self).run()
	await ManualTests.new(self).run()
	await GrindTests.new(self).run()

	stage = Stage.RECORDING
	RiderInput.start_recording()


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
	intent.reset = true
	intent.foot = true
	check(RiderIntent.from_array(intent.to_array()).equals(intent), "intent survives array round trip")

	var frames := PackedFloat64Array([0.1, 0.2, 0.3, 0.4, 0.5, 1.0])
	check(RiderInput.save_replay(TEST_REPLAY, frames) == OK, "replay file written")
	check(RiderInput.load_replay(TEST_REPLAY) == frames, "replay file round trip")


## Every prop's collider must match the geometry it was built from: rays
## cast down across each prop must hit at the profile's height, on the
## right material. A wrongly wound collider (invisible from above) fails.
func _run_prop_tests(park: Node3D) -> void:
	var props := 0
	for prop in park.get_children():
		if prop is ProfileProp:
			props += 1
			_check_profile_prop(prop)
		elif prop is Rail:
			props += 1
			var top: Vector3 = prop.to_global(Vector3(0.5, prop.height, 0))
			var hit := _ray_down(top)
			check(not hit.is_empty() and absf(hit["position"].y - prop.height) < 0.005
					and _is_steel(hit), "%s: steel rail top at %.2f m" % [prop.name, prop.height])
	check(props == 7, "park has 7 props (found %d)" % props)


func _check_profile_prop(prop: ProfileProp) -> void:
	var zr := prop.z_range()
	var misses: Array[String] = []
	var coping_z := NAN
	if prop is QuarterPipe and prop.coping:
		coping_z = prop.lip().x
	for f in [0.1, 0.3, 0.5, 0.7, 0.9]:
		var z := lerpf(zr.x, zr.y, f)
		if not is_nan(coping_z) and absf(z - coping_z) < 0.1:
			continue
		var expected := prop.top_height(z)
		for x_frac in [-0.4, 0.0, 0.4]:
			var hit := _ray_down(prop.to_global(Vector3(prop.width * x_frac, expected, z)))
			var ok: bool = not hit.is_empty() and absf(hit["position"].y - expected) < 0.005 \
					and hit["collider"] == prop
			if not ok:
				misses.append("z=%.2f x=%.1f expected %.3f got %s" % [z, x_frac,
						expected, "nothing" if hit.is_empty() else "%.3f on %s" % [hit["position"].y, hit["collider"].name]])
	check(misses.is_empty(), "%s: collider matches profile%s" % [prop.name,
			"" if misses.is_empty() else "\n      " + "\n      ".join(misses)])
	check(prop.physics_material_override == PropMaterials.CONCRETE, "%s: concrete" % prop.name)

	for edge in prop._steel_edges():
		var at: Vector2 = edge["at"]
		var top: float = at.y + edge["size"] * 0.5
		var hit := _ray_down(prop.to_global(Vector3(0, top, at.x)))
		check(not hit.is_empty() and absf(hit["position"].y - top) < 0.005 and _is_steel(hit),
				"%s: steel edge on top at %.3f m" % [prop.name, top])


func _ray_down(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 2.0)
	return get_world_3d().direct_space_state.intersect_ray(query)


static func _is_steel(hit: Dictionary) -> bool:
	var body := hit["collider"] as StaticBody3D
	return body != null and body.physics_material_override == PropMaterials.STEEL \
			and body.collision_layer & PropMaterials.LAYER_GRINDABLE != 0


## Information that isn't pass/fail.
func note(description: String) -> void:
	print("  note  " + description)


func check(condition: bool, description: String) -> void:
	print(("  ok    " if condition else "  FAIL  ") + description)
	if not condition:
		failures += 1
