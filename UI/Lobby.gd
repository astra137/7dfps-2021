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
	# Sometimes the Player/Soul doesn't release mouse
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$Menu.show()
	if not errtxt.empty():
		$ErrorDialog.dialog_text = errtxt
		$ErrorDialog.popup_centered_minsize()
