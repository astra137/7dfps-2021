extends VBoxContainer


const update_period := 0.1
var time_left := 0.0
var scoreboard_row := preload("res://UI/ScoreboardRow.tscn")

onready var header := $Header
onready var world := get_tree().get_root().get_node("World")



class PlayerScoreSorter:
	static func sort_descending(a, b):
		if a[1] > b[1]:
			return true
		return false



func _process(_delta):
# Uncomment for a live scoreboard
#	if time_left <= 0.0:
#		update_scores()
#
#		time_left = update_period
#	else:
#		time_left -= delta
	pass


func update_scores():
	# Delete children
	var children := get_children()
	for child in children:
		if child != header:
			child.queue_free()
	
	# Get scoreboard data (from the World node)
	var player_scores: Array = world.player_scores
	player_scores.sort_custom(PlayerScoreSorter, "sort_descending")
	
	# Loop through the data
	for score in player_scores:
		# Create scoreboard row
		var row = scoreboard_row.instance()
		
		# Set values
		row.get_node("Name").text = str(score[0])
		row.get_node("Score").text = str(score[1])
		
		# Append row
		add_child(row)

func _on_ScoreboardBackground_visibility_changed():
	update_scores()
