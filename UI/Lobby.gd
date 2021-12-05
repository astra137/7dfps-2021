extends Control

func _ready():
	# warning-ignore:return_value_discarded
	Network.connect("connection_failed", self, "_on_connection_failed")
	# warning-ignore:return_value_discarded
	Network.connect("connection_succeeded", self, "_on_connection_success")
	# warning-ignore:return_value_discarded
	Network.connect("player_list_changed", self, "refresh_lobby")
	# warning-ignore:return_value_discarded
	Network.connect("game_ended", self, "_on_game_ended")
	# warning-ignore:return_value_discarded
	Network.connect("game_error", self, "_on_game_error")

func _on_join_pressed():
	Network.join_game($Menu/Address.text)
	$Menu.hide()

func _on_start_pressed():
	Network.host_game(true)
	$Menu.hide()

func refresh_lobby():
	print("refresh_lobby")

func _on_connection_success():
	print("_on_connection_success")

func _on_connection_failed():
	print("_on_connection_failed")
	$Menu.show()

func _on_game_ended():
	print("_on_game_ended")
	$Menu.show()

func _on_game_error(errtxt):
	$Menu.show()
	$ErrorDialog.dialog_text = errtxt
	$ErrorDialog.popup_centered_minsize()
