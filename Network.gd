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
	print("Starting server local_player=", local_player)
	peer = NetworkedMultiplayerENet.new()
	var ok = peer.create_server(DEFAULT_PORT, MAX_PEERS)
	if ok != OK: return get_tree().quit(1);
	multiplayer.set_network_peer(peer)
	world = world_scene.instance()
	get_tree().get_root().add_child(world)
	if local_player: _network_peer_connected(1)


func join_game(address: String):
	peer = NetworkedMultiplayerENet.new()
	var ok = peer.create_client(address, DEFAULT_PORT)
	if ok != OK: return get_tree().quit(1);
	multiplayer.set_network_peer(peer)
	world = world_scene.instance()
	get_tree().get_root().add_child(world)


func quit_game():
	multiplayer.set_network_peer(null)
	if has_node("/root/World"):
		get_node("/root/World").queue_free()
	players.clear()
	emit_signal("disconnected")


remotesync func player_join(player_id: int):
	var sender_id = multiplayer.get_rpc_sender_id()
	assert(sender_id == 1)
	print("player_join ", player_id)
	var player: KinematicBody = player_scene.instance()
	player.set_name(str(player_id))
	player.set_network_master(player_id)
	player.set_process(false)
	
	# Move players to spawn points
	# We have to get vector coordinates for each of the spawn points
	var spawn_points := []
	for point in world.get_node("SpawnPoints").get_children():
		spawn_points.append(point.to_global(Vector3.ZERO))
	
	player.transform.origin = spawn_points[rng.randi_range(0, spawn_points.size())]
	world.get_node("Players").add_child(player)


remotesync func player_start(player_id: int):
	var sender_id = multiplayer.get_rpc_sender_id()
	assert(sender_id == 1)
	print("player_start ", player_id)
	var player: KinematicBody = world.get_node("Players").get_node(str(player_id))
	player.set_process(true)


remotesync func player_leave(player_id: int):
	var sender_id = multiplayer.get_rpc_sender_id()
	assert(sender_id == 1)
	print("player_leave ", player_id)
	var player: KinematicBody = world.get_node("Players").get_node(str(player_id))
	player.queue_free()


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
		for player_id in players:
			rpc_id(id, "player_join", player_id) # Send existing players to new one
		players.append(id) # Assume all new connections are players
		rpc("player_join", id) # Add player for ALL peers
		rpc_id(id, "player_start", id) # Unpause the new player AND server copy


func _network_peer_disconnected(id):
	print("_network_peer_disconnected", id)
	if multiplayer.is_network_server():
		players.erase(id)
		rpc("player_leave", id)


func _connected_to_server():
	print("_connected_to_server")


func _connection_failed():
	print("_connection_failed")
	quit_game()


func _server_disconnected():
	print("_server_disconnected")
	quit_game()
