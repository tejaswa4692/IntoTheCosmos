extends Node3D


func _ready() -> void:
	if !MusicAutoload.music_player.playing:
		MusicAutoload.play(preload("res://Assets/Music/Cosmos1.mp3"))
