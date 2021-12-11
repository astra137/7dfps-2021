extends Label

onready var round_timer: Timer = get_tree().get_root().get_node("World/RoundTimer")
var time_left: int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if time_left != int(round_timer.time_left):
		var time_string = Helpers.get_time_string(round_timer.time_left)
		if time_string:
			text = time_string
