@tool
extends SkeletonModifier3D
## Eén pose-uitvoerder; de planner bewaart alleen doelen en schrijft nooit de capsule.
var driver: Node
func _process_modification_with_delta(_delta: float) -> void:
	if is_instance_valid(driver):
		driver.apply_render_pose(get_skeleton())
