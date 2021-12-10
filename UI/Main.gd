extends Node

var address := ""

func _ready():
		# warning-ignore:return_value_discarded
	Network.connect("connected", self, "_on_connected")
	# warning-ignore:return_value_discarded
	Network.connect("disconnected", self, "_on_disconnected")

#
# Network Events
#

func _on_connected():
	pass

func _on_disconnected(errtxt: String):
	print("Lobby _server_disconnected")
	$ConnectPanel.show()
	$LobbyPanel.hide()
	$ConnectDialog.hide()
	if not errtxt.empty():
		$ErrorDialog.dialog_text = errtxt
		$ErrorDialog.popup_centered_minsize()

#
# UI Events
#

func _on_Address_text_changed(new_text:String):
	address = new_text

func _on_JoinBtn_pressed():
	if address.empty(): address = "localhost"
	Network.join_game(address)
	$ConnectDialog.popup()

func _on_HostBtn_pressed():
	Network.host_game(true)
	$ConnectDialog.popup()
