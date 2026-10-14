extends "res://tests/procedural_live_preview.gd"
## Rendererbewijs van WALK/tegenbeweging en knieslide, met controle van echte huidvertices.
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=144
	_build(4,true)
	await _ticks(30)
	focus=0
	camera.cull_mask=1 | (1 << (actors[0].get_presentation_layer()-1))
	camera.size=2.35
	_intent(1.0)
	await _ticks(50)
	view_offset=Vector3(4.0,1.1,0.0)
	await _ticks(2)
	await _capture("style_walk_side")
	view_offset=Vector3(0.0,1.1,4.0)
	for sample in range(3):
		await _ticks(4)
		await _capture("style_walk_back_%d"%sample)
	_intent(1.0,true)
	await _ticks(50)
	for sample in range(3):
		await _ticks(4)
		await _capture("style_run_back_%d"%sample)
	view_offset=Vector3(4.0,1.1,0.0)
	await _ticks(2)
	await _capture("style_run_side")
	_intent(1.0,true,false,true)
	for tick in range(120):
		await _ticks(1)
		if actors.all(func(actor): return actor.get_debug_state().slide_active):
			break
	await _ticks(3)
	await _capture("style_knee_slide_side")
	var view:AtlasCharacterPresentation=actors[0].get_node("Presentation/ProceduralBody")
	var min_height:=100.0
	var foot_min_height:=100.0
	var vertices:=0
	for child in view._visual.find_children("*","MeshInstance3D",true,false):
		if child.skin==null:
			continue
		var baked:Mesh=child.bake_mesh_from_current_skeleton_pose()
		for surface in range(baked.get_surface_count()):
			for point in baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var local:Vector3=actors[0].to_local(child.global_transform*point)
				min_height=minf(min_height,local.y)
				if local.z>0.15:
					foot_min_height=minf(foot_min_height,local.y)
				vertices+=1
	var report:={"min_skin_y":min_height,"min_rear_skin_y":foot_min_height,"readback_vertices":vertices,"min_world_skin_y":min_height+actors[0].global_position.y,"body_y":actors[0].global_position.y}
	print("SLIDE_SKIN ",JSON.stringify(report))
	var file:=FileAccess.open("user://t011_slide_skin.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	view_offset=Vector3(0.0,1.0,-4.0)
	await _ticks(2)
	await _capture("style_knee_slide_front")
	focus=-1
	camera.cull_mask=(1 << 20)-1
	camera.size=8.8
	view_offset=Vector3(4.6,2.4,-7.5)
	await _ticks(2)
	await _capture("style_knee_slide_four")
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	quit(0 if min_height> -0.002 and foot_min_height> -0.002 else 1)
