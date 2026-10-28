
extends Button

func _ready() -> void:
	text = "PICKUP"
	pressed.connect(_on_pickup_pressed)

func _on_pickup_pressed() -> void:
	var player = get_node_or_null("../../Player")
	if player == null:
		print("ERROR: Player not found")
		return

	var pickups = get_tree().get_nodes_in_group("ammo_pickups")

	var nearest_pickup = null
	var nearest_distance = 2.5

	for pickup in pickups:
		if not is_instance_valid(pickup):
			continue

		var distance = player.global_position.distance_to(
			pickup.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_pickup = pickup

	if nearest_pickup != null and nearest_pickup.has_method("pickup_weapon"):
		nearest_pickup.pickup_weapon()
	else:
		print("NO PICKUP NEARBY")
