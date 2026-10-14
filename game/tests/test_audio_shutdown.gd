extends RefCounted
## Alleen testafsluiting: na queue_free de echte audiothread laten uitlopen.
## Een SceneTreeTimer gebruikt met --fixed-fps gesimuleerde tijd en geeft de
## Dummy-audiothread daarom geen betrouwbare gelegenheid om streams los te laten.


static func drain(tree: SceneTree) -> void:
	await tree.process_frame
	OS.delay_msec(120)
	await tree.process_frame
