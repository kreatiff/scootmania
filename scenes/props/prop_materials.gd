@tool
class_name PropMaterials
## Shared physics and visual materials for park props.
##
## Physics materials are per body in Godot, not per shape, so every steel
## part (coping, rails, box edges) is its own StaticBody3D with STEEL.

const CONCRETE: PhysicsMaterial = preload("res://scenes/props/materials/concrete.tres")
const STEEL: PhysicsMaterial = preload("res://scenes/props/materials/steel.tres")
const GRID_SHADER: Shader = preload("res://scenes/props/materials/grid.gdshader")

## Layer 1: everything solid. Layer 2: grindable edges (coping, rails, box
## edges), so grind detection can query just those later.
const LAYER_WORLD := 1
const LAYER_GRINDABLE := 2

static var _concrete_visual: ShaderMaterial
static var _steel_visual: StandardMaterial3D


static func concrete_visual() -> ShaderMaterial:
	if _concrete_visual == null:
		_concrete_visual = ShaderMaterial.new()
		_concrete_visual.shader = GRID_SHADER
		_concrete_visual.set_shader_parameter("base_color", Color(0.46, 0.45, 0.42))
		_concrete_visual.set_shader_parameter("minor_line_color", Color(0.34, 0.33, 0.31))
		_concrete_visual.set_shader_parameter("major_line_color", Color(0.24, 0.23, 0.22))
	return _concrete_visual


static func steel_visual() -> StandardMaterial3D:
	if _steel_visual == null:
		_steel_visual = StandardMaterial3D.new()
		_steel_visual.albedo_color = Color(0.72, 0.73, 0.75)
		_steel_visual.metallic = 1.0
		_steel_visual.roughness = 0.35
	return _steel_visual


## A steel StaticBody3D holding one shape and its mesh, on the grindable layer.
static func make_steel_body(body_name: String, shape: Shape3D, mesh: Mesh, xform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.physics_material_override = STEEL
	body.collision_layer = LAYER_WORLD | LAYER_GRINDABLE
	body.transform = xform
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = steel_visual()
	body.add_child(visual)
	return body


## Marks a steel body as a grindable edge: a straight centre line from `a`
## to `b` (in the body's own frame) whose top is `top` above that line.
## GrindControl finds these through the "grind_edges" group.
static func mark_grind_edge(body: Node3D, a: Vector3, b: Vector3, top: float) -> void:
	body.set_meta("grind_a", a)
	body.set_meta("grind_b", b)
	body.set_meta("grind_top", top)
	if not body.is_in_group("grind_edges"):
		body.add_to_group("grind_edges")
