extends Node

var music_player: AudioStreamPlayer

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

func play(stream: AudioStream) -> void:
	music_player.stream = stream
	music_player.play()

func stop() -> void:
	music_player.stop()
