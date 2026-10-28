
extends CharacterBody3D

const SOLDIER_GEAR = preload("res://soldier_gear.gd")

@export var move_speed: float = 5.0
@export var gravity: float = 9.8
@export var shoot_range: float = 100.0
@export var max_health: float = 100.0
@export var grenade_damage: float = 60.0
@export var grenade_range: float = 5.0

var health: float = 100.0
var energy: float = 60.0
var sprinting: bool = false
var aiming: bool = false
# Limited survival inventory; loot crates can replenish these items.
var grenades: int = 3
var smoke_grenades: int = 3
var energy_drinks: int = 5
var first_aid_kits: int = 3
var medkits: int = 2
var reloading: bool = false
var shot_timer: float = 0.0
var grenade_ready: bool = true
var smoke_ready: bool = true
var using_item: bool = false
var held_weapon_root: Node3D
var muzzle_flash: MeshInstance3D
var soldier_animation_player: AnimationPlayer
var current_animation_name := ""

var weapon_names: Array[String] = ["M416", "AKM", "SCAR-L", "GROZA", "AWM", "PISTOL"]
# Standard magazine sizes; AWM uses a 5-round magazine in this prototype.
var magazine_sizes: Array[int] = [30, 30, 30, 30, 5, 12]
var damages: Array[float] = [24.0, 28.0, 23.0, 29.0, 90.0, 20.0]
var fire_delays: Array[float] = [0.10, 0.13, 0.10, 0.09, 1.05, 0.30]
var reload_times: Array[float] = [2.1, 2.4, 2.0, 2.0, 3.6, 1.5]

var weapon_index: int = 0
# Start with M416 and Pistol. Other rifles become available when picked up.
var unlocked_weapons: Array[bool] = [true, false, false, false, false, true]
var ammo_by_weapon: Array[int] = [30, 30, 30, 30, 5, 12]
var reserve_by_weapon: Array[int] = [120, 120, 120, 120, 25, 48]

var ammo: int:
	get:
		return ammo_by_weapon[weapon_index]
	set(value):
		ammo_by_weapon[weapon_index] = value

var reserve_ammo: int:
	get:
		return reserve_by_weapon[weapon_index]
	set(value):
		reserve_by_weapon[weapon_index] = value


func _ready() -> void:
	health = max_health
	energy = 60.0
	add_to_group("players")
	_update_held_weapon_visual()
	var soldier_model := get_node_or_null("character-soldier2") as Node3D
	if soldier_model != null:
		SOLDIER_GEAR.apply_to(soldier_model, false)
		soldier_animation_player = _find_animation_player(soldier_model)
		_update_soldier_animation(false)
	print("PLAYER READY")


func _physics_process(delta: float) -> void:
	shot_timer = maxf(shot_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var input_dir := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)

	var joystick = get_node_or_null("../MobileUI/MobileJoystick")
	if joystick != null and joystick.has_method("get_input_vector"):
		var joy_dir: Vector2 = joystick.get_input_vector()
		if joy_dir.length() > 0.1:
			input_dir = joy_dir

	var pivot := get_node_or_null("CameraPivot") as Node3D
	var direction := Vector3(input_dir.x, 0.0, -input_dir.y)
	if pivot != null:
		var forward := -pivot.global_transform.basis.z
		var right := pivot.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		direction = (right.normalized() * input_dir.x + forward.normalized() * -input_dir.y)
	direction = direction.normalized()

	var wants_sprint := sprinting or Input.is_key_pressed(KEY_SHIFT)
	var current_speed := move_speed
	if aiming:
		current_speed *= 0.78
	if wants_sprint and direction.length() > 0.05 and not aiming:
		if energy > 0.0:
			current_speed *= 1.55
			energy = maxf(energy - delta * 8.0, 0.0)
	else:
		energy = minf(energy + delta * 2.0, 100.0)
	if direction.length() > 0.0:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 1.5)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 1.5)
	var soldier := get_node_or_null("character-soldier2") as Node3D
	_update_soldier_animation(direction.length() > 0.05)
	if soldier != null:
		if aiming and pivot != null:
			var aim_forward := -pivot.global_transform.basis.z
			aim_forward.y = 0.0
			if aim_forward.length() > 0.01:
				soldier.rotation.y = atan2(-aim_forward.normalized().x, -aim_forward.normalized().z)
		elif direction.length() > 0.05:
			soldier.rotation.y = atan2(-direction.x, -direction.z)

	move_and_slide()


func set_sprinting(enabled: bool) -> void:
	sprinting = enabled


func set_aiming(enabled: bool) -> void:
	aiming = enabled
	if aiming:
		sprinting = false


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return

	health = maxf(health - amount, 0.0)
	print("PLAYER HEALTH: ", health)

	if health <= 0.0:
		velocity = Vector3.ZERO
		var manager = get_node_or_null("../GameManager")
		if manager != null and manager.has_method("end_game"):
			manager.end_game()


func switch_weapon() -> void:
	if reloading:
		return
	for step in range(1, weapon_names.size() + 1):
		var next_index := (weapon_index + step) % weapon_names.size()
		if unlocked_weapons[next_index]:
			weapon_index = next_index
			print("WEAPON: ", weapon_names[weapon_index])
			print("AMMO: ", ammo, " / ", reserve_ammo)
			_update_held_weapon_visual()
			return


func equip_weapon(index: int) -> bool:
	if index < 0 or index >= weapon_names.size() or reloading:
		return false
	var is_new_weapon := not unlocked_weapons[index]
	unlocked_weapons[index] = true
	if is_new_weapon:
		ammo_by_weapon[index] = magazine_sizes[index]
		reserve_by_weapon[index] = magazine_sizes[index] * 2
	else:
		reserve_by_weapon[index] += magazine_sizes[index]
	weapon_index = index
	print("WEAPON PICKED UP: ", weapon_names[index])
	print("AMMO: ", ammo, " / ", reserve_ammo)
	_update_held_weapon_visual()
	return true


func shoot() -> void:
	if health <= 0.0 or reloading or shot_timer > 0.0:
		return
	if ammo <= 0:
		print("MAGAZINE EMPTY - RELOAD")
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		print("ERROR: Camera not found!")
		return

	ammo -= 1
	shot_timer = fire_delays[weapon_index]
	_show_muzzle_flash()

	var start := camera.global_position
	var end := start - camera.global_transform.basis.z * shoot_range
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [self]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var tracer_end: Vector3 = end
	if not result.is_empty():
		tracer_end = result.get("position", end)
	_show_bullet_tracer(start, tracer_end)
	if result.is_empty():
		print("SHOT FIRED - NO HIT")
		return

	var target = result.get("collider")
	if target != null and target.has_method("take_damage"):
		target.take_damage(damages[weapon_index])
		_show_hit_marker()
		print("HIT ENEMY: ", target.name)


func reload() -> void:
	if health <= 0.0 or reloading:
		return
	if ammo >= magazine_sizes[weapon_index] or reserve_ammo <= 0:
		print("RELOAD NOT NEEDED")
		return

	reloading = true
	await get_tree().create_timer(reload_times[weapon_index]).timeout

	if not is_inside_tree():
		return

	var needed: int = magazine_sizes[weapon_index] - ammo
	var loaded: int = mini(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	reloading = false
	print("RELOAD COMPLETE: ", ammo, " / ", reserve_ammo)


func pickup_ammo(amount: int, weapon_type: int = -1) -> void:
	var index := weapon_index
	if weapon_type >= 0 and weapon_type < reserve_by_weapon.size():
		index = weapon_type

	reserve_by_weapon[index] += amount
	print("AMMO PICKED UP: ", weapon_names[index])


func throw_grenade() -> void:
	if health <= 0.0 or not grenade_ready:
		print("GRENADE NOT READY")
		return
	if grenades <= 0:
		print("NO GRENADES LEFT")
		return

	grenades -= 1
	grenade_ready = false
	var explosion_position := global_position - global_transform.basis.z * 5.0
	print("GRENADE EXPLODED")

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue

		if enemy.global_position.distance_to(explosion_position) <= grenade_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(grenade_damage)

	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		grenade_ready = true


func throw_smoke() -> void:
	if health <= 0.0 or not smoke_ready:
		print("SMOKE NOT READY")
		return
	if smoke_grenades <= 0:
		print("NO SMOKE GRENADES LEFT")
		return

	smoke_grenades -= 1
	smoke_ready = false

	var cloud := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.5
	sphere.height = 5.0
	cloud.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.7, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud.material_override = material

	get_tree().current_scene.add_child(cloud)
	cloud.global_position = global_position - global_transform.basis.z * 4.0
	cloud.global_position.y += 2.0

	print("SMOKE CLOUD CREATED")

	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(cloud):
		cloud.queue_free()

	if is_inside_tree():
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree():
			smoke_ready = true


func use_drink() -> void:
	if health <= 0.0 or using_item or energy >= 100.0:
		print("DRINK NOT AVAILABLE")
		return
	if energy_drinks <= 0:
		print("NO ENERGY DRINKS LEFT")
		return

	energy_drinks -= 1
	using_item = true
	print("USING ENERGY DRINK")
	await get_tree().create_timer(2.0).timeout

	if not is_inside_tree():
		return

	energy = minf(energy + 40.0, 100.0)
	using_item = false
	print("ENERGY: ", energy)


func use_first_aid() -> void:
	if health <= 0.0 or using_item or health >= 75.0:
		print("FIRST AID NOT NEEDED")
		return
	if first_aid_kits <= 0:
		print("NO FIRST AID KITS LEFT")
		return

	first_aid_kits -= 1
	using_item = true
	print("USING FIRST AID")
	await get_tree().create_timer(3.0).timeout

	if not is_inside_tree():
		return

	health = minf(health + 50.0, 75.0)
	using_item = false
	print("PLAYER HEALTH: ", health)


func use_medkit() -> void:
	if health <= 0.0 or using_item or health >= max_health:
		print("MED KIT NOT NEEDED")
		return
	if medkits <= 0:
		print("NO MED KITS LEFT")
		return

	medkits -= 1
	using_item = true
	print("USING MED KIT")
	await get_tree().create_timer(5.0).timeout

	if not is_inside_tree():
		return

	health = max_health
	using_item = false
	print("MED KIT COMPLETE: ", health)


func add_loot_supplies(grenade_amount: int = 1, smoke_amount: int = 1, drink_amount: int = 1, first_aid_amount: int = 1, medkit_amount: int = 0) -> void:
	grenades = mini(grenades + grenade_amount, 5)
	smoke_grenades = mini(smoke_grenades + smoke_amount, 5)
	energy_drinks = mini(energy_drinks + drink_amount, 8)
	first_aid_kits = mini(first_aid_kits + first_aid_amount, 5)
	medkits = mini(medkits + medkit_amount, 3)
	print("LOOT INVENTORY UPDATED")


func _update_held_weapon_visual() -> void:
	# A lightweight procedural weapon is attached to the soldier model so the
	# selected weapon is visible in third-person. Replace with licensed rigged
	# weapon assets later for hand-bone attachment and animations.
	var soldier := get_node_or_null("character-soldier2") as Node3D
	if soldier == null:
		return
	var old := soldier.get_node_or_null("HeldWeapon")
	if old != null:
		old.queue_free()
	held_weapon_root = Node3D.new()
	held_weapon_root.name = "HeldWeapon"
	held_weapon_root.position = Vector3(0.22, 0.30, -0.28)
	held_weapon_root.rotation_degrees = Vector3(0.0, 0.0, -7.0)
	soldier.add_child(held_weapon_root)
	var is_pistol := weapon_names[weapon_index] == "PISTOL"
	var is_awm := weapon_names[weapon_index] == "AWM"
	var body_mat := _weapon_material(Color(0.10, 0.13, 0.12))
	var metal_mat := _weapon_material(Color(0.30, 0.32, 0.30))
	var accent_mat := _weapon_material(Color(0.35, 0.24, 0.13))
	var scale_factor := 0.62 if is_pistol else (1.16 if is_awm else 1.0)
	_add_weapon_part("Receiver", Vector3(0.12, 0.11, 0.42) * scale_factor, Vector3(0.0, 0.0, 0.0), body_mat)
	_add_weapon_part("Barrel", Vector3(0.045, 0.045, (0.48 if is_awm else 0.30) * scale_factor), Vector3(0.0, 0.01, -0.34 * scale_factor), metal_mat)
	_add_weapon_part("Stock", Vector3(0.10, 0.09, 0.23) * scale_factor, Vector3(0.0, 0.0, 0.28 * scale_factor), accent_mat)
	_add_weapon_part("Magazine", Vector3(0.075, 0.17, 0.10) * scale_factor, Vector3(0.0, -0.12 * scale_factor, 0.02), metal_mat)
	_add_weapon_part("Grip", Vector3(0.06, 0.13, 0.07) * scale_factor, Vector3(0.0, -0.11 * scale_factor, 0.14 * scale_factor), body_mat)
	if not is_pistol:
		_add_weapon_part("Sight", Vector3(0.055, 0.045, 0.08) * scale_factor, Vector3(0.0, 0.075 * scale_factor, -0.05), accent_mat)
	if is_awm:
		_add_weapon_part("Scope", Vector3(0.07, 0.075, 0.22), Vector3(0.0, 0.10, -0.04), accent_mat)
	if is_pistol:
		var pistol_slide := _add_weapon_part("PistolSlide", Vector3(0.075, 0.06, 0.24), Vector3(0.0, 0.04, -0.10), metal_mat)
		if pistol_slide != null:
			pistol_slide.rotation_degrees.x = 0.0


func _add_weapon_part(part_name: String, dimensions: Vector3, local_pos: Vector3, material: Material) -> MeshInstance3D:
	if held_weapon_root == null:
		return null
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = material
	part.position = local_pos
	held_weapon_root.add_child(part)
	return part


func _weapon_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.28
	material.roughness = 0.62
	return material


func _show_muzzle_flash() -> void:
	if held_weapon_root == null:
		return
	if is_instance_valid(muzzle_flash):
		muzzle_flash.queue_free()
	var flash := MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.07
	flash_mesh.height = 0.14
	flash.mesh = flash_mesh
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.55, 0.12)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.32, 0.04)
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = flash_mat
	flash.position = Vector3(0.0, 0.015, -0.65 if weapon_names[weapon_index] == "AWM" else -0.48)
	held_weapon_root.add_child(flash)
	muzzle_flash = flash
	await get_tree().create_timer(0.07).timeout
	if is_instance_valid(flash):
		flash.queue_free()


func _show_bullet_tracer(from: Vector3, to: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	tracer.name = "BulletTracer"
	var line_mesh := ImmediateMesh.new()
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(1.0, 0.82, 0.35, 0.85)
	line_material.emission_enabled = true
	line_material.emission = Color(1.0, 0.55, 0.12)
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	line_mesh.surface_add_vertex(from)
	line_mesh.surface_add_vertex(to)
	line_mesh.surface_end()
	tracer.mesh = line_mesh
	get_tree().current_scene.add_child(tracer)
	await get_tree().create_timer(0.055).timeout
	if is_instance_valid(tracer):
		tracer.queue_free()


func _show_hit_marker() -> void:
	var crosshair := get_node_or_null("../MobileUI/Crosshair") as Label
	if crosshair == null:
		return
	crosshair.text = "×"
	crosshair.add_theme_color_override("font_color", Color(1.0, 0.22, 0.16))
	await get_tree().create_timer(0.16).timeout
	if is_instance_valid(crosshair):
		crosshair.text = "+"
		crosshair.add_theme_color_override("font_color", Color.WHITE)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _update_soldier_animation(moving: bool) -> void:
	if not is_instance_valid(soldier_animation_player):
		return
	var clips := soldier_animation_player.get_animation_list()
	var preferred: Array[String] = ["run", "walk", "move"] if moving else ["idle", "stand"]
	for wanted in preferred:
		for clip in clips:
			if String(clip).to_lower().contains(wanted):
				if current_animation_name != String(clip):
					soldier_animation_player.play(clip)
					current_animation_name = String(clip)
				return
