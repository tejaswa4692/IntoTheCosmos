extends StaticBody3D

var scrap_quantity: int = 5

func remove() -> void:
	$GPUParticles3D.emitting = true
	$Scrap.hide()
	$CollisionShape3D.disabled = true
	$CD.start()


func _on_cd_timeout() -> void:
	queue_free()
