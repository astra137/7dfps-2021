extends KinematicBody

# State
enum PlayerState {
	IDLE,
	STARING_COUNTDOWN,
	STARING_PERSISTENT
}
var state: int = PlayerState.IDLE

const MAX_SLOPE_ANGLE = 40

export(float, 0.0, 1.0) var max_speed := 18.0
export(float, 0.0, 20.0) var acceleration := 4.5
export(float, 0.0, 20.0) var deacceleration := 16.0
export(float, 0.0, 0.5) var mouse_sensitivity := 0.05
export(int, 0, 1000) var initial_burst_score := 500
export(float, 0.0, 500.0) var delta_score_rate := 80.0
export(float, 0.0, 90.0) var stare_angle_tolerance := 20.0

var vel = Vector3()
var dir = Vector3()
var staring_at := []
var stared_by := []

onready var camera: Camera = $Head/Camera
onready var rotation_helper: Spatial = $Head
onready var hide_the_body: Spatial = $Head/proob
onready var score_bar: ProgressBar = get_tree().get_root().get_node("World/GameUI/VerticalElements/TopRow/ScoreElements/Score")
onready var score_board := get_tree().get_root().get_node("World/GameUI/ScoreboardBackground")
onready var victor_area := get_tree().get_root().get_node("World/GameUI/ScoreboardBackground/ScoreboardMargin/Scoreboard/VictorArea")
onready var stare_sound: AudioStreamPlayer = $StareCountdownSound
onready var stare_timer: Timer = $StareTimer
onready var spotlight: SpotLight = $Head/SpotLight
onready var omnilight: OmniLight = $Head/OmniLight

puppet var puppet_transform: Transform
puppet var puppet_transform_head: Transform
puppet var puppet_velocity: Vector3
remotesync var score := 0



func _ready():
	puppet_transform = transform
	puppet_velocity = vel
	if is_network_master():
		camera.make_current()
		hide_the_body.hide()
	if OS.is_window_focused():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Choose a random color for the player
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var hue = rng.randf_range(0, 1.0)
	spotlight.light_color = Color.from_hsv(hue, 1.0, 1.0, 1.0)
	omnilight.light_color = Color.from_hsv(hue, 1.0, 1.0, 1.0)



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

	vel = move_and_slide(vel, Vector3.ZERO, 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))

	# Set the puppet variables with new calculated values,
	# effectively interpolating until remotely overwritten.
	if not is_network_master():
		puppet_transform = transform
		puppet_velocity = vel

	if is_network_master():
		process_stare(delta)



# Handles staring mechanics. Function can only be ran on a master node.
master func process_stare(delta):
	# We need to raycast to every player to determine which ones are currently viewable (not behind an obstacle)
	var players = get_tree().get_nodes_in_group("player")
	players.remove(players.find(self))

	# We need the space state in order to raycast to each player
	var space_state = get_world().get_direct_space_state()
	var staring_at_temp := []
	var raycast_from = global_transform.xform(Vector3.ZERO)
	for player in players:
		var raycast_to = player.global_transform.xform(Vector3.ZERO)
		var intersect = space_state.intersect_ray(raycast_from, raycast_to)

		# If the player is viewable the raycast will collide with it
		if intersect and !intersect.empty() and player == intersect.collider:
			# We want to calculate the angle between the direction to the other player and the direction of where the camera is facing
			var player_direction = camera.global_transform.xform_inv(raycast_to)
			if player_direction.angle_to(Vector3(0, 0, -1)) <= (stare_angle_tolerance * PI/180):
				staring_at_temp.append(player)

				# Regardless of the state we need to make an rpc on the entity we're staring at
				if not staring_at.has(player):
					if player.has_method("being_stared"):
						player.rpc_id(Helpers.get_player_id(player), "being_stared")

	# If we stop staring at someone we were previously staring at we will send them a little message ;)
	for player in staring_at:
		if not staring_at_temp.has(player):
			# Letting other player know that we are done staring at them
			if player.has_method("not_being_stared"):
				player.rpc_id(Helpers.get_player_id(player), "not_being_stared")
			# If we stop staring at someone who's staring at us then we play the sound
			if stared_by.has(player):
				player.get_node("StareCountdownSound").play()

	# Setting the values for who we're staring at
	staring_at = [] + staring_at_temp

	# We are removing players who are staring at us so we only get the players that we are staring at
	for p in stared_by:
		if staring_at_temp.has(p):
			staring_at_temp.remove(staring_at_temp.find(p))
			p.get_node("StareCountdownSound").stop()

	if not staring_at_temp.empty():
		match state:
			PlayerState.IDLE:
				stare_timer.start()
				state = PlayerState.STARING_COUNTDOWN
				print("Staring Countdown")
			PlayerState.STARING_PERSISTENT:
				inc_score(delta_score_rate * delta * staring_at_temp.size())
	else:
		match state:
			PlayerState.STARING_COUNTDOWN, PlayerState.STARING_PERSISTENT:
				stare_timer.stop()
				stare_sound.stop()
				state = PlayerState.IDLE
				print("Idle")



# Increases the score and sets it
func inc_score(amount: int):
	score += amount
	rset("score", score)
	score_bar.value = score



# Remotely called when your object is being stared at
master func being_stared():
	var sender = Helpers.get_player_node_by_id(get_tree().get_rpc_sender_id())
	if not stared_by.has(sender):
		stared_by.append(sender)
		sender.get_node("StareCountdownSound").play()



# Remotely called when someone stops staring at you
master func not_being_stared():
	var sending = Helpers.get_player_node_by_id(get_tree().get_rpc_sender_id())
	if stared_by.has(sending):
		stared_by.remove(stared_by.find(sending))
		sending.get_node("StareCountdownSound").stop()



# Receive burst points and switch to points over time
func _on_StareTimer_timeout():
	if state == PlayerState.STARING_COUNTDOWN:
		var staring_at_temp = [] + staring_at
		for p in stared_by:
			if staring_at_temp.has(p):
				staring_at_temp.remove(staring_at_temp.find(p))

		inc_score(initial_burst_score * staring_at_temp.size())
		state = PlayerState.STARING_PERSISTENT
		print("Staring Persistent")

master func respawn(to: Vector3):
	# Move player
	transform.origin = to
	
	# Reset score
	inc_score(-score)
	
	# Hide victor label
	victor_area.visible = false
	victor_area.get_node("Victor/Name").text = ""
	
	# Hide scoreboard
	score_board.visible = false
	
	# Enable movement
	pass
	
master func round_ended(victor: String):
	# Disable movement
	pass
	
	# Show scoreboard
	score_board.visible = true
	
	# Show victor label
	victor_area.visible = true
	victor_area.get_node("Victor/Name").text = victor
