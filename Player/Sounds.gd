extends Node

var enemyLock := false

func _ready():
	# warning-ignore:return_value_discarded
	$EnemyLockWarning.connect("finished", self, "_on_EnemyLockWarning_finished")

func _on_EnemyLockWarning_finished():
	$EnemyLockSustained.playing = enemyLock

func cue_enemy_lock(locked: bool):
	if locked:
		enemyLock = true
		$EnemyLockLost.stop()
		$EnemyLockSustained.stop()
		$EnemyLockWarning.play()
	else:
		enemyLock = false
		$EnemyLockLost.play()
		$EnemyLockSustained.stop()
		$EnemyLockWarning.stop()

func cue_player_lock(locked: bool):
	if locked:
		$PlayerLockCharging.play()
		$PlayerLockLost.stop()
	else:
		$PlayerLockCharging.stop()
		$PlayerLockLost.play()
