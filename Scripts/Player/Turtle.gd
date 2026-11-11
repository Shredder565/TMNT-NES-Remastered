class_name Turtle
extends CharacterBody2D
## One playable turtle with placeholder art.
##
## Movement copies the 1989 game. The numbers were measured from the USA ROM
## running in Mesen (see Research/movement_measurements.md):
## - The original updates the turtle 30 times a second (every 2nd frame).
## - Speeds are stored in 1/256ths of a pixel per update. 576 = 2.25 pixels.

signal health_changed(health: int, max_health: int)
signal died

enum State { NORMAL, CROUCH, HURT, DEAD, CLIMB }

## --- Measured from the original (units: 1/256 pixel per update) ---
const TICK_FRAMES := 2          ## one game update every 2 frames (30 per second)
const WALK_SPEED := 576         ## 2.25 px per update = 67.5 px per second
const CLIMB_SPEED := 576        ## ladders: also 2.25 px per update
const JUMP_SPEED := -1536       ## -6 px per update at take-off
const GRAVITY := 84             ## added to the fall speed every update
const BODY_HEIGHT := 30.0        ## the box enemies touch, and the practice room's collision
const SHORT_JUMP_TICK := 4      ## 4 updates after take-off: button released?
const SHORT_JUMP_SPEED := -624  ## ...then the rise is cut to this (low jump, 33 px)
const BOOST_TICK := 8           ## 8 updates after take-off: button still held?
const BOOST_SPEED := -1536      ## ...then a second push (high jump, 97 px)
## Being hit throws him back at 1.3125 pixels an update to the right or
## 1.5 to the left, and 1 pixel up (the original's numbers, bank 4 $A66B).
const KNOCKBACK_RIGHT := 336
const KNOCKBACK_LEFT := -384
const KNOCKBACK_UP := -258
## --- Not measured yet: guesses ---
const WALK_OFF_DELAY := 2
const CENTRE_ABOVE_FEET := 20.0   ## the original measures his boxes and his weapon from his middle
const MAX_FALL_SPEED := 2559    ## the original holds the whole pixels of his fall at 9

@export var turtle_name := "Leonardo"
@export var bandana_color := Color(0.2, 0.45, 1.0)
@export var max_health := 8
@export var invulnerable_time := 0.8  ## seconds of blinking safety after a hit (the original counts 24 updates)

var health := 8
var facing := 1                        ## 1 = right, -1 = left
var state := State.NORMAL
var speed := Vector2i.ZERO             ## current speed in 1/256 px per update
var jump_tick := -1                    ## updates since take-off, -1 when not jumping
var attack_tick := -1                  ## updates since the swing began, -1 when not attacking
var attack_length := 6                 ## 3 frames of 2 updates each, as in the original
var attack_direction := 1              ## 0 up, 1 forward, 2 down
## From the ROM, set by the room scene when one is installed:
var weapon_swings: Array = []          ## per direction: { places: where the weapon is each frame, half: its box }
var body_boxes := {}                   ## "stand", "crouch", "ball" -> half the size of his own hit box
var anim := "stand"
var anim_tick := 0
var sprites: SpriteSet                 ## null until a ROM is supplied: then placeholder art is used
var grounded := false                  ## standing on something
var _bumped_head := false
var _was_grounded := true
var _unheld_ticks := 0
var _just_landed := false
var room: RoomData                     ## set by the room, so the turtle can find ladders
var climb_distance := 0.0              ## pixels climbed, used to step the ladder animation
var invulnerable_timer := 0.0
var _frame := 0
var _jump_pressed := false             ## remembered until the next update
var _attack_pressed := false
var _hurt_ticks := 0

@onready var art: Node2D = $Art
@onready var body_art: ColorRect = $Art/Body
@onready var bandana_art: ColorRect = $Art/Bandana
@onready var weapon_art: ColorRect = $Art/Weapon
@onready var rom_sprite: Sprite2D = $Art/RomSprite
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var weapon_shape: CollisionShape2D = $WeaponHitbox/CollisionShape2D

func _ready() -> void:
	health = max_health
	bandana_art.color = bandana_color
	# Each turtle needs its own collision shape so crouching can shrink it.
	body_shape.shape = body_shape.shape.duplicate()
	weapon_shape.shape = weapon_shape.shape.duplicate()
	sprites = SpriteSet.load_for(turtle_name)
	if sprites != null:
		body_art.visible = false
		bandana_art.visible = false
		rom_sprite.visible = true
	_set_attacking(false)
	_update_art()
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	# Button presses can land on either frame, so remember them for the update.
	if Input.is_action_just_pressed("jump"):
		_jump_pressed = true
	if Input.is_action_just_pressed("attack"):
		_attack_pressed = true

	# Timers that run in real time
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		art.visible = invulnerable_timer <= 0.0 or int(invulnerable_timer * 20.0) % 2 == 0

	_frame += 1
	if _frame % TICK_FRAMES == 0:
		_tick()

## One game update, in the same order as the original:
## move with the current speed first, then work out the next speed.
func _tick() -> void:
	if state == State.CLIMB:
		_climb()
		_jump_pressed = false
		_attack_pressed = false
		_update_art()
		return
	if room != null:
		_move_in_room()
	else:
		# The practice room has no tile map: Godot's own collision does it.
		# move_and_slide moves by velocity / 60 each call, so this moves
		# exactly speed / 256 pixels.
		velocity = Vector2(speed) / 256.0 * Engine.physics_ticks_per_second
		move_and_slide()
		grounded = is_on_floor()
		_bumped_head = is_on_ceiling()

	_just_landed = grounded and not _was_grounded
	_was_grounded = grounded
	if grounded:
		if speed.y > 0:
			speed.y = 0
		if jump_tick > 0:
			jump_tick = -1
	else:
		if _bumped_head:
			speed.y = 0
			jump_tick = -1
		speed.y = mini(speed.y + GRAVITY, MAX_FALL_SPEED)

	match state:
		State.NORMAL, State.CROUCH:
			_control()
		State.HURT:
			_hurt_ticks += 1
			if on_floor() and _hurt_ticks > 2:
				state = State.NORMAL
				speed.x = 0
		State.DEAD:
			speed.x = 0
	_jump_pressed = false
	_attack_pressed = false
	_update_art()

## Picks the animation for what the turtle is doing and shows its frame.
func _update_art() -> void:
	_fit_body()
	var wanted := "stand"
	if state == State.CLIMB:
		wanted = "climb"
	elif attack_tick >= 0:
		wanted = ["attack_up", "attack", "attack_crouch"][attack_direction]
	elif state == State.HURT or state == State.DEAD or not on_floor():
		wanted = "jump"
	elif state == State.CROUCH:
		wanted = "crouch"
	elif speed.x != 0:
		wanted = "walk"
	if wanted != anim:
		anim = wanted
		anim_tick = 0
	else:
		anim_tick += 1
	if sprites == null:
		return
	var frame := sprites.frame_at(anim, attack_tick if attack_tick >= 0 else anim_tick)
	if state == State.CLIMB:
		# The ladder animation only moves while he does: a new pose every 9 pixels.
		frame = sprites.frame_at("climb", int(climb_distance / 9.0) * 4)
	if sprites.textures.has(frame):
		rom_sprite.texture = sprites.textures[frame]
		rom_sprite.position = sprites.offsets[frame]

## On a ladder, by the original's rules (bank 4, $A24D; checked in the
## emulator). Points are from his feet, at his middle unless said.
## - Left or right: if the three points 9 pixels to that side (32, 20 and
##   5 up) are empty or ladder, he lets go and falls. Otherwise nothing.
## - Up: he climbs while there is ladder 36 up. With something solid there
##   he stops. Past the ladder's top he keeps going while the point 3
##   below his feet is not empty, then is set down on the first thing
##   under him, which leaves him 1 pixel into the ladder's top cell.
## - Down: he climbs down until the floor is 3 below and 3 above his feet,
##   then is raised to stand on it. With nothing below his feet and
##   nothing at his middle, he falls.
## - Jump does nothing on a ladder.
func _climb() -> void:
	var x := floorf(position.x)
	var feet := floorf(position.y)
	var side := int(signf(Input.get_axis("move_left", "move_right")))
	if side != 0:
		facing = side
		art.scale.x = facing
		weapon_hitbox.scale.x = facing
		if _clear_beside(x + side * 9.0, feet - 32.0) and _clear_beside(x + side * 9.0, feet - 20.0) and _clear_beside(x + side * 9.0, feet - 5.0):
			_let_go()
		return
	var vertical := int(signf(Input.get_axis("move_up", "move_down")))
	if vertical == 0:
		return
	var step := vertical * CLIMB_SPEED / 256.0
	if vertical < 0:
		if not _ladder_at(x, feet - 36.0):
			if room.solid_at(x, feet - 36.0):
				return
			if room.kind_at_pixel(x, feet + 3.0) == RoomData.KIND_EMPTY:
				var lowered := 0
				feet += 1.0
				while room.kind_at_pixel(x, feet - 1.0) == RoomData.KIND_EMPTY and lowered < 32:
					feet += 1.0
					lowered += 1
				position.y = feet + position.y - floorf(position.y)
				_leave_ladder()
				return
	else:
		if room.solid_at(x, feet + 3.0):
			if room.solid_at(x, feet - 3.0):
				var raised := 0
				while room.solid_at(x, feet - 1.0) and raised < 32:
					feet -= 1.0
					raised += 1
				position.y = feet + position.y - floorf(position.y)
				_leave_ladder()
				return
		elif room.kind_at_pixel(x, feet + 3.0) == RoomData.KIND_EMPTY and room.kind_at_pixel(x, feet - 20.0) == RoomData.KIND_EMPTY:
			_let_go()
			return
	position.y += step
	climb_distance += absf(step)

func _ladder_at(x: float, y: float) -> bool:
	return room.is_ladder_cell(floori(x / RoomData.TILE), floori(y / RoomData.TILE))

func _clear_beside(x: float, y: float) -> bool:
	return room.kind_at_pixel(x, y) == RoomData.KIND_EMPTY or _ladder_at(x, y)

## Stands him where he is, off the ladder.
func _leave_ladder() -> void:
	state = State.NORMAL
	speed = Vector2i.ZERO
	grounded = true
	_was_grounded = true
	_unheld_ticks = 0

## Drops him from the ladder: he falls from rest.
func _let_go() -> void:
	state = State.NORMAL
	speed = Vector2i.ZERO
	grounded = false
	_was_grounded = false
	jump_tick = -1

## Starts climbing if a ladder is in reach, as the original tests it: Up
## needs ladder at his middle 28 above his feet, Down needs it 3 below
## them. He is not moved sideways onto it.
func _try_grab_ladder(vertical: int) -> bool:
	if room == null or vertical == 0 or not on_floor():
		return false   # the original only takes a ladder from the ground
	var x := floorf(position.x)
	var feet := floorf(position.y)
	if not _ladder_at(x, feet - 28.0 if vertical < 0 else feet + 3.0):
		return false
	_set_crouching(false)
	attack_tick = -1
	_set_attacking(false)
	state = State.CLIMB
	speed = Vector2i.ZERO
	jump_tick = -1
	return true

func _control() -> void:
	var direction := int(signf(Input.get_axis("move_left", "move_right")))
	if _try_grab_ladder(int(signf(Input.get_axis("move_up", "move_down")))):
		return
	if direction != 0:
		facing = direction
		art.scale.x = facing
		weapon_hitbox.scale.x = facing

	# Crouch: hold down on the ground. No walking while crouched.
	_set_crouching(Input.is_action_pressed("move_down") and on_floor())

	var taking_off := _jump_pressed and on_floor() and state != State.CROUCH and not _just_landed
	if taking_off:
		pass   # a jump keeps the sideways speed he already had (none from a standstill)
	elif on_floor():
		# On the ground the turtle starts and stops instantly.
		speed.x = 0 if state == State.CROUCH else direction * WALK_SPEED
	elif direction != 0:
		# In the air a direction takes effect at once; letting go keeps the drift.
		speed.x = direction * WALK_SPEED

	# The three jump heights of the original.
	if jump_tick >= 0:
		jump_tick += 1
		if jump_tick == SHORT_JUMP_TICK and not Input.is_action_pressed("jump"):
			speed.y = SHORT_JUMP_SPEED
		elif jump_tick == BOOST_TICK and Input.is_action_pressed("jump"):
			speed.y = BOOST_SPEED
	if taking_off:
		speed.y = JUMP_SPEED
		jump_tick = 0

	# Attack: the sword is out from the second frame of the swing.
	if attack_tick >= 0:
		attack_tick += 1
		if attack_tick >= attack_length:
			attack_tick = -1
			_set_attacking(false)
		elif weapon_swings.is_empty():
			if attack_tick == 2:
				_set_attacking(true)   # no ROM: the stand-in swing is out from its second frame
		else:
			_place_weapon()
	elif _attack_pressed:
		attack_tick = 0
		if weapon_swings.is_empty():
			attack_direction = 2 if state == State.CROUCH else 1
			attack_length = 8 if state == State.CROUCH else 6
		else:
			# Up or Down held picks the swing, on the ground and in the air.
			attack_direction = 1
			if Input.is_action_pressed("move_up"):
				attack_direction = 0
			elif Input.is_action_pressed("move_down"):
				attack_direction = 2
			attack_length = weapon_swings[attack_direction].places.size() * 2
			_set_attacking(true)
			_place_weapon()

## Moves him through a ROM room by the original's own rules, read from its
## code (bank 4, $9D0C and $9FB0 on; Research/turtle_collision.md). It
## tests single points of the tile map, given here from his feet:
## - Walking: a wall at 9 pixels ahead, 7 or 24 up, stops him. He stays up
##   while either foot, 6 pixels to each side, has something under it.
##   Standing still it is the one point under his middle.
## - In the air: going up, something at 32 above his middle stops the
##   rise. Sideways he is stopped by 6 ahead at 32 up, or 7 ahead at 20 or
##   3 up. Coming down he lands when the point 3 up, at his middle, is in
##   a floor: he is lifted until he stands on it, and pushed out of a wall
##   2 pixels at a time if he is against one.
## Every test is made where he is, before he moves, as the original does.
func _move_in_room() -> void:
	_bumped_head = false
	var x := floorf(position.x)
	var feet := floorf(position.y)
	if grounded and speed.y < 0:
		grounded = false   # a jump has begun
	if grounded:
		var walking := speed.x != 0
		if walking:
			var ahead := 9.0 if speed.x > 0 else -9.0
			if room.solid_at(x + ahead, feet - 7.0) or room.solid_at(x + ahead, feet - 24.0):
				speed.x = 0
		var held := false
		if walking:
			held = _stands_on(x + 6.0, feet + 1.0) or _stands_on(x - 6.0, feet + 1.0)
		else:
			held = _stands_on(x, feet + 1.0)
		# Measured: he starts to drop two updates later than this test
		# alone would have it. Why is not known; the delay is copied.
		_unheld_ticks = 0 if held else _unheld_ticks + 1
		if _unheld_ticks > WALK_OFF_DELAY:
			grounded = false
			speed.y = 0
			_unheld_ticks = 0
		position.x += speed.x / 256.0
		return
	if speed.y < 0 and room.solid_at(x, feet - 32.0):
		_bumped_head = true
		speed.y = 0
	var side := 1.0 if speed.x >= 0 else -1.0
	if room.solid_at(x + side * 6.0, feet - 32.0) or room.solid_at(x + side * 7.0, feet - 20.0) or room.solid_at(x + side * 7.0, feet - 3.0):
		speed.x = 0
	if speed.y >= 0 and _lands_on(x, feet):
		var lifted := 0
		while _lands_on(x, feet + 2.0) and lifted < 32:
			feet -= 1.0     # up until the point just above his soles is clear
			lifted += 1
		while room.solid_at(x + side * 8.0, feet - 13.0) and absf(x - position.x) < 32.0:
			x -= side * 2.0
		# The fractions of his position are kept, as in the original.
		position = Vector2(x + position.x - floorf(position.x), feet + position.y - floorf(position.y))
		speed = Vector2i.ZERO
		grounded = true
		_unheld_ticks = 0
		return
	position += Vector2(speed) / 256.0

## Something he can stand on: anything but empty space, a hurting tile or
## a doorway (the original's list).
func _stands_on(x: float, y: float) -> bool:
	var kind := room.kind_at_pixel(x, y)
	return kind != RoomData.KIND_EMPTY and kind != RoomData.KIND_HURTS and kind != RoomData.KIND_DOOR

## Coming down: is the point 3 pixels above his feet in a floor? A ladder
## counts only at its top.
func _lands_on(x: float, feet: float) -> bool:
	if room.solid_at(x, feet - 3.0):
		return true
	return room.is_ladder_cell(floori(x / RoomData.TILE), floori((feet - 3.0) / RoomData.TILE)) \
		and not room.is_ladder_cell(floori(x / RoomData.TILE), floori((feet - 13.0) / RoomData.TILE))

## True when he stands on something. (Godot's is_on_floor only knows about
## its own collision, which the ROM rooms do not use for him.)
func on_floor() -> bool:
	return grounded

func _set_crouching(on: bool) -> void:
	if on == (state == State.CROUCH):
		return
	state = State.CROUCH if on else State.NORMAL
	# The box enemies touch: 30 tall standing, 28 crouching (both guesses).
	var height := 28.0 if on else BODY_HEIGHT
	(body_shape.shape as RectangleShape2D).size.y = height
	body_shape.position.y = -height / 2.0
	weapon_hitbox.position.y = 12.0 if on else 0.0
	# Placeholder art only: squash the block to show the crouch.
	if sprites == null:
		art.scale.y = 0.7 if on else 1.0

## Puts the weapon's box where the original has the weapon on this frame of
## the swing (two updates a frame). A crouching turtle's boxes sit 8 lower.
func _place_weapon() -> void:
	var swing: Dictionary = weapon_swings[attack_direction]
	var places: Array = swing.places
	var place: Vector2 = places[mini(attack_tick / 2, places.size() - 1)]
	var half: Vector2 = swing.half
	var rectangle := weapon_shape.shape as RectangleShape2D
	rectangle.size = half * 2.0
	weapon_hitbox.position.y = 0.0
	weapon_shape.position = Vector2(place.x, place.y - CENTRE_ABOVE_FEET + (8.0 if state == State.CROUCH else 0.0))

## His own hit box, as the ROM has it: centred on his middle (20 above his
## feet), smaller while he spins through the air, and lower when he crouches.
func _fit_body() -> void:
	if body_boxes.is_empty():
		return
	var which := "stand"
	var lower := 0.0
	if state == State.CROUCH:
		which = "crouch"
		lower = 8.0
	elif state == State.NORMAL and not on_floor() and attack_tick < 0:
		which = "ball"
	var half := Vector2(body_boxes[which])
	var rectangle := body_shape.shape as RectangleShape2D
	if rectangle.size != half * 2.0 or body_shape.position.y != lower - CENTRE_ABOVE_FEET:
		rectangle.size = half * 2.0
		body_shape.position = Vector2(0.0, lower - CENTRE_ABOVE_FEET)

func _set_attacking(on: bool) -> void:
	weapon_art.visible = on and sprites == null
	# Physics shapes must be switched with set_deferred, not directly.
	weapon_shape.set_deferred("disabled", not on)

## Called by anything that hurts the turtle. `from_x` is where the hit came
## from, so the turtle is knocked away from it.
func take_damage(amount: int, from_x: float = NAN) -> void:
	if invulnerable_timer > 0.0 or state == State.DEAD:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	attack_tick = -1
	_set_attacking(false)
	_set_crouching(false)
	if health == 0:
		state = State.DEAD
		art.modulate = Color(0.5, 0.5, 0.5)
		died.emit()
		return
	state = State.HURT
	_hurt_ticks = 0
	jump_tick = -1
	invulnerable_timer = invulnerable_time
	# Thrown away from what hit him; level with it, to the left (bank 6, $989E).
	var away := -facing if is_nan(from_x) else (1 if floorf(from_x) < floorf(global_position.x) else -1)
	speed = Vector2i(KNOCKBACK_RIGHT if away > 0 else KNOCKBACK_LEFT, KNOCKBACK_UP)

## Energy lost to something that hurts every update he stays on it (a deadly
## floor). There is no knock-back and the blinking safe time does not help.
func drain(amount: int) -> void:
	if state == State.DEAD:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		attack_tick = -1
		_set_attacking(false)
		_set_crouching(false)
		state = State.DEAD
		art.modulate = Color(0.5, 0.5, 0.5)
		died.emit()

## Energy gained from a pizza. It cannot go above full.
func heal(amount: int) -> void:
	if state == State.DEAD:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

func revive() -> void:
	health = max_health
	state = State.NORMAL
	invulnerable_timer = 0.0
	art.visible = true
	art.modulate = Color.WHITE
	speed = Vector2i.ZERO
	velocity = Vector2.ZERO
	health_changed.emit(health, max_health)
