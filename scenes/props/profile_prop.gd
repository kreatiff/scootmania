@tool
class_name ProfileProp
extends StaticBody3D
## Base for concrete props defined by a 2D side profile, extruded along X.
##
## Subclasses return the profile as (z, y) points from `_profile()`. The
## visual mesh and the collider are built from the same triangles, so they
## always match. Steel edges come from `_steel_edges()`.
##
## Conventions: the prop's origin is where its riding surface meets the
## ground, centred in X. Surfaces rise toward -Z (Godot's forward), so a
## rider travelling forward from the origin rides up the prop.
##
## Everything generated is rebuilt when an exported value changes, and is
## never saved into the scene file.

## Normals of adjacent faces closer than this are smoothed (curved parts).
const SMOOTH_ANGLE := 0.35 # radians, ~20°

## Extent along X: the length of the lip, or the length of a box.
@export_range(0.5, 20.0, 0.1, "suffix:m") var width := 4.0:
	set(value):
		width = value
		queue_rebuild()

var _rebuild_queued := false


func _ready() -> void:
	if physics_material_override == null:
		physics_material_override = PropMaterials.CONCRETE
	collision_layer = PropMaterials.LAYER_WORLD
	rebuild()


## Closed polygon in the (z, y) plane, in metres. Any winding.
func _profile() -> PackedVector2Array:
	return PackedVector2Array()


## Steel edges running along X: an Array of dictionaries with
## "at": Vector2 (z, y) centre, "shape": "round" or "square", "size": metres.
func _steel_edges() -> Array[Dictionary]:
	return []


func queue_rebuild() -> void:
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

	var faces := build_faces(_ccw(_profile()), width)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = faces["mesh"]
	mesh_instance.material_override = PropMaterials.concrete_visual()
	_add_generated(mesh_instance, "Mesh")

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces["collision"])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_add_generated(collision, "Collision")

	var index := 0
	for edge in _steel_edges():
		_add_generated(_make_steel_edge(edge), "Steel%d" % index)
		index += 1


## Highest point of the profile at `z`, or NAN if `z` is outside it.
## Used by tests to check the collider against the intended geometry.
func top_height(z: float) -> float:
	var pts := _profile()
	var best := NAN
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		if is_equal_approx(a.x, b.x) or z < minf(a.x, b.x) or z > maxf(a.x, b.x):
			continue
		var y := lerpf(a.y, b.y, (z - a.x) / (b.x - a.x))
		if is_nan(best) or y > best:
			best = y
	return best


## Profile extent along z as Vector2(min_z, max_z).
func z_range() -> Vector2:
	var pts := _profile()
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return Vector2(lo, hi)


func _add_generated(node: Node, node_name: String) -> void:
	node.name = node_name
	node.set_meta("generated", true)
	add_child(node)


func _make_steel_edge(edge: Dictionary) -> StaticBody3D:
	var at: Vector2 = edge["at"]
	var size: float = edge["size"]
	var shape: Shape3D
	var mesh: Mesh
	var basis := Basis()
	if edge["shape"] == "round":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = size * 0.5
		cylinder.height = width
		shape = cylinder
		var cylinder_mesh := CylinderMesh.new()
		cylinder_mesh.top_radius = size * 0.5
		cylinder_mesh.bottom_radius = size * 0.5
		cylinder_mesh.height = width
		cylinder_mesh.radial_segments = 16
		mesh = cylinder_mesh
		basis = Basis(Vector3.BACK, PI * 0.5) # cylinder axis Y -> X
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(width, size, size)
		shape = box
		var box_mesh := BoxMesh.new()
		box_mesh.size = box.size
		mesh = box_mesh
	var xform := Transform3D(basis, Vector3(0, at.y, at.x))
	var body := PropMaterials.make_steel_body("Steel", shape, mesh, xform)
	var to_body := xform.affine_inverse()
	PropMaterials.mark_grind_edge(body, to_body * Vector3(-width * 0.5, at.y, at.x),
			to_body * Vector3(width * 0.5, at.y, at.x), size * 0.5)
	# Children of a generated node aren't saved either, but mark them anyway.
	body.set_meta("generated", true)
	return body


## Builds the extruded mesh and matching collision triangles from a CCW
## (z, y) profile. Returns {"mesh": ArrayMesh, "collision": PackedVector3Array}.
static func build_faces(pts: PackedVector2Array, extrude: float) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision := PackedVector3Array()
	var hx := extrude * 0.5
	var n := pts.size()

	# Outward normal of each edge. For a CCW polygon it's the edge rotated
	# clockwise: (dz, dy) -> (dy, -dz).
	var edge_normals: Array[Vector3] = []
	for i in n:
		var d := pts[(i + 1) % n] - pts[i]
		edge_normals.append(Vector3(0, -d.x, d.y).normalized())

	# Sides: one quad per profile edge, smooth-shaded across gentle bends.
	for i in n:
		var j := (i + 1) % n
		var face_n := edge_normals[i]
		var n_start := _vertex_normal(edge_normals[(i - 1 + n) % n], face_n)
		var n_end := _vertex_normal(edge_normals[(i + 1) % n], face_n)
		var a0 := Vector3(-hx, pts[i].y, pts[i].x)
		var a1 := Vector3(hx, pts[i].y, pts[i].x)
		var b0 := Vector3(-hx, pts[j].y, pts[j].x)
		var b1 := Vector3(hx, pts[j].y, pts[j].x)
		_add_tri(st, collision, [a0, a1, b1], [n_start, n_start, n_end], face_n)
		_add_tri(st, collision, [a0, b1, b0], [n_start, n_end, n_end], face_n)

	# End caps.
	var tris := Geometry2D.triangulate_polygon(pts)
	for side in [-1.0, 1.0]:
		var cap_n := Vector3(side, 0, 0)
		for t in range(0, tris.size(), 3):
			var verts: Array[Vector3] = []
			for k in 3:
				var p := pts[tris[t + k]]
				verts.append(Vector3(hx * side, p.y, p.x))
			_add_tri(st, collision, verts, [cap_n, cap_n, cap_n], cap_n)

	return {"mesh": st.commit(), "collision": collision}


static func _vertex_normal(neighbour: Vector3, face: Vector3) -> Vector3:
	if neighbour.angle_to(face) < SMOOTH_ANGLE:
		return (neighbour + face).normalized()
	return face


## Adds one triangle wound so its front side faces `facing`. Godot treats
## clockwise triangles (seen from the front) as front faces, for both
## rendering and one-sided collision.
static func _add_tri(st: SurfaceTool, collision: PackedVector3Array, v: Array, normals: Array, facing: Vector3) -> void:
	var order := [0, 1, 2]
	if (v[1] - v[0]).cross(v[2] - v[0]).dot(facing) > 0.0:
		order = [0, 2, 1]
	for k in order:
		st.set_normal(normals[k])
		st.add_vertex(v[k])
		collision.append(v[k])


static func _ccw(pts: PackedVector2Array) -> PackedVector2Array:
	var area := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	if area < 0.0:
		pts.reverse()
	return pts
