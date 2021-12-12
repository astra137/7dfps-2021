extends Node

const DEFAULT_PORT := 10567
const MAX_PEERS := 10

signal disconnected(errmsg)

var world_scene = preload("res://Entities/World.tscn")
var player_scene = preload("res://Player/Player.tscn")

var world
var peer
var players = []
var rng := RandomNumberGenerator.new()


func host_game(local_player: bool):
	print("host_game:", local_player)
	peer = NetworkedMultiplayerENet.new()
	var ok = peer.create_server(DEFAULT_PORT, MAX_PEERS)
	if ok != OK: return get_tree().quit(1);
	multiplayer.set_network_peer(peer)
	world = world_scene.instance()
	get_tree().get_root().add_child(world)
	if local_player: _network_peer_connected(1)


func join_game(address: String):
	print("join_game:", address)
	peer = NetworkedMultiplayerENet.new()
	var ok = peer.create_client(address, DEFAULT_PORT)
	if ok != OK: return get_tree().quit(1);
	multiplayer.set_network_peer(peer)
	world = world_scene.instance()
	get_tree().get_root().add_child(world)


func quit_game():
	print("quit_game")
	multiplayer.set_network_peer(null)
	if has_node("/root/World"):
		get_node("/root/World").queue_free()
	players.clear()
	emit_signal("disconnected", "")


puppetsync func player_join(player_id: int, pos: Vector3, vel: Vector3):
	print("player_join:", player_id)
	var player: Player = player_scene.instance()
	world.get_node("Players").add_child(player)
	player.post_player_join(player_id, pos, vel)
	players.append(player_id)


puppetsync func player_leave(player_id: int):
	print("player_leave:", player_id)
	var player: Player = world.get_node("Players").get_node(str(player_id))
	player.queue_free()
	players.erase(player_id)


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
	rng.randomize()


func _network_peer_connected(id):
	print("_network_peer_connected ", id)
	if multiplayer.is_network_server():
		# Send existing players to new one
		for player_id in players:
			var player_node = Helpers.get_player_node_by_id(player_id)
			rpc_id(id, "player_join", player_id, player_node._position, player_node._velocity)
			world.rpc("time_left", world.get_node("RoundTimer").time_left)

		# Assume new peers want to play
		var spawn_points = world.get_node("SpawnPoints").get_children()
		var at = spawn_points[rng.randi_range(0, spawn_points.size() - 1)].transform.origin
		rpc("player_join", id, at, Vector3.ZERO)


func _network_peer_disconnected(id):
	print("_network_peer_disconnected", id)
	if multiplayer.is_network_server():
		rpc("player_leave", id)


func _connected_to_server():
	print("_connected_to_server")


func _connection_failed():
	print("_connection_failed")
	quit_game()


func _server_disconnected():
	print("_server_disconnected")
	quit_game()
