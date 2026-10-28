
extends Node3D

@export var start_radius: float = 40.0
@export var final_radius: float = 8.0
@export var shrink_duration: float = 180.0
@export var damage_interval: float = 2.0
@export var outside_damage: float = 5.0

var current_radius: float = 40.0
var elapsed_time: float = 0.0
var damage_timer: float = 0.0
var player: CharacterBody3D

@onready var zone_visual: MeshInstance3D = $ZoneVisual

func _ready() -> void:
	current_radius = start_radius
	player = get_node_or_null("../Player") as CharacterBody3D

	if zone_visual == null:
		push_error("ZoneVisual node nahi mila!")
		return

	update_zone_visual()
	print("SAFE ZONE STARTED")

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	elapsed_time += delta
	damage_timer += delta

	var progress: float = clampf(
		elapsed_time / shrink_duration, 0.0, 1.0
	)

	current_radius = lerpf(
		start_radius,
		final_radius,
		progress
	)

	update_zone_visual()

	var distance_from_center := Vector2(
		player.global_position.x,
		player.global_position.z
	).length()

	if distance_from_center > current_radius:
		if damage_timer >= damage_interval:
			damage_timer = 0.0
			player.take_damage(outside_damage)
			print("OUTSIDE SAFE ZONE!")
	else:
		damage_timer = 0.0

func update_zone_visual() -> void:
	if not is_instance_valid(zone_visual):
		return

	var ratio: float = current_radius / start_radius
	zone_visual.scale = Vector3(ratio, 1.0, ratio)
