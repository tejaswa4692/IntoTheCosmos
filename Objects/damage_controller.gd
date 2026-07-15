extends Node
@onready var rocket = get_parent()

@export var impact_velocity_threshold: float = 10.0

func collision_impact(body: Node) -> void:
	if abs(rocket.linear_velocity.length()) > impact_velocity_threshold:
		rocket.canmove = false
		rocket.has_player = false
		rocket.get_node("Explosion").explode()
		await rocket.get_tree().create_timer(0.5).timeout
		rocket.get_node("Explosion3").explode()
		await rocket.get_tree().create_timer(0.5).timeout
		rocket.get_node("Explosion4").explode()
		print("Impact with ", body.name, " at ", rocket.linear_velocity.length())
