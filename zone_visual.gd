
extends MeshInstance3D

@export var radius: float = 40.0
@export var segments: int = 128
@export var line_width: float = 0.15

func _ready() -> void:
	var points := PackedVector3Array()
	var indices := PackedInt32Array()

	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var next_angle := TAU * float(i + 1) / float(segments)

		var outer_a := Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)

		var outer_b := Vector3(
			cos(next_angle) * radius,
			0.0,
			sin(next_angle) * radius
		)

		var inner_a := Vector3(
			cos(angle) * (radius - line_width),
			0.0,
			sin(angle) * (radius - line_width)
		)

		var inner_b := Vector3(
			cos(next_angle) * (radius - line_width),
			0.0,
			sin(next_angle) * (radius - line_width)
		)

		var base := points.size()
		points.append(outer_a)
		points.append(outer_b)
		points.append(inner_a)
		points.append(inner_b)

		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2,
			base + 1, base + 3, base + 2
		]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = indices

	var ring_mesh := ArrayMesh.new()
	ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = ring_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.5, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
