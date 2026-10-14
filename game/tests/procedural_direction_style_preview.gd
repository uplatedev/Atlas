extends "res://tests/procedural_live_preview.gd"
## Werkelijke zijhup en diagonale rencyclus; geen ingevoerde poseframes.
func _run() -> void:
	Engine.max_fps=144
	for mode in ["side_jog","side_run","diagonal_forward","diagonal_back"]:
		_build(1,false)
		focus=0
		camera.size=2.35
		view_offset=Vector3(0.0,1.0,-4.0)
		await _ticks(25)
		var intent:=AtlasCharacterIntent.new()
		intent.run=mode!="side_jog"
		intent.movement=Vector2(1,0) if mode.begins_with("side") else Vector2(1,-1 if mode=="diagonal_forward" else 1).normalized()
		actors[0].submit_intent(intent)
		await _ticks(90)
		await _await_kind("none",0.10,0.45)
		await _capture(mode+"_support")
		await _await_kind("stride",0.70,0.88)
		await _capture(mode+"_flight")
		world.queue_free()
		actors.clear()
		frames.clear()
		await _ticks(3)
	await AUDIO_SHUTDOWN.drain(self)
	quit()
