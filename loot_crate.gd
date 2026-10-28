extends Node3D

@export var supply_name: String = "SUPPLY"
@export var healing_amount: float = 25.0
@export var energy_amount: float = 20.0
var picked_up := false

func _ready() -> void:
	add_to_group("ammo_pickups")
	add_to_group("loot_containers")
	if get_child_count() == 0:
		_build_crate()

func _build_crate() -> void:
	var body := MeshInstance3D.new()
	body.name = "CrateMesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.65, 0.75)
	body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.31, 0.22)
	material.roughness = 0.8
	body.material_override = material
	body.position.y = 0.35
	add_child(body)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.94, 0.08, 0.79)
	lid.mesh = lid_mesh
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.78, 0.58, 0.18)
	lid.material_override = lid_mat
	lid.position.y = 0.72
	add_child(lid)
	var label := Label3D.new()
	label.text = supply_name
	label.position = Vector3(0, 1.25, 0)
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func pickup_weapon() -> void:
	if picked_up or not is_inside_tree():
		return
	var player := get_parent().get_node_or_null("Player")
	if player == null:
		push_warning("Supply crate could not find Player.")
		return
	player.health = minf(player.health + healing_amount, player.max_health)
	player.energy = minf(player.energy + energy_amount, 100.0)
	if player.has_method("add_loot_supplies"):
		player.add_loot_supplies(1, 1, 1, 1, 0)
	picked_up = true
	print("SUPPLIES COLLECTED: ", supply_name)
	print("PLAYER HEALTH: ", player.health)
	queue_free()
