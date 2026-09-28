class_name SlowMotion
extends Node
## Slows the whole game for a moment (e.g. on a bail), then restores it.
## Timed in real (unscaled) time. Physics still steps at the same fixed
## rate, just fewer steps per second, so replays are unaffected.

var active := false
var _timer: SceneTreeTimer


func play(time_scale: float, seconds: float) -> void:
	if seconds <= 0.0 or time_scale >= 1.0:
		return
	Engine.time_scale = time_scale
	active = true
	_timer = get_tree().create_timer(seconds, true, false, true)
	var this_timer := _timer
	_timer.timeout.connect(func() -> void:
		if _timer == this_timer: # a newer play() extends the slow motion
			stop())


func stop() -> void:
	Engine.time_scale = 1.0
	active = false
	_timer = null


func _exit_tree() -> void:
	if active:
		stop()
