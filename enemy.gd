extends CharacterBody3D

const SOLDIER_GEAR = preload("res://soldier_gear.gd")
## Lightweight offline enemy AI: chase at long range and fire when the player is visible.

const LOOT_SCRIPT = preload("res://loot_crate.gd")

@export var max_health: float = 100.0
@export var move_speed: float = 2.0
@export var attack_range: float = 22.0
@export var attack_damage: float = 7.0
@export var attack_interval: float = 1.7

var health: float = 100.0
var attack_timer: float = 1.0
var player: CharacterBody3D
var defeated: bool = false
var soldier: Node3D

func _ready() -> void:
	health = max_health
	defeated = false
	add_to_group("enemies")
	player = get_node_or_null("../Player") as CharacterBody3D
	soldier = get_node_or_null("character-soldier") as Node3D
	if soldier != null:
		SOLDIER_GEAR.apply_to(soldier, true)
	_try_start_animation()

func _physics_process(delta: float) -> void:
	if defeated or not is_instance_valid(player) or player.health <= 0.0:
		return
	attack_timer -= delta
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var direction := offset.normalized()
	if soldier != null and direction.length() > 0.01:
		soldier.rotation.y = atan2(-direction.x, -direction.z)

	if distance > attack_range:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if attack_timer <= 0.0:
			_fire_at_player()
			attack_timer = attack_interval

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _fire_at_player() -> void:
	if not is_instance_valid(player):
		return
	var origin := global_position + Vector3.UP * 1.25
	var target := player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider = result.get("collider")
	if collider == player:
		player.take_damage(attack_damage)
		_show_enemy_tracer(origin, target)

func _show_enemy_tracer(from: Vector3, to: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	tracer.name = "EnemyShotTracer"
	var line_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.22, 0.12, 0.8)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.12, 0.04)
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	line_mesh.surface_add_vertex(from)
	line_mesh.surface_add_vertex(to)
	line_mesh.surface_end()
	tracer.mesh = line_mesh
	get_tree().current_scene.add_child(tracer)
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(tracer):
		tracer.queue_free()

func _try_start_animation() -> void:
	if soldier == null:
		return
	var animation_player := _find_animation_player(soldier)
	if animation_player == null:
		return
	var choices := animation_player.get_animation_list()
	for preferred in ["run", "Run", "walk", "Walk", "idle", "Idle"]:
		for clip in choices:
			if String(clip).to_lower().contains(preferred.to_lower()):
				animation_player.play(clip)
				return

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func take_damage(amount: float) -> void:
	if defeated:
		return
	health = maxf(health - amount, 0.0)
	print("ENEMY HEALTH: ", health)
	if health <= 0.0:
		_defeat()

func _defeat() -> void:
	defeated = true
	remove_from_group("enemies")
	print("ENEMY DEFEATED")
	var manager := get_node_or_null("../GameManager")
	if manager != null and manager.has_method("add_kill"):
		manager.add_kill()
	_spawn_loot()
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	rotation.z = deg_to_rad(78.0)
	await get_tree().create_timer(35.0).timeout
	if is_instance_valid(self):
		queue_free()

func _spawn_loot() -> void:
	var crate = LOOT_SCRIPT.new() as Node3D
	crate.name = "DeathLoot"
	crate.set("supply_name", "ENEMY SUPPLIES")
	crate.set("healing_amount", 20.0)
	crate.set("energy_amount", 15.0)
	get_parent().add_child(crate)
	crate.global_position = global_position + Vector3(1.0, 0.0, 0.0)
