extends Node

export(float, 0.0, 0.5) var mouse_sensitivity := 0.05

puppetsync var move := Vector3.ZERO
puppetsync var look_yaw := 0.0
puppetsync var look_pitch := 0.0

func _ready():
	if not is_network_master(): return
	if not OS.is_window_focused(): return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _exit_tree():
	if not is_network_master(): return
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _notification(what):
	if not is_inside_tree(): return
	if not is_network_master(): return
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
		var dx = event.relative.x * mouse_sensitivity * -1
		var dy = event.relative.y * mouse_sensitivity * -1
		look_pitch = clamp(look_pitch + dy, -70, 70)
		look_yaw = wrapf(look_yaw + dx, 0, 360)
		rset_unreliable("look_yaw", look_yaw)
		rset_unreliable("look_pitch", look_pitch)

func _physics_process(_delta):
	if not is_network_master(): return
	move = Vector3.ZERO
	if Input.is_action_pressed("movement_forward"):
		move.z += 1
	if Input.is_action_pressed("movement_backward"):
		move.z -= 1
	if Input.is_action_pressed("movement_left"):
		move.x -= 1
	if Input.is_action_pressed("movement_right"):
		move.x += 1
	if Input.is_action_pressed("movement_up"):
		move.y += 1
	if Input.is_action_pressed("movement_down"):
		move.y -= 1
	rset_unreliable("move", move) # does this spam packets?
