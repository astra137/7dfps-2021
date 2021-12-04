extends Node

const DEFAULT_PORT = 10567
const MAX_PEERS = 10

var players_joined = []
var players_ready = []

signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)


func _ready():
	# warning-ignore:return_value_discarded
	multiplayer.connect("network_peer_connected", self, "_player_connected")
	# warning-ignore:return_value_discarded
	multiplayer.connect("network_peer_disconnected", self,"_player_disconnected")
	# warning-ignore:return_value_discarded
	multiplayer.connect("connected_to_server", self, "_connected_ok")
	# warning-ignore:return_value_discarded
	multiplayer.connect("connection_failed", self, "_connected_fail")
	# warning-ignore:return_value_discarded
	multiplayer.connect("server_disconnected", self, "_server_disconnected")

	# TODO
	if OS.has_feature("Server"):
		print("OS.has_feature Server")
	if OS.has_feature("Client"):
		print("OS.has_feature Client")
	if OS.get_environment('SERVER'):
		print("SERVER")

# Callback from SceneTree.
func _player_connected(id):
	print("_player_connected ", id)
	# Registration of a client beings here, tell the connected player that we are here.
	rpc_id(id, "register_player")


# Callback from SceneTree.
func _player_disconnected(id):
	print("_player_disconnected", id)
	if has_node("/root/World"):
		# Game is in progress.
		if get_tree().is_network_server():
			emit_signal("game_error", "Player " + str(id) + " disconnected")
			end_game()
	else:
		# Game is not in progress.
		# Unregister this player.
		unregister_player(id)


# Callback from SceneTree, only for clients (not server).
func _connected_ok():
	print("_connected_ok")
	emit_signal("connection_succeeded")


# Callback from SceneTree, only for clients (not server).
func _server_disconnected():
	print("_server_disconnected")
	emit_signal("game_error", "Server disconnected")
	end_game()


# Callback from SceneTree, only for clients (not server).
func _connected_fail():
	print("_connected_fail")
	get_tree().set_network_peer(null)
	emit_signal("connection_failed")


# Lobby management functions.

remote func register_player():
	var id = get_tree().get_rpc_sender_id()
	print("register_player ", id)
	players_joined.append(id)
	emit_signal("player_list_changed")


func unregister_player(id):
	players_joined.erase(id)
	emit_signal("player_list_changed")


remote func pre_start_game(spawn_points):
	var world_scene = preload("res://Entities/World.tscn")
	var player_scene = preload("res://Player/Player.tscn")

	var world = world_scene.instance()
	get_tree().get_root().add_child(world)

	for p_id in spawn_points:
		var spawn_node: Spatial = world.get_node("SpawnPoints/" + str(spawn_points[p_id]))
		var spawn_pos = spawn_node.global_transform.origin
		var player = player_scene.instance()
		player.set_name(str(p_id)) # Use unique ID as node name.
		player.set_network_master(p_id) #set unique id as master.
		print("assigned ", player, " to ", str(p_id))
		# if p_id == get_tree().get_network_unique_id():
		# 	# If node for this peer id, set name.
		# 	player.set_player_name(player_name)
		# else:
		# 	# Otherwise set name from peer.
		# 	player.set_player_name(players[p_id])
		world.get_node("Players").add_child(player)
		player.global_transform.origin = spawn_pos

	if not get_tree().is_network_server():
		rpc_id(1, "ready_to_start", get_tree().get_network_unique_id())


remote func post_start_game():
	print("post_start_game")
	get_tree().set_pause(false)

remote func ready_to_start(id):
	print("ready_to_start ", id)
	assert(get_tree().is_network_server())

	if not id in players_ready:
		players_ready.append(id)

	if players_ready.size() == players_joined.size():
		for p in players_joined:
			rpc_id(p, "post_start_game")
		post_start_game()

func host_game():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(DEFAULT_PORT, MAX_PEERS)
	get_tree().set_network_peer(peer)
	get_tree().refuse_new_network_connections = false

func join_game(address: String):
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(address, DEFAULT_PORT)
	get_tree().set_network_peer(peer)


func get_player_list():
	var list = players_joined.duplicate()
	list.push_front(get_tree().get_network_unique_id())
	return list


func begin_game():
	print("begin_game")
	assert(get_tree().is_network_server())
	get_tree().refuse_new_network_connections = true
	var spawn_points = {}
	spawn_points[1] = 0 # Server in spawn point 0.
	var spawn_point_idx = 1
	for p in players_joined:
		spawn_points[p] = spawn_point_idx
		spawn_point_idx += 1
	# Call to pre-start game with the spawn points.
	for p in players_joined:
		rpc_id(p, "pre_start_game", spawn_points)

	pre_start_game(spawn_points)


func end_game():
	if has_node("/root/World"):
		get_node("/root/World").queue_free()

	get_tree().set_network_peer(null)
	players_ready.clear()
	players_joined.clear()
	emit_signal("game_ended")
