@tool
extends RefCounted
## Drie meetbare humanoïde rustskeletten, niet drie versies van de staplogica.
static func build(variant: int, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Proeflichaam"
	var skeleton := Skeleton3D.new()
	root.add_child(skeleton)
	skeleton.name = "Skeleton3D"
	var upper := [0.38, 0.49, 0.27][clampi(variant, 0, 2)] as float
	var lower := [0.38, 0.32, 0.44][clampi(variant, 0, 2)] as float
	var upper_arm := [0.28, 0.31, 0.22][clampi(variant, 0, 2)] as float
	var forearm := [0.25, 0.23, 0.29][clampi(variant, 0, 2)] as float
	var hip_y := upper + lower + 0.11
	_add(skeleton, "hips", -1, Vector3(0.0, hip_y, 0.0))
	_add(skeleton, "spine.002", 0, Vector3(0.0, 0.29, 0.0))
	_add(skeleton, "head", 1, Vector3(0.0, 0.34, 0.0))
	for side in range(2):
		var suffix := ".l" if side == 0 else ".r"
		var sign_side := -1.0 if side == 0 else 1.0
		var thigh := skeleton.get_bone_count()
		_add(skeleton, "thigh" + suffix, 0, Vector3(sign_side * 0.115, 0.0, 0.0))
		_add(skeleton, "calf" + suffix, thigh, Vector3(0.0, -upper, 0.0))
		_add(skeleton, "foot" + suffix, thigh + 1, Vector3(0.0, -lower, 0.0))
		_add(skeleton, "toes" + suffix, thigh + 2, Vector3(0.0, -0.045, -0.14))
		var arm := skeleton.get_bone_count()
		_add(skeleton, "upperarm" + suffix, 1, Vector3(sign_side * 0.22, 0.18, 0.0))
		_add(skeleton, "forearm" + suffix, arm, Vector3(sign_side * 0.08, -sqrt(upper_arm * upper_arm - 0.0064), 0.0))
		_add(skeleton, "hand" + suffix, arm + 1, Vector3(0.0, -forearm, 0.0))
	for bone in range(skeleton.get_bone_count()):
		var children := skeleton.get_bone_children(bone)
		if children.is_empty():
			_visual(skeleton, bone, Vector3(0.0, 0.14 if skeleton.get_bone_name(bone) == "head" else -0.07, 0.0), color, 0.10 if skeleton.get_bone_name(bone) == "head" else 0.045)
		else:
			for child in children:
				var child_name := skeleton.get_bone_name(child)
				if child_name.begins_with("thigh") or child_name.begins_with("upperarm"):
					continue
				_visual(skeleton, bone, skeleton.get_bone_rest(child).origin, color, 0.115 if bone < 2 else 0.055)
	return root

static func _add(skeleton: Skeleton3D, bone: String, parent: int, offset: Vector3) -> void:
	skeleton.add_bone(bone)
	var index := skeleton.get_bone_count() - 1
	skeleton.set_bone_parent(index, parent)
	skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))
	skeleton.reset_bone_pose(index)

static func _visual(skeleton: Skeleton3D, bone: int, end: Vector3, color: Color, radius: float) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(attachment)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(radius * 2.0, end.length())
	capsule.radial_segments = 10
	capsule.rings = 4
	mesh.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material_override = material
	attachment.add_child(mesh)
	mesh.position = end * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, end.normalized())
