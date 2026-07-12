extends Node
@onready var rocket = get_parent()

var curent_help = 0

func handle_help() -> void:
	var help = rocket.get_node("Control/Help")
	if curent_help == 0:
		help.visible = true
		help.get_node("Help1").show()
		curent_help = 1
	elif curent_help == 1:
		help.get_node("Help2").show()
		help.get_node("Help1").hide()
		curent_help = 2
	elif curent_help == 2:
		help.get_node("Help2").hide()
		help.hide()
		curent_help = 0
