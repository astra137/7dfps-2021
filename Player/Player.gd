extends KinematicBody

# State
enum PlayerState {
	IDLE,
	STARING_COUNTDOWN,
	STARING_PERSISTENT,
	INTERRUPTED
}
var state: int = PlayerState.IDLE

const MAX_SLOPE_ANGLE = 40

export(float, 0.0, 1.0) var max_speed := 18.0
export(float, 0.0, 20.0) var acceleration := 4.5
export(float, 0.0, 20.0) var deacceleration := 16.0
export(float, 0.0, 0.5) var mouse_sensitivity := 0.05
export(int, 0, 1000) var initial_burst_score := 500
export(float, 0.0, 500.0) var delta_score_rate := 80.0

var vel = Vector3()
var dir = Vector3()
puppet var score := 0
var staring_at := 0

onready var camera: Camera = $Head/Camera
onready var rotation_helper: Spatial = $Head
onready var hide_the_body: Spatial = $Head/Proob
onready var stare: RayCast = $Stare
onready var score_label: Label = get_tree().get_root().get_node("World/Margin/VerticalElements/TopRow/Score")
onready var stare_indicator: Label = get_tree().get_root().get_node("World/Margin/VerticalElements/TopRow/StareIndicator")
onready var stare_timer: Timer = $StareTimer

puppet var puppet_transform: Transform
puppet var puppet_transform_head: Transform
puppet var puppet_velocity: Vector3


func _ready():
	puppet_transform = transform
	puppet_velocity = vel
	if is_network_master():
		camera.make_current()
		hide_the_body.hide()
	if OS.is_window_focused():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _exit_tree():
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event):
	if not is_network_master(): return
	if not OS.is_window_focused(): return

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	elif event is InputEventMouseButton:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	elif event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * mouse_sensitivity * -1))
		self.rotate_y(deg2rad(event.relative.x * mouse_sensitivity * -1))
		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot


func _physics_process(delta):
	dir = Vector3()
	var cam_xform = camera.get_global_transform()

	var input_movement_vector = Vector3()

	if is_network_master():
		if Input.is_action_pressed("movement_forward"):
			input_movement_vector.z += 1
		if Input.is_action_pressed("movement_backward"):
			input_movement_vector.z -= 1
		if Input.is_action_pressed("movement_left"):
			input_movement_vector.x -= 1
		if Input.is_action_pressed("movement_right"):
			input_movement_vector.x += 1
		if Input.is_action_pressed("movement_up"):
			input_movement_vector.y += 1
		if Input.is_action_pressed("movement_down"):
			input_movement_vector.y -= 1
		input_movement_vector = input_movement_vector.normalized()

	# Basis vectors are already normalized.
	dir += -cam_xform.basis.z * input_movement_vector.z
	dir += cam_xform.basis.x * input_movement_vector.x
	dir += cam_xform.basis.y * input_movement_vector.y
	dir = dir.normalized()

	var target = dir
	target *= max_speed

	var accel
	if dir.length() > 0:
		accel = acceleration
	else:
		accel = deacceleration

	vel = vel.linear_interpolate(target, accel * delta)

	if is_network_master():
		rset("puppet_transform_head", rotation_helper.transform)
		rset("puppet_transform", transform)
		rset("puppet_velocity", vel)
	else:
		rotation_helper.transform = puppet_transform_head
		transform = puppet_transform
		vel = puppet_velocity

	vel = move_and_slide(vel, Vector3(0, 0, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

	# Set the puppet variables with new calculated values,
	# effectively interpolating until remotely overwritten.
	if not is_network_master():
		puppet_transform = transform
		puppet_velocity = vel

	if is_network_master():
		process_stare(delta)

# Handles staring mechanics. Function can only be ran on a master node.
master func process_stare(delta):
	# 2 is the collision layer for stareable areas
	if stare.is_colliding() and stare.get_collider().get_collision_layer_bit(1):
		match state:
			PlayerState.IDLE:
				stare_timer.start()
				state = PlayerState.STARING_COUNTDOWN
				print("Staring Countdown")
			PlayerState.STARING_PERSISTENT:
				inc_score(delta_score_rate * delta)

		# Regardless of the state we need to make an rpc on the entity we're staring at
		staring_at = Helpers.get_player_id(stare.get_collider())
		var other_player = Helpers.get_player_node_by_id(staring_at)
		if other_player and other_player.has_method("being_stared"):
			other_player.rpc_id(staring_at, "being_stared")
	# If you are no longer staring at someone then stop scoring
	else:
		match state:
			PlayerState.STARING_COUNTDOWN, PlayerState.STARING_PERSISTENT, PlayerState.INTERRUPTED:
				stare_timer.stop()
				state = PlayerState.IDLE
				print("Idle")

				# Letting other player know that we are done staring at them
				var other_player = Helpers.get_player_node_by_id(staring_at)
				if other_player and other_player.has_method("not_being_stared"):
					other_player.rpc_id(staring_at, "not_being_stared")
				staring_at = 0

# Receive burst points and switch to points over time
func _on_StareTimer_timeout():
	if state == PlayerState.STARING_COUNTDOWN:
		inc_score(initial_burst_score)
		state = PlayerState.STARING_PERSISTENT
		print("Staring Persistent")

# Increases the score and sets it
func inc_score(amount: int):
	score += amount
	rset("score", score)
	score_label.text = str(score)

# Remotely called when your object is being stared at
master func being_stared():
	stare_indicator.text = str(true)
	match state:
		PlayerState.STARING_COUNTDOWN, PlayerState.STARING_PERSISTENT:
			var sending_id = get_tree().get_rpc_sender_id()
			if sending_id == staring_at:
				stare_timer.stop()
				state = PlayerState.INTERRUPTED
				print("Interrupted")

# Remotely called when someone stops staring at you
master func not_being_stared():
	var sending_id = get_tree().get_rpc_sender_id()
	stare_indicator.text = str(false)
	match state:
		PlayerState.INTERRUPTED:
			if sending_id == staring_at:
				state = PlayerState.IDLE
