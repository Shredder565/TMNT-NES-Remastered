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
const SHORT_JUMP_TICK := 4      ## 4 updates after take-off: button released?
const SHORT_JUMP_SPEED := -624  ## ...then the rise is cut to this (low jump, 33 px)
const BOOST_TICK := 8           ## 8 updates after take-off: button still held?
const BOOST_SPEED := -1536      ## ...then a second push (high jump, 97 px)
const KNOCKBACK := Vector2i(384, -258)  ## approximate, read from one hit
## --- Not measured yet: guesses ---
const MAX_FALL_SPEED := 3072    ## the original was still speeding up at 2076

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
var anim := "stand"
var anim_tick := 0
var sprites: SpriteSet                 ## null until a ROM is supplied: then placeholder art is used
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
	# move_and_slide moves by velocity / 60 each call, so this moves exactly
	# speed / 256 pixels.
	velocity = Vector2(speed) / 256.0 * Engine.physics_ticks_per_second
	move_and_slide()

	if is_on_floor():
		if speed.y > 0:
			speed.y = 0
		if jump_tick > 0:
			jump_tick = -1
	else:
		if is_on_ceiling() and speed.y < 0:
			speed.y = 0
			jump_tick = -1
		speed.y = mini(speed.y + GRAVITY, MAX_FALL_SPEED)

	match state:
		State.NORMAL, State.CROUCH:
			_control()
		State.HURT:
			_hurt_ticks += 1
			if is_on_floor() and _hurt_ticks > 2:
				state = State.NORMAL
				speed.x = 0
		State.DEAD:
			speed.x = 0
	_jump_pressed = false
	_attack_pressed = false
	_update_art()

## Picks the animation for what the turtle is doing and shows its frame.
func _update_art() -> void:
	var wanted := "stand"
	if state == State.CLIMB:
		wanted = "climb"
	elif attack_tick >= 0:
		wanted = "attack_crouch" if state == State.CROUCH else "attack"
	elif state == State.HURT or state == State.DEAD or not is_on_floor():
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

## On a ladder: no gravity, straight up and down, centred on the ladder.
func _climb() -> void:
	var feet := position.y
	var step := int(signf(Input.get_axis("move_up", "move_down"))) * CLIMB_SPEED / 256.0
	var new_feet := feet + step
	if step > 0.0 and room.solid_at(position.x, new_feet - 0.01):
		# Reached the floor at the bottom of the ladder.
		position.y = floorf(new_feet / RoomData.TILE) * RoomData.TILE
		_leave_ladder()
		return
	if step < 0.0 and is_nan(room.ladder_center_at(position.x, new_feet - 1.0)):
		# Reached the top: step off onto the ledge.
		position.y = ceilf(new_feet / RoomData.TILE) * RoomData.TILE
		_leave_ladder()
		return
	position.y = new_feet
	climb_distance += absf(step)
	if _jump_pressed:
		_leave_ladder()

func _leave_ladder() -> void:
	state = State.NORMAL
	speed = Vector2i.ZERO

## Starts climbing if a ladder is in reach. Up grabs a ladder behind the
## turtle; Down grabs one that goes down through the floor he stands on.
func _try_grab_ladder(vertical: int) -> bool:
	if room == null or vertical == 0:
		return false
	var probe_y := position.y - 12.0 if vertical < 0 else position.y + 4.0
	var center := room.ladder_center_at(position.x, probe_y)
	if is_nan(center) or absf(center - position.x) > 6.0:
		return false
	# Going up needs ladder above the feet, or there is nowhere to climb.
	if vertical < 0 and is_nan(room.ladder_center_at(position.x, position.y - 1.0)):
		return false
	_set_crouching(false)
	attack_tick = -1
	_set_attacking(false)
	state = State.CLIMB
	speed = Vector2i.ZERO
	jump_tick = -1
	position.x = center
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
	_set_crouching(Input.is_action_pressed("move_down") and is_on_floor())

	if is_on_floor():
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
	if _jump_pressed and is_on_floor() and state != State.CROUCH:
		speed.y = JUMP_SPEED
		jump_tick = 0

	# Attack: the sword is out from the second frame of the swing.
	if attack_tick >= 0:
		attack_tick += 1
		if attack_tick == 2:
			_set_attacking(true)
		elif attack_tick >= attack_length:
			attack_tick = -1
			_set_attacking(false)
	elif _attack_pressed:
		attack_tick = 0
		attack_length = 8 if state == State.CROUCH else 6

func _set_crouching(on: bool) -> void:
	if on == (state == State.CROUCH):
		return
	state = State.CROUCH if on else State.NORMAL
	# The collision box is 40 tall standing and 28 crouching (both guesses).
	var height := 28.0 if on else 40.0
	(body_shape.shape as RectangleShape2D).size.y = height
	body_shape.position.y = -height / 2.0
	weapon_hitbox.position.y = 12.0 if on else 0.0
	# Placeholder art only: squash the block to show the crouch.
	if sprites == null:
		art.scale.y = 0.7 if on else 1.0

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
	var away := -facing if is_nan(from_x) else (1 if global_position.x >= from_x else -1)
	speed = Vector2i(KNOCKBACK.x * away, KNOCKBACK.y)

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

func revive() -> void:
	health = max_health
	state = State.NORMAL
	invulnerable_timer = 0.0
	art.visible = true
	art.modulate = Color.WHITE
	speed = Vector2i.ZERO
	velocity = Vector2.ZERO
	health_changed.emit(health, max_health)
