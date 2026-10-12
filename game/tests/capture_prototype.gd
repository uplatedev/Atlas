extends SceneTree
## Alleen QA: maak een render van de echte hoofdscene.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("capture_mouse_on_start", false)
	root.add_child(main)
	for argument in OS.get_cmdline_user_args():
		if argument == "--view=first-person":
			main.get_node("Characters/AtlasA").set_camera_distance(0.0)
		elif argument == "--view=second":
			main.call("set_active_character", 1)
	for i in 45:
		await process_frame
	main.set_process(false)
	main.get_node("UI/MouseHint").visible = false
	await RenderingServer.frame_post_draw
	var target := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			target = argument.trim_prefix("--output=")
	if target.is_empty():
		printerr("Geef -- --output=<absoluut PNG-pad> op.")
		quit(1)
		return
	var image := root.get_texture().get_image()
	var result := image.save_png(target)
	if result != OK:
		printerr("Screenshot opslaan mislukt: ", result)
		quit(1)
		return
	print("Screenshot opgeslagen: ", target)
	quit(0)
