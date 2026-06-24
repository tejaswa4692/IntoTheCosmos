
extends Camera3D

# ============================================================
#  THIRD-PERSON CHASE CAMERA
#  Does NOT rotate with the target's body — only follows its
#  position. Works no matter where you place this node in the
#  scene tree (sibling or even child of the rocket), since it
#  overwrites its own global transform every frame.
# ============================================================

@export var target: Node3D                  # drag your rocket node here
@export var offset: Vector3 = Vector3(0, 4, 10)   # world-space offset (up/behind)
@export var follow_speed: float = 4.0             # higher = snappier, lower = floatier

func _physics_process(delta: float) -> void:
	if not target:
		return

	var desired_position := target.global_position + offset
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	look_at(target.global_position, Vector3.UP)
