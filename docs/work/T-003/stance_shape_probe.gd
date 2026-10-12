extends SceneTree
## Tijdelijke queryproef van kandidaatvormen; bouwt geen houdingcontroller.

var world: Node3D
var character: AtlasCharacter
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("SOURCE: c23038f4a97836773fbcbfe897b82b4b9e141e77; candidate query harness only")
	print("ENGINE: ", Engine.get_version_info().string, "; Jolt Physics")
	world = Node3D.new()
	root.add_child(world)
	_add_box(Vector3(0, -0.1, 0), Vector3(30, 0.2, 30))
	character = preload("res://characters/Character.tscn").instantiate() as AtlasCharacter
	character.position = Vector3(10, 0.01, 10)
	world.add_child(character)
	character.set_physics_process(false)
	# 0.30m step, roof underside 1.50m: 1.20m clear above the step.
	_add_box(Vector3(-5, 0.15, 0), Vector3(4, 0.3, 4))
	_add_box(Vector3(-5, 1.60, 0), Vector3(4, 0.2, 4))
	# 0.30m step, roof underside 1.10m: 0.80m clear above the step.
	_add_box(Vector3(0, 0.15, 0), Vector3(4, 0.3, 4))
	_add_box(Vector3(0, 1.20, 0), Vector3(4, 0.2, 4))
	# 0.90m wide tunnel; prone capsule is 0.70m wide, 1.80m long.
	_add_box(Vector3(4.45, 0.8, 0), Vector3(0.2, 1.6, 5))
	_add_box(Vector3(5.55, 0.8, 0), Vector3(0.2, 1.6, 5))
	await physics_frame
	await process_frame
	var stand := _shape(1.8)
	var crawl := _shape(1.1)
	var prone := _shape(1.8)
	var step_feet := Vector3(-5, 0.31, 0)
	_check(not _clear(stand, step_feet, false), "1.20m headroom blocks standing 1.80m capsule")
	_check(_clear(crawl, step_feet, false), "1.20m headroom admits crawl 1.10m capsule")
	step_feet.x = 0
	_check(not _clear(crawl, step_feet, false), "0.80m headroom blocks crawl 1.10m capsule")
	_check(_clear(prone, step_feet, true), "0.80m headroom admits prone horizontal capsule, 0.70m high")
	var tunnel_feet := Vector3(5, 0.01, 0)
	_check(_clear(prone, tunnel_feet, true, 0), "0.90m tunnel admits straight prone capsule")
	_check(not _clear(prone, tunnel_feet, true, PI / 2.0), "0.90m tunnel blocks 90 degree prone rotation")
	# A capsule's height bound is observable directly, so minimum height must
	# be explained in the Inspector rather than silently treated as arbitrary.
	var minimum := _shape(0.5)
	print("MINIMUM_CAPSULE: requested height=0.50m/radius=0.35m; actual height=", minimum.height, "; actual radius=", minimum.radius)
	print("This checks candidate shape volumes only. It does not prove automatic posture transitions.")
	for failure in failures:
		printerr("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)


func _shape(height: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = height
	return shape


func _clear(shape: Shape3D, feet: Vector3, horizontal: bool, yaw: float = 0.0) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = character.collision_mask
	query.exclude = [character.get_rid()]
	query.margin = 0.002
	var basis := Basis(Vector3.UP, yaw)
	var height := (shape as CapsuleShape3D).height
	var offset := height * 0.5
	if horizontal:
		basis = basis * Basis(Vector3.RIGHT, PI / 2.0)
		offset = (shape as CapsuleShape3D).radius
	query.transform = Transform3D(basis, feet + Vector3.UP * offset)
	return character.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _add_box(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	world.add_child(body)
	body.position = position


func _check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ", message)
	if not condition:
		failures.append(message)
