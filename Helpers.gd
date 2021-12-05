extends Node

# Gets the player id for a node belonging to that player
func get_player_id(node: Node):
	var temp = node
	while temp:
		if temp.is_in_group("player"):
			return int(temp.name)
		temp = temp.get_parent()
		
	return -1

# Gets the node for a player with a given id
func get_player_node_by_id(id: int):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if Helpers.get_player_id(p) == id:
			return p
	return null
