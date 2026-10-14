extends "res://tests/procedural_live_preview.gd"
## Zijaanzicht rond echte spronglanding; dezelfde motor als de speelbare Character.
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=144
	_build(1,false)
	focus=0
	camera.size=2.35
	view_offset=Vector3(4.0,1.1,0.0)
	await _ticks(30)
	await _capture("soft_idle")
	_intent(0.0,false,true)
	await _ticks(10)
	await _capture("soft_jump")
	for tick in range(120):
		await _ticks(1)
		if frames.has(0) and frames[0].landed:
			break
	await _capture("soft_contact")
	await _ticks(3)
	await _capture("soft_compressed")
	await _ticks(8)
	await _capture("soft_release")
	await _ticks(16)
	await _capture("soft_settled")
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	quit()
