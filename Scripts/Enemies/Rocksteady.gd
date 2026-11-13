class_name Rocksteady
extends Boss
## Object kind 71, the boss of world 1's last room (it looks like
## Rocksteady). Written from the original's routine at bank 5, $AC0B
## (Research/encounters.md), state by state:
##   0  April is put at the left of the screen (the room scene shows her);
##   1  turns to the turtle and sets off at 2 pixels an update;
##   2  walking. Nothing under it: it falls (state 4). Under 32 pixels
##      from the turtle (across only): a jump. After 28 updates: it shoots;
##   3  the jump: 7 pixels an update upward;
##   4  in the air; landing, state 7;
##   5  turns to the turtle, stops and fires a bullet (kind 19);
##   6  plays the firing animation through, then state 1;
##   7  stands. When bits 1 to 3 of the frame counter are all 0: state 1
##      if bit 6 is set, state 5 (a shot) if not.

const KIND := 0x71
const WALK_SPEED := 512
const JUMP_SPEED := -1792
const JUMP_WITHIN := 32
const WALK_UPDATES := 28
const WALK := 0x45
const STAND := 0x46
const FIRE := 0x47
const JUMP := 0x48
const ANIMATIONS := {
	WALK: [16, [0x87, 0x88, 0x89], LOOPS],
	STAND: [16, [0x8A], LOOPS],
	FIRE: [16, [0x8A, 0x8B, 0x8A], ENDS],
	JUMP: [16, [0x8D], LOOPS],
}
const BULLET_UP := -20

func _animations() -> Dictionary:
	return ANIMATIONS

func _default_kind() -> int:
	return KIND

func _first_animation() -> int:
	return STAND

func _run_state() -> void:
	match state:
		0:
			state = 1
		1:
			face()
			set_off(WALK_SPEED)
			set_animation(WALK)
			go(2)
		2:
			stop_at_wall()
			state_ticks += 1
			if kind_at(0, -4) == RoomData.KIND_EMPTY:
				go(4)
				return
			turn_at_edge()
			if gap() < JUMP_WITHIN:
				go(3)
			elif state_ticks >= WALK_UPDATES:
				go(5)
		3:
			speed_y = JUMP_SPEED
			state = 4
			set_animation(JUMP)
		4:
			fly(FLIGHT)
			if land(LAND_UP):
				state = 7
		5:
			face()
			stop_across()
			var bullet := throw_object(Bullet.new(), Bullet.KIND, 0, BULLET_UP)
			if bullet != null:
				bullet.update_now()
			state = 6
			set_animation(FIRE)
		6:
			if animation_ended():
				set_animation(STAND)
				go(1)
		_:
			set_animation(STAND)
			stop()
			if (counter() >> 1) & 0x07 == 0:
				state = 1 if counter() & 0x40 != 0 else 5
