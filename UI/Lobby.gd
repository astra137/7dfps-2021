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
	$Players.hide()


func refresh_lobby():
	$Players/List.clear()
	if get_tree().has_network_peer():
		$Players.show()
		for id in Network.get_player_list():
			$Players/List.add_item(str(id))
	else:
		$Players.hide()


func _on_tab_changed(tab):
	if tab == 1:
		Network.host_game()
	else:
		Network.end_game()
	refresh_lobby()


func _on_join_pressed():
	Network.join_game($Connect/Join/Address.text)
	$Connect.hide()


func _on_start_pressed():
	Network.begin_game()
	$Connect.hide()


func _on_connection_success():
	print("_on_connection_success")
	refresh_lobby()


func _on_connection_failed():
	print("_on_connection_failed")
	refresh_lobby()
	$Connect.show()


func _on_game_ended():
	print("_on_game_ended")
	refresh_lobby()
	$Connect.show()


func _on_game_error(errtxt):
	refresh_lobby()
	$Connect.show()
	$ErrorDialog.dialog_text = errtxt
	$ErrorDialog.popup_centered_minsize()
