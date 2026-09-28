@tool
class_name ManualPad
extends ProfileProp
## A low concrete box with square steel edges along both long sides.
## `width` (from ProfileProp) is its length along X; `depth` is across Z.

@export_range(0.1, 1.0, 0.05, "suffix:m") var height := 0.3:
	set(value):
		height = value
		queue_rebuild()
@export_range(0.3, 3.0, 0.05, "suffix:m") var depth := 1.2:
	set(value):
		depth = value
		queue_rebuild()
@export_range(0.02, 0.1, 0.005, "suffix:m") var edge_size := 0.05:
	set(value):
		edge_size = value
		queue_rebuild()


func _profile() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO,
		Vector2(0.0, height),
		Vector2(-depth, height),
		Vector2(-depth, 0.0),
	])


func _steel_edges() -> Array[Dictionary]:
	# Angle iron wraps each top edge. It's 2 mm proud of the concrete so
	# anything touching the edge touches steel first.
	var half := edge_size * 0.5
	var proud := 0.002
	return [
		{"at": Vector2(-half + proud, height - half + proud), "shape": "square", "size": edge_size},
		{"at": Vector2(-depth + half - proud, height - half + proud), "shape": "square", "size": edge_size},
	]
