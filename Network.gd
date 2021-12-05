extends Node

const DEFAULT_PORT = 10567
const MAX_PEERS = 10

signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)

var world_scene = preload("res://Entities/World.tscn")
var player_scene = preload("res://Player/Player.tscn")

var player_list = []
var world

puppet var players_ready = []

func host_game(local_player: bool):
	print("Starting server local_player=", local_player)
	var peer = NetworkedMultiplayerENet.new()
	var ok = peer.create_server(DEFAULT_PORT, MAX_PEERS)
	if ok != OK: get_tree().quit(1);
	get_tree().set_network_peer(peer)
	world = world_scene.instance()
	get_tree().get_root().add_child(world)
	if local_player: player_add(1)

func join_game(address: String):
	var peer = NetworkedMultiplayerENet.new()
	var ok = peer.create_client(address, DEFAULT_PORT)
	if ok != OK: get_tree().quit(1);
	get_tree().set_network_peer(peer)
	world = world_scene.instance()
	get_tree().get_root().add_child(world)

func quit_game():
	get_tree().set_network_peer(null)
	if has_node("/root/World"):
		get_node("/root/World").queue_free()
	players_ready.clear()
	player_list.clear()
	emit_signal("game_ended")

func player_add(player_id: int):
	print("player_add ", player_id)
	player_list.append(player_id)
	var player = player_scene.instance()
	player.set_name(str(player_id))
	player.set_network_master(player_id)
	world.get_node("Players").add_child(player)
	emit_signal("player_list_changed")

func player_remove(player_id: int):
	print("player_remove ", player_id)
	players_ready.erase(player_id)
	var player: KinematicBody = world.get_node("Players").get_node(str(player_id))
	player.queue_free()
	emit_signal("player_list_changed")

#
#
#
#
#

func _ready():
	# warning-ignore:return_value_discarded
	multiplayer.connect("network_peer_connected", self, "_network_peer_connected")
	# warning-ignore:return_value_discarded
	multiplayer.connect("network_peer_disconnected", self, "_network_peer_disconnected")
	# warning-ignore:return_value_discarded
	multiplayer.connect("connected_to_server", self, "_connected_to_server")
	# warning-ignore:return_value_discarded
	multiplayer.connect("connection_failed", self, "_connection_failed")
	# warning-ignore:return_value_discarded
	multiplayer.connect("server_disconnected", self, "_server_disconnected")


func _network_peer_connected(id):
	print("_network_peer_connected ", id)
	if multiplayer.is_network_server():
		for player_id in player_list:
			rpc_id(id, "player_join", player_id)

		player_add(id)
		for peer_id in multiplayer.get_network_connected_peers():
			rpc_id(peer_id, "player_join", id)
		# TODO: send server if server wants to play

func _network_peer_disconnected(id):
	print("_network_peer_disconnected", id)
	if multiplayer.is_network_server():
		player_remove(id)
		for peer_id in multiplayer.get_network_connected_peers():
			rpc_id(peer_id, "player_leave", id)
		# Server physically can't be disconnected

func _connected_to_server():
	print("_connected_to_server")
	emit_signal("connection_succeeded")

func _connection_failed():
	print("_connection_failed")
	get_tree().set_network_peer(null)
	emit_signal("connection_failed")

func _server_disconnected():
	print("_server_disconnected")
	quit_game()
	emit_signal("game_error", "Server disconnected")


#
#
#
#


# Server -> all clients notification of player change
remote func player_join(player_id: int):
	var sender_id = multiplayer.get_rpc_sender_id()
	assert(sender_id <= 1)
	player_add(player_id)


# Server -> all clients notification of player change
remote func player_leave(player_id: int):
	var sender_id = multiplayer.get_rpc_sender_id()
	assert(sender_id == 1)
	player_remove(player_id)


# Self client -> server notification that client is ready
remote func set_player_ready(flag: bool):
	assert(multiplayer.is_network_server())
	var sender_id = multiplayer.get_rpc_sender_id()
	if flag:
		if not players_ready.find(sender_id):
			players_ready.append(sender_id)
	else:
		players_ready.erase(sender_id)
	rset("players_ready", players_ready)
