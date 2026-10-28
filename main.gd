extends Node3D
## Frontline world setup and lightweight battle-royale events.
## Uses the existing scene's Player, Enemy, SafeZone and MobileUI nodes; does not spawn duplicates.

const WORLD_SIZE := 260.0
const LOOT_SCRIPT := preload("res://loot_crate.gd")
const GUN_PICKUP_SCRIPT := preload("res://gun_pickup.gd")

var player: CharacterBody3D
var camera: Camera3D
var camera_pivot: Node3D
var red_zone_timer := 24.0
var airdrop_timer := 45.0
var event_rng := RandomNumberGenerator.new()
var event_label: Label
var aim_feedback_timer := 0.0
var _fl_network_panel: PanelContainer
var _fl_network_status: Label
var _fl_address_input: LineEdit
var _fl_port_input: LineEdit
var _fl_network_tick := 0.0

func _ready() -> void:
	event_rng.randomize()
	player = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_error("Frontline: Main scene has no Player node.")
		return
	camera_pivot = player.get_node_or_null("CameraPivot") as Node3D
	camera = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera != null:
		camera.current = true
	if player.global_position.y < 0.5:
		player.global_position = Vector3(0.0, 0.95, 8.0)
	_setup_environment()
	_setup_ground()
	_rebuild_buildings()
	_add_world_details()
	_add_battlefield_map()
	_spawn_weapon_pickups()
	_fix_hud_layout()
	apply_graphics_preset(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fl_setup_multiplayer_lobby()
	var user_args := OS.get_cmdline_user_args()
	if "--frontline-server" in user_args:
		var configured_port := OS.get_environment("FRONTLINE_PORT")
		if not configured_port.is_empty() and is_instance_valid(_fl_port_input):
			_fl_port_input.text = configured_port
		_fl_host_match()
			print("FRONTLINE_SERVER_READY port=", _fl_read_port(), " protocol=UDP")
	print("FRONTLINE WORLD READY")

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_fl_network_tick += delta
	if _fl_network_tick >= 0.05:
		_fl_network_tick = 0.0
		if multiplayer.has_multiplayer_peer() and (multiplayer.is_server() or multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED):
			var local_id := multiplayer.get_unique_id()
			if player.get_multiplayer_authority() == local_id:
				rpc("_fl_receive_player_state", local_id, player.global_position, player.rotation.y)
	red_zone_timer -= delta
	airdrop_timer -= delta
	if red_zone_timer <= 0.0:
		red_zone_timer = event_rng.randf_range(28.0, 40.0)
		var angle := event_rng.randf_range(0.0, TAU)
		var distance := event_rng.randf_range(10.0, 28.0)
		var strike_pos := player.global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		strike_pos.x = clampf(strike_pos.x, -82.0, 82.0)
		strike_pos.z = clampf(strike_pos.z, -82.0, 82.0)
		_red_zone_strike(strike_pos)
	if airdrop_timer <= 0.0:
		airdrop_timer = 75.0
		_spawn_airdrop()
	if is_instance_valid(event_label):
		event_label.text = "RED ZONE IN %ds   |   AIRDROP IN %ds" % [int(ceil(red_zone_timer)), int(ceil(airdrop_timer))]
	aim_feedback_timer -= delta
	if aim_feedback_timer <= 0.0:
		aim_feedback_timer = 0.10
		_update_aim_feedback()

func _update_aim_feedback() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var ui := get_node_or_null("MobileUI") as CanvasLayer
	if ui == null:
		return
	var crosshair := ui.get_node_or_null("Crosshair") as Label
	if crosshair == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var ray_origin := camera.project_ray_origin(center)
	var ray_end := ray_origin + camera.project_ray_normal(center) * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var enemy_target := false
	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider is Node and collider.is_in_group("enemies"):
			enemy_target = true
		elif collider is Node and collider.get_parent() != null and collider.get_parent().is_in_group("enemies"):
			enemy_target = true
	crosshair.add_theme_color_override("font_color", Color(1.0, 0.22, 0.18) if enemy_target else Color(1.0, 1.0, 1.0, 0.95))
	crosshair.text = "✣" if enemy_target else "+"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif is_instance_valid(player) and player.has_method("shoot"):
				player.shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT and is_instance_valid(player):
			var spring := player.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
			if spring != null:
				spring.spring_length = 2.4 if spring.spring_length > 3.0 else 5.0
			if camera != null:
				camera.fov = 55.0 if camera.fov > 60.0 else 75.0


func _spawn_weapon_pickups() -> void:
	# Lightweight procedural weapon models placed near buildings for looting.
	# Indexes match Player.weapon_names: M416, AKM, SCAR-L, GROZA, AWM, PISTOL.
	var pickup_data: Array[Dictionary] = [
		{"name": "AKM", "index": 1, "pos": Vector3(6.0, 0.0, 5.0)},
		{"name": "SCAR-L", "index": 2, "pos": Vector3(18.0, 0.0, -16.0)},
		{"name": "GROZA", "index": 3, "pos": Vector3(-22.0, 0.0, -23.0)},
		{"name": "AWM", "index": 4, "pos": Vector3(28.0, 0.0, 12.0)}
	]
	for data in pickup_data:
		var pickup := GUN_PICKUP_SCRIPT.new() as Area3D
		pickup.name = "GunPickup_" + str(data["name"])
		pickup.set("weapon_name", str(data["name"]))
		pickup.set("weapon_index", int(data["index"]))
		add_child(pickup)
		pickup.global_position = data["pos"]

func _setup_environment() -> void:
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		add_child(world_env)
	if world_env.environment == null:
		world_env.environment = Environment.new()
	var env := world_env.environment
	env.background_mode = Environment.BG_SKY
	if env.sky == null:
		env.sky = Sky.new()
	if env.sky.sky_material == null:
		env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.64, 0.72)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "DirectionalLight3D"
		add_child(sun)
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0

func _setup_ground() -> void:
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		ground = MeshInstance3D.new()
		ground.name = "Ground"
		add_child(ground)
	var plane := PlaneMesh.new()
	plane.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	ground.mesh = plane
	ground.position = Vector3.ZERO
	var grass := _material(Color(0.30, 0.40, 0.24), 0.98)	
	var grass_texture := load("res://assets/Textures/grass_ground.png") as Texture2D
	if grass_texture != null:
		grass.albedo_texture = grass_texture
	grass.uv1_scale = Vector3(28.0, 28.0, 28.0)
	ground.material_override = grass
	if get_node_or_null("GroundCollision") == null:
		var body := StaticBody3D.new()
		body.name = "GroundCollision"
		body.position.y = -0.25
		add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(WORLD_SIZE, 0.5, WORLD_SIZE)
		collision.shape = shape
		body.add_child(collision)

func _rebuild_buildings() -> void:
	for old_name in ["Building1", "Building2", "Building3", "CoverWall1", "CoverWall2"]:
		var old_node := get_node_or_null(old_name)
		if old_node != null:
			old_node.queue_free()
	var wall := _material(Color(0.52, 0.49, 0.42))
	var trim := _material(Color(0.28, 0.29, 0.27))
	var roof := _material(Color(0.20, 0.22, 0.21))
	var positions: Array[Vector3] = [
		Vector3(18, 0, -18), Vector3(-22, 0, -25), Vector3(28, 0, 12),
		Vector3(-30, 0, 15), Vector3(8, 0, -42), Vector3(42, 0, -35),
		Vector3(-45, 0, -8), Vector3(-12, 0, 35), Vector3(58, 0, 28),
		Vector3(-58, 0, -42), Vector3(50, 0, -62), Vector3(-42, 0, 58)
	]
	for i in positions.size():
		_make_open_building("House_%02d" % (i + 1), positions[i], 8.0 if i % 2 == 0 else 7.0, 4.2 if i % 3 == 0 else 3.7, 7.0, wall, trim, roof)
	# A few low cover walls near the player spawn.
	_add_solid(self, "Cover_A", Vector3(-3.0, 1.0, 2.0), Vector3(4.5, 2.0, 0.45), trim)
	_add_solid(self, "Cover_B", Vector3(5.0, 1.0, -1.0), Vector3(0.45, 2.0, 4.0), trim)

func _make_open_building(building_name: String, pos: Vector3, width: float, height: float, depth: float, wall: Material, trim: Material, roof: Material) -> void:
	var house := Node3D.new()
	house.name = building_name
	house.position = pos
	add_child(house)
	_add_solid(house, "Floor", Vector3(0, 0.12, 0), Vector3(width, 0.24, depth), trim)
	_add_solid(house, "BackWall", Vector3(0, height / 2.0, -depth / 2.0), Vector3(width, height, 0.24), wall)
	_add_solid(house, "LeftWall", Vector3(-width / 2.0, height / 2.0, 0), Vector3(0.24, height, depth), wall)
	_add_solid(house, "RightWall", Vector3(width / 2.0, height / 2.0, 0), Vector3(0.24, height, depth), wall)
	# Front wall deliberately has a central door gap so the player can enter.
	var door_width := 1.6
	var segment_width := (width - door_width) / 2.0
	_add_solid(house, "FrontLeft", Vector3(-(door_width + segment_width) / 2.0, height / 2.0, depth / 2.0), Vector3(segment_width, height, 0.24), wall)
	_add_solid(house, "FrontRight", Vector3((door_width + segment_width) / 2.0, height / 2.0, depth / 2.0), Vector3(segment_width, height, 0.24), wall)
	_add_solid(house, "DoorLintel", Vector3(0, height - 0.35, depth / 2.0), Vector3(door_width, 0.7, 0.24), wall)
	_add_solid(house, "Roof", Vector3(0, height + 0.18, 0), Vector3(width + 0.35, 0.36, depth + 0.35), roof)
	# Simple contrasting window panels are visual only.
	_add_visual_box(house, "Window_Back", Vector3(0, height * 0.58, -depth / 2.0 - 0.13), Vector3(1.25, 0.75, 0.035), _material(Color(0.10, 0.17, 0.20), 0.3))

func _add_solid(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	parent.add_child(body)
	var mesh_node := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_node.mesh = box_mesh
	mesh_node.material_override = mat
	body.add_child(mesh_node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _add_visual_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = mat
	node.position = pos
	parent.add_child(node)

func _add_world_details() -> void:
	var trunk_mat := _material(Color(0.26, 0.17, 0.10))
	var leaf_mats: Array[Material] = [
		_material(Color(0.13, 0.29, 0.13)),
		_material(Color(0.17, 0.34, 0.16)),
		_material(Color(0.22, 0.32, 0.13))
	]
	var rock_mat := _material(Color(0.34, 0.35, 0.31))
	# Main road with pale broken centre markings.
	var road_material := _material(Color(0.22, 0.24, 0.23), 0.96)
	var road_texture := load("res://assets/Textures/road_asphalt.png") as Texture2D
	if road_texture != null:
		road_material.albedo_texture = road_texture
	road_material.uv1_scale = Vector3(1.0, 1.0, 1.0)
	_add_visual_box(self, "MainRoad", Vector3(0, 0.025, -12), Vector3(7.0, 0.05, 72.0), road_material)
	for z in range(-45, 24, 7):
		_add_visual_box(self, "RoadMark", Vector3(0, 0.058, float(z)), Vector3(0.14, 0.02, 2.8), _material(Color(0.78, 0.73, 0.52)))
	# Tree clusters around the playable area; keep the spawn and road clear.
	for i in range(64):
		var angle := float(i) * 2.399963
		var radius := 24.0 + float((i * 17) % 35)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if absf(x) < 8.0 or (absf(x) < 11.0 and absf(z + 12.0) < 38.0):
			continue
		var tree := Node3D.new()
		tree.name = "Tree_%02d" % i
		tree.add_to_group("world_detail")
		tree.position = Vector3(x, 0.0, z)
		add_child(tree)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.16
		trunk_mesh.bottom_radius = 0.27
		trunk_mesh.height = 1.8
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_mat
		trunk.position.y = 0.9
		tree.add_child(trunk)
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 1.25
		crown_mesh.height = 2.5
		crown.mesh = crown_mesh
		crown.material_override = leaf_mats[i % leaf_mats.size()]
		crown.position.y = 2.25
		tree.add_child(crown)
	for i in range(24):
		var x := sin(float(i) * 13.7) * 78.0
		var z := cos(float(i) * 8.3) * 78.0
		var hill := MeshInstance3D.new()
		hill.name = "DistantHill_%02d" % i
		hill.add_to_group("world_detail")
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		hill.mesh = sphere
		hill.material_override = _material(Color(0.25, 0.32, 0.26))
		hill.scale = Vector3(12.0 + float(i % 4) * 3.0, 4.0 + float(i % 3), 10.0 + float(i % 5) * 2.0)
		hill.position = Vector3(x, -1.4, z)
		add_child(hill)
	for i in range(40):
		var angle := float(i) * 2.17
		var radius := 12.0 + float((i * 11) % 68)
		var rock := MeshInstance3D.new()
		rock.name = "Rock_%02d" % i
		rock.add_to_group("world_detail")
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.7
		rock_mesh.height = 1.0
		rock.mesh = rock_mesh
		rock.material_override = rock_mat
		rock.scale = Vector3(1.2 + float(i % 3) * 0.3, 0.6 + float(i % 2) * 0.2, 1.0)
		rock.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		add_child(rock)

func _red_zone_strike(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "RedZoneWarning"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 5.0
	cylinder.bottom_radius = 5.0
	cylinder.height = 0.035
	marker.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.08, 0.04, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat
	marker.position = Vector3(pos.x, 0.08, pos.z)
	add_child(marker)
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	if is_instance_valid(player) and Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length() < 5.0:
		player.take_damage(35.0)
	var blast := MeshInstance3D.new()
	var blast_mesh := SphereMesh.new()
	blast_mesh.radius = 2.0
	blast_mesh.height = 4.0
	blast.mesh = blast_mesh
	blast.material_override = _material(Color(1.0, 0.26, 0.04, 0.8))
	blast.position = Vector3(pos.x, 1.0, pos.z)
	add_child(blast)
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(marker):
		marker.queue_free()
	if is_instance_valid(blast):
		blast.queue_free()

func _spawn_airdrop() -> void:
	if not is_instance_valid(player):
		return
	var drop = LOOT_SCRIPT.new() as Node3D
	drop.name = "AirdropSupply"
	drop.set("supply_name", "AIRDROP SUPPLIES")
	drop.set("healing_amount", 35.0)
	drop.set("energy_amount", 40.0)
	add_child(drop)
	var angle := event_rng.randf_range(0.0, TAU)
	var radius := event_rng.randf_range(12.0, 30.0)
	drop.global_position = player.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	# Visible red smoke beacon so the airdrop is easy to find from a distance.
	var smoke_beacon := MeshInstance3D.new()
	smoke_beacon.name = "AirdropRedSmoke"
	var smoke_mesh := CylinderMesh.new()
	smoke_mesh.top_radius = 0.45
	smoke_mesh.bottom_radius = 1.15
	smoke_mesh.height = 7.0
	smoke_beacon.mesh = smoke_mesh
	var smoke_material := StandardMaterial3D.new()
	smoke_material.albedo_color = Color(0.92, 0.08, 0.035, 0.36)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	smoke_beacon.material_override = smoke_material
	smoke_beacon.position = Vector3(0.0, 4.1, 0.0)
	drop.add_child(smoke_beacon)
	print("AIRDROP LANDED: SUPPLIES")

func _fix_hud_layout() -> void:
	var ui := get_node_or_null("MobileUI") as CanvasLayer
	if ui == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var w := viewport_size.x
	var h := viewport_size.y
	var joystick := ui.get_node_or_null("MobileJoystick") as Control
	if joystick != null:
		joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hud_positions := {
		"PlayerHealthBar": Vector2(20, 18),
		"EnemyHealthBar": Vector2(20, 48),
		"KillLabel": Vector2(20, 78),
		"AmmoLabel": Vector2(20, 108),
		"WeaponLabel": Vector2(20, 138),
		"InventoryLabel": Vector2(20, 174)
	}
	for node_name in hud_positions:
		var control := ui.get_node_or_null(node_name) as Control
		if control == null:
			continue
		control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		control.position = hud_positions[node_name]
		if control is ProgressBar:
			control.size = Vector2(230, 22)
		else:
			control.size = Vector2(300, 32 if node_name != "InventoryLabel" else 62)
			control.add_theme_font_size_override("font_size", 19 if node_name != "InventoryLabel" else 15)
	var minimap := ui.get_node_or_null("MiniMap") as Control
	if minimap != null:
		minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		minimap.position = Vector2(-174, 14)
		minimap.size = Vector2(158, 158)
	# A small event strip keeps the upcoming red-zone and airdrop timers visible.
	event_label = ui.get_node_or_null("EventLabel") as Label
	if event_label == null:
		event_label = Label.new()
		event_label.name = "EventLabel"
		ui.add_child(event_label)
	event_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	event_label.position = Vector2(maxf(320.0, w * 0.5 - 210.0), 14.0)
	event_label.size = Vector2(420.0, 30.0)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.add_theme_font_size_override("font_size", 18)
	event_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	# Large thumb-friendly controls in two columns.
	var right_x := w - 164.0
	var mid_x := w - 322.0
	var button_positions := {
		"MedKitButton": Vector2(right_x, h * 0.30),
		"FirstAidButton": Vector2(mid_x, h * 0.30),
		"DrinkButton": Vector2(right_x, h * 0.39),
		"SmokeButton": Vector2(mid_x, h * 0.39),
		"GrenadeButton": Vector2(right_x, h * 0.48),
		"PickupButton": Vector2(mid_x, h * 0.48),
		"ReloadButton": Vector2(right_x, h * 0.57),
		"WeaponSwitchButton": Vector2(mid_x, h * 0.57),
		"AimButton": Vector2(w - 322.0, h - 90.0),
		"FireButton": Vector2(w - 166.0, h - 100.0)
	}
	for button_name in button_positions:
		var button := ui.get_node_or_null(button_name) as Button
		if button == null:
			continue
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		button.position = button_positions[button_name]
		button.size = Vector2(146, 56)
		button.custom_minimum_size = Vector2(146, 56)
		button.add_theme_font_size_override("font_size", 18)
		button.focus_mode = Control.FOCUS_NONE
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.055, 0.075, 0.085, 0.86)
		normal.border_color = Color(0.72, 0.78, 0.70, 0.95)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(12)
		button.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.16, 0.23, 0.18, 0.96)
		button.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.38, 0.26, 0.08, 0.98)
		button.add_theme_stylebox_override("pressed", pressed)
	var fire := ui.get_node_or_null("FireButton") as Button
	if fire != null:
		fire.size = Vector2(158, 82)
		fire.position = Vector2(w - 166.0, h - 98.0)
		fire.add_theme_font_size_override("font_size", 25)
	var aim := ui.get_node_or_null("AimButton") as Button
	if aim != null:
		aim.size = Vector2(146, 68)
		aim.position = Vector2(w - 322.0, h - 90.0)
		aim.add_theme_font_size_override("font_size", 22)
	var crosshair := ui.get_node_or_null("Crosshair") as Label
	if crosshair != null:
		crosshair.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		crosshair.position = Vector2(w * 0.5 - 20.0, h * 0.5 - 20.0)
		crosshair.size = Vector2(40, 40)
		crosshair.add_theme_font_size_override("font_size", 32)
	# Hold-to-sprint button for touch screens; Shift also works on PC.
	var sprint := ui.get_node_or_null("SprintButton") as Button
	if sprint == null:
		sprint = Button.new()
		sprint.name = "SprintButton"
		sprint.text = "SPRINT"
		ui.add_child(sprint)
		sprint.button_down.connect(_start_sprint)
		sprint.button_up.connect(_stop_sprint)
	sprint.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	sprint.position = Vector2(226.0, h - 104.0)
	sprint.size = Vector2(122, 58)
	sprint.add_theme_font_size_override("font_size", 18)
	sprint.focus_mode = Control.FOCUS_NONE
	var sprint_style := StyleBoxFlat.new()
	sprint_style.bg_color = Color(0.055, 0.075, 0.085, 0.86)
	sprint_style.border_color = Color(0.72, 0.78, 0.70, 0.95)
	sprint_style.set_border_width_all(2)
	sprint_style.set_corner_radius_all(12)
	sprint.add_theme_stylebox_override("normal", sprint_style)

func _start_sprint() -> void:
	if is_instance_valid(player) and player.has_method("set_sprinting"):
		player.set_sprinting(true)

func _stop_sprint() -> void:
	if is_instance_valid(player) and player.has_method("set_sprinting"):
		player.set_sprinting(false)

func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func apply_graphics_preset(high_quality: bool) -> void:
	# Low preset keeps the map readable while reducing mobile GPU load.
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = high_quality
		sun.directional_shadow_max_distance = 90.0 if high_quality else 35.0
	for detail in get_tree().get_nodes_in_group("world_detail"):
		if not is_instance_valid(detail):
			continue
		if String(detail.name).begins_with("DistantHill_") or String(detail.name).begins_with("Rock_"):
			detail.visible = high_quality
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		env_node.environment.ambient_light_energy = 0.85 if high_quality else 1.0
	print("GRAPHICS PRESET: ", "HIGH" if high_quality else "LOW")


# Additional low-poly battle-royale map dressing: side roads, an outpost,
# fenced compounds, sandbags and roadside utility structures.
func _add_battlefield_map() -> void:
	var asphalt := _material(Color(0.25, 0.26, 0.24), 0.98)
	var dirt := _material(Color(0.39, 0.34, 0.24), 1.0)
	var concrete := _material(Color(0.43, 0.43, 0.39), 0.95)
	var metal := _material(Color(0.19, 0.25, 0.25), 0.8)
	var sandbag := _material(Color(0.55, 0.49, 0.34), 1.0)
	var dark := _material(Color(0.12, 0.15, 0.15), 0.9)

	# Branching roads connect the village with the outer combat area.
	_add_visual_box(self, "Road_East", Vector3(31.0, 0.018, -12.0), Vector3(70.0, 0.04, 5.0), asphalt)
	_add_visual_box(self, "Road_South", Vector3(-1.0, 0.02, 28.0), Vector3(5.0, 0.04, 58.0), dirt)
	_add_visual_box(self, "Road_West", Vector3(-35.0, 0.02, 19.0), Vector3(48.0, 0.04, 4.0), dirt)
	for x in range(4, 68, 8):
		_add_visual_box(self, "EastRoadMark_%d" % x, Vector3(float(x), 0.05, -12.0), Vector3(3.0, 0.015, 0.12), _material(Color(0.78, 0.73, 0.56)))

	# Small military checkpoint in the western outskirts.
	var outpost := Node3D.new()
	outpost.name = "MilitaryOutpost"
	outpost.position = Vector3(-72.0, 0.0, 12.0)
	add_child(outpost)
	_add_solid(outpost, "CheckpointFloor", Vector3(0.0, 0.08, 0.0), Vector3(19.0, 0.16, 15.0), concrete)
	_add_solid(outpost, "GuardRoom", Vector3(-4.5, 1.7, -2.0), Vector3(5.5, 3.4, 5.0), metal)
	_add_solid(outpost, "GuardRoof", Vector3(-4.5, 3.55, -2.0), Vector3(6.0, 0.3, 5.5), dark)
	_add_solid(outpost, "Container_A", Vector3(5.0, 1.25, -3.0), Vector3(6.0, 2.5, 2.5), _material(Color(0.38, 0.18, 0.13)))
	_add_solid(outpost, "Container_B", Vector3(5.0, 1.25, 1.0), Vector3(6.0, 2.5, 2.5), _material(Color(0.18, 0.30, 0.24)))
	_add_solid(outpost, "SandbagLine_A", Vector3(0.0, 0.48, 5.5), Vector3(6.0, 0.96, 0.8), sandbag)
	_add_solid(outpost, "SandbagLine_B", Vector3(8.0, 0.48, 3.0), Vector3(0.8, 0.96, 4.0), sandbag)

	# Utility poles beside the roads.
	for i in range(7):
		var pole := Node3D.new()
		pole.name = "UtilityPole_%02d" % i
		pole.position = Vector3(-24.0 + float(i) * 14.0, 0.0, -18.0)
		add_child(pole)
		_add_visual_box(pole, "Pole", Vector3(0.0, 3.0, 0.0), Vector3(0.18, 6.0, 0.18), dark)
		_add_visual_box(pole, "CrossArm", Vector3(0.0, 5.2, 0.0), Vector3(2.0, 0.14, 0.14), dark)

	# Low perimeter walls around a village compound.
	var wall_mat := _material(Color(0.38, 0.39, 0.34), 0.98)
	for i in range(5):
		var px := -49.0 + float(i) * 5.0
		_add_solid(self, "VillageWall_South_%02d" % i, Vector3(px, 0.55, 45.0), Vector3(4.6, 1.1, 0.32), wall_mat)
	for i in range(4):
		var pz := 28.0 + float(i) * 5.0
		_add_solid(self, "VillageWall_West_%02d" % i, Vector3(-51.5, 0.55, pz), Vector3(0.32, 1.1, 4.6), wall_mat)

	# A shallow water strip beyond the southern road (visual only).
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.10, 0.28, 0.32, 0.82)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.18
	_add_visual_box(self, "ShallowWater", Vector3(24.0, -0.08, 78.0), Vector3(58.0, 0.08, 8.0), water_mat)


# Basic ENet multiplayer lobby. The host must be reachable by other devices.
func _fl_setup_multiplayer_lobby() -> void:
	multiplayer.peer_connected.connect(_fl_on_peer_connected)
	multiplayer.peer_disconnected.connect(_fl_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_fl_on_connected_to_server)
	multiplayer.connection_failed.connect(_fl_on_connection_failed)
	multiplayer.server_disconnected.connect(_fl_on_server_disconnected)
	var layer := get_node_or_null("MobileUI") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "MobileUI"
		add_child(layer)
	_fl_network_panel = PanelContainer.new()
	_fl_network_panel.name = "OnlineLobby"
	_fl_network_panel.position = Vector2(18, 235)
	_fl_network_panel.custom_minimum_size = Vector2(310, 0)
	layer.add_child(_fl_network_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_fl_network_panel.add_child(column)
	var heading := Label.new()
	heading.text = "FRONTLINE ONLINE"
	column.add_child(heading)
	_fl_address_input = LineEdit.new()
	_fl_address_input.placeholder_text = "Host IP (e.g. 192.168.1.5)"
	_fl_address_input.text = ""
	column.add_child(_fl_address_input)
	_fl_port_input = LineEdit.new()
	_fl_port_input.placeholder_text = "Port"
	_fl_port_input.text = "7777"
	_fl_port_input.max_length = 5
	_fl_port_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	column.add_child(_fl_port_input)
	var host_button := Button.new()
	host_button.text = "HOST MATCH (LAN)"
	host_button.pressed.connect(_fl_host_match)
	column.add_child(host_button)
	var join_button := Button.new()
	join_button.text = "JOIN MATCH"
	join_button.pressed.connect(_fl_join_match)
	column.add_child(join_button)
	var disconnect_button := Button.new()
	disconnect_button.text = "DISCONNECT"
	disconnect_button.pressed.connect(_fl_disconnect_match)
	column.add_child(disconnect_button)
	_fl_network_status = Label.new()
	_fl_network_status.text = "Offline practice. Host or join to sync players."
	_fl_network_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_fl_network_status)

func _fl_read_port() -> int:
	var port_value := int(_fl_port_input.text.strip_edges())
	if port_value < 1 or port_value > 65535:
		return 7777
	return port_value

func _fl_host_match() -> void:
	_fl_disconnect_match(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(_fl_read_port(), 16)
	if err != OK:
		_fl_set_network_status("Host failed (error %d). Check the port." % err)
		return
	multiplayer.multiplayer_peer = peer
	player.set_multiplayer_authority(multiplayer.get_unique_id())
	_fl_set_network_status("Hosting on port %d. Same Wi-Fi works; internet needs a reachable server/port." % _fl_read_port())

func _fl_join_match() -> void:
	var address := _fl_address_input.text.strip_edges()
	if address.is_empty():
		_fl_set_network_status("Enter the host's IP address first.")
		return
	_fl_disconnect_match(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, _fl_read_port())
	if err != OK:
		_fl_set_network_status("Could not start connection (error %d)." % err)
		return
	multiplayer.multiplayer_peer = peer
	_fl_set_network_status("Connecting to %s:%d..." % [address, _fl_read_port()])

func _fl_disconnect_match(update_status: bool = true) -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	for child in get_children():
		if child.name.begins_with("RemotePlayer_"):
			child.queue_free()
	if is_instance_valid(player):
		player.set_multiplayer_authority(1)
	if update_status:
		_fl_set_network_status("Disconnected. Offline practice is ready.")

func _fl_set_network_status(message: String) -> void:
	if is_instance_valid(_fl_network_status):
		_fl_network_status.text = message

func _fl_on_connected_to_server() -> void:
	player.set_multiplayer_authority(multiplayer.get_unique_id())
	_fl_set_network_status("Connected to host. Player sync active.")

func _fl_on_connection_failed() -> void:
	_fl_set_network_status("Connection failed. Check IP, port, Wi-Fi and host availability.")
	_fl_disconnect_match(false)

func _fl_on_server_disconnected() -> void:
	_fl_set_network_status("Host disconnected.")
	_fl_disconnect_match(false)

func _fl_on_peer_connected(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	_fl_spawn_remote_player(peer_id)
	if multiplayer.is_server():
		var ids: Array[int] = [1]
		for connected_id in multiplayer.get_peers():
			ids.append(int(connected_id))
		rpc("_fl_receive_existing_players", ids)
		_fl_set_network_status("Hosting. Players connected: %d" % (multiplayer.get_peers().size() + 1))

func _fl_on_peer_disconnected(peer_id: int) -> void:
	var remote := get_node_or_null("RemotePlayer_%d" % peer_id)
	if remote != null:
		remote.queue_free()
	if multiplayer.is_server():
		_fl_set_network_status("Hosting. Players connected: %d" % (multiplayer.get_peers().size() + 1))

func _fl_spawn_remote_player(peer_id: int) -> void:
	if not is_instance_valid(player) or peer_id == multiplayer.get_unique_id():
		return
	var node_name := "RemotePlayer_%d" % peer_id
	if get_node_or_null(node_name) != null:
		return
	var remote := player.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as CharacterBody3D
	if remote == null:
		return
	remote.name = node_name
	add_child(remote)
	remote.set_multiplayer_authority(peer_id)
	remote.set_physics_process(false)
	remote.set_process(false)
	var remote_camera := remote.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if remote_camera != null:
		remote_camera.current = false
	remote.global_position = Vector3(float(peer_id % 4) * 2.0, 0.95, 2.0 + float(peer_id % 3) * 2.0)

@rpc("authority", "call_remote", "reliable")
func _fl_receive_existing_players(peer_ids: Array) -> void:
	for raw_id in peer_ids:
		var peer_id := int(raw_id)
		if peer_id != multiplayer.get_unique_id():
			_fl_spawn_remote_player(peer_id)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _fl_receive_player_state(peer_id: int, world_position: Vector3, yaw: float) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var remote := get_node_or_null("RemotePlayer_%d" % peer_id) as CharacterBody3D
	if remote == null:
		_fl_spawn_remote_player(peer_id)
		remote = get_node_or_null("RemotePlayer_%d" % peer_id) as CharacterBody3D
	if remote != null:
		remote.global_position = remote.global_position.lerp(world_position, 0.65)
		remote.rotation.y = yaw
