extends Node3D

@onready var debrie: GPUParticles3D = $Debrie
@onready var fire: GPUParticles3D = $Fire
@onready var explosion_sound: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var smoke: GPUParticles3D = $Smoke


func explode() -> void:
	debrie.emitting = true
	fire.emitting = true
	smoke.emitting = true
	explosion_sound.play()
	await explosion_sound.finished
	queue_free()
