class_name Charger
extends Area2D
## Enemy kind A0: walks up to the turtle, waits, then charges through him.
##
## The numbers come from one recording of the USA ROM
## (Research/enemy_49_88_A0.md). The rules that connect them are a simple
## pattern fitted to that recording, not the original's code.

const KIND := 0xA0
const TICK_FRAMES := 2
const WALK_SPEED := 448          ## 1.75 px per update
const CHARGE_SPEED := 1152       ## 4.5 px per update
const FALL_START_SPEED := 768
const GRAVITY := 36
const SINK := 3.0
const REST_AFTER_FALL := 26      ## updates it stood after dropping in
const READY_DISTANCE := 31.0     ## it stopped walking this far from the turtle
const READY_TICKS := 12          ## then stood this long before charging
const CHARGE_TICKS := 18         ## the charge lasted this long (81 pixels)
const REST_AFTER_CHARGE := 27    ## a small hop and a wait, then the next charge
const WALL_LOOK := 14.0          ## guess
const SAME_FLOOR := 40.0         ## guess: only goes for a turtle about level with it

enum State { REST, WALK, READY, CHARGE, AIR }

var room: RoomData
var target: Node2D
var state := State.REST
var direction := 1
var state_ticks := REST_AFTER_FALL
var has_charged := false
var fall_speed := 0
var health := 47
var touch_damage := 22
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
	health = maxi(spot.hit_points, 1)
	touch_damage = spot.touch_damage
	sprites = sprite_set
	if room.solid_at(position.x, position.y) and not room.solid_at(position.x, position.y - RoomData.TILE):
		position.y = floorf(position.y / RoomData.TILE) * RoomData.TILE + SINK

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
		block.color = Color(0.2, 0.5, 0.8)
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

func _wall_ahead() -> bool:
	var ahead := position.x + direction * WALL_LOOK
	return ahead < 0.0 or ahead >= room.size_pixels().x or room.solid_at(ahead, position.y - 8.0)

func _face_turtle() -> float:
	var gap := 0.0 if target == null else target.position.x - position.x
	if gap != 0.0:
		direction = 1 if gap > 0.0 else -1
	return gap

## One game update.
func tick() -> void:
	_ticks += 1
	if room == null:
		return
	if state == State.AIR:
		position.y += fall_speed / 256.0
		fall_speed += GRAVITY
		if room.solid_at(position.x, position.y - SINK - 1.0):
			position.y = floorf((position.y - SINK) / RoomData.TILE) * RoomData.TILE + SINK
			state = State.REST
			state_ticks = REST_AFTER_FALL
		elif position.y > room.size_pixels().y + 64.0:
			queue_free()
	elif not room.solid_at(position.x, position.y):
		state = State.AIR
		fall_speed = FALL_START_SPEED
	else:
		_on_ground()
	_show_frame()

func _on_ground() -> void:
	var level := target != null and absf(target.position.y - (position.y - SINK)) < SAME_FLOOR
	match state:
		State.REST:
			state_ticks -= 1
			if state_ticks <= 0 and level:
				_face_turtle()
				if has_charged:
					state = State.CHARGE   # after the first charge it goes straight into the next
					state_ticks = CHARGE_TICKS
				else:
					state = State.WALK
		State.WALK:
			var gap := _face_turtle()
			if absf(gap) <= READY_DISTANCE:
				state = State.READY
				state_ticks = READY_TICKS
			elif level and not _wall_ahead():
				position.x += direction * WALK_SPEED / 256.0
		State.READY:
			state_ticks -= 1
			if state_ticks <= 0:
				_face_turtle()
				state = State.CHARGE
				state_ticks = CHARGE_TICKS
		State.CHARGE:
			if not _wall_ahead():
				position.x += direction * CHARGE_SPEED / 256.0
			state_ticks -= 1
			if state_ticks <= 0:
				has_charged = true
				state = State.REST
				state_ticks = REST_AFTER_CHARGE

func _show_frame() -> void:
	_art.scale.x = direction
	if sprites == null:
		return
	var animation := "stand"
	if state == State.CHARGE:
		animation = "charge"
	elif state == State.READY:
		animation = "ready"
	var frame := sprites.frame_at(animation, _ticks)
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
