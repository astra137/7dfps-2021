extends Node

func _ready():
	# warning-ignore:return_value_discarded
	$EnemyLockWarning.connect("finished", self, "_on_EnemyLockWarning_finished")


func _on_EnemyLockWarning_finished():
	$EnemyLockSustained.playing = true


remote func cue_enemy_lock(locked: bool):
	print("cue_enemy_lock ", locked, " ", $"..".get_is_me())
	if locked:
		$EnemyLockLost.stop()
		$EnemyLockSustained.stop()
		$EnemyLockWarning.play()
	else:
		$EnemyLockLost.play()
		$EnemyLockSustained.stop()
		$EnemyLockWarning.stop()

remote func cue_player_lock(locked: bool):
	if locked:
		$PlayerLockCharging.play()
		$PlayerLockLost.stop()
	else:
		$PlayerLockCharging.stop()
		$PlayerLockLost.play()
