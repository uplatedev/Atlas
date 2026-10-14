extends "res://tests/procedural_live_preview.gd"
## Echte rustige Alt-wandelpas naast jog en sprint; vaste camera voor beoordeling.
func _run() -> void:
	_build(4, true)
	await _ticks(30)
	focus = 0
	camera.cull_mask = 1 | (1 << (actors[0].get_presentation_layer()-1))
	camera.size = 2.25
	for style in ["walk", "jog", "sprint"]:
		for actor in actors:
			var intent := AtlasCharacterIntent.new()
			intent.movement = Vector2(0, -1)
			intent.sneak = style == "walk"
			intent.sprint = style == "sprint"
			actor.submit_intent(intent)
		await _ticks(90)
		view_offset = Vector3(4, 1.1, 0)
		for sample in range(6):
			await _ticks(3)
			await _capture(style + "_side_" + str(sample))
		view_offset = Vector3(0, 1.1, -4)
		await _ticks(3)
		await _capture(style + "_front")
	await AUDIO_SHUTDOWN.drain(self)
	quit()
