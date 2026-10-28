extends CharacterBody3D

const LOOT_SCRIPT = preload("res://loot_crate.gd")

@export var max_health: float = 100.0
@export var move_speed: float = 2.0
@export var attack_range: float = 2.0
@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.5

var health: float = 100.0
var attack_timer: float = 0.0
var player: CharacterBody3D
var defeated: bool = false

func _ready() -> void:
	health = max_health
	defeated = false
	add_to_group("enemies")
	player = get_node_or_null("../Player") as CharacterBody3D

func _physics_process(delta: float) -> void:
	if defeated or not is_instance_valid(player):
		return
	attack_timer -= delta
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > attack_range:
		var direction := offset.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if attack_timer <= 0.0:
			player.take_damage(attack_damage)
			attack_timer = attack_interval
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

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
	# Leave a visible body for looting, then clean it up.
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
