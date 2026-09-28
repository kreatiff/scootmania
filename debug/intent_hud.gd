class_name IntentHud
extends Control
## Draws the current RiderIntent: both sticks (raw in grey, shaped in
## colour), brake and kick, plus replay state and tick rates.

const STICK_RADIUS := 48.0
const MARGIN := 16.0

var _info := Label.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.position = Vector2(MARGIN, MARGIN)
	var settings := LabelSettings.new()
	settings.font_size = 14
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	_info.label_settings = settings
	add_child(_info)


func _process(_delta: float) -> void:
	var pads := Input.get_connected_joypads()
	var pad_name := Input.get_joy_name(pads[0]) if not pads.is_empty() else "none (keyboard fallback)"
	var i := RiderInput.intent
	var lines := PackedStringArray([
		"FPS %d   physics %d Hz" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second],
		"Gamepad: %s" % pad_name,
		"Replay: %s" % _replay_text(),
		"",
		"lean  (%+.2f, %+.2f)" % [i.lean.x, i.lean.y],
		"pose  (%+.2f, %+.2f)" % [i.pose.x, i.pose.y],
		"brake  %.2f   kick %s" % [i.brake, "ON" if i.kick else "off"],
		"",
		"F2 camera · F3 debug lines · F5 record · F6 replay · Tab/Back tuning",
	])
	if not DebugDraw.watches.is_empty():
		lines.append("")
		for label in DebugDraw.watches:
			lines.append("%s  %s" % [label, DebugDraw.watches[label]])
	_info.text = "\n".join(lines)
	queue_redraw()


func _draw() -> void:
	var base := Vector2(MARGIN + STICK_RADIUS, size.y - MARGIN * 2.0 - STICK_RADIUS)
	var i := RiderInput.intent
	_draw_stick(base, RiderInput.raw_lean, i.lean, "LEAN")
	_draw_stick(base + Vector2(STICK_RADIUS * 2.0 + MARGIN * 2.0, 0), RiderInput.raw_pose, i.pose, "POSE")
	var bar_origin := base + Vector2(STICK_RADIUS * 4.0 + MARGIN * 3.0, STICK_RADIUS)
	_draw_bar(bar_origin, i.brake, "BRK")
	var kick_center := bar_origin + Vector2(40, -STICK_RADIUS + 10)
	draw_circle(kick_center, 10, Color.GREEN if i.kick else Color(1, 1, 1, 0.2))


func _draw_stick(center: Vector2, raw: Vector2, shaped: Vector2, label: String) -> void:
	draw_circle(center, STICK_RADIUS, Color(0, 0, 0, 0.4))
	draw_arc(center, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 1.5)
	var deadzone := RiderInput.tuning.stick_deadzone * STICK_RADIUS
	draw_arc(center, deadzone, 0, TAU, 24, Color(1, 0.4, 0.4, 0.5), 1.0)
	# Screen y points down; intent y points "up/forward".
	draw_circle(center + Vector2(raw.x, -raw.y) * STICK_RADIUS, 4, Color(1, 1, 1, 0.35))
	draw_circle(center + Vector2(shaped.x, -shaped.y) * STICK_RADIUS, 6, Color.AQUA)
	_draw_text(center + Vector2(-STICK_RADIUS, STICK_RADIUS + 14), label)


func _draw_bar(origin: Vector2, value: float, label: String) -> void:
	var height := STICK_RADIUS * 2.0
	draw_rect(Rect2(origin - Vector2(0, height), Vector2(14, height)), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(origin - Vector2(0, height * value), Vector2(14, height * value)), Color.ORANGE)
	_draw_text(origin + Vector2(-4, 14), label)


func _draw_text(at: Vector2, text: String) -> void:
	var font := get_theme_default_font()
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)


static func _replay_text() -> String:
	match RiderInput.mode:
		RiderInput.Mode.RECORDING:
			return "● REC  %d ticks" % RiderInput.replay_tick
		RiderInput.Mode.PLAYBACK:
			return "▶ PLAY  %d / %d" % [RiderInput.replay_tick, RiderInput.replay_length]
		RiderInput.Mode.ARMED_RECORD, RiderInput.Mode.ARMED_PLAYBACK:
			return "restarting…"
	return "live"
