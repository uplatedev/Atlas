extends SceneTree
## Echte motorbeelden en realtime frametijden; geen fixed-fps simulatie.
const CHARACTER = preload("res://characters/Character.tscn")
const AUDIO_SHUTDOWN = preload("res://tests/test_audio_shutdown.gd")
var world: Node3D
var actors: Array[AtlasCharacter] = []
var camera: Camera3D
var frames: Dictionary = {}
var intervals: Array[float] = []
var process_times: Array[float] = []
var physics_times: Array[float] = []
var collect: bool = false
var last_usec: int = 0
var query_count: int = 0
var metrics: Dictionary = {}
var follow: bool = true
var focus: int = -1
var view_offset := Vector3(4.6, 2.4, -7.5)

func _initialize() -> void:
	call_deferred("_run")

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if collect and last_usec > 0:
		intervals.append(float(now-last_usec)/1000.0)
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	last_usec = now
	if follow and is_instance_valid(camera) and not actors.is_empty():
		var center := Vector3.ZERO
		for actor in actors:
			center += actor.global_position
		center /= actors.size()
		if focus >= 0:
			center = actors[focus].global_position
		camera.position = center + view_offset
		camera.look_at(center + Vector3.UP*0.9)
	return false

func _build(count: int, varied: bool) -> void:
	world = Node3D.new()
	root.add_child(world)
	root.size=Vector2i(1280,800)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color(0.045,0.063,0.09)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color(0.7,0.8,1.0)
	settings.ambient_light_energy=0.65
	environment.environment=settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-35,-20,0)
	sun.light_energy=1.6
	sun.shadow_enabled=true
	world.add_child(sun)
	var floor_body:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(500,0.2,500)
	collider.shape=shape
	collider.position.y=-0.1
	floor_body.add_child(collider)
	var mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(500,500)
	mesh.mesh=plane
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(0.19,0.24,0.28)
	material.roughness=1.0
	material.albedo_texture=load("res://assets/prototype/kenney_light_grid.png")
	material.uv1_scale=Vector3(250,250,1)
	mesh.material_override=material
	floor_body.add_child(mesh)
	world.add_child(floor_body)
	for index in range(count):
		var actor:=CHARACTER.instantiate() as AtlasCharacter
		actor.position=Vector3((index%4)*1.8-2.7,0.04,(index/4)*2.5)
		actor.name_visible=false
		actor.debug_enabled=false
		actor.feedback_enabled=false
		if varied and index>0:
			actor.body_profile=AtlasCharacterBodyProfile.new()
			actor.body_profile.test_body=index-1
			actor.body_profile.test_color=[Color(0.24,0.65,0.85),Color(0.85,0.55,0.23),Color(0.36,0.76,0.50)][index-1]
		actor.contact_frame_ready.connect(func(frame:AtlasCharacterContactFrame):
			frames[index]=frame
			if collect:
				query_count+=int(actor.get_debug_state().stride_probe_count)+int(actor.get_node("Presentation/ProceduralBody").get_debug_state().rays_last_frame))
		actors.append(actor)
		world.add_child(actor)
	camera=Camera3D.new()
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=8.8 if count<=4 else 12.5
	camera.current=true

func _intent(amount:float,run:bool=false,jump:bool=false,crouch:bool=false,prone:bool=false) -> void:
	for actor in actors:
		var intent:=AtlasCharacterIntent.new()
		intent.movement=Vector2(0,-amount)
		intent.run=run
		intent.jump_pressed=jump
		intent.crouch_pressed=crouch
		intent.prone_pressed=prone
		actor.submit_intent(intent)

func _ticks(count:int) -> void:
	for tick in range(count):
		await physics_frame
		await process_frame

func _capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	var path:="user://t011_live_"+name+".png"
	root.get_texture().get_image().save_png(path)
	print("LIVE_IMAGE ",ProjectSettings.globalize_path(path))

func _await_kind(kind:String, lower:float=0.0,upper:float=1.0) -> void:
	for tick in range(150):
		await _ticks(1)
		if frames.has(0):
			var f:AtlasCharacterContactFrame=frames[0]
			if f.air_kind==kind and f.gait_phase>=lower and f.gait_phase<=upper:
				return

func _detail_views() -> void:
	focus=0
	camera.cull_mask=1 | (1 << (actors[0].get_presentation_layer()-1))
	camera.size=2.35
	view_offset=Vector3(4.0,1.1,0.0)
	for sample in range(6):
		await _ticks(2)
		await _capture("artemis_side_%d"%sample)
	view_offset=Vector3(0.0,1.1,-4.0)
	await _ticks(2)
	await _capture("artemis_front")
	view_offset=Vector3(0.0,1.1,4.0)
	await _ticks(2)
	await _capture("artemis_back")
	focus=-1
	camera.cull_mask=(1 << 20)-1
	camera.size=8.8
	view_offset=Vector3(4.6,2.4,-7.5)
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=144
	_build(4,true)
	await _ticks(15)
	await _capture("idle")
	_intent(0.2)
	await _ticks(50)
	await _capture("slow")
	_intent(1.0,true)
	await _ticks(50)
	await _await_kind("none",0.05,0.48)
	await _capture("run_support")
	await _await_kind("stride",0.65,0.88)
	await _capture("run_flight")
	await _detail_views()
	_intent(1.0,true,true)
	await _ticks(8)
	await _capture("jump")
	_intent(1.0,true,false,true)
	for tick in range(120):
		await _ticks(1)
		if bool(actors[0].get_debug_state().slide_active):
			break
	await _capture("slide")
	_intent(0.0)
	await _ticks(75)
	for actor in actors:
		actor.request_posture(AtlasCharacter.Posture.CROUCH)
	await _ticks(12)
	await _capture("crouch")
	for actor in actors:
		actor.request_posture(AtlasCharacter.Posture.PRONE)
	await _ticks(12)
	await _capture("prone")
	if OS.get_cmdline_user_args().has("--poses-only"):
		world.queue_free()
		await AUDIO_SHUTDOWN.drain(self)
		quit()
		return
	world.queue_free()
	actors.clear()
	frames.clear()
	await _ticks(4)
	for count in [1,4,12]:
		Engine.max_fps=0
		_build(count,false)
		_intent(1.0,true)
		await create_timer(3.0).timeout
		intervals.clear()
		process_times.clear()
		physics_times.clear()
		query_count=0
		collect=true
		var start:=Time.get_ticks_usec()
		await create_timer(4.0).timeout
		collect=false
		var elapsed:=float(Time.get_ticks_usec()-start)/1000000.0
		var result:={"wall_seconds":elapsed,"render_frames":intervals.size(),"frame_ms":_stats(intervals),"process_cpu_ms":_stats(process_times),"physics_cpu_ms":_stats(physics_times),"queries":query_count,"queries_per_second":float(query_count)/elapsed}
		metrics[str(count)]=result
		print("LIVE_PERFORMANCE ",count," ",JSON.stringify(result))
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(4)
	follow=false
	var main:Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await _ticks(15)
	await _capture("main")
	main.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	var file:=FileAccess.open("user://t011_live_metrics.json",FileAccess.WRITE)
	metrics["environment"]={"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"physics_hz":Engine.physics_ticks_per_second,"warmup_seconds":3.0,"sample_seconds":4.0,"vsync":false,"fixed_fps":false}
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	print("LIVE_METRICS ",ProjectSettings.globalize_path("user://t011_live_metrics.json"))
	quit()

func _stats(values:Array[float]) -> Dictionary:
	values.sort()
	if values.is_empty():
		return {}
	return {"p50":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*0.95))],"max":values[-1]}




