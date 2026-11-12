class_name Lurker
extends OriginalEnemy
## Enemy kind 49, by the original's rules (Research/enemy_49_91.md, read
## from the code at bank 5, $9249 and $934C to $93D3).
##
## It waits where it is placed, and cannot be touched or hit while it
## waits. When the turtle is 32 to 79 pixels away across it comes out,
## walks at him at 1 pixel an update and throws kind 4A every 32 updates.
## If he gets within 16 pixels it goes back in.

const KINDS := { 0x49: true }
const OUT_FROM := 32              ## comes out with the turtle this far away...
const OUT_UNTIL := 80             ## ...and less than this
const IN_WITHIN := 16             ## goes back in with him nearer than this
const WALK_SPEED := 256
const DROP_SPEED := 3             ## whole pixels an update when the floor ends
const FALL_PULL := 36
const THROW_EVERY := 32           ## updates
const THROWN_KIND := 0x4A
const THROWN_UP := 16
const WAITING := 0x50
const COMING_OUT := 0x51
const GOING_IN := 0x52
const WALKING := 0x53
const THROWING := 0x54
const ANIMATIONS := {
	WAITING: [16, [0x90], LOOPS],
	COMING_OUT: [8, [0x90, 0x91, 0x92], ENDS],
	GOING_IN: [8, [0x92, 0x91, 0x90], ENDS],
	WALKING: [8, [0x93, 0x94], LOOPS],
	THROWING: [8, [0x95], ENDS],
}

enum Mode { COME_OUT, OUT, DROP, THROW, GO_IN }

var mode := Mode.COME_OUT
var timer := 0

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return 0x49

func _first_animation() -> int:
	return WAITING

## While it waits it can neither hurt nor be hurt (the original's list at
## bank 6, $963F: kind 49 showing animation 50).
func _touch(turtle: Turtle) -> void:
	if animation != WAITING:
		super._touch(turtle)

func _on_weapon_entered(area: Area2D) -> void:
	if animation != WAITING:
		super._on_weapon_entered(area)

func _act() -> void:
	if not busy:
		var across := face_turtle()
		if across >= OUT_FROM and across < OUT_UNTIL:
			set_animation(COMING_OUT)
			mode = Mode.COME_OUT
			busy = true
		return
	match mode:
		Mode.COME_OUT, Mode.THROW:
			if animation_ended():
				mode = Mode.OUT
		Mode.OUT:
			_out()
		Mode.DROP:
			speed_y += FALL_PULL
			if something_behind(12, 4) and land():
				mode = Mode.OUT   # but landing also ends "busy": it starts over from waiting
		Mode.GO_IN:
			if animation_ended():
				set_animation(WAITING)
				busy = false

func _out() -> void:
	if not something_behind(10, -1):
		set_fall_pixels(DROP_SPEED)
		stop_across()
		mode = Mode.DROP
		return
	if face_turtle() < IN_WITHIN:
		stop()
		set_animation(GOING_IN)
		mode = Mode.GO_IN
		return
	timer = (timer + 1) & 255
	if timer % THROW_EVERY == 0:
		stop()
		var thrown := throw_object(Missile.new(), THROWN_KIND, 0, -THROWN_UP)
		set_animation(THROWING)
		mode = Mode.THROW
		if thrown != null:
			thrown.tick()
		return
	if animation != WALKING:
		set_animation(WALKING)
	set_off(WALK_SPEED)
	if wall_ahead(22, -36):
		stop_across()
