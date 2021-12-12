extends Spatial

export(float) var rot := 0.5
onready var gear = $gear

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	gear.transform = gear.transform.rotated(Vector3.UP, rot * delta)

puppetsync func sync_rotation(transform: Transform):
	gear.transform = transform
