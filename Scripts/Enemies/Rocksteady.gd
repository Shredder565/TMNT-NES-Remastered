class_name Rocksteady
extends Area2D
## Object kind 71: the boss of world 1's last room. It looks like Rocksteady.
##
## Every number here is from one 25-second recording of the USA ROM with the
## turtle standing still (Research/world1.md). The boss repeated the same
## round over and over in it: walk up, shoot, walk a little closer, jump
## over the turtle, jump back. This script plays that round. How the
## original chooses its moves is not known, so against a moving turtle the
## real boss may well act differently.

signal defeated

const KIND := 0x71
const TICK_FRAMES := 2
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

var room: RoomData
var target: Node2D
var state := State.ENTER
var direction := -1
var fall_speed := 0
var state_ticks := 2
var jumps_done := 0
var air_ticks := 0
var health := 96
var touch_damage := 23
var weapon_damage := 7
var weapon_damage_low := 10
var sprites: SpriteSet
var _frame := 0
var _ticks := 0
var _art := Node2D.new()
var _picture := Sprite2D.new()

func setup(at: Vector2, in_room: RoomData, sprite_set: SpriteSet, turtle: Node2D) -> void:
	position = at
	room = in_room
	target = turtle
	sprites = sprite_set
	_face_turtle()

func _ready() -> void:
	var touch := Rect2(-8, -44, 16, 44)      # guesses, as for the other enemies
	var reach := Rect2(-16, -52, 32, 56)
	if sprites != null:
		var picture := sprites.bounds("stand")
		touch = Rect2(-8, picture.position.y, 16, picture.size.y)
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
		block.position = Vector2(-10, -44)
		block.size = Vector2(20, 44)
		block.color = Color(0.5, 0.5, 0.2)
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

func _face_turtle() -> float:
	var gap := 0.0 if target == null else target.position.x - position.x
	if gap != 0.0:
		direction = 1 if gap > 0.0 else -1
	return gap

func _on_floor() -> bool:
	return room.solid_at(position.x, position.y)

func _wall_ahead() -> bool:
	var ahead := position.x + direction * WALL_LOOK
	return ahead < 0.0 or ahead >= room.size_pixels().x or room.solid_at(ahead, position.y - 8.0)

## One game update.
func tick() -> void:
	_ticks += 1
	if room == null:
		return
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
	_show_frame()

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

func _show_frame() -> void:
	_art.scale.x = direction
	if sprites == null:
		return
	var animation := "stand"
	if state == State.WALK or state == State.CLOSE_IN or (state == State.ENTER and state_ticks > 0):
		animation = "walk"
	elif state == State.SHOOT:
		animation = "shoot"
	elif state == State.JUMP or state == State.ENTER:
		animation = "jump"
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
	if health <= 0:
		return
	health -= amount
	if health <= 0:
		Puff.leave(self)
		defeated.emit()
		queue_free()
