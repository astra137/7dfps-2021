extends KinematicBody
class_name Player

# State
enum PlayerState {
	IDLE,
	STARING_COUNTDOWN,
	STARING_PERSISTENT
}
var state: int = PlayerState.IDLE

const MAX_SLOPE_ANGLE = 40

export(float, 0.0, 100.0) var max_speed := 18.0
export(float, 0.0, 20.0) var acceleration := 4.5
export(float, 0.0, 20.0) var deacceleration := 16.0
export(float, 0.0, 0.5) var mouse_sensitivity := 0.05
export(int, 0, 1000) var initial_burst_score := 500
export(float, 0.0, 500.0) var delta_score_rate := 80.0
export(float, 0.0, 90.0) var stare_angle_tolerance := 20.0

# Server-set values for this player's kinematics
var _position := Vector3.ZERO
var _velocity := Vector3.ZERO

# Locally calculated values for this player's kinematics
var velocity := Vector3.ZERO

var staring_at := []
var stared_by := []

puppetsync var score := 0

onready var control := $Control
onready var camera: Camera = $Head/Camera
onready var rotation_helper: Spatial = $Head
onready var hide_the_body: Spatial = $Head/proob
onready var score_bar: ProgressBar = get_tree().get_root().get_node("World/GameUI/VerticalElements/TopRow/ScoreElements/Score")
onready var score_board := get_tree().get_root().get_node("World/GameUI/ScoreboardBackground")
onready var victor_area := get_tree().get_root().get_node("World/GameUI/ScoreboardBackground/ScoreboardMargin/Scoreboard/VictorArea")
onready var stare_timer: Timer = $StareTimer
onready var spotlight: SpotLight = $Head/SpotLight
onready var omnilight: OmniLight = $Head/OmniLight





func get_is_me():
	return control.is_network_master()

func post_player_join(id: int, pos: Vector3, vel: Vector3):
	print("post_player_join:", id)
	control.set_network_master(id)
	name = str(id)
	_position = pos
	_velocity = vel
	transform.origin = _position
	velocity = _velocity
	if control.is_network_master():
		camera.make_current()
		$Head/proob/body.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		$Head/proob/engine.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	else:
		$Head/proob/body.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
		$Head/proob/engine.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON


puppetsync func set_real_kinematics(pos: Vector3, vel: Vector3):
	_position = pos;
	_velocity = vel;


func _ready():
	# Choose a random color for the player
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var hue = rng.randf_range(0, 1.0)
	spotlight.light_color = Color.from_hsv(hue, 1.0, 1.0, 1.0)
	omnilight.light_color = Color.from_hsv(hue, 1.0, 1.0, 1.0)


func _process(delta):
	if get_is_me():
		score_bar.value = score

	if multiplayer.is_network_server():
		# The server's simulation is the source of truth.
		rpc_unreliable("set_real_kinematics", transform.origin, velocity)
	else:
		# Clients also simulate kinematics, but need to interpolate to server values.
		transform.origin = transform.origin.linear_interpolate(_position, delta * 0.5)
		velocity = velocity.linear_interpolate(_velocity, delta * 0.5)


func _physics_process(delta):
	# We accept that a player could cheat with aimbot
	# So that we never limit how fast a player can look around
	rotation_degrees.y = control.look_yaw
	rotation_helper.rotation_degrees.x = control.look_pitch

	# Motion, however, will be simulated.
	var move_intent = control.move_dir.normalized()
	var cam_xform = camera.get_global_transform()

	# Basis vectors are already normalized.
	var dir = Vector3()
	dir += -cam_xform.basis.z * move_intent.z
	dir += cam_xform.basis.x * move_intent.x
	dir += cam_xform.basis.y * move_intent.y
	dir = dir.normalized() * max_speed

	var accel
	if dir.length() > 0:
		accel = acceleration
	else:
		accel = deacceleration

	velocity = velocity.linear_interpolate(dir, accel * delta)
	velocity = move_and_slide(velocity, Vector3.ZERO, true, 4, deg2rad(MAX_SLOPE_ANGLE))

	if multiplayer.is_network_server():
		process_stare(delta)


# Handles staring mechanics.
func process_stare(delta):
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

	for player in players:
		var here = Helpers.get_player_id(self)
		var there = Helpers.get_player_id(player)
		if staring_at_temp.has(player): # self is staring at player
			if not player.stared_by.has(self): # player doesn't know yet
				player.stared_by.append(self)
				if not stared_by.has(player): # player is NOT looking at self
					player.get_node("Sounds").rpc_id(here, "cue_lock_charging", true)
					self.get_node("Sounds").rpc_id(there, "cue_enemy_lock", true)
				else: # other player is looking at self
					player.get_node("Sounds").rpc_id(here, "cue_enemy_lock", false)
					self.get_node("Sounds").rpc_id(there, "cue_lock_charging", false)

		else: # self is NOT looking at player
			if player.stared_by.has(self): # player doesn't know yet
				player.stared_by.erase(self)
				if not stared_by.has(player): # player is NOT looking at self
					player.get_node("Sounds").rpc_id(here, "cue_lock_charging", false)
					self.get_node("Sounds").rpc_id(there, "cue_enemy_lock", false)
				else: # player is looking at self
					player.get_node("Sounds").rpc_id(here, "cue_enemy_lock", true)
					self.get_node("Sounds").rpc_id(there, "cue_lock_charging", true)


	# Setting the values for who we're staring at
	staring_at = [] + staring_at_temp

	for player in stared_by:
		staring_at_temp.erase(player)

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
				state = PlayerState.IDLE
				print("Idle")



# Increases the score and sets it
func inc_score(amount: int):
	score += amount
	rset("score", score)

# Receive burst points and switch to points over time
func _on_StareTimer_timeout():
	if state == PlayerState.STARING_COUNTDOWN:
		var staring_at_temp = [] + staring_at
		for p in stared_by:
			if staring_at_temp.has(p):
				staring_at_temp.remove(staring_at_temp.find(p))

		state = PlayerState.STARING_PERSISTENT
		print("Staring Persistent")
		inc_score(initial_burst_score * staring_at_temp.size())




puppetsync func respawn(to: Vector3):
	# Move player
	transform.origin = to

	if get_is_me():
		# Hide victor label
		victor_area.visible = false
		victor_area.get_node("Victor/Name").text = ""

		# Hide scoreboard
		score_board.visible = false

		# Enable movement
		pass


puppetsync func round_ended(victor: String):
	if get_is_me():
	# Disable movement
		pass

		# Show scoreboard
		score_board.visible = true

		# Show victor label
		victor_area.visible = true
		victor_area.get_node("Victor/Name").text = victor
