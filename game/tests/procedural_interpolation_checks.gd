extends "res://tests/procedural_live_preview.gd"
## Readbackdiagnose buiten performance-meting: veranderen huidvertices tussen physics-ticks?
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Deze huidproef vereist een echte renderer; gebruik geen --headless.")
		quit(1)
		return
	_build(1,false)
	_intent(1.0,true)
	await _ticks(60)
	var view:AtlasCharacterPresentation=actors[0].get_node("Presentation/ProceduralBody")
	var skin:MeshInstance3D
	for child in view._visual.find_children("*","MeshInstance3D",true,false):
		if child.skin != null:
			skin=child
			break
	var results:Dictionary={}
	for fps in [60,144]:
		Engine.max_fps=fps
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var previous:PackedVector3Array=[]
		var same_tick:int=0
		var changed_same_tick:int=0
		var changed_total:int=0
		var old_tick:int=-1
		var start:=Time.get_ticks_usec()
		for sample in range(180):
			await RenderingServer.frame_post_draw
			var baked:=skin.bake_mesh_from_current_skeleton_pose()
			var points:PackedVector3Array=[]
			for surface in range(baked.get_surface_count()):
				points.append_array(baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			var difference:=0.0
			if previous.size()==points.size():
				for vertex in range(points.size()):
					difference=maxf(difference,points[vertex].distance_squared_to(previous[vertex]))
			var tick:=Engine.get_physics_frames()
			if old_tick==tick:
				same_tick+=1
				if difference>0.0000000001:
					changed_same_tick+=1
			if difference>0.0000000001:
				changed_total+=1
			previous=points
			old_tick=tick
		results[str(fps)]={"render_samples":180,"wall_seconds":float(Time.get_ticks_usec()-start)/1000000.0,"same_physics_tick_pairs":same_tick,"skin_changed_same_tick":changed_same_tick,"changed_pairs":changed_total}
	print("SKIN_INTERPOLATION ",JSON.stringify(results))
	var file:=FileAccess.open("user://t011_skin_interpolation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	quit()

