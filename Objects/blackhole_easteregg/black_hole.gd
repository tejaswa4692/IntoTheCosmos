extends MeshInstance3D

var tween: Tween

func _ready() -> void:
	$EasterEgg.hide()

func _on_area_3d_body_entered(body: Node3D) -> void:
	print("entered", body)
	if body.is_in_group("rocket"):
		if tween: tween.kill()
		$EasterEgg.modulate.a = 0.0
		$EasterEgg.show()
		tween = create_tween()
		tween.tween_property($EasterEgg, "modulate:a", 1.0, 0.2)

func _on_area_3d_body_exited(body: Node3D) -> void:
	print("exited", body)
	if body.is_in_group("rocket"):
		if tween: tween.kill()
		tween = create_tween()
		tween.tween_property($EasterEgg, "modulate:a", 0.0, 0.5)
		tween.tween_callback($EasterEgg.hide)
