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
signal moved   ## every frame, after he has (or has not) moved
## A special weapon's throw has begun (the room scene makes what is thrown).
signal throw_started(crouching: bool)
var swing_sound := 0x0A   ## the sound of his weapon's swing; the room scene sets it for each turtle

enum State { NORMAL, CROUCH, HURT, DEAD, CLIMB, SWIM }   ## SWIM: under water (the swimming section at the end of this file)

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
const WALK_OFF_DELAY := 1
const DOOR_HOLD_UPDATES := 7
const POWER_WALK_SPEED := 768   ## 3 px per update with the power item
const POWER_UPDATES := 256      ## how long the power item lasts
const POWER_BLINK_FROM := 48    ## he blinks for its last 48 updates
const POWER_DAMAGE := 240       ## what his touch does to an enemy meanwhile
const ENEMY_SAFE_UPDATES := 24  ## an enemy that was hit cannot be hit again for this long
const SCREEN_WIDTH := 256.0
const SCROLL_LEFT_OF := 96.0      ## moving left, the screen scrolls while he is left of this
const SCROLL_RIGHT_FROM := 160.0  ## moving right, from this on
const SCREEN_LEFT := 20.0         ## he is kept between these two on the screen
const SCREEN_RIGHT := 236.0
const SPRITE_FEET_BELOW := 24.0   ## the original's pictures are drawn with his feet this far below his position value
## His boxes when no ROM is there to ask (the ROM's own numbers).
const DEFAULT_BODY_BOXES := { "stand": Vector2i(5, 16), "crouch": Vector2i(5, 11), "ball": Vector2i(5, 6), "swim": Vector2i(11, 6) }
const SWING_REST := 2
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
var swing_sprites: SpriteSet           ## his body's pictures while swinging, by the original's picture number
var weapon_sprites: SpriteSet          ## the weapons' pictures, by the original's picture number
var weapon_swings: Array = []          ## per direction: { places: where the weapon is each frame, half: its box }
var body_boxes := {}                   ## "stand", "crouch", "ball" -> half the size of his own hit box
var anim := "stand"
var anim_tick := 0
var sprites: SpriteSet                 ## null until a ROM is supplied: then placeholder art is used
var grounded := false                  ## standing on something
## The screen, as the original keeps it (bank 4, $9851): how far the room
## has scrolled, and where he is across the screen. Moving left with him
## left of 96, or right with him at 160 or beyond, the screen scrolls and
## he stays put on it; otherwise he moves and it does not. Each keeps its
## own fraction of a pixel, and his place in the room is the whole pixels
## of the one plus the other.
var scroll_x := 0.0
var screen_x := 0.0
var scroll_max := 0.0                  ## the furthest the room can scroll: its width less the screen's
var scroll_locked := false             ## true while the screen is held for a fight
var scroll_seen := 0.0                 ## the scroll his map tests use: one step behind while the screen scrolls
var _bumped_head := false
var _was_grounded := true
var _unheld_ticks := 0
var _just_landed := false
var room: RoomData                     ## set by the room, so the turtle can find ladders
var climb_ticks := 0                   ## updates spent moving on the ladder, for its animation
var climb_distance := 0.0              ## pixels climbed, used to step the ladder animation
var invulnerable_timer := 0.0
var _frame := 0
var _jump_pressed := false             ## remembered until the next update
var _attack_pressed := false
var _hurt_ticks := 0
var _weapon_picture := Sprite2D.new()  ## the weapon, drawn where the original has it on each step of a swing
var _weapon_box_new: Array[int] = []    ## the weapon's box after his latest update, and
var _weapon_box_old: Array[int] = []    ## after the one before (see weapon_box_for_enemies)
var _climb_step := 0.0                 ## how far the next update moves him on a ladder
var _ladder_wait := 0                  ## updates left before he moves on a ladder he has just taken
var _swing_lingers := 0                ## updates left of the swing's own box after it has ended
var _low_after := 0                    ## updates left of the low box after a downward swing has ended
var _swing_rest := 0                   ## updates left in which a new swing cannot start
## After a door his speeds do not move him for this many updates (bank 4,
## $9761: the door sets a count of 7). His routine runs meanwhile: states
## change, gravity builds up.
var hold_updates := 0
var _swing_rooted := false             ## the swing going on is a downward one begun on the ground (the original's $D4)
var _jump_held := false                ## jump has been down on every update of this jump so far
var _crouch_ticks := 0                 ## updates he has been crouching
var _crouched_before := false          ## was he crouching at the end of the update before this one
var _spinning := false                 ## in the high part of a held jump: his box is the small one
## Throwing a special weapon (Research/special_weapons.md): with one in
## use, attack starts a throw instead of a swing. It lasts 12 updates, four
## pictures of 3; he goes on walking, jumping or falling meanwhile.
const THROW_UPDATES := 12
const THROW_PICTURE_UPDATES := 3
const THROW_PICTURES := [["stand", "p11", "p5", "stand"], ["crouch", "p14", "p98", "crouch"], ["jump", "p21", "p66", "jump"]]
var special_ready := false             ## the room scene sets this while a special weapon that can be thrown is the one in use
var throw_tick := -1                   ## updates since the throw began, -1 when not throwing
var throw_pose := 0                    ## 0 standing, 1 crouching, 2 with jump held
var power_ticks := 0                   ## updates of the power item left (kind 0B), 0 when not in use

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

## Becomes another of the four turtles to look at: his name, his bandana's
## colour (for the placeholder art) and his pictures (null keeps the
## placeholder art).
func set_look(new_name: String, colour: Color, pictures: SpriteSet, swing_pictures: SpriteSet = null, weapon_pictures: SpriteSet = null) -> void:
	turtle_name = new_name
	bandana_color = colour
	bandana_art.color = colour
	sprites = pictures
	swing_sprites = swing_pictures
	weapon_sprites = weapon_pictures
	if _weapon_picture.get_parent() == null:
		_weapon_picture.centered = false
		_weapon_picture.visible = false
		art.add_child(_weapon_picture)
	body_art.visible = sprites == null
	bandana_art.visible = sprites == null
	rom_sprite.visible = sprites != null
	_update_art()

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
	elif power_ticks > 0:
		# The power item: he blinks as it runs out.
		art.visible = power_ticks >= POWER_BLINK_FROM or _frame % 4 < 2
	elif not art.visible:
		art.visible = true

	_frame += 1
	if _frame % TICK_FRAMES != 0 and swimming:
		_step_swim_picture()   # (swimming) pictures step on the frame between his updates
	if _frame % TICK_FRAMES == 0:
		_tick()
	elif throw_tick >= 0:
		_show_throw(1)   # the original's pictures change on the frame between his updates
	moved.emit()   # the room puts the screen in place now, not a frame late

## One game update, in the same order as the original: move with the
## current speed, let the controls ask for the next speed, then test the map.
func _tick() -> void:
	_weapon_box_old = _weapon_box_new
	_weapon_box_new = []
	if swimming and room != null:
		_swim_tick()   # (swimming) the whole update is the swimming section's
		_jump_pressed = false
		_attack_pressed = false
		_update_art()
		return
	if state == State.CLIMB:
		_climb()
		_jump_pressed = false
		_attack_pressed = false
		_update_art()
		return
	if power_ticks > 0:
		power_ticks -= 1
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
		_spinning = false
		if speed.y > 0:
			speed.y = 0
		if jump_tick > 0:
			jump_tick = -1
	else:
		if _bumped_head:
			if room == null:
				speed.y = 0
			jump_tick = -1
		if room == null:
			speed.y = mini(speed.y + GRAVITY, MAX_FALL_SPEED)   # in a ROM room the mover has done this

	match state:
		State.NORMAL, State.CROUCH:
			_control()
		State.HURT:
			_hurt_ticks += 1
			_swing()
			if on_floor() and _hurt_ticks > 2:
				state = State.NORMAL
				speed.x = 0
		State.DEAD:
			speed.x = 0
	if room != null:
		_test_room()
		if state == State.HURT and grounded:
			# Landed from a throw: he can act again from his next update (measured).
			state = State.NORMAL
			speed.x = 0
	_weapon_box_new = _weapon_box()
	_crouched_before = _crouch_ticks >= 1
	_crouch_ticks = _crouch_ticks + 1 if state == State.CROUCH else 0
	if _low_after > 0:
		_low_after -= 1
	if _swing_lingers > 0:
		_swing_lingers -= 1
	_jump_pressed = false
	_attack_pressed = false
	_update_art()

## Picks the animation for what the turtle is doing and shows its frame.
func _update_art() -> void:
	_fit_body()
	if swimming and _show_swim_picture():
		return   # (swimming) his own pictures
	var wanted := "stand"
	if state == State.CLIMB:
		wanted = "climb"
	elif attack_tick >= 0 and (weapon_swings.is_empty() or _swing_stage() >= 0):
		wanted = ["attack_up", "attack", "attack_crouch"][attack_direction]
	elif state == State.DEAD and sprites != null and sprites.animations.has("caught"):
		wanted = "caught"   # out of energy: four pictures of 6 updates, then he is gone (measured)
	elif state == State.HURT and sprites != null and sprites.animations.has("hurt"):
		wanted = "hurt"
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
	var frame := sprites.frame_at(anim, anim_tick)
	if anim.begins_with("attack"):
		# Two updates a frame, after the swing's first update.
		frame = sprites.frame_at(anim, _swing_stage() * 2 if _swing_stage() >= 0 else attack_tick)
	if state == State.CLIMB:
		# The ladder animation only moves while he does, up or down: the
		# first pose for 3 updates, the second for 5 (measured).
		frame = sprites.frame_at("climb", 0 if climb_ticks % 8 < 3 else 4)
	if sprites.textures.has(frame):
		rom_sprite.texture = sprites.textures[frame]
		rom_sprite.position = sprites.offsets[frame]
	rom_sprite.visible = not (anim == "caught" and anim_tick >= sprites.length("caught"))
	_weapon_picture.visible = false
	if attack_tick >= 0 and swing_sprites != null and not weapon_swings.is_empty() and weapon_swings[attack_direction].has("pictures"):
		# A swing by the ROM's own lists (each turtle has his own): his body's
		# picture for this step, and the weapon's where the table puts it.
		var swing: Dictionary = weapon_swings[attack_direction]
		var step := mini(_swing_stage() + 1 if _swing_stage() >= 0 else (0 if attack_tick < int(swing.updates) else swing.pictures.size() - 1), swing.pictures.size() - 1)
		var body := "p%d" % swing.pictures[step]
		if swing_sprites.textures.has(body):
			rom_sprite.texture = swing_sprites.textures[body]
			rom_sprite.position = swing_sprites.offsets[body]
		var weapon := "w%d" % (swing.weapon_pictures[step] if step < swing.weapon_pictures.size() else 0)
		if _swing_stage() >= 0 and weapon_sprites != null and weapon_sprites.textures.has(weapon):
			var place: Vector2 = swing.places[_swing_stage()]
			_weapon_picture.texture = weapon_sprites.textures[weapon]
			_weapon_picture.position = place + weapon_sprites.offsets[weapon] + Vector2(0, -SPRITE_FEET_BELOW)
			_weapon_picture.visible = true
	_show_throw()

## Shows one named picture of his sprite map, facing the given way, for a
## scene that moves him itself (the walk to April at the end of world 1).
func pose(frame: String, new_facing: int) -> void:
	facing = new_facing
	art.scale.x = facing
	weapon_hitbox.scale.x = facing
	_weapon_picture.visible = false
	if sprites != null and sprites.textures.has(frame):
		rom_sprite.texture = sprites.textures[frame]
		rom_sprite.position = sprites.offsets[frame]
		rom_sprite.visible = true

## The picture of a throw going on, over whatever else he would show.
func _show_throw(frames_on := 0) -> void:
	if throw_tick >= 0 and state != State.NORMAL and state != State.CROUCH:
		throw_tick = -1   # a hit, a ladder or a capture ends it
	if throw_tick < 0 or sprites == null:
		return
	var frames := throw_tick * TICK_FRAMES + frames_on
	var frame: String = THROW_PICTURES[throw_pose][mini((frames + 1) / (THROW_PICTURE_UPDATES * TICK_FRAMES), 3)]
	var from: SpriteSet = sprites if sprites.textures.has(frame) else swing_sprites
	if from != null and from.textures.has(frame):
		rom_sprite.texture = from.textures[frame]
		rom_sprite.position = from.offsets[frame]
		rom_sprite.visible = true
		_weapon_picture.visible = false

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
	# Like everything else he is moved by what the update before decided,
	# so letting go of Up or Down takes one more step (measured).
	if hold_updates > 0:
		hold_updates -= 1    # just through a door: not moved yet
		_climb_step = 0.0
	position.y += _climb_step
	climb_distance += absf(_climb_step)
	_climb_step = 0.0
	if _ladder_wait > 0:
		_ladder_wait -= 1   # taking the ladder: an update's pause first (measured)
		return
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
	_climb_step = step
	climb_ticks += 1

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
	_ladder_wait = 1
	_climb_step = 0.0
	climb_ticks = 0
	speed = Vector2i.ZERO
	jump_tick = -1
	return true

func _control() -> void:
	var direction := int(signf(Input.get_axis("move_left", "move_right")))
	if _try_grab_ladder(int(signf(Input.get_axis("move_up", "move_down")))):
		return
	# A downward swing begun on the ground roots him (bank 4, $9D49 and the
	# flag at $D4): while it lasts Left and Right do nothing at all, also
	# after a throw has put him back on the ground with it still going on.
	# One begun in the air, or with jump held, does not.
	var rooted := _swing_rooted and (attack_tick >= 0 or _swing_lingers > 0) and on_floor()   # the swing's flag outlasts it by an update
	if rooted:
		direction = 0
	if direction != 0:
		facing = direction
		art.scale.x = facing
		weapon_hitbox.scale.x = facing

	# Crouch: Down on the ground with neither Left nor Right: those come
	# first in the original's routine, so Down with one of them walks
	# (read from 4:$9D37, measured).
	_set_crouching(Input.is_action_pressed("move_down") and (direction == 0 or rooted) and on_floor())

	var walk := POWER_WALK_SPEED if power_ticks > 0 else WALK_SPEED
	var taking_off := _jump_pressed and on_floor() and state != State.CROUCH
	if taking_off:
		pass   # a jump keeps the sideways speed he already had (none from a standstill)
	elif on_floor():
		# On the ground the turtle starts and stops instantly.
		speed.x = 0 if state == State.CROUCH else direction * walk
	elif direction != 0:
		# In the air a direction takes effect at once; letting go keeps the drift.
		speed.x = direction * walk

	# The three jump heights of the original.
	var pushed := false
	if jump_tick >= 0:
		jump_tick += 1
		# The original keeps one flag for "jump still held" (bank 4, $A007):
		# an update that finds the button up clears it for the rest of the
		# jump, and pressing again does not bring it back. The cut at the
		# fourth update and the push at the eighth both go by that flag.
		_jump_held = _jump_held and Input.is_action_pressed("jump")
		if jump_tick == SHORT_JUMP_TICK and not _jump_held:
			speed.y = SHORT_JUMP_SPEED
		elif jump_tick == BOOST_TICK and _jump_held:
			speed.y = BOOST_SPEED
			# Only the high jump curls him into a ball (the original's state 8),
			# and not if a swing is going on at this moment: he then keeps his
			# full box for the rest of the jump (measured in three runs).
			pushed = true
	if taking_off:
		Sound.play(0x07)   # the jump (4:$9E79)
		_jump_held = true
		speed.y = JUMP_SPEED
		jump_tick = 0
		_spinning = false

	if _throw():
		if pushed:
			_spinning = attack_tick < 0
		return
	_swing()
	# The original sees to the attack button before the jump's count in the
	# same update (bank 4, $9FBC before $A007), so a swing begun on the very
	# update of the second push also keeps him from curling up.
	if pushed:
		_spinning = attack_tick < 0

## A special weapon's throw: begins one, or runs the one going on. Returns
## true when the attack button is the throw's business this update. The
## original chooses the pose from the buttons held (bank 4, $9EA5): jump
## held, the picture of the throw in the air; else Down, the crouching one.
func _throw() -> bool:
	if throw_tick >= 0:
		throw_tick += 1
		if throw_tick < THROW_UPDATES:
			_attack_pressed = false
			return true
		throw_tick = -1   # over: a press on this update can begin the next
	if not (special_ready and _attack_pressed and attack_tick < 0 and power_ticks == 0):
		return false
	_attack_pressed = false
	throw_tick = 0
	throw_pose = 2 if Input.is_action_pressed("jump") else (1 if Input.is_action_pressed("move_down") else 0)
	throw_started.emit(throw_pose == 1)
	return true

## The swing: starting one when attack is pressed, and running it. The
## original does this while he is thrown by a hit as well (measured: a
## swing goes on through a hit, and one can be started in the air after it).
func _swing() -> void:
	# Attack: the sword is out from the second frame of the swing.
	if attack_tick >= 0:
		attack_tick += 1
		if attack_tick >= attack_length:
			attack_tick = -1
			_swing_rest = SWING_REST
			_swing_lingers = 2
			if attack_direction == 2 and not weapon_swings.is_empty():
				_low_after = 3
			_set_attacking(false)
		elif weapon_swings.is_empty():
			if attack_tick == 2:
				_set_attacking(true)   # no ROM: the stand-in swing is out from its second frame
		else:
			_place_weapon()
	elif _swing_rest > 0:
		# For two updates after a swing a press of attack is thrown away
		# (measured: the next swing can start 11 updates after a forward
		# one began, 13 after an upward one).
		_swing_rest -= 1
		if _swing_rest == 0 and _attack_pressed and power_ticks == 0:
			_begin_swing()
	elif _attack_pressed and power_ticks == 0:
		_begin_swing()

## Starts a swing: which one, and how long it lasts.
func _begin_swing() -> void:
	Sound.play(swing_sound)   # his weapon's swish (4:$9F5C)
	attack_tick = 0
	# A swing begun while he is curled up shows its own box for as long as
	# it lasts; after it he is curled up again (measured in a boss fight).
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
		# Its length: the first update, each frame's updates, and the last
		# frame's worth at his middle (Leonardo: 2 updates a frame, so
		# places * 2 + 3; the others' lists give 1 or 5 updates a frame).
		_swing_rooted = attack_direction == 2 and on_floor() and not Input.is_action_pressed("jump")
		var swing: Dictionary = weapon_swings[attack_direction]
		attack_length = (swing.places.size() + 2) * int(swing.get("updates", 2)) - 1
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
	if hold_updates > 0:
		hold_updates -= 1    # just through a door: not moved yet
	else:
		move_across(speed.x / 256.0)
		position.y += speed.y / 256.0
	if not grounded:
		# In the air: gravity, the whole pixels of the speed held at 9.
		speed.y = mini(speed.y + GRAVITY, MAX_FALL_SPEED)

## The second half of an update in a ROM room: the map is tested where he
## now stands, with the speeds the controls have just asked for, and the
## speeds are cut where something is in the way. (The original's order,
## read from its code: move, then the turtle's own routine.)
func _test_room() -> void:
	_bumped_head = false
	# While the screen scrolls the original's tests still use the scroll
	# from before this step (seen in the emulator; its scroll is only asked
	# for at this point and carried out later in the frame).
	var x := floorf(scroll_seen) + floorf(screen_x)
	var feet := floorf(position.y)
	if grounded and speed.y < 0:
		grounded = false   # a jump has begun: its first tests come next update
		return
	if grounded:
		var walking := speed.x != 0
		var held := false
		if walking:
			# Only a wall (kind 4) stops a walk; a moving floor's side does not.
			var ahead := 9.0 if speed.x > 0 else -9.0
			if _feel(x + ahead, feet - 7.0) == RoomData.KIND_SOLID or _feel(x + ahead, feet - 24.0) == RoomData.KIND_SOLID:
				speed.x = 0
			# Under his right foot first; only if nothing at all is there
			# does his left foot get a say.
			var right := _feel(x + 6.0, feet + 1.0)
			if right == RoomData.KIND_EMPTY:
				held = _stands_on(x - 6.0, feet + 1.0)
			else:
				held = right != RoomData.KIND_DOOR and right != RoomData.KIND_HURTS
		else:
			_feel(x, feet - 3.0)
			held = _stands_on(x, feet + 1.0)
		# With nothing under him the original spends one update changing
		# over (its state 6) before the fall begins.
		_unheld_ticks = 0 if held else _unheld_ticks + 1
		if _unheld_ticks > WALK_OFF_DELAY:
			grounded = false
			speed.y = 0
			_unheld_ticks = 0
		return
	if speed.y < 0 and _blocks_in_air(x, feet - 32.0):
		_bumped_head = true
		speed.y = 0
	var side := 1.0 if speed.x >= 0 else -1.0
	if _blocks_in_air(x + side * 6.0, feet - 32.0) or _blocks_in_air(x + side * 7.0, feet - 20.0) or _blocks_in_air(x + side * 7.0, feet - 3.0):
		speed.x = 0
	if speed.y >= 0 and _lands_on(x, feet):
		var lifted := 0
		while _lands_on(x, feet + 2.0) and lifted < 32:
			feet -= 1.0     # up until the point just above his soles is clear
			lifted += 1
		# Out of a wall, 2 pixels at a time (a wall only: kind 4), on the
		# side he is still moving towards: if the wall has just stopped him
		# his speed is nought, and the original then looks to his right.
		side = 1.0 if speed.x >= 0 else -1.0
		var pushed_from := x
		while room.kind_at_pixel(x + side * 8.0, feet - 13.0) == RoomData.KIND_SOLID and absf(x - pushed_from) < 32.0:
			x -= side * 2.0
		# The fractions of his position are kept, as in the original.
		place_across(position.x + x - pushed_from)
		position.y = feet + position.y - floorf(position.y)
		speed = Vector2i.ZERO
		grounded = true
		Sound.play(0x08)   # landing (4:$A1AE)
		_unheld_ticks = 0

## The kind of tile at a point one of his tests looks at. A hurting tile
## (kind 1) found this way costs him energy there and then: the original
## hurts him only where its own tests look, not anywhere his body is.
func _feel(x: float, y: float) -> int:
	var kind := room.kind_at_pixel(x, y)
	if kind == RoomData.KIND_HURTS:
		tile_hurt(RoomData.HURT_DAMAGE)
	return kind

## In the air these stop him: walls and both moving floors.
func _blocks_in_air(x: float, y: float) -> bool:
	var kind := _feel(x, y)
	return kind == RoomData.KIND_SOLID or kind == RoomData.KIND_MOVING_FLOOR or kind == RoomData.KIND_MOVING_FLOOR_LEFT

## Puts the screen's left edge where a door's record says, with him where
## he already is.
func put_screen(left: float) -> void:
	scroll_x = clampf(left, 0.0, scroll_max)
	scroll_seen = scroll_x
	screen_x = position.x - scroll_x

## He has just come through a door: hanging on a ladder, standing, or in
## the air; and held for his first 7 updates.
func arrive(on_ladder: bool, on_ground: bool) -> void:
	_set_crouching(false)
	attack_tick = -1
	_set_attacking(false)
	jump_tick = -1
	speed = Vector2i.ZERO
	_climb_step = 0.0
	_ladder_wait = 0
	_unheld_ticks = 0
	hold_updates = DOOR_HOLD_UPDATES
	if on_ladder:
		state = State.CLIMB
		climb_ticks = 0
	else:
		state = State.NORMAL
		grounded = true       # in the air he finds that out on his first update, as in the original
		_was_grounded = true

## Brings the screen numbers into line when something else has moved him
## (a door, a test, the fly key): the screen is put with him at its middle,
## or, when it is held, he is kept on it.
func sync_screen() -> void:
	if absf(floorf(scroll_x) + screen_x - position.x) < 0.001:
		return
	if scroll_locked:
		screen_x = clampf(position.x - floorf(scroll_x), SCREEN_LEFT, SCREEN_RIGHT)
	else:
		scroll_x = clampf(floorf(position.x) - SCREEN_WIDTH / 2.0, 0.0, scroll_max)
		screen_x = position.x - scroll_x
		scroll_seen = scroll_x
	position.x = floorf(scroll_x) + screen_x

## Moves him sideways the original's way: the screen scrolls or he does.
func move_across(step: float) -> void:
	sync_screen()
	scroll_seen = scroll_x
	if step == 0.0:
		return
	var scrolls := false
	if not scroll_locked and room != null:
		if step < 0.0:
			scrolls = floorf(screen_x) < SCROLL_LEFT_OF and floorf(scroll_x) > 0.0
		else:
			scrolls = floorf(screen_x) >= SCROLL_RIGHT_FROM and scroll_x + step <= scroll_max
	scroll_seen = scroll_x
	if scrolls:
		scroll_x = clampf(scroll_x + step, 0.0, scroll_max)
	else:
		screen_x += step
	if room != null:
		# Kept on the screen by his whole pixels; the fraction is left as
		# it is (measured against the right side: he creeps on by quarters).
		if floorf(screen_x) > SCREEN_RIGHT or floorf(screen_x) < SCREEN_LEFT:
			screen_x = clampf(floorf(screen_x), SCREEN_LEFT, SCREEN_RIGHT) + screen_x - floorf(screen_x)
	position.x = floorf(scroll_x) + screen_x

## Puts him at a place in the room without scrolling the screen.
func place_across(x: float) -> void:
	sync_screen()
	screen_x += x - position.x
	position.x = floorf(scroll_x) + screen_x

## Something he can stand on: anything but empty space, a hurting tile or
## a doorway (the original's list).
func _stands_on(x: float, y: float) -> bool:
	var kind := room.kind_at_pixel(x, y)
	return kind != RoomData.KIND_EMPTY and kind != RoomData.KIND_HURTS and kind != RoomData.KIND_DOOR

## Coming down: is the point 3 pixels above his feet in a floor? A ladder
## counts only at its top.
func _lands_on(x: float, feet: float) -> bool:
	var kind := _feel(x, feet - 3.0)
	if kind == RoomData.KIND_SOLID or kind == RoomData.KIND_MOVING_FLOOR or kind == RoomData.KIND_MOVING_FLOOR_LEFT or kind == RoomData.KIND_DEADLY:
		return true
	# A ladder's top, looked up the way every other point is (by cells in a
	# ROM room: a lone ladder tile that is not a cell's top-left one is not
	# there for him; measured in the last room).
	var above := room.kind_at_pixel(x, feet - 13.0)
	return (kind == RoomData.KIND_LADDER or kind == RoomData.KIND_LADDER_TOP) \
		and above != RoomData.KIND_LADDER and above != RoomData.KIND_LADDER_TOP

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
	var stage := _swing_stage()
	var place := Vector2.ZERO
	# Measured: the crouching swing's first frame keeps the weapon at his
	# middle whatever the table says.
	if stage >= 0 and not (attack_direction == 2 and stage == 0) and _weapon_shown(stage):
		place = places[stage]
	var half: Vector2 = swing.half
	var rectangle := weapon_shape.shape as RectangleShape2D
	# The original's test lets boxes that just meet count on the left and
	# above, but not on the right and below (bank 6, $9AD3). Godot counts
	# every meeting, so the box is half a pixel short on those two sides.
	rectangle.size = half * 2.0 - Vector2(0.5, 0.5)
	weapon_hitbox.position.y = 0.0
	weapon_shape.position = Vector2(place.x - 0.25 * facing, place.y - 0.25 - CENTRE_ABOVE_FEET + (8.0 if state == State.CROUCH else 0.0))

## The weapon's box in whole pixels as it stands after this update: its
## middle across the screen (not the room) and down, half its width and
## half its height. Empty when he is not swinging.
func _weapon_box() -> Array[int]:
	if attack_tick < 0 or weapon_swings.is_empty():
		return []
	var swing: Dictionary = weapon_swings[attack_direction]
	var stage := _swing_stage()
	var place := Vector2.ZERO
	if stage >= 0 and not (attack_direction == 2 and stage == 0) and _weapon_shown(stage):
		place = swing.places[stage]
	var half: Vector2 = swing.half
	var lower := 8 if state == State.CROUCH or _low_swing() else 0
	sync_screen()
	# The fifth number is the weapon's own height without the 8: the original
	# asks "which of the two is higher" with that (bank 6, $9AF7) and only
	# builds the box 8 lower.
	var own := floori(position.y) - int(CENTRE_ABOVE_FEET) + int(place.y)
	return [floori(screen_x) + int(place.x) * facing, own + lower, int(half.x), int(half.y), own]

## The weapon's box as the enemies' hit test meets it. The original puts
## the weapon in place at the end of the enemies' frame, after hits have
## been worked out, so the test always sees where the weapon was put one
## update before: on the first update of a swing there is nothing to hit
## with yet (read from the frame's order at 7:$CC7E, and measured).
## The weapon keeps its place on the screen meanwhile, so if the screen
## has scrolled since, it has moved with it.
func weapon_box_for_enemies() -> Array[int]:
	if _weapon_box_old.is_empty():
		return _weapon_box_old
	return [_weapon_box_old[0] + floori(scroll_x), _weapon_box_old[1], _weapon_box_old[2], _weapon_box_old[3], _weapon_box_old[4]]

## Which frame of the swing he is on, or -1 for its first update and its
## last two, when the weapon is at his middle and he stands as usual.
## Measured in the emulator: one update, then two for each frame, then two.
func _swing_stage() -> int:
	if attack_tick < 0 or weapon_swings.is_empty():
		return -1
	# Two updates a frame for Leonardo; the ROM's animation gives each
	# turtle's own number (Raphael and Michelangelo 1, Donatello 5 forward).
	var updates := int(weapon_swings[attack_direction].get("updates", 2))
	var stage := (attack_tick + 1) / updates - 1
	return stage if stage >= 0 and stage < weapon_swings[attack_direction].places.size() else -1

## Does the weapon's own animation show a picture on this frame of the
## swing? (Leonardo's crouching swing has none on its first frame.)
func _weapon_shown(stage: int) -> bool:
	var pictures: Variant = weapon_swings[attack_direction].get("weapon_pictures")
	return pictures == null or stage + 1 >= (pictures as PackedInt32Array).size() or pictures[stage + 1] != 0

## His own hit box, as the ROM has it: centred on his middle (20 above his
## feet), smaller while he spins through the air, and lower when he crouches.
func _fit_body() -> void:
	if body_boxes.is_empty():
		return
	var which := _body_box_name()
	var lower := 8.0 if state == State.CROUCH else 0.0
	var half := Vector2(body_boxes[which])
	var rectangle := body_shape.shape as RectangleShape2D
	if rectangle.size != half * 2.0 or body_shape.position.y != lower - CENTRE_ABOVE_FEET:
		rectangle.size = half * 2.0
		body_shape.position = Vector2(0.0, lower - CENTRE_ABOVE_FEET)

## A downward swing keeps him in his crouching box, lowered, for as long
## as it lasts, also in the air. When it is over the low box stays for
## one update more, then the full box 8 lower for one, then all is as
## usual (measured: the original clears its flags an update apart).
func _low_swing() -> bool:
	return attack_tick >= 0 and attack_direction == 2 and not weapon_swings.is_empty()

## Which of his boxes he has just now.
func _body_box_name() -> String:
	if state == State.SWIM:
		return "swim"   # (swimming) one flat box for all four swimming animations
	if state == State.CROUCH or _low_swing() or _low_after >= 2:
		return "crouch"
	if state == State.NORMAL and _spinning and not on_floor() and attack_tick < 0 and _swing_lingers == 0:   # the swing's picture, and box, last one update past its end
		return "ball"
	return "stand"

## His hit box in whole pixels, for the original's own touch test
## (OriginalEnemy.touches_turtle): the middle across, the middle down
## (8 lower when he crouches), half the width and half the height.
func touch_box() -> Array[int]:
	var half: Vector2i = body_boxes.get(_body_box_name(), DEFAULT_BODY_BOXES[_body_box_name()])
	# The box changes size on the update he crouches or gets up; it drops,
	# or comes back up, the update after (measured: the original's "lower"
	# flag runs one update behind, also when he jumps out of a crouch).
	# The same on the first update of a downward swing begun in the air.
	var lower := 8 if _crouched_before or (_low_swing() and attack_tick >= 1) or _low_after >= 1 else 0
	var own := floori(position.y) - int(CENTRE_ABOVE_FEET)
	return [floori(position.x), own + lower, half.x, half.y, own]   # the fifth: his own height without the 8, see _weapon_box

func _set_attacking(on: bool) -> void:
	weapon_art.visible = on and sprites == null
	# Physics shapes must be switched with set_deferred, not directly.
	weapon_shape.set_deferred("disabled", not on)

## Called by anything that hurts the turtle. `from_x` is where the hit came
## from, so the turtle is knocked away from it.
## What an enemy calls when it touches him. With the power item running
## the touch hurts the enemy instead (the original's hit number 16: 240).
## Returns true if he was hurt.
func touched_by(enemy: Node, amount: int) -> bool:
	if power_ticks > 0:
		if enemy.has_method("take_hit") and weapon_lands(enemy):
			enemy.take_hit(POWER_DAMAGE)
		return false
	return take_damage(amount, enemy.global_position.x)

## May a hit land on this enemy now? After one lands the enemy blinks and
## nothing more can hit it for 24 updates (bank 6, $9955). True starts
## that time running.
static func weapon_lands(enemy: Node) -> bool:
	var now := Engine.get_physics_frames()
	if now < int(enemy.get_meta("safe_until", 0)):
		return false
	enemy.set_meta("safe_until", now + ENEMY_SAFE_UPDATES * TICK_FRAMES)
	Sound.play(0x21)   # a weapon lands (6:$9948)
	if enemy is CanvasItem and enemy.is_inside_tree():
		var blink := enemy.create_tween().set_loops(ENEMY_SAFE_UPDATES / 2)
		blink.tween_property(enemy, "modulate:a", 0.25, 2.0 / 60.0)
		blink.tween_property(enemy, "modulate:a", 1.0, 2.0 / 60.0)
	return true

## The power item (kind 0B): 256 updates in which nothing that touches him
## hurts him, he walks at 3 pixels an update and cannot swing.
func start_power() -> void:
	if state == State.DEAD:
		return
	power_ticks = POWER_UPDATES
	attack_tick = -1
	_set_attacking(false)

## Returns true when the hit landed (false while he blinks, or is dead, or
## has the power item running).
func take_damage(amount: int, from_x: float = NAN) -> bool:
	if invulnerable_timer > 0.0 or state == State.DEAD or power_ticks > 0:
		return false
	Sound.play(0x25)   # hurt (6:$98F5)
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_set_crouching(false)
	if health == 0:
		attack_tick = -1
		_set_attacking(false)
		state = State.DEAD
		art.modulate = Color(0.5, 0.5, 0.5)
		died.emit()
		return true
	if state == State.SWIM:
		invulnerable_timer = invulnerable_time   # (swimming) hurt but not thrown; a guess for touches, read for tiles
		_swim_hurt = true
		return true
	state = State.HURT   # a swing under way goes on (measured)
	_hurt_ticks = 0
	jump_tick = -1
	invulnerable_timer = invulnerable_time
	# Thrown away from what hit him; level with it, to the left (bank 6, $989E).
	var away := -facing if is_nan(from_x) else (1 if floorf(from_x) < floorf(global_position.x) else -1)
	speed = Vector2i(KNOCKBACK_RIGHT if away > 0 else KNOCKBACK_LEFT, KNOCKBACK_UP)
	grounded = false   # thrown: he is in the air at once, so the pull acts from his first update (measured)
	if room != null:
		_test_room()   # and the map is felt at once: against a wall he is not thrown into it (measured)
	return true

## A hurting tile: energy lost and the blinking safe time, but he is not
## thrown and keeps doing what he was doing (bank 4, $A5BB).
func tile_hurt(amount: int) -> void:
	if invulnerable_timer > 0.0 or state == State.DEAD:
		return
	Sound.play(0x25)   # hurt by a tile (4:$A5CC)
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	invulnerable_timer = invulnerable_time
	_swim_hurt = swimming
	if health == 0:
		attack_tick = -1
		_set_attacking(false)
		_set_crouching(false)
		state = State.DEAD
		art.modulate = Color(0.5, 0.5, 0.5)
		died.emit()

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


# =====================================================================
# SWIMMING: the lake of world 2 (Research/swimming.md).
# Written from the original's state 0F (bank 4, $A78B) and the lines of
# its update that ask "is he swimming" ($D3). Nothing in this section is
# used unless the room scene sets `swimming`; walking, jumping and
# climbing never come here.
# =====================================================================

signal swim_row_wanted(way: int)   ## he has reached the top (-1) or bottom (1) of the screen: the room changes row

const SWIM_SPEED := 512            ## 2 pixels an update, left or right
const SWIM_SINK := 16              ## added to his downward speed every update
const SWIM_STROKE := -224          ## a new press of jump
const SWIM_FASTEST := 512          ## up or down: 2 pixels an update
const SWIM_TOP := 16               ## his middle is kept between these two down the screen;
const SWIM_BOTTOM := 181           ## at either the screen changes row
const SWIM_SIDE := 13.0            ## the map is felt this far to the side, at
const SWIM_SIDE_HIGH := 7.0        ## this far above and below his middle,
const SWIM_HEAD := 7.0             ## and this far above (rising) or below (sinking) it, at
const SWIM_HEAD_SIDE := 8.0        ## his middle and this far to each side
const SWIM_CURRENT_UP := 0x10      ## the original's values for the current he is in
const SWIM_CURRENT_DOWN := 0x20
const SWIM_CURRENT_RIGHT := 0x40
const SWIM_CURRENT_LEFT := 0x80
const SWIM_CURRENT_DRIFT := 18     ## what a current up or down adds every update
const SWIM_CURRENT_PUSH := 48      ## what one to the side adds; and Down held in any current, downward
const SWIM_ANIMATION_STROKE := 0xBC   ## the original's animation numbers
const SWIM_ANIMATION_ACROSS := 0xBE
const SWIM_ANIMATION_SINK := 0xBF
const SWIM_ANIMATION_DOWN := 0x8C
const SWIM_PICTURES := { 0xBC: [0x80, 0x81, 0x82], 0xBE: [0x83, 0x84, 0x85], 0xBF: [0x83], 0x8C: [0x86, 0x87, 0x88] }
const SWIM_PICTURE_UPDATES := 5
const SWIM_DEAD_PICTURES := [0x9F, 0xA0, 0xA1]   ## out of energy: 6 updates each, then nothing
const SWIM_CRUSHED_PICTURES := [0xA2, 0xA3, 0xA4, 0xA5]   ## killed by the map: 16 updates each
const SWIM_CRUSHED_RISE := 13      ## and he is put this far up when that happens

var swimming := false              ## set by the room scene in the underwater area
var swim_current := 0              ## the current he is in (one of SWIM_CURRENT_..., the room scene sets it), 0 for none
var swim_screen_top := 0.0         ## the top of the screen in the room (the room scene keeps it)
var swim_animation := SWIM_ANIMATION_SINK
var swim_step := 0                 ## which picture of the animation
var swim_left := SWIM_PICTURE_UPDATES   ## updates before the next
var swim_picture := 0x83
var swim_sprites: SpriteSet        ## the swimming pictures, by the original's picture number
var swim_crushed := false          ## killed by the map's deadly kind
var _swim_hurt := false            ## hurt under water: the water flashes while he blinks
var _swim_dead_updates := 0
var _swim_bubble := Sprite2D.new()
var _swim_bubble_at := Vector2.ZERO   ## the bubble's place in the room
const SWIM_BUBBLE_FRAME := "p137"
const SWIM_BUBBLE_LEFT := -8.0     ## where it starts from his middle, facing left
const SWIM_BUBBLE_RIGHT := 14.0    ## ...and facing right
const SWIM_BUBBLE_UP := 12.0
const SWIM_BUBBLE_RISE := 1.5

## One update under water, in the original's order: he is moved by the
## speeds his last update left, kept on the screen, and then his routine
## sets the speeds for the next one and feels the map.
func _swim_tick() -> void:
	if state == State.DEAD:
		_swim_dead_updates += 1
		return
	var scroll_before := scroll_x
	if hold_updates > 0:
		hold_updates -= 1
	else:
		move_across(speed.x / 256.0)
		position.y += speed.y / 256.0
	var fraction := position.y - floorf(position.y)
	var middle := floori(position.y) - int(CENTRE_ABOVE_FEET) - int(swim_screen_top)
	if middle < SWIM_TOP or middle >= SWIM_BOTTOM:
		speed.y = 0
		middle = SWIM_TOP if middle < SWIM_TOP else SWIM_BOTTOM
		position.y = swim_screen_top + middle + CENTRE_ABOVE_FEET + fraction
	if (middle == SWIM_TOP or middle == SWIM_BOTTOM) and not scroll_locked:
		# Nothing else happens on this update, and a step the screen was to
		# scroll for is lost (measured: the screen stays where it was).
		if scroll_x != scroll_before:
			scroll_x = scroll_before
			scroll_seen = scroll_x
			position.x = floorf(scroll_x) + screen_x
		swim_row_wanted.emit(-1 if middle == SWIM_TOP else 1)
		return
	if swim_crushed:
		# Killed by the map: put 13 higher, all his energy gone.
		position.y -= SWIM_CRUSHED_RISE
		speed = Vector2i.ZERO
		_swim_bubble.visible = false
		drain(health)
		return
	if state != State.SWIM:
		# The ground routine's first lines: under water it only changes him
		# over, and his swimming begins with the next update.
		state = State.SWIM
		grounded = false
		attack_tick = -1
		_set_attacking(false)
		_set_crouching(false)
		return
	_swim_routine()

## The original's state 0F.
func _swim_routine() -> void:
	_start_bubble()
	var left := Input.is_action_pressed("move_left")
	var right := Input.is_action_pressed("move_right")
	var up := Input.is_action_pressed("move_up")
	var down := Input.is_action_pressed("move_down")
	var stroke_held := Input.is_action_pressed("jump")
	if left or right:
		facing = -1 if left else 1   # with both held he faces left
		art.scale.x = facing
	var animation := SWIM_ANIMATION_STROKE
	if not (left or right or up or down):
		animation = SWIM_ANIMATION_STROKE if stroke_held or speed.y < 0 else SWIM_ANIMATION_SINK
	elif not (up or down):
		animation = SWIM_ANIMATION_ACROSS
	elif down:
		animation = SWIM_ANIMATION_DOWN
	_start_swim_animation(animation)
	# Sideways: the whole pixels are set, the fraction is left as it was.
	var across := 0
	if right != left:
		across = SWIM_SPEED if right else -SWIM_SPEED
	speed.x = across + posmod(speed.x, 256)
	# Sinking, held to 2 whole pixels; a stroke; then the current.
	speed.y += SWIM_SINK
	if speed.y >= SWIM_FASTEST:
		speed.y = SWIM_FASTEST + posmod(speed.y, 256)
	if _jump_pressed:
		speed.y += SWIM_STROKE
		if speed.y < -768:
			speed.y = -768 + posmod(speed.y, 256)
	if swim_current != 0:
		match swim_current & 0xF0:
			SWIM_CURRENT_UP: speed.y -= SWIM_CURRENT_DRIFT
			SWIM_CURRENT_DOWN: speed.y += SWIM_CURRENT_DRIFT
			SWIM_CURRENT_RIGHT: speed.x += SWIM_CURRENT_PUSH
			SWIM_CURRENT_LEFT: speed.x -= SWIM_CURRENT_PUSH
		if down:
			speed.y += SWIM_CURRENT_PUSH
	speed.y = clampi(speed.y, -SWIM_FASTEST, SWIM_FASTEST)
	# The map, felt where his speed's whole pixels would take him.
	var here := floorf(scroll_seen) + floorf(screen_x)
	var x := here + float(speed.x >> 8)
	var y := floorf(position.y) - CENTRE_ABOVE_FEET + float(speed.y >> 8)
	if speed.x != 0:
		var side := SWIM_SIDE if speed.x >= 0 else -SWIM_SIDE
		if _swim_blocked(x + side, y - SWIM_SIDE_HIGH) or _swim_blocked(x + side, y + SWIM_SIDE_HIGH):
			speed.x = 0
			x = here   # the looks up and down that follow use the speed as it now is
	var ahead := -SWIM_HEAD if speed.y < 0 else SWIM_HEAD
	if _swim_blocked(x, y + ahead) or _swim_blocked(x + SWIM_HEAD_SIDE, y + ahead) or _swim_blocked(x - SWIM_HEAD_SIDE, y + ahead):
		speed.y = 0

## One of the swimming routine's looks at the map: a wall stops him, the
## hurting kind hurts and lets him through, the deadly kind kills.
func _swim_blocked(x: float, y: float) -> bool:
	if state == State.DEAD:
		return true
	var kind := room.kind_at_pixel(x, y)
	if kind == RoomData.KIND_SOLID:
		return true
	if kind == RoomData.KIND_HURTS:
		tile_hurt(RoomData.HURT_DAMAGE)
	elif kind == RoomData.KIND_DEADLY:
		swim_crushed = true   # the original's state 13: it acts on his next update
		return true
	return false

func _start_swim_animation(animation: int) -> void:
	if animation == swim_animation:
		return
	swim_animation = animation
	swim_step = 0
	swim_left = SWIM_PICTURE_UPDATES

## The bubble: the original keeps it in the weapon's object slot. It
## starts by his head whenever there is none (bank 4, $A910), rises 1.5
## pixels an update and goes when it is less than 16 from the screen's top
## (measured).
func _start_bubble() -> void:
	if _swim_bubble.get_parent() == null:
		_swim_bubble.centered = false
		_swim_bubble.top_level = true
		_swim_bubble.z_index = 1
		add_child(_swim_bubble)
		_swim_bubble.visible = false
	if _swim_bubble.visible or swim_sprites == null or not swim_sprites.textures.has(SWIM_BUBBLE_FRAME):
		return
	_swim_bubble.texture = swim_sprites.textures[SWIM_BUBBLE_FRAME]
	_swim_bubble_at = Vector2(floorf(position.x) + (SWIM_BUBBLE_LEFT if facing < 0 else SWIM_BUBBLE_RIGHT), floorf(position.y) - CENTRE_ABOVE_FEET - SWIM_BUBBLE_UP)
	_swim_bubble.visible = true
	_place_bubble()

func _place_bubble() -> void:
	_swim_bubble.global_position = get_parent().to_global(_swim_bubble_at.floor()) + swim_sprites.offsets[SWIM_BUBBLE_FRAME] if get_parent() is Node2D else _swim_bubble_at

func _step_bubble() -> void:
	if not _swim_bubble.visible:
		return
	_swim_bubble_at.y -= SWIM_BUBBLE_RISE
	if floorf(_swim_bubble_at.y) - swim_screen_top < SWIM_TOP:
		_swim_bubble.visible = false
	else:
		_place_bubble()

## The original steps every object's animation on the frame between the
## turtle's updates.
func _step_swim_picture() -> void:
	if state != State.SWIM:
		return
	_step_bubble()
	swim_left -= 1
	var pictures: Array = SWIM_PICTURES[swim_animation]
	if swim_left == 0:
		swim_step += 1
		swim_left = SWIM_PICTURE_UPDATES
		if swim_step >= pictures.size():
			swim_step = 0   # the list's end mark takes this frame: the first picture shows from the next
			return
	swim_picture = pictures[swim_step]

## Shows the swimming picture; false when there is none to show (no ROM
## pictures, or he is not yet swimming).
func _show_swim_picture() -> bool:
	if swim_sprites == null or (state != State.SWIM and state != State.DEAD):
		return false
	_fit_body()
	_weapon_picture.visible = false
	var picture := swim_picture
	if state == State.DEAD:
		var list: Array = SWIM_CRUSHED_PICTURES if swim_crushed else SWIM_DEAD_PICTURES
		var each := 16 if swim_crushed else 6
		var step := _swim_dead_updates / each
		rom_sprite.visible = step < list.size()
		if step >= list.size():
			return true
		picture = list[step]
	else:
		rom_sprite.visible = true
	var frame := "p%d" % picture
	if swim_sprites.textures.has(frame):
		rom_sprite.texture = swim_sprites.textures[frame]
		rom_sprite.position = swim_sprites.offsets[frame] + Vector2(0, -CENTRE_ABOVE_FEET)
	return true

## Out of the water (another room, the overworld, a new turtle).
func stop_swimming() -> void:
	swimming = false
	swim_current = 0
	swim_crushed = false
	_swim_bubble.visible = false
	_swim_hurt = false
	_swim_dead_updates = 0
	if state == State.SWIM:
		state = State.NORMAL
