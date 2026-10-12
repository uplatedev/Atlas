extends SceneTree
## Meet de werkelijke Character-stop met physics-interpolatie en rendercamera.
## --path game --script ../docs/work/T-005/camera_inertia_motion_probe.gd -- --fps=144

var character: AtlasCharacter
var rig: Node3D
var frames: int = 0
var fixed_rate: int = 144
var stopped: bool = false
var peak_front: float = 0.0
var peak_offset: float = 0.0
var maximum_total: float = 0.0
var stop_frames: int = 0
var camera_script: String = ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fps="):
			fixed_rate = int(argument.trim_prefix("--fps="))
		if argument.begins_with("--camera="):
			camera_script = argument.trim_prefix("--camera=")
	Engine.max_fps = fixed_rate
	call_deferred("run")


func run() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200.0, 0.2, 200.0)
	floor_shape.shape = shape
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.1
	root.add_child(floor_body)
	character = load("res://characters/Character.tscn").instantiate()
	rig = character.get_node("CameraPivot")
	if not camera_script.is_empty():
		rig.set_script(load(camera_script))
	root.add_child(character)
	character.set_controlled(true)
	rig.set_distance(4.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var observer := Node.new()
	observer.set_script(load(get_script().resource_path.get_base_dir().path_join("camera_probe_observer.gd")))
	observer.probe = self
	observer.process_priority = 200
	root.add_child(observer)


func sample(_delta: float) -> void:
	frames += 1
	if not stopped and frames >= fixed_rate * 2:
		Input.action_release("move_forward")
		stopped = true
	if not stopped:
		return
	stop_frames += 1
	var target: Vector3 = character.get_global_transform_interpolated().origin
	var front := target.z - rig.global_position.z
	peak_front = maxf(peak_front, front)
	peak_offset = maxf(peak_offset, rig.get_state().camera_inertia_amount)
	maximum_total = maxf(maximum_total, rig.get_state().camera_follow_lag)
	if stop_frames >= fixed_rate:
		print("MEASURE actual-Character-inertia fps=%d brake=%.1fm/s2 front=%.6fm offset=%.6fm total=%.6fm remaining=%.9fm final_speed=%.6fm/s" % [fixed_rate, character.sprint_deceleration, peak_front, peak_offset, maximum_total, rig.get_state().camera_inertia_amount, Vector2(character.velocity.x, character.velocity.z).length()])
		Input.action_release("sprint")
		quit(0 if peak_front > 0.008 and peak_front < 0.020 and maximum_total <= 0.12001 and rig.get_state().camera_inertia_amount < 0.00001 else 1)
