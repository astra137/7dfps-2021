extends KinematicBody

const MAX_SLOPE_ANGLE = 40

export(float) var max_speed := 0.3
export(float) var acceleration := 4.5
export(float) var deacceleration := 16.0
export(float) var mouse_sensitivity = 0.05

var vel = Vector3()
var dir = Vector3()

onready var camera: Camera = $Head/Camera
onready var rotation_helper: Spatial = $Head
onready var hide_the_body: Spatial = $Head/Proob

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
		
	move_and_collide(vel)

	# Set the puppet variables with new calculated values,
	# effectively interpolating until rset() overwrites them.
	if not is_network_master():
		puppet_transform = transform
		puppet_velocity = vel
