extends Node3D


func _ready() -> void:
	if !MusicAutoload.music_player.playing:
		MusicAutoload.play(preload("res://Assets/Music/Ambient Space Synth Music (For Videos) - Adrift by Hayden Folker.mp3"))
		
