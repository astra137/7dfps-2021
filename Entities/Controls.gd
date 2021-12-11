extends Node

export(float, 0.0, 0.5) var mouse_sensitivity := 0.05

signal updated(peer_id, move_dir, look_pitch, look_yaw)

mastersync func update(move: Vector3, pitch: float, yaw: float):
	var peer_id = multiplayer.get_rpc_sender_id()
	emit_signal("updated", peer_id, move, pitch, yaw)

var move_dir := Vector3.ZERO
var look_pitch := 0.0
var look_yaw := 0.0

func _ready():
	if not OS.is_window_focused(): return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta):
	rpc("update", move_dir, look_pitch, look_yaw)

func _exit_tree():
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _notification(what):
	if not is_inside_tree(): return
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		# Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		pass # Let _input handle recapturing the mouse
	elif what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not OS.is_window_focused(): return

	elif event is InputEventMouseButton:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	elif event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var dx = event.relative.x * mouse_sensitivity * -1
			var dy = event.relative.y * mouse_sensitivity * -1
			look_pitch = clamp(look_pitch + dy, -70, 70)
			look_yaw = wrapf(look_yaw + dx, 0, 360)

	move_dir = Vector3.ZERO
	if Input.is_action_pressed("movement_forward"):
		move_dir.z += 1
	if Input.is_action_pressed("movement_backward"):
		move_dir.z -= 1
	if Input.is_action_pressed("movement_left"):
		move_dir.x -= 1
	if Input.is_action_pressed("movement_right"):
		move_dir.x += 1
	if Input.is_action_pressed("movement_up"):
		move_dir += Vector3.UP.rotated(Vector3.RIGHT, look_pitch * (PI/180))
	if Input.is_action_pressed("movement_down"):
		move_dir += Vector3.DOWN.rotated(Vector3.RIGHT, look_pitch * (PI/180))
