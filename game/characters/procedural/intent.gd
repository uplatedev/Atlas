@tool
class_name AtlasCharacterIntent
extends RefCounted
## Dezelfde besturingsinvoer voor speler en AI. Edges gelden één physicstick.

var movement: Vector2 = Vector2.ZERO
var sprint: bool = false
var sneak: bool = false
var jump_pressed: bool = false
var crouch_pressed: bool = false
var prone_pressed: bool = false
var has_look_direction: bool = false
var look_direction: Vector2 = Vector2.ZERO


func copy() -> AtlasCharacterIntent:
	var result := AtlasCharacterIntent.new()
	result.movement = movement.limit_length(1.0)
	result.sprint = sprint
	result.sneak = sneak
	result.jump_pressed = jump_pressed
	result.crouch_pressed = crouch_pressed
	result.prone_pressed = prone_pressed
	result.has_look_direction = has_look_direction
	result.look_direction = look_direction
	return result


func clear_edges() -> void:
	jump_pressed = false
	crouch_pressed = false
	prone_pressed = false
