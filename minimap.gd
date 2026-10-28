extends Control
## Lightweight top-down minimap: player, enemies, weapon loot, crates and safe-zone ring.
@export var world_radius: float = 95.0

func _ready() -> void:
	custom_minimum_size = Vector2(158, 158)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(center, radius, Color(0.035, 0.065, 0.055, 0.88))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.72, 0.82, 0.70, 0.95), 2.0, true)
	draw_line(Vector2(center.x - radius, center.y), Vector2(center.x + radius, center.y), Color(0.45, 0.55, 0.45, 0.22), 1.0)
	draw_line(Vector2(center.x, center.y - radius), Vector2(center.x, center.y + radius), Color(0.45, 0.55, 0.45, 0.22), 1.0)
	var player := get_node_or_null("../../Player") as Node3D
	if player == null:
		return
	var safe_zone := get_node_or_null("../../SafeZone")
	if safe_zone != null:
		var current_radius_value: Variant = safe_zone.get("current_radius")
		if current_radius_value != null:
			var scale_factor := radius / world_radius
			var zone_offset := Vector2(-player.global_position.x, -player.global_position.z) * scale_factor
			var zone_center := center + zone_offset
			var zone_radius := float(current_radius_value) * scale_factor
			if zone_radius > 1.0:
				draw_arc(zone_center, zone_radius, 0.0, TAU, 64, Color(0.15, 0.62, 1.0, 0.95), 2.0, true)
	for loot in get_tree().get_nodes_in_group("loot_containers"):
		if is_instance_valid(loot):
			_draw_world_dot(center, radius, player.global_position, loot.global_position, Color(1.0, 0.72, 0.18), 3.4)
	for pickup in get_tree().get_nodes_in_group("weapon_pickups"):
		if is_instance_valid(pickup):
			_draw_world_dot(center, radius, player.global_position, pickup.global_position, Color(1.0, 0.86, 0.24), 2.8)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			_draw_world_dot(center, radius, player.global_position, enemy.global_position, Color(1.0, 0.20, 0.16), 3.5)
	var forward := -player.global_transform.basis.z
	var direction := Vector2(forward.x, forward.z).normalized()
	var tip := center + direction * 8.0
	var side := Vector2(-direction.y, direction.x) * 4.5
	draw_colored_polygon(PackedVector2Array([tip, center - direction * 4.0 + side, center - direction * 4.0 - side]), Color(0.35, 0.95, 0.45))

func _draw_world_dot(center: Vector2, radius: float, origin: Vector3, target: Vector3, color: Color, dot_radius: float) -> void:
	var offset := Vector2(target.x - origin.x, target.z - origin.z)
	var scaled := offset * (radius / world_radius)
	if scaled.length() <= radius - 4.0:
		draw_circle(center + scaled, dot_radius, color)
