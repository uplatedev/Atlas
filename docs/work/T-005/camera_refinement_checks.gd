extends SceneTree
var failures: int = 0
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
 print("PASS " if value else "FAIL ",message)
 if not value: failures += 1
func run():
 var actor = load("res://characters/Character.tscn").instantiate()
 actor.set_script(load(get_script().resource_path.get_base_dir().path_join("camera_test_owner.gd")))
 root.add_child(actor)
 actor.set_physics_process(false)
 var rig = actor.get_node("CameraPivot")
 rig.set_process(false)
 var lags: Array[float] = []
 for rate in [30,60,144]:
  rig.set_distance(4.0)
  rig.reset_follow_history()
  for frame in rate * 2:
   rig._update_follow_position(Vector3(2.0 * float(frame + 1) / float(rate),0,0),1.0 / float(rate),false)
  var lag: float = rig._previous_follow_target.distance_to(rig._follow_position)
  lags.append(lag)
  check(absf(lag - 2.0 * 0.018 / log(2.0)) < 0.00001, "bewegend doel zelfde minimale camera-achterstand bij %d fps: %.6fm" % [rate,lag])
 check(lags.max() - lags.min() < 0.00001, "positievolging onafhankelijk van renderframerate")
 rig.reset_follow_history()
 for frame in 144:
  rig._update_follow_position(Vector3(100.0 * float(frame + 1) / 144.0,0,0),1.0 / 144.0,false)
 check(rig._previous_follow_target.distance_to(rig._follow_position) <= 0.12001, "hoge snelheid houdt extra achterstand binnen 12cm")
 rig.set_distance(0.0)
 rig._update_follow_position(Vector3(6,0,2),1.0/60.0,false)
 check(rig._follow_position.distance_to(Vector3(6,0,2)) < 0.00001, "first person heeft standaard geen extra positie-lag")
 rig.reset_view()
 var before: float = rig.get_look_yaw()
 rig.apply_look_delta(Vector2(-10,0))
 check(absf(rig.get_look_yaw() - before - deg_to_rad(1.2)) < 0.00001, "muisrichting blijft direct en los van positievolging")
 for profile in ["sneak","kruipen","liggen"]:
  actor.test_profile = profile
  actor.test_mix = 1.0
  for frame in 180: rig._process(1.0/60.0)
  var expected: float = {"sneak":68.0,"kruipen":67.0,"liggen":65.0}[profile]
  check(absf(rig.get_state().camera_fov - expected) < 0.01, "%s heeft eigen zachte FOV zonder oude sprintbonus: %.3f" % [profile,rig.get_state().camera_fov])
 actor.camera_speed_fov_enabled = false
 for frame in 180: rig._process(1.0/60.0)
 check(absf(rig.get_state().camera_fov - 70.0) < 0.01, "F4-uit schakelt ook houdings-FOV uit")
 actor.camera_speed_fov_enabled = true
 actor.test_profile = "prone"
 rig.set_distance(0)
 for frame in 180: rig._process(1.0/60.0)
 check(absf(rig.get_state().camera_fov - 70.0) < 0.01, "lig-FOV gebruikt first-personbasis als bewust ingezoomd")
 actor.test_eye = 0.55
 actor.test_clearance = 0.7
 rig._process(1.0/60.0)
 check(rig.global_position.y <= 0.511, "lage houding blijft met zachte camera direct plafondveilig")
 actor.test_eye = 1.62
 actor.test_clearance = 1.8
 rig.reset_view()
 var wall = StaticBody3D.new()
 var collider = CollisionShape3D.new()
 var shape = BoxShape3D.new()
 shape.size = Vector3(0.2,3,3)
 collider.shape = shape
 wall.add_child(collider)
 wall.position = Vector3(-0.35,1.5,0)
 root.add_child(wall)
 await physics_frame
 await physics_frame
 var safe: Vector3 = rig._safe_follow_anchor(Vector3(0,1.61,0),Vector3(-0.12,1.61,0))
 check(safe.x > -0.075, "kleine camera-achterstand stopt veilig voor zijmuur: %.4f" % safe.x)
 wall.queue_free()
 await physics_frame
 actor.global_position = Vector3(4,0,6)
 actor.reset_physics_interpolation()
 rig.reset_follow_history()
 check(rig.get_state().camera_follow_lag < 0.00001 and rig.global_position.distance_to(Vector3(4,1.61,6)) < 0.01, "reset/wisselen wist positiegeschiedenis zonder zwaai")
 check(not rig.get_node("SpringArm3D").is_physics_processing_internal(), "camera heeft één render-schrijver, geen SpringArm physics-overschrijving")
 print("CAMERA T005 CHECKS failures=",failures)
 quit(0 if failures == 0 else 1)
