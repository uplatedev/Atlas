extends SceneTree

func _initialize() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var rate := AudioServer.get_mix_rate()
	var info: Dictionary = {}
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".ogg"):
			continue
		var source := directory.path_join(name)
		var stream := AudioStreamOggVorbis.load_from_file(source)
		if stream == null:
			push_error("Niet decodeerbaar: " + name)
			quit(1)
			return
		var playback := stream.instantiate_playback()
		playback.start()
		var frames := playback.mix_audio(1.0, ceili(stream.get_length() * rate) + 512)
		var mono := PackedFloat32Array()
		for frame in frames:
			mono.append((frame.x + frame.y) * 0.5)
		var file := FileAccess.open(directory.path_join(name + ".f32"), FileAccess.WRITE)
		file.store_buffer(mono.to_byte_array())
		file.close()
		info[name] = {"mix_rate": rate, "source_seconds": stream.get_length(), "frames": frames.size()}
	var report := FileAccess.open(directory.path_join("decode.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(info, "\t"))
	print("Gedecodeerd: ", info.size(), " originele monofoleys op ", rate, " Hz")
	quit()
