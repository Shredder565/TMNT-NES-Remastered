class_name Leaper
extends Area2D
## Enemy kind 92: walks at the turtle and leaps at him from close by.
## Also kind 9D, which only hops: 64 pixels one way, a rest, 64 back.
##
## The numbers come from recordings of the USA ROM (Research/enemy_92.md).
## As with the soldier, the rules that choose what it does are a simple
## pattern fitted to a few recordings, not the original's code.

const KIND := 0x9D
## `walk` and `side` are speeds along the floor and through the air.
## `rest` is the updates it stands between hops. `alternate` kinds turn
## round after every hop instead of following the turtle.
const KINDS := {
	0x9D: { "walk": 0, "side": 512, "rest": 17, "alternate": true },
	# 9E stands for 75 updates, then jumps straight up 82 pixels. After 26
	# updates its upward speed is set to 0 and it falls back.
	# It fires kind 9F when it lands and 25 updates later, and 11 and 43
	# updates into each jump.
	0x9E: { "walk": 0, "side": 0, "rest": 75, "alternate": true, "leap": -1152, "gravity": 28, "cut": 26,
		"shot": 0x9F, "ground_shots": [0, 25], "air_shots": [11, 43] },
}
const TICK_FRAMES := 2
const WALK_SPEED := 448          ## 1.75 px per update
const FALL_START_SPEED := 768    ## first update of a fall
const FALL_GRAVITY := 36
const LEAP_SPEED := -768         ## upward speed at the start of a leap
const LEAP_GRAVITY := 48
const LEAP_SIDEWAYS_TICKS := 32  ## it moves sideways for the first 32 of a leap's 34 updates
const LEAP_DISTANCE := 37.0      ## it leapt with the two middles this far apart (seen twice)
const SINK := 3.0                ## rides 3 pixels below the floor's top edge
const WALL_LOOK := 14.0          ## a wall this close ahead stops it
const SAME_FLOOR := 40.0         ## guess: only chases a turtle about level with it

var room: RoomData
var target: Node2D
var kind := KIND
var walk_speed := WALK_SPEED
var side_speed := WALK_SPEED
var rest_between := 0
var alternate := false
var rest_ticks := 0
var leap_speed := LEAP_SPEED
var leap_gravity := LEAP_GRAVITY
var leap_cut := 0                ## above 0: the rise is stopped dead after this many updates
var shot_kind := -1
var ground_shots: Array = []     ## updates after landing at which it fires
var air_shots: Array = []        ## updates after take-off at which it fires
var direction := 1
var in_air := false
var leaping := false
var has_walked := true           ## pattern: it must walk again before the next leap
var fall_speed := 0
var air_ticks := 0
var health := 24
var touch_damage := 16
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
	walk_speed = how.walk
	side_speed = how.side
	rest_between = how.rest
	alternate = how.alternate
	leap_speed = how.get("leap", LEAP_SPEED)
	leap_gravity = how.get("gravity", LEAP_GRAVITY)
	leap_cut = how.get("cut", 0)
	shot_kind = how.get("shot", -1)
	ground_shots = how.get("ground_shots", [])
	air_shots = how.get("air_shots", [])
	rest_ticks = rest_between
	if turtle != null and turtle.position.x < position.x:
		direction = -1
	health = maxi(spot.hit_points, 1)
	touch_damage = spot.touch_damage
	sprites = sprite_set
	if room.solid_at(position.x, position.y) and not room.solid_at(position.x, position.y - RoomData.TILE):
		position.y = floorf(position.y / RoomData.TILE) * RoomData.TILE + SINK

func _ready() -> void:
	var touch := Rect2(-6, -22, 12, 22)      # guesses, as for the other enemies
	var reach := Rect2(-12, -30, 24, 36)
	if sprites != null:
		var picture := sprites.bounds("walk")
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
		block.position = Vector2(-8, -22)
		block.size = Vector2(16, 22)
		block.color = Color(0.8, 0.6, 0.3)
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
			body.touched_by(self, touch_damage)

func _wall_ahead() -> bool:
	var ahead := position.x + direction * WALL_LOOK
	return ahead < 0.0 or ahead >= room.size_pixels().x or room.solid_at(ahead, position.y - 8.0)

## One game update.
func tick() -> void:
	_ticks += 1
	if room == null:
		return
	if in_air:
		_air()
	elif not room.solid_at(position.x, position.y):
		in_air = true
		leaping = false
		fall_speed = FALL_START_SPEED
		_air()
	elif alternate:
		# Kind 9D: rest, hop, turn round, and again.
		if shot_kind >= 0 and ground_shots.has(rest_between - rest_ticks):
			_fire(true)
		rest_ticks -= 1
		if rest_ticks <= 0:
			in_air = true
			leaping = true
			fall_speed = leap_speed
			_air()
	elif target != null:
		var gap := target.position.x - position.x
		var level := absf(target.position.y - (position.y - SINK)) < SAME_FLOOR
		if gap != 0.0:
			direction = 1 if gap > 0.0 else -1
		if not level:
			pass
		elif absf(gap) > LEAP_DISTANCE:
			if not _wall_ahead():
				position.x += direction * walk_speed / 256.0
				has_walked = true
		elif has_walked:
			has_walked = false
			in_air = true
			leaping = true
			fall_speed = leap_speed
			_air()
	_show_frame()

func _air() -> void:
	if leaping and air_ticks < LEAP_SIDEWAYS_TICKS and not _wall_ahead():
		position.x += direction * side_speed / 256.0
	if leaping and shot_kind >= 0 and air_shots.has(air_ticks):
		_fire(air_shots.find(air_ticks) % 2 == 0)
	air_ticks += 1
	position.y += fall_speed / 256.0
	if leaping and leap_cut > 0 and air_ticks == leap_cut:
		fall_speed = 0
	else:
		fall_speed += leap_gravity if leaping else FALL_GRAVITY
	# It has to pass its resting height before the floor catches it.
	if fall_speed > 0 and room.solid_at(position.x, position.y - SINK - 1.0):
		position.y = floorf((position.y - SINK) / RoomData.TILE) * RoomData.TILE + SINK
		in_air = false
		air_ticks = 0
		if leaping and alternate:
			direction = -direction
			rest_ticks = rest_between
		leaping = false
	elif position.y > room.size_pixels().y + 64.0:
		queue_free()

## Fires at the turtle's side, or away from it (in the air it was seen
## firing both ways).
func _fire(at_turtle: bool) -> void:
	var side := direction
	if target != null and target.position.x != position.x:
		side = 1 if target.position.x > position.x else -1
	Shot.fire(self, shot_kind, side if at_turtle else -side, room, target)

func _show_frame() -> void:
	_art.scale.x = direction
	if sprites == null:
		return
	var frame := sprites.frame_at("walk", _ticks)
	if sprites.textures.has(frame):
		_picture.texture = sprites.textures[frame]
		_picture.position = sprites.offsets[frame]

func _on_weapon_entered(area: Area2D) -> void:
	if area.name == "WeaponHitbox" and Turtle.weapon_lands(self):
		var turtle := area.get_parent() as Turtle
		var weakened := turtle != null and turtle.health * 2 < turtle.max_health
		take_hit(weapon_damage_low if weakened else weapon_damage)

func take_hit(amount: int) -> void:
	health -= amount
	if health <= 0:
		Puff.leave(self)
		queue_free()
