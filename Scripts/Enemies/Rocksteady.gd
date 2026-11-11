class_name Rocksteady
extends Boss
## Object kind 71: the boss of world 1's last room. It looks like Rocksteady.
##
## Every number here is from one 25-second recording of the USA ROM with the
## turtle standing still (Research/world1.md). The boss repeated the same
## round over and over in it: walk up, shoot, walk a little closer, jump
## over the turtle, jump back. This script plays that round. How the
## original chooses its moves is not known, so against a moving turtle the
## real boss may well act differently.

const KIND := 0x71
const WALK_SPEED := 512          ## 2 px per update
const GRAVITY := 78              ## added to the fall speed every update
const JUMP_SPEED := -1792        ## upward speed at the start of a jump
const JUMP_CUT_TICKS := 20       ## the rise is stopped dead after 20 updates, 82 pixels up
const SINK := 4.0                ## rides 4 pixels below the floor's top edge
const SHOOT_DISTANCE := 34.0     ## it stopped to shoot 31 and 36 pixels from the turtle
const SHOOT_TICKS := 48          ## stands this long, firing one bullet at the start
const CLOSE_IN_TICKS := 12       ## then walks at him this long before the first jump
const REST_AFTER_FIRST_JUMP := 5
const REST_AFTER_SECOND_JUMP := 6
const BULLET := 0x19
const WALL_LOOK := 20.0          ## a wall this close stopped its jump sideways

enum State { ENTER, WALK, SHOOT, CLOSE_IN, JUMP, REST }

var state := State.ENTER
var fall_speed := 0
var state_ticks := 2
var jumps_done := 0
var air_ticks := 0

func _init() -> void:
	kind = KIND
	health = 96
	full_health = 96
	touch_damage = 23

func _on_floor() -> bool:
	return room.solid_at(position.x, position.y)

func _wall_ahead() -> bool:
	var ahead := position.x + direction * WALL_LOOK
	return ahead < 0.0 or ahead >= room.size_pixels().x or room.solid_at(ahead, position.y - 8.0)

## One game update.
func tick() -> void:
	match state:
		State.ENTER:
			# It walks off the ledge it appears on and drops to the floor.
			if state_ticks > 0:
				state_ticks -= 1
				position.x += direction * WALK_SPEED / 256.0
			else:
				_fall(true)
		State.JUMP:
			_fall(true)
		State.WALK:
			if not _on_floor():
				state = State.JUMP
				fall_speed = 0
			elif absf(_face_turtle()) <= SHOOT_DISTANCE:
				state = State.SHOOT
				state_ticks = SHOOT_TICKS
				Shot.fire(self, BULLET, direction, room, target)
			elif not _wall_ahead():
				position.x += direction * WALK_SPEED / 256.0
		State.SHOOT:
			state_ticks -= 1
			if state_ticks <= 0:
				state = State.CLOSE_IN
				state_ticks = CLOSE_IN_TICKS
				jumps_done = 0
		State.CLOSE_IN:
			_face_turtle()
			if not _wall_ahead():
				position.x += direction * WALK_SPEED / 256.0
			state_ticks -= 1
			if state_ticks <= 0:
				_jump()
		State.REST:
			state_ticks -= 1
			if state_ticks <= 0:
				if jumps_done == 1:
					_jump()     # straight back over him
				else:
					state = State.WALK

func _jump() -> void:
	_face_turtle()
	state = State.JUMP
	fall_speed = JUMP_SPEED
	air_ticks = 0
	jumps_done += 1

func _fall(sideways: bool) -> void:
	if sideways and not _wall_ahead():
		position.x += direction * WALK_SPEED / 256.0
	position.y += fall_speed / 256.0
	air_ticks += 1
	if fall_speed < 0 and air_ticks == JUMP_CUT_TICKS:
		fall_speed = 0
	else:
		fall_speed += GRAVITY
	if fall_speed > 0 and room.solid_at(position.x, position.y - SINK - 1.0):
		air_ticks = 0
		position.y = floorf((position.y - SINK) / RoomData.TILE) * RoomData.TILE + SINK
		if state == State.ENTER:
			state = State.WALK
		else:
			state = State.REST
			state_ticks = REST_AFTER_FIRST_JUMP if jumps_done == 1 else REST_AFTER_SECOND_JUMP
	elif position.y > room.size_pixels().y + 64.0:
		queue_free()

func _animation() -> String:
	if state == State.WALK or state == State.CLOSE_IN or (state == State.ENTER and state_ticks > 0):
		return "walk"
	if state == State.SHOOT:
		return "shoot"
	if state == State.JUMP or state == State.ENTER:
		return "jump"
	return "stand"
