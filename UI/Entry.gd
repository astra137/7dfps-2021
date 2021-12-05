extends Node

func _ready():
	if OS.has_feature("Server"):
		Network.call_deferred("host_game", false)

	else:
		var ok = get_tree().change_scene_to(load("res://UI/Lobby.tscn"))
		if ok != OK: get_tree().quit(1)
