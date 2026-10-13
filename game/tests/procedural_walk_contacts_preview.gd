extends "res://tests/procedural_live_preview.gd"
## Huidbeelden van lopen vanaf stilstand, zijwaarts lopen, omkeren en smal stoppen.
func _run() -> void:
	Engine.max_fps=144
	_build(1,false)
	focus=0
	camera.size=2.15
	view_offset=Vector3(0.0,1.0,-4.0)
	await _ticks(30)
	await _capture("walk_contact_idle")
	view_offset=Vector3(4.0,1.0,0.0)
	_send_direction(Vector2(0,-1))
	await _ticks(6)
	await _capture("walk_contact_start")
	_send_direction(Vector2.ZERO)
	await _ticks(90)
	view_offset=Vector3(0.0,1.0,-4.0)
	_send_direction(Vector2(1,0))
	await _ticks(60)
	await _await_kind("none",0.15,0.48)
	await _capture("walk_contact_right")
	await _await_kind("stride",0.65,0.90)
	await _capture("walk_contact_right_flight")
	_send_direction(Vector2(-1,0))
	await _ticks(12)
	await _capture("walk_contact_reverse")
	await _ticks(60)
	await _await_kind("none",0.15,0.48)
	await _capture("walk_contact_left")
	_send_direction(Vector2.ZERO)
	await _ticks(8)
	await _capture("walk_contact_stopping")
	await _ticks(90)
	await _capture("walk_contact_stopped")
	world.queue_free()
	await AUDIO_SHUTDOWN.drain(self)
	quit()

func _send_direction(direction:Vector2) -> void:
	for actor in actors:
		var intent:=AtlasCharacterIntent.new()
		intent.movement=direction
		actor.submit_intent(intent)
