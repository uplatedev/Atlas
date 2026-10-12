extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
 call_deferred('_run')
func _run() -> void:
 var character = load('res://characters/Character.tscn').instantiate()
 root.add_child(character)
 character.set_controlled(true)
 character.set_physics_process(false)
 var rig = character.get_node('CameraPivot')
 rig.set_process(false)
 var outcomes: Array[float] = []
 for fps in [30, 60, 144]:
  character.camera_speed_fov_enabled = false
  rig.reset_view()
  rig.set_distance(0.0)
  for frame in fps:
   rig._process(1.0 / float(fps))
  outcomes.append(rig.get_state().camera_fov)
  print('CAMERA RATE ',fps,' Hz: FOV=',rig.get_state().camera_fov,' actualzoom=',rig.get_state().camera_actual_distance)
 if absf(outcomes.max() - outcomes.min()) > 0.01:
  failures.append('FOVhalveringstijd verschilt per renderframerate')
 for failure in failures:
  printerr('FAIL: ',failure)
 character.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
