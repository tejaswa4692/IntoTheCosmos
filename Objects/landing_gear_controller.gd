extends Node
@onready var rocket = get_parent()

var landing_gear: bool = false

func play_initial_deploy() -> void:
	rocket.get_node("Rocket/AnimationPlayer").play("CubeAction_004")
	landing_gear = true
	await rocket.get_node("Rocket/AnimationPlayer").animation_finished
	rocket.get_node("LandingGearCollision").disabled = false

func handle_landing_gear() -> void:
	var anim = rocket.get_node("Rocket/AnimationPlayer")
	if Input.is_action_just_pressed("LandingGear") and !anim.is_playing():
		if !landing_gear:
			anim.play("CubeAction_004")
			landing_gear = true
			await anim.animation_finished
			rocket.get_node("LandingGearCollision").disabled = false
		else:
			anim.play_backwards("CubeAction_004")
			landing_gear = false
			await anim.animation_finished
			rocket.get_node("LandingGearCollision").disabled = true
