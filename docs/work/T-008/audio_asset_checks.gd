extends SceneTree
## Controleert de echt geïmporteerde buffers; geen luister-/kwaliteitsclaim.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func run() -> void:
	var count := 0
	for name in DirAccess.get_files_at("res://assets/audio"):
		if not name.ends_with(".wav"):
			continue
		var stream := load("res://assets/audio/" + name) as AudioStreamWAV
		check(stream != null, name + " importeert als WAV")
		if stream == null:
			continue
		count += 1
		check(not stream.stereo and stream.mix_rate == 22050, name + " mono 22050Hz")
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.data.size() > 1000, name + " echte 16-bit PCM")
		var playback := stream.instantiate_playback()
		playback.start()
		var frames := playback.mix_audio(1.0, ceili(stream.get_length() * AudioServer.get_mix_rate()))
		var peak := 0.0
		for frame in frames:
			peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		check(peak > 0.01 and peak < 0.502, name + " werkelijk afspeelbare begrensde buffer")
		print("AUDIO_BUFFER: ", name, " seconds=", stream.get_length(), " peak=", peak)
	check(count == 13, "alle dertien gekozen assets aanwezig")
	var original := load("res://assets/audio/slide_scrape_loop.wav") as AudioStreamWAV
	var loop := original.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.data.size() / 2
	var playback := loop.instantiate_playback()
	playback.start()
	var loop_frames := playback.mix_audio(1.0, int(AudioServer.get_mix_rate() * 2.4))
	check(loop_frames.size() >= int(AudioServer.get_mix_rate() * 2.3) and playback.is_playing(), "lokale loop blijft afspelen over meerdere periodes")
	check(original.loop_mode == AudioStreamWAV.LOOP_DISABLED, "loopkopie muteert gedeelde bron niet")
	check(loop.data.decode_s16(0) == 0 and loop.data.decode_s16(loop.data.size() - 2) == 0, "loopgrens sluit zonder DC-sprong op nul aan")
	print("AUDIO_ASSET_CHECKS failures=", failures)
	quit(0 if failures == 0 else 1)
