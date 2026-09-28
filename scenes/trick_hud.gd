class_name TrickHud
extends Label
## The trick callout at the top of the screen: "TAILWHIP + BARSPIN" in
## green when landed, "BARSPIN — too early" in red when not, and a running
## manual in white. Fades out in
## real time, so slow motion doesn't hold it on screen.

const SHOW_TIME := 1.6
const FADE_TIME := 0.4

var _shown_at := -INF


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_top = 40.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 44)
	add_theme_constant_override("outline_size", 10)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	modulate.a = 0.0


func show_result(result: String, landed: bool) -> void:
	text = result
	add_theme_color_override("font_color", Color(0.45, 1.0, 0.5) if landed else Color(1.0, 0.4, 0.35))
	_shown_at = Time.get_ticks_msec() / 1000.0


## Something still going on, like a manual's running time (white).
func show_live(result: String) -> void:
	text = result
	add_theme_color_override("font_color", Color(1, 1, 1))
	_shown_at = Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	var age := Time.get_ticks_msec() / 1000.0 - _shown_at
	modulate.a = clampf((SHOW_TIME + FADE_TIME - age) / FADE_TIME, 0.0, 1.0)
