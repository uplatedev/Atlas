extends "res://tests/procedural_live_preview.gd"
## Herhaalbare beeldproef: drie seconden echte beweging na twee seconden inlopen, eigen side/front/rearbeelden.
## Voorbeeld: --fixed-fps 60 -- --style=walk --view=side. GIFs worden buiten de bronhistorie opgebouwd.
func _run() -> void:
	Engine.max_fps = 0
	var style := "walk"
	var view := "side"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--style="):
			style = argument.trim_prefix("--style=")
		if argument.begins_with("--view="):
			view = argument.trim_prefix("--view=")
	if style not in ["walk", "jog", "run", "shuffle", "shuffle_run"] or view not in ["side", "front", "rear"]:
		printerr("Gebruik style=walk/jog/run/shuffle/shuffle_run en view=side/front/rear")
		quit(1)
		return
	_build(1, false)
	root.size = Vector2i(800, 600)
	focus = 0
	camera.size = 1.85
	camera.cull_mask = 1 | (1 << (actors[0].get_presentation_layer()-1))
	view_offset = Vector3(4.0, 1.0, 0.0) if view == "side" else Vector3(0.0, 1.0, -4.0 if view == "front" else 4.0)
	await _ticks(30)
	var intent := AtlasCharacterIntent.new()
	intent.movement = Vector2(1, 0) if style.begins_with("shuffle") else Vector2(0, -1)
	intent.walk = style == "walk"
	intent.run = style in ["run", "shuffle_run"]
	actors[0].submit_intent(intent)
	await _ticks(120)
	var output_dir := "user://t011_gait_review/" + style + "_" + view
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var overlay := Label.new()
	overlay.position = Vector2(18, 16)
	overlay.add_theme_font_size_override("font_size", 22)
	root.add_child(overlay)
	var records: Array = []
	var previous_tick := -1
	for sample in range(180):
		await RenderingServer.frame_post_draw
		var physics_tick := Engine.get_physics_frames()
		if previous_tick >= 0 and physics_tick - previous_tick != 1:
			printerr("Beeldproef vereist precies één physics-tick per PNG; gebruik --fixed-fps 60.")
			quit(1)
			return
		previous_tick = physics_tick
		var frame: AtlasCharacterContactFrame = frames[0]
		var presentation: AtlasCharacterPresentation = actors[0].get_node("Presentation/ProceduralBody")
		overlay.text = "%s · %.1f m/s · %s" % [style, frame.horizontal_speed, view]
		records.append({"sample": sample, "physics_tick": physics_tick, "step": frame.step_index, "phase": frame.gait_phase, "air": frame.air_kind, "foot_contacts": frame.foot_contacts.size(), "locked": presentation._locked.duplicate()})
		root.get_texture().get_image().save_png(output_dir + "/%04d.png" % sample)
	var output := FileAccess.open(output_dir + "/frames.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(records, "\t"))
	output.close()
	print("GAIT_REVIEW_FRAMES ", ProjectSettings.globalize_path(output_dir))
	await AUDIO_SHUTDOWN.drain(self)
	quit()

func _process(_delta: float) -> bool:
	if is_instance_valid(camera) and not actors.is_empty():
		# Dezelfde geïnterpoleerde wereldpositie als het model, zodat de meetcamera
		# geen physics/render-trilling aan de zichtbare pas toevoegt.
		var center := actors[0].get_global_transform_interpolated().origin
		camera.position = center + view_offset
		camera.look_at(center + Vector3.UP * 0.82)
	return false
