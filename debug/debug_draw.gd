extends Node
## Autoload "DebugDraw". Immediate-mode 3D lines for visualising forces.
##
## Call the draw functions from _physics_process. Everything queued during a
## physics tick is shown until the next tick starts, so lines don't flicker
## when the render rate and physics rate differ. Lines are drawn at physics
## positions, so they can lag interpolated bodies by up to one tick.
##
## F3 toggles drawing.

var enabled := true
## Named telemetry lines shown on the HUD, e.g. watch("speed", "12 km/h").
var watches := {}
## Named time series drawn as graphs on the HUD: name -> PackedFloat32Array.
var plots := {}
## Samples kept per plot.
const PLOT_LENGTH := 600

var _lines := PackedVector3Array()
var _colors := PackedColorArray()
var _mesh := ImmediateMesh.new()
var _instance := MeshInstance3D.new()


func _ready() -> void:
	# Clear before any other node draws in this tick.
	process_physics_priority = -1001
	process_mode = Node.PROCESS_MODE_ALWAYS

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true # always visible, even through geometry
	material.render_priority = 100
	_instance.mesh = _mesh
	_instance.material_override = material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_instance)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_draw"):
		enabled = not enabled


func _physics_process(_delta: float) -> void:
	_lines.clear()
	_colors.clear()


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	_instance.visible = enabled
	if not enabled or _lines.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in _lines.size():
		_mesh.surface_set_color(_colors[i])
		_mesh.surface_add_vertex(_lines[i])
	_mesh.surface_end()


func line(from: Vector3, to: Vector3, color := Color.WHITE) -> void:
	_lines.append(from)
	_lines.append(to)
	_colors.append(color)
	_colors.append(color)


## Draws `vector * scale` starting at `origin`, with an arrowhead.
## Use a consistent scale per quantity, e.g. 0.001 m per newton for forces.
func arrow(origin: Vector3, vector: Vector3, color := Color.WHITE, scale := 1.0) -> void:
	var tip := origin + vector * scale
	line(origin, tip, color)
	var length := (tip - origin).length()
	if length < 0.001:
		return
	var dir := (tip - origin) / length
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var head := minf(length * 0.25, 0.15)
	line(tip, tip - dir * head + side * head * 0.5, color)
	line(tip, tip - dir * head - side * head * 0.5, color)


## Shows `text` on the HUD under `label` until it's replaced or cleared.
func watch(label: String, text: String) -> void:
	watches[label] = text


func clear_watches() -> void:
	watches.clear()


## Appends a sample to a graph on the HUD. Call once per physics tick (or at
## any steady rate); the last PLOT_LENGTH samples are shown.
func plot(label: String, value: float) -> void:
	var series: PackedFloat32Array = plots.get(label, PackedFloat32Array())
	series.append(value)
	if series.size() > PLOT_LENGTH:
		series = series.slice(series.size() - PLOT_LENGTH)
	plots[label] = series


## A small 3-axis cross at a point.
func point(position: Vector3, color := Color.WHITE, size := 0.05) -> void:
	line(position - Vector3.RIGHT * size, position + Vector3.RIGHT * size, color)
	line(position - Vector3.UP * size, position + Vector3.UP * size, color)
	line(position - Vector3.FORWARD * size, position + Vector3.FORWARD * size, color)


## Draws a transform's basis: X red, Y green, Z blue.
func axes(xform: Transform3D, size := 0.3) -> void:
	line(xform.origin, xform.origin + xform.basis.x * size, Color.RED)
	line(xform.origin, xform.origin + xform.basis.y * size, Color.GREEN)
	line(xform.origin, xform.origin + xform.basis.z * size, Color.BLUE)
