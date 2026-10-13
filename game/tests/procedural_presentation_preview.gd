extends SceneTree
## Grafische proef voor lichaamsverhoudingen en rig; schrijft alleen lokale PNGs.
const Profile = preload("res://characters/procedural/body_profile.gd")
const Presentation = preload("res://characters/procedural/presentation.gd")
var _world: Node3D
var _actors: Array[Node3D] = []
var _presentations: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	root.size = Vector2i(1280, 800)
	var environment := WorldEnvironment.new()
	var config := Environment.new()
	config.background_mode = Environment.BG_COLOR
	config.background_color = Color(0.065, 0.085, 0.12)
	config.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	config.ambient_light_color = Color(0.7, 0.8, 1.0)
	config.ambient_light_energy = 0.65
	environment.environment = config
	_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	light.light_energy = 1.6
	_world.add_child(light)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	var floor_mesh := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(20, 20)
	floor_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.19, 0.23)
	floor_mesh.material_override = mat
	floor_body.add_child(floor_mesh)
	_world.add_child(floor_body)
	var camera := Camera3D.new()
	_world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.6
	camera.position = Vector3(2.5, 2.5, 6.8)
	camera.look_at(Vector3(0.0, 0.95, 0.0))
	camera.current = true
	for index in range(4):
		var actor := CharacterBody3D.new()
		_world.add_child(actor)
		actor.position.x = (float(index) - 1.5) * 1.35
		var profile := Profile.new()
		profile.test_body = mini(index, 2)
		profile.test_color = [Color(0.25,0.65,0.88), Color(0.85,0.55,0.23), Color(0.37,0.77,0.54), Color.WHITE][index]
		if index == 3:
			profile.visual_scene = load("res://assets/characters/artemis_rigged.glb") as PackedScene
		var presentation := Presentation.new()
		actor.add_child(presentation)
		presentation.setup(actor, profile)
		_actors.append(actor)
		_presentations.append(presentation)
		var label := Label3D.new()
		label.text = ["Gelijk .38/.38", "Bovenbeen .49/.32", "Onderbeen .27/.44", "Artemis .335/.339"][index]
		label.position.y = 2.0
		label.pixel_size = 0.003
		label.font_size = 30
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)
	await physics_frame
	await physics_frame
	for index in range(_actors.size()):
		_presentations[index].consume_frame(_frame(_actors[index], 0.0, 0.0))
	await process_frame
	await RenderingServer.frame_post_draw
	_capture("t011_bodies_idle.png")
	for tick in range(8):
		for index in range(_actors.size()):
			_actors[index].position.z -= 0.035
			_presentations[index].consume_frame(_frame(_actors[index], 7.0, float(tick) / 20.0))
		await physics_frame
	await RenderingServer.frame_post_draw
	_capture("t011_bodies_stride.png")
	for index in range(_actors.size()):
		_actors[index].position.y = 0.07
		var frame := _frame(_actors[index], 9.0, 0.75)
		frame.supported = false
		frame.air_kind = "stride"
		_presentations[index].consume_frame(frame)
	await physics_frame
	await RenderingServer.frame_post_draw
	_capture("t011_bodies_flight.png")
	for index in range(_actors.size()):
		print("PREVIEW_BODY ", index, " ", _presentations[index].get_debug_state())
	_world.queue_free()
	await process_frame
	quit()

func _frame(actor: Node3D, speed: float, phase: float) -> Dictionary:
	return {"body_transform": actor.global_transform, "horizontal_speed": speed, "gait_phase": phase, "step_index": 0, "air_kind": "none", "posture": "staan", "sliding": false, "body_velocity": Vector3(0.0, 0.0, -speed), "delta": 1.0/60.0, "supported": true, "stride_started": false, "stride_landed": false, "ground_step": false, "foot_contacts": []}

func _capture(name: String) -> void:
	var path := "user://" + name
	root.get_texture().get_image().save_png(path)
	print("PREVIEW_IMAGE ", ProjectSettings.globalize_path(path))


