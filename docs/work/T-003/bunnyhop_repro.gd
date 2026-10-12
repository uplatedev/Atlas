extends SceneTree
## Tijdelijke T-003-reproductie; oorspronkelijke Character-bronnen blijven intact.

const SOURCE_COMMIT := "c23038f4a97836773fbcbfe897b82b4b9e141e77"
const CHARACTER_SCENE = preload("res://characters/Character.tscn")
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump"]

var world: Node3D
var character: AtlasCharacter
var frame_counter: int = 0
var immediate_launches: Array[float] = []
var settled_launches: Array[float] = []
var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("SOURCE: ", SOURCE_COMMIT)
	print("ENGINE: ", Engine.get_version_info().string)
	print("PHYSICS: ", ProjectSettings.get_setting("physics/3d/physics_engine"))
	print("PHYSICS_RATE: ", Engine.physics_ticks_per_second)
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(800, 0.2, 800)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	floor_body.position = Vector3(0, -0.1, 0)
	character = CHARACTER_SCENE.instantiate() as AtlasCharacter
	character.position = Vector3(0, 0.05, 0)
	world.add_child(character)
	character.set_controlled(true)
	await _frames(8)
	immediate_launches = await _sequence("immediate_next_physics_frame", 0, 12)
	settled_launches = await _sequence("30_ground_frames_between_jumps", 30, 4)
	print("SEQUENCE_IMMEDIATE: ", immediate_launches)
	print("SEQUENCE_SETTLED: ", settled_launches)
	var stacking := immediate_launches.size() == 12 and immediate_launches[-1] > immediate_launches[0] + 40.0
	var settled := settled_launches.size() == 4 and absf(settled_launches[-1] - settled_launches[0]) < 0.05
	print("REPRODUCED_STACKING: ", stacking)
	print("SETTLED_CONTROL_NO_STACKING: ", settled)
	print("The harness exits 0 when the reported defect is reproduced; this is not a regression pass.")
	_release_inputs()
	quit(0 if stacking and settled and not failed else 1)


func _sequence(label: String, ground_gap_frames: int, jumps: int) -> Array[float]:
	_release_inputs()
	character.reset_to_spawn()
	await _frames(8)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	var launches: Array[float] = []
	print("CASE: ", label, "; grounded initial speed=", _horizontal_speed())
	for jump_index in jumps:
		print("PRE_JUMP %02d frame=%d grounded=%s y=%.5f speed=%.5f" % [jump_index + 1, frame_counter, character.is_on_floor(), character.position.y, _horizontal_speed()])
		Input.action_press("jump")
		await _frames(1)
		Input.action_release("jump")
		var debug := character.get_debug_state()
		launches.append(float(debug.launch_speed))
		print("LAUNCH %02d frame=%d grounded=%s y=%.5f speed=%.5f profile=%s cap=%.5f" % [jump_index + 1, frame_counter, character.is_on_floor(), character.position.y, _horizontal_speed(), debug.jump_profile, float(character.get("_air_speed_cap"))])
		var seen_airborne := not character.is_on_floor()
		var landed := false
		for airborne_frame in 240:
			await _frames(1)
			seen_airborne = seen_airborne or not character.is_on_floor()
			if seen_airborne and character.is_on_floor():
				landed = true
				print("LAND %02d frame=%d grounded=%s y=%.5f speed=%.5f vertical=%.5f" % [jump_index + 1, frame_counter, character.is_on_floor(), character.position.y, _horizontal_speed(), character.velocity.y])
				break
		if not landed:
			printerr("REPRO_ERROR: jump never returned to floor: ", jump_index + 1)
			failed = true
			break
		# No extra grounded frame in the first case. The next jump request is
		# observed in the very next physics update after move_and_slide landed.
		await _frames(ground_gap_frames)
	return launches


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
		frame_counter += 1


func _horizontal_speed() -> float:
	return Vector2(character.velocity.x, character.velocity.z).length()


func _release_inputs() -> void:
	for action in ACTIONS:
		Input.action_release(action)
