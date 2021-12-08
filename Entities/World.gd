extends Spatial

export(int) var maximum_score := 5000

onready var post_round_timer: Timer = $PostRoundTimer
onready var round_timer: Timer = $RoundTimer
onready var score_board := $GameUI/ScoreboardBackground
onready var victor_area := $GameUI/ScoreboardBackground/ScoreboardMargin/Scoreboard/VictorArea


remotesync var player_scores := []

func get_highest_scoring_player(scores):
	var highest = null
	for score in scores:
		if not highest or highest[1] < score[1]:
			highest = score
	return highest

func _process(_delta):
	if is_network_master():
		var players = get_tree().get_nodes_in_group("player")
		var player_scores_temp := []
		for player in players:
			player_scores_temp.append([Helpers.get_player_id(player), player.score])
		rset("player_scores", player_scores_temp)
		
		if not player_scores_temp.empty() and get_highest_scoring_player(player_scores_temp)[1] >= maximum_score and post_round_timer.is_stopped():
			end_round()




master func end_round():
	# Find victor
	var victor = get_highest_scoring_player(player_scores)
	
	# Disable movement
	
	# Show scoreboard
	score_board.visible = true
	
	# Show victor label
	victor_area.visible = true
	victor_area.get_node("Victor/Name").text = str(victor[0])
	
	# Remotely show scoreboard and label
	
	# Stop round timer and start post round timer
	round_timer.stop()
	post_round_timer.start()



func _on_PostRoundTimer_timeout():
	# Reset scores
	rset("player_scores", [])
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		player.rset("score", 0)
		# Remotely change score progress bar
	
	# Move players to spawn points
	# We have to get vector coordinates for each of the spawn points
	var spawn_points := []
	for point in $SpawnPoints.get_children():
		spawn_points.append(point.to_global(Vector3.ZERO))
	spawn_points.shuffle()
	
	var rng = RandomNumberGenerator.new()
	for player in players:
		var index = rng.randi_range(0, spawn_points.size())
		player.translate(spawn_points.pop_at(index))
		
	# Hide victor label
	victor_area.visible = false
	victor_area.get_node("Victor/Name").text = ""
	
	# Hide scoreboard
	score_board.visible = false
	
	# Remotely hide scoreboard
	
	# Start round timer
	round_timer.start()
	post_round_timer.stop()
	
	# Enable movement
