extends Node

const DEFAULT_PORT := 10567
const MAX_PEERS := 10

signal connected()
signal disconnected(errmsg)
signal player_changed()

var world_scene = preload("res://Entities/World.tscn")
var player_scene = preload("res://Player/Player.tscn")

var world
var peer
var players = []
var rng := RandomNumberGenerator.new()

#
# Lifecycle
#

func _ready():
	# warning-ignore:return_value_discarded
	multiplayer.connect("connected_to_server", self, "_connected_to_server")
	# warning-ignore:return_value_discarded
	multiplayer.connect("connection_failed", self, "_connection_failed")
	# warning-ignore:return_value_discarded
	multiplayer.connect("server_disconnected", self, "_server_disconnected")
	# warning-ignore:return_value_discarded
	multiplayer.connect("network_peer_connected", self, "_network_peer_connected")
	# warning-ignore:return_value_discarded
	multiplayer.connect("network_peer_disconnected", self, "_network_peer_disconnected")

	rng.randomize()

	if OS.has_feature("Server") or "--server" in OS.get_cmdline_args():
		call_deferred("host_game", false)

#
# Events
#

func _connected_to_server():
	players.clear()
	world = world_scene.instance()
	get_tree().get_root().add_child(world)
	emit_signal("connected")

func _connection_failed():
	print("_connection_failed")
	multiplayer.set_network_peer(null)
	emit_signal("disconnected", "_connection_failed")

func _server_disconnected():
	print("_server_disconnected")
	multiplayer.set_network_peer(null)
	get_node("/root/World").queue_free()
	emit_signal("disconnected", "_server_disconnected")

func _network_peer_connected(id):
	print("_network_peer_connected ", id)
	if multiplayer.is_network_server():
		# Send existing players to new one
		for player_id in players:
			var player_node = Helpers.get_player_node_by_id(player_id)
			rpc_id(id, "player_join", player_id, player_node._position, player_node._velocity)

		# Assume new peers want to play
		var spawn_points = world.get_node("SpawnPoints").get_children()
		var at = spawn_points[rng.randi_range(0, players.size())].transform.origin
		rpc("player_join", id, at, Vector3.ZERO)

func _network_peer_disconnected(id):
	print("_network_peer_disconnected", id)
	if multiplayer.is_network_server():
		rpc("player_leave", id)

#
# Lobby
#

puppetsync func player_join(player_id: int):
	print("player_join:", player_id)
	var player: Player = player_scene.instance()
	world.get_node("Players").add_child(player)
	# player.post_player_join(player_id, pos, vel)
	players.append(player_id)
	emit_signal("player_changed")

puppetsync func player_leave(player_id: int):
	print("player_leave:", player_id)
	var player: Player = world.get_node("Players").get_node(str(player_id))
	player.queue_free()
	players.erase(player_id)
	emit_signal("player_changed")

#
# Local
#

func host_game(local_player: bool):
	print("host_game local_player=", local_player)
	peer = NetworkedMultiplayerENet.new()
	if peer.create_server(DEFAULT_PORT, MAX_PEERS):
		multiplayer.set_network_peer(peer)
		_connected_to_server()
		if local_player: _network_peer_connected(1)
	else:
		emit_signal("disconnected", "create_server failed")

func join_game(address: String):
	print("join_game address=", address)
	peer = NetworkedMultiplayerENet.new()
	if peer.create_client(address, DEFAULT_PORT):
		multiplayer.set_network_peer(peer)
	else:
		emit_signal("disconnected", "create_client failed")
