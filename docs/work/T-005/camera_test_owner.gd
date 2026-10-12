extends "res://characters/character.gd"
var test_profile: String = "lopen"
var test_mix: float = 0.0
var test_eye: float = 1.62
var test_clearance: float = 1.8
func get_camera_motion_profile(): return test_profile
func get_fov_speed_mix(): return test_mix
func get_eye_height(): return test_eye
func get_camera_clearance_height(): return test_clearance
