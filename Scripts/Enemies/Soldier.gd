class_name Soldier
extends Area2D
## Enemy kind 98, which looks like the foot soldier, and kind 49, which
## walks up the same way but does not hop or attack (see KINDS).
##
## The numbers come from recordings of the USA ROM (Research/enemy_98.md):
## how it falls, hops, walks and how long its kicks and punches last. The
## rules that choose between those are NOT taken from the original's code.
## They are a simple pattern that reproduces what three recordings showed
## with the turtle standing still, and they are marked "pattern" below.

const KIND := 0x98
## What differs between the kinds this script runs. For 49 see
## Research/enemy_49_88_A0.md.
const KINDS := {
	0x98: { "speed": 320, "stop": 23.0, "fall": 512, "hops": true, "attacks": true, "throws": 0x99 },
	0x49: { "speed": 256, "stop": 16.0, "fall": 768, "hops": false, "attacks": false, "throws": 0x4A },
}
const TICK_FRAMES := 2
const WALK_SPEED := 320          ## 1.25 px per update
const FALL_START_SPEED := 512    ## first update of a fall
const GRAVITY := 36              ## added to the fall speed every update
const HOP_SPEED := -1536         ## upward speed at the start of a hop
const HOP_CUT_TICKS := 6         ## after this many updates the rise is stopped dead
const SINK := 3.0                ## rides 3 pixels below the floor's top edge
const STOP_DISTANCE := 23.0      ## it stopped walking this far from the turtle's middle (seen twice)
const WAIT_TICKS := 13           ## stands this long between attacks
const KICK_TICKS := 6
const PUNCH_TICKS := 12
## Pattern: when it does what.
const HOP_DISTANCE := 90.0       ## further away than this on landing, it hops closer (seen at 96 and 120, not at 16)
const REST_AFTER_FALL := 26      ## updates it waited before walking (one sample)
const REST_AFTER_HOP := 25       ## after a hop it stands this long, then throws
const STARS := 8                 ## ...this many of kind 99, one every 13 updates, before walking
const STAR_EVERY := 13
const THROW_EVERY := 40          ## kind 49, standing in reach, throws kind 4A this often
const THROW_POSE_TICKS := 9
const JUMP_SPEED := -1536        ## the spinning jump: 320 across, this fast upward
const JUMP_CUT_TICKS := 37       ## its rise is stopped dead after 37 updates, 128 pixels up
const JUMP_REACH := 120.0        ## pattern: it jumps for a turtle above it and this close across
const SAME_FLOOR := 40.0         ## guess: only walks at a turtle about level with it

enum State { REST, WALK, WAIT, KICK, PUNCH, AIR, THROW }

var room: RoomData
var target: Node2D               ## the turtle
var kind := KIND
var walk_speed := WALK_SPEED
var stop_distance := STOP_DISTANCE
var fall_start := FALL_START_SPEED
var hops := true
var attacks_at_all := true
var throws := -1                 ## the kind of object it throws
var stars_left := 0
var jumping := false
var pose_ticks := 0              ## updates left of kind 49's throwing pose
var state := State.REST
var direction := 1               ## 1 = right, -1 = left
var fall_speed := 0
var air_ticks := 0
var hopping := false
var state_ticks := 0             ## updates left in the current rest, wait or attack
var attacks := 0
var health := 12
var touch_damage := 17
var weapon_damage := 7
var weapon_damage_low := 10
var sprites: SpriteSet
var _frame := 0
var _ticks := 0
var _art := Node2D.new()
var _picture := Sprite2D.new()

func setup(spot: EnemySpot, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	room = in_room
	target = turtle
	position = spot.position
	kind = spot.kind if KINDS.has(spot.kind) else KIND
	var how: Dictionary = KINDS[kind]
	walk_speed = how.speed
	stop_distance = how.stop
	fall_start = how.fall
	hops = how.hops
	attacks_at_all = how.attacks
	throws = how.throws
	health = maxi(spot.hit_points, 1)
	touch_damage = spot.touch_damage
	sprites = sprite_set
	if room.solid_at(position.x, position.y) and not room.solid_at(position.x, position.y - RoomData.TILE):
		position.y = floorf(position.y / RoomData.TILE) * RoomData.TILE + SINK
	state = State.REST
	state_ticks = REST_AFTER_FALL

func _ready() -> void:
	var touch := Rect2(-6, -44, 12, 44)      # guesses, as for the other enemies
	var reach := Rect2(-12, -52, 24, 56)
	if sprites != null:
		var picture := sprites.bounds("stand")
		touch = Rect2(-6, picture.position.y, 12, picture.size.y)
		reach = picture.grow(8)
	add_child(_box_shape(touch))
	var hurt := Area2D.new()
	hurt.name = "HurtBox"
	hurt.add_child(_box_shape(reach))
	hurt.area_entered.connect(_on_weapon_entered)
	add_child(hurt)
	add_child(_art)
	if sprites != null:
		_picture.centered = false
		_art.add_child(_picture)
	else:
		var block := ColorRect.new()
		block.position = Vector2(-7, -44)
		block.size = Vector2(14, 44)
		block.color = Color(0.5, 0.25, 0.7)
		_art.add_child(block)
	_show_frame()

func _box_shape(box: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = box.size
	shape.shape = rectangle
	shape.position = box.get_center()
	return shape

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % TICK_FRAMES == 0:
		tick()
	for body in get_overlapping_bodies():
		if body is Turtle:
			body.take_damage(touch_damage, global_position.x)

## One game update.
func tick() -> void:
	_ticks += 1
	if room == null:
		return
	if state == State.AIR:
		_air()
	elif not room.solid_at(position.x, position.y):
		_leave_ground(0, fall_start, false)   # walked off a ledge
	else:
		_on_ground()
	_show_frame()

func _on_ground() -> void:
	var gap := 0.0 if target == null else target.position.x - position.x
	var level := target != null and absf(target.position.y - (position.y - SINK)) < SAME_FLOOR
	if state == State.REST:
		state_ticks -= 1
		if state_ticks > 0:
			return
		if stars_left > 0:
			state = State.THROW
			state_ticks = 0
		else:
			state = State.WAIT
			state_ticks = 0
	if state == State.THROW:
		# After a hop: stars at the turtle, one every 13 updates.
		if gap != 0.0:
			direction = 1 if gap > 0.0 else -1
		if state_ticks <= 0:
			Shot.fire(self, throws, direction, room, target)
			stars_left -= 1
			state_ticks = STAR_EVERY
		state_ticks -= 1
		if stars_left == 0 and state_ticks <= 0:
			state = State.WAIT
		return
	pose_ticks = maxi(pose_ticks - 1, 0)
	if hops and target != null and state != State.KICK and state != State.PUNCH:
		# Pattern: the spinning jump, for a turtle on a floor above it or behind a wall.
		var above := target.position.y < (position.y - SINK) - SAME_FLOOR
		var walled := level and absf(gap) > stop_distance and room.solid_at(position.x + (1 if gap > 0.0 else -1) * 12.0, position.y - 8.0)
		if (above and absf(gap) < JUMP_REACH) or walled:
			jumping = true
			_leave_ground(1 if gap >= 0.0 else -1, JUMP_SPEED, false)
			return
	if target != null and gap != 0.0 and state != State.KICK and state != State.PUNCH:
		direction = 1 if gap > 0.0 else -1
	match state:
		State.KICK, State.PUNCH:
			state_ticks -= 1
			if state_ticks <= 0:
				state = State.WAIT
				state_ticks = WAIT_TICKS
		State.WALK, State.WAIT:
			if level and absf(gap) > stop_distance:
				# Pattern: walk straight at him, stopping at a wall.
				state = State.WALK
				if not room.solid_at(position.x + direction * 12.0, position.y - 8.0):
					position.x += direction * walk_speed / 256.0
			else:
				if state == State.WALK:
					state = State.WAIT
					state_ticks = WAIT_TICKS
				state_ticks -= 1
				if state_ticks <= 0 and level and not attacks_at_all and throws >= 0:
					# Kind 49: throws at him every 40 updates while it stands in reach.
					Shot.fire(self, throws, direction, room, target)
					pose_ticks = THROW_POSE_TICKS
					state_ticks = THROW_EVERY
				if state_ticks <= 0 and level and attacks_at_all:
					# Pattern: kicks and punches in pairs (the recordings were irregular).
					var kick := (attacks / 2) % 2 == 0
					attacks += 1
					state = State.KICK if kick else State.PUNCH
					state_ticks = KICK_TICKS if kick else PUNCH_TICKS

func _leave_ground(sideways: int, speed: int, hop: bool) -> void:
	state = State.AIR
	direction = sideways if sideways != 0 else direction
	hopping = hop
	fall_speed = speed
	air_ticks = 0
	_air()

func _air() -> void:
	var before := position
	if hopping or jumping:
		# Guess: a wall at foot or head height stops the sideways movement.
		var side := position.x + direction * 10.0
		if not room.solid_at(side, position.y - 8.0) and not room.solid_at(side, position.y - 40.0):
			position.x += direction * WALK_SPEED / 256.0
	if fall_speed < 0 and room.solid_at(position.x, position.y - 48.0 + fall_speed / 256.0):
		fall_speed = 0   # guess: a ceiling stops the rise
	position.y += fall_speed / 256.0
	air_ticks += 1
	if (hopping and air_ticks == HOP_CUT_TICKS) or (jumping and air_ticks == JUMP_CUT_TICKS):
		fall_speed = 0
	else:
		fall_speed += GRAVITY
	if fall_speed >= 0 and room.solid_at(position.x, position.y - SINK):
		position.y = floorf((position.y - SINK) / RoomData.TILE) * RoomData.TILE + SINK
		position.x = before.x   # the update that lands does not move it sideways
		var gap := 0.0 if target == null else target.position.x - position.x
		if hops and not hopping and absf(gap) > HOP_DISTANCE:
			_leave_ground(1 if gap > 0.0 else -1, HOP_SPEED, true)
			return
		state = State.REST
		state_ticks = REST_AFTER_HOP if hopping else REST_AFTER_FALL
		stars_left = STARS if hopping and throws >= 0 else 0
		hopping = false
		jumping = false
	elif position.y > room.size_pixels().y + 64.0:
		queue_free()

func _show_frame() -> void:
	_art.scale.x = direction
	if sprites == null:
		return
	var animation := "stand"
	var step := 0
	if state == State.AIR and jumping:
		animation = "spin"
		step = _ticks
	elif pose_ticks > 0:
		animation = "throw"
	match state:
		State.WALK:
			animation = "walk"
			step = _ticks
		State.KICK:
			animation = "kick"
		State.PUNCH:
			animation = "punch"
			step = PUNCH_TICKS - state_ticks
	var frame := sprites.frame_at(animation, step)
	if sprites.textures.has(frame):
		_picture.texture = sprites.textures[frame]
		_picture.position = sprites.offsets[frame]

func _on_weapon_entered(area: Area2D) -> void:
	if area.name == "WeaponHitbox":
		var turtle := area.get_parent() as Turtle
		var weakened := turtle != null and turtle.health * 2 < turtle.max_health
		take_hit(weapon_damage_low if weakened else weapon_damage)

func take_hit(amount: int) -> void:
	health -= amount
	if health <= 0:
		Puff.leave(self)
		queue_free()
