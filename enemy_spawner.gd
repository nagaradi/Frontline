extends Node3D

@export var spawn_interval: float = 18.0
@export var max_enemies: int = 5
@export var spawn_distance: float = 24.0

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
var spawn_timer: float = 0.0
var player: CharacterBody3D

func _ready() -> void:
	player = get_node_or_null("../Player") as CharacterBody3D
	print("ENEMY SPAWNER READY")

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	spawn_timer += delta
	if spawn_timer < spawn_interval:
		return
	spawn_timer = 0.0
	var alive := get_tree().get_nodes_in_group("enemies")
	if alive.size() >= max_enemies:
		return
	var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
	if enemy == null:
		return
	get_parent().add_child(enemy)
	var angle := randf() * TAU
	var offset := Vector3(cos(angle) * spawn_distance, 0.0, sin(angle) * spawn_distance)
	enemy.global_position = player.global_position + offset
	print("ENEMY SPAWNED")
