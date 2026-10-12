extends SceneTree
var character: AtlasCharacter
var rig: Node3D
var observer: Node
var frames: int = 0
var samples: Array[Dictionary] = []
var fixed_rate: int = 144
var scenario: String = "straight"
func _initialize():
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--fps="): fixed_rate = int(argument.trim_prefix("--fps="))
  if argument.begins_with("--scenario="): scenario = argument.trim_prefix("--scenario=")
 Engine.max_fps = fixed_rate
 call_deferred("run")
func run():
 var floor_body := StaticBody3D.new()
 var floor_shape := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(2000, 0.2, 2000)
 floor_shape.shape = shape
 floor_body.add_child(floor_shape)
 floor_body.position.y = -0.1
 root.add_child(floor_body)
 character = load("res://characters/Character.tscn").instantiate()
 character.position.y = 80.0 if scenario == "fall" else 0.01
 root.add_child(character)
 character.walk_forward_speed = 40.0
 character.walk_acceleration = 2000.0
 character.set_controlled(true)
 rig = character.get_node("CameraPivot")
 rig.set_distance(0.0)
 if scenario != "fall": Input.action_press("move_forward")
 observer = Node.new()
 observer.set_script(load(get_script().resource_path.get_base_dir().path_join("camera_probe_observer.gd")))
 observer.probe = self
 observer.process_priority = 200
 root.add_child(observer)
func sample(delta: float):
 frames += 1
 if frames < fixed_rate: return
 var rendered: Vector3 = character.get_global_transform_interpolated().origin
 samples.append({"dt": delta,"raw": character.global_position.y if scenario == "fall" else character.global_position.z,"interpolated": rendered.y if scenario == "fall" else rendered.z,"camera": rig.global_position.y - 1.61 if scenario == "fall" else rig.global_position.z,"phase": Engine.get_physics_interpolation_fraction(),"physics": Engine.get_physics_frames()})
 if frames >= fixed_rate * 3:
  var raw_stalls := 0
  var interp_stalls := 0
  var camera_stalls := 0
  var max_raw_step := 0.0
  var max_camera_error := 0.0
  var step_speeds: Array[float] = []
  for i in range(1, samples.size()):
   var sample: Dictionary = samples[i]
   var previous: Dictionary = samples[i-1]
   var raw_step := absf(float(sample.raw) - float(previous.raw))
   var interp_step := absf(float(sample.interpolated) - float(previous.interpolated))
   var camera_step := absf(float(sample.camera) - float(previous.camera))
   if raw_step < 0.00001: raw_stalls += 1
   if interp_step < 0.00001: interp_stalls += 1
   if camera_step < 0.00001: camera_stalls += 1
   max_raw_step = maxf(max_raw_step,raw_step)
   max_camera_error = maxf(max_camera_error, absf(float(sample.camera) - float(sample.interpolated)))
   step_speeds.append(camera_step / float(sample.dt))
  print("MEASURE camera-position scenario=",scenario," fps=", fixed_rate, " samples=", samples.size(), " raw_stalls=", raw_stalls, " interp_stalls=", interp_stalls, " camera_stalls=", camera_stalls, " max_raw_step=", max_raw_step, " camera_vs_interpolated_error=",max_camera_error," camera_speed_min/max=",step_speeds.min(),"/",step_speeds.max())
  Input.action_release("move_forward")
  quit()
