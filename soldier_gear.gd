extends RefCounted
## Lightweight visual equipment for Frontline's existing licensed soldier model.
## Procedural meshes only; no collisions, keeping mobile performance inexpensive.

static func apply_to(model: Node3D, enemy_variant: bool = false) -> void:
	if model == null or model.get_node_or_null("FrontlineTacticalGear") != null:
		return

	var gear := Node3D.new()
	gear.name = "FrontlineTacticalGear"
	model.add_child(gear)

	var armor_color := Color(0.20, 0.24, 0.18) if not enemy_variant else Color(0.28, 0.20, 0.16)
	var helmet_color := Color(0.16, 0.20, 0.15) if not enemy_variant else Color(0.25, 0.19, 0.15)
	var fabric_color := Color(0.34, 0.32, 0.23) if not enemy_variant else Color(0.38, 0.27, 0.20)
	var dark_color := Color(0.08, 0.09, 0.08)
	var strap_color := Color(0.12, 0.13, 0.10)

	# Combat helmet and front mount.
	_add_sphere(gear, "CombatHelmet", Vector3(0, 1.54, 0.015), Vector3(0.29, 0.205, 0.28), helmet_color)
	_add_box(gear, "HelmetFrontRim", Vector3(0, 1.48, -0.205), Vector3(0.34, 0.055, 0.12), dark_color)
	_add_box(gear, "HelmetMount", Vector3(0, 1.55, -0.255), Vector3(0.09, 0.08, 0.035), strap_color)
	_add_box(gear, "HelmetSideLeft", Vector3(-0.275, 1.43, 0.01), Vector3(0.065, 0.16, 0.11), dark_color)
	_add_box(gear, "HelmetSideRight", Vector3(0.275, 1.43, 0.01), Vector3(0.065, 0.16, 0.11), dark_color)

	# Plate carrier, webbing and magazine pouches.
	_add_box(gear, "PlateCarrier", Vector3(0, 1.02, -0.015), Vector3(0.53, 0.48, 0.30), armor_color)
	_add_box(gear, "FrontArmorPanel", Vector3(0, 1.05, -0.178), Vector3(0.36, 0.29, 0.035), fabric_color)
	for i in range(3):
		_add_box(gear, "MagazinePouch_%d" % i, Vector3(-0.16 + i * 0.16, 0.91, -0.205), Vector3(0.115, 0.14, 0.075), strap_color)
	_add_box(gear, "UtilityBelt", Vector3(0, 0.76, 0), Vector3(0.48, 0.09, 0.31), dark_color)
	_add_box(gear, "BeltBuckle", Vector3(0, 0.76, -0.17), Vector3(0.09, 0.07, 0.025), fabric_color)

	# Rear backpack and shoulder straps.
	_add_box(gear, "TacticalBackpack", Vector3(0, 1.12, 0.235), Vector3(0.36, 0.47, 0.24), fabric_color)
	_add_box(gear, "BackpackTop", Vector3(0, 1.34, 0.24), Vector3(0.30, 0.12, 0.25), armor_color)
	_add_box(gear, "ShoulderStrapLeft", Vector3(-0.205, 1.15, -0.105), Vector3(0.075, 0.35, 0.07), strap_color)
	_add_box(gear, "ShoulderStrapRight", Vector3(0.205, 1.15, -0.105), Vector3(0.075, 0.35, 0.07), strap_color)

	# Shoulder protection and knee pads give the silhouette a modern combat-kit look.
	_add_sphere(gear, "ShoulderPadLeft", Vector3(-0.32, 1.19, 0), Vector3(0.14, 0.12, 0.16), armor_color)
	_add_sphere(gear, "ShoulderPadRight", Vector3(0.32, 1.19, 0), Vector3(0.14, 0.12, 0.16), armor_color)
	_add_box(gear, "KneePadLeft", Vector3(-0.14, 0.43, -0.105), Vector3(0.17, 0.15, 0.08), dark_color)
	_add_box(gear, "KneePadRight", Vector3(0.14, 0.43, -0.105), Vector3(0.17, 0.15, 0.08), dark_color)

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

static func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	parent.add_child(node)

static func _add_sphere(parent: Node3D, node_name: String, pos: Vector3, scale_value: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = pos
	node.scale = scale_value
	parent.add_child(node)
