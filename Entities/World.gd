extends Spatial

export(int) var maximum_score := 5000

onready var post_round_timer: Timer = $PostRoundTimer
onready var round_timer: Timer = $RoundTimer
onready var score_board := $GameUI/Margin/ScoreboardBackground
onready var victor_area := $GameUI/Margin/ScoreboardBackground/ScoreboardMargin/Scoreboard/VictorArea

var rng := RandomNumberGenerator.new()
remotesync var player_scores := []

func get_highest_scoring_player(scores):
	var highest = null
	for score in scores:
		if not highest or highest[1] < score[1]:
			highest = score
	return highest



func _ready():
	rng.randomize()



func _process(_delta):
	if is_network_master():
		var players = get_tree().get_nodes_in_group("player")
		var player_scores_temp := []
		for player in players:
			player_scores_temp.append([Helpers.get_player_id(player), player.score])
		rset("player_scores", player_scores_temp)

		if not player_scores_temp.empty() and get_highest_scoring_player(player_scores_temp)[1] >= maximum_score and post_round_timer.is_stopped():
			rpc("end_round")



func round_timer_ended():
	print("timer ended")
	if is_network_master():
		rpc("end_round")



puppetsync func end_round():
	# Find victor
	var victor = get_highest_scoring_player(player_scores)

	# Let players know the round is over
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		player.round_ended(str(victor[0]))

	# Stop round timer and start post round timer
	round_timer.stop()
	post_round_timer.start()



func _on_PostRoundTimer_timeout():
	if is_network_master():
		# Reset scores
		rset("player_scores", [])
		var players = get_tree().get_nodes_in_group("player")
		for player in players:
			# Don't comment or remove this please, it is actually a workaround for resetting rounds
			player.rset("score", 0)

		# Move players to spawn points
		# We have to get vector coordinates for each of the spawn points
		var spawn_points := []
		for point in $SpawnPoints.get_children():
			spawn_points.append(point.to_global(Vector3.ZERO))
		spawn_points.shuffle()

		for player in players:
			var index = rng.randi_range(0, spawn_points.size() - 1)
			player.rpc("respawn", spawn_points.pop_at(index))

		# Start round timer
		post_round_timer.stop()
		round_timer.start()
		rpc("time_left", round_timer.time_left)
	
remotesync func time_left(time_left: float):
	var wait_time = round_timer.wait_time
	round_timer.start(time_left)
	round_timer.wait_time = wait_time
