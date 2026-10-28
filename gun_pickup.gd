extends Area3D
## Collectible weapon pickup with a simple low-poly 3D silhouette.
@export var weapon_name: String = "M416"
@export_range(0, 5) var weapon_index: int = 0
var picked_up := false

func _ready() -> void:
	add_to_group("ammo_pickups")
	add_to_group("weapon_pickups")
	monitoring = true
	monitorable = true
	_build_model()
	print("WEAPON DROP READY: ", weapon_name)

func _build_model() -> void:
	var body_mat := _mat(Color(0.12, 0.15, 0.13))
	var metal_mat := _mat(Color(0.30, 0.32, 0.30))
	var accent_mat := _mat(Color(0.52, 0.36, 0.16))
	var body := _box("Receiver", Vector3(0.17, 0.13, 0.62), Vector3(0.0, 0.34, 0.0), body_mat)
	add_child(body)
	var barrel := _box("Barrel", Vector3(0.055, 0.055, 0.42), Vector3(0.0, 0.38, -0.49), metal_mat)
	add_child(barrel)
	var stock := _box("Stock", Vector3(0.13, 0.10, 0.28), Vector3(0.0, 0.32, 0.43), accent_mat)
	add_child(stock)
	var magazine := _box("Magazine", Vector3(0.11, 0.22, 0.15), Vector3(0.0, 0.19, 0.06), metal_mat)
	add_child(magazine)
	var grip := _box("Grip", Vector3(0.08, 0.16, 0.09), Vector3(0.0, 0.20, 0.19), body_mat)
	add_child(grip)
	var sight := _box("Sight", Vector3(0.08, 0.06, 0.08), Vector3(0.0, 0.435, -0.06), accent_mat)
	add_child(sight)
	if weapon_name == "AWM":
		var long_barrel := _box("SniperBarrel", Vector3(0.04, 0.04, 0.62), Vector3(0.0, 0.39, -0.77), metal_mat)
		add_child(long_barrel)
		var scope := _box("Scope", Vector3(0.08, 0.09, 0.24), Vector3(0.0, 0.48, -0.08), accent_mat)
		add_child(scope)
	elif weapon_name == "PISTOL":
		body.scale = Vector3(0.7, 0.7, 0.7)
		barrel.scale = Vector3(0.7, 0.7, 0.7)
		stock.visible = false
		magazine.scale = Vector3(0.7, 0.7, 0.7)
		grip.scale = Vector3(0.7, 0.7, 0.7)
		sight.visible = false
	var label := Label3D.new()
	label.text = weapon_name + "\nPICKUP"
	label.position = Vector3(0.0, 0.95, 0.0)
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.9, 0.55)
	add_child(label)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.7
	collision.shape = sphere
	add_child(collision)

func _box(node_name: String, dimensions: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	return node

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material

func pickup_weapon() -> void:
	if picked_up or not is_inside_tree():
		return
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player == null or not player.has_method("equip_weapon"):
		push_warning("Weapon pickup could not find Player/equip_weapon().")
		return
	if player.equip_weapon(weapon_index):
		picked_up = true
		print("PICKED UP ", weapon_name)
		queue_free()
