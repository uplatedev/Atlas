extends "res://tests/procedural_live_preview.gd"

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	var file:=FileAccess.open("user://t011_live_metrics.json",FileAccess.WRITE)
	metrics["environment"]={"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"physics_hz":Engine.physics_ticks_per_second,"warmup_seconds":3.0,"sample_seconds":4.0,"vsync":false,"fixed_fps":false}
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	await AUDIO_SHUTDOWN.drain(self)
	quit()