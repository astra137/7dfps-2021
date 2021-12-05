extends Control

func _ready():
	# warning-ignore:return_value_discarded
	Network.connect("disconnected", self, "_on_disconnected")

func _on_join_pressed():
	var address = $Menu/Address.text
	if address.empty(): address = "localhost"
	Network.join_game(address)
	$Menu.hide()

func _on_start_pressed():
	Network.host_game(true)
	$Menu.hide()

func _on_start_pressed2():
	Network.host_game(false)
	$Menu.hide()

func _on_disconnected(errtxt: String):
	print("Lobby _server_disconnected")
	$Menu.show()
	if not errtxt.empty():
		$ErrorDialog.dialog_text = errtxt
		$ErrorDialog.popup_centered_minsize()
