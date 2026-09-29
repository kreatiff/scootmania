@tool
class_name Rail
extends StaticBody3D
## A round steel flat rail on two posts, running along X, centred on the
## origin. Entirely steel and on the grindable layer.

@export_range(1.0, 12.0, 0.1, "suffix:m") var length := 4.0:
	set(value):
		length = value
		_queue_rebuild()
## Height of the top of the rail above the ground.
@export_range(0.15, 1.2, 0.01, "suffix:m") var height := 0.35:
	set(value):
		height = value
		_queue_rebuild()
@export_range(0.025, 0.08, 0.005, "suffix:m") var diameter := 0.05:
	set(value):
		diameter = value
		_queue_rebuild()

const POST_SIZE := 0.05
const POST_INSET := 0.3

var _rebuild_queued := false


func _ready() -> void:
	physics_material_override = PropMaterials.STEEL
	collision_layer = PropMaterials.LAYER_WORLD | PropMaterials.LAYER_GRINDABLE
	rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.has_meta("generated"):
			remove_child(child)
			child.queue_free()

	var r := diameter * 0.5
	var bar_xform := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, height - r, 0))
	var bar_shape := CylinderShape3D.new()
	bar_shape.radius = r
	bar_shape.height = length
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = r
	bar_mesh.bottom_radius = r
	bar_mesh.height = length
	bar_mesh.radial_segments = 16
	_add_part("Bar", bar_shape, bar_mesh, bar_xform)
	PropMaterials.mark_grind_edge(self, Vector3(-length * 0.5, height - r, 0),
			Vector3(length * 0.5, height - r, 0), r)

	var post_height := height - diameter
	var post_shape := BoxShape3D.new()
	post_shape.size = Vector3(POST_SIZE, post_height, POST_SIZE)
	var post_mesh := BoxMesh.new()
	post_mesh.size = post_shape.size
	for side in [-1.0, 1.0]:
		var x: float = side * (length * 0.5 - POST_INSET)
		_add_part("Post", post_shape, post_mesh, Transform3D(Basis(), Vector3(x, post_height * 0.5, 0)))


func _add_part(part_name: String, shape: Shape3D, mesh: Mesh, xform: Transform3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = xform
	collision.name = part_name + "Collision"
	collision.set_meta("generated", true)
	add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.transform = xform
	visual.material_override = PropMaterials.steel_visual()
	visual.name = part_name + "Mesh"
	visual.set_meta("generated", true)
	add_child(visual)
