class_name PlotHud
extends Control
## Draws every DebugDraw.plot() series as a small line graph, stacked in the
## top-right corner, each scaled to its own recent min and max.

const GRAPH_SIZE := Vector2(300, 70)
const MARGIN := 16.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var origin := Vector2(size.x - GRAPH_SIZE.x - MARGIN, MARGIN)
	for label in DebugDraw.plots:
		var series: PackedFloat32Array = DebugDraw.plots[label]
		if series.size() < 2:
			continue
		var lo := INF
		var hi := -INF
		for v in series:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var span := maxf(hi - lo, 1e-6)
		draw_rect(Rect2(origin, GRAPH_SIZE), Color(0, 0, 0, 0.45))
		var points := PackedVector2Array()
		var step := GRAPH_SIZE.x / float(DebugDraw.PLOT_LENGTH - 1)
		var start_x := GRAPH_SIZE.x - step * (series.size() - 1)
		for i in series.size():
			var t := (series[i] - lo) / span
			points.append(origin + Vector2(start_x + step * i, GRAPH_SIZE.y * (1.0 - t)))
		draw_polyline(points, Color.GOLD, 1.5, true)
		var text := "%s  %.0f  (%.0f…%.0f)" % [label, series[series.size() - 1], lo, hi]
		draw_string_outline(font, origin + Vector2(6, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(font, origin + Vector2(6, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		origin.y += GRAPH_SIZE.y + 8.0
