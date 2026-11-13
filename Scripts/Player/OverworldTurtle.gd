class_name OverworldTurtle
extends Node2D
## The small turtle that walks around the top-down overworld map.
## With a ROM he is drawn from the turtles' own overworld sprites
## (Resources/AssetRipper/Sprites/LeonardoOverworld.json, shared by all four
## with the bandana's colour changed); without one he is a green block with
## the bandana on the side he faces.
##
## His walk (Research/overworld.md): each direction has a standing picture
## and two strides, shown as stand, stride, stand, other stride, 8 updates
## each. The count starts again whenever he stops or turns between across,
## up and down; turning from left to right or back does not restart it.
##
## Movement copies the original (see Research/doors.md):
## - One update every 2 frames, 2 pixels per update, no diagonals.
##   Left/right wins when both a sideways and an up/down key are held.
## - Before each step the game looks at ONE point ahead of him. A wall or
##   water there stops him; a doorway there sends him through the door.

signal door_reached(door: Door)
signal moved   ## every frame, after he has (or has not) moved

const TICK_FRAMES := 2
const STEP := 2
## Where the game looks before a step, measured from his centre.
const PROBES := {
	Vector2i.UP: Vector2i(0, -3),
	Vector2i.DOWN: Vector2i(0, 6),
	Vector2i.RIGHT: Vector2i(7, 3),
	Vector2i.LEFT: Vector2i(-7, 3),
}

var room: RoomData
var door_reach := 32.0          ## how close to a door's own spot he must be
var facing := Vector2i.DOWN
var bandana_color := Color(0.2, 0.45, 1.0)
var camera: Camera2D
var rest_frames := 0            ## frames left to stand still (just came through a door)
var sprites: SpriteSet          ## null without a ROM
var _frame := 0
var _steps := 0                 ## updates walked in the current animation, which picks its picture
var _animation := ""            ## the walk being shown: "right" (also left), "up" or "down"; "" standing
var updated := false            ## true on the frames his own update ran (every second frame)
## His attack (Research/overworld.md), set by the map scene from the ROM:
## one entry per direction number (0 down, 1 up, 2 right, 3 left), as
## RomLevels.overworld_swing gives them. Empty: he cannot attack.
var swings: Array = []
var swing_sound := 0x0A         ## the swing's sound; the map scene sets it for each turtle
var weapon_sprites: SpriteSet   ## the weapons' pictures, by the original's picture number
var attack_tick := -1           ## updates since the attack began, -1 when not attacking
var attack_direction := 0
var sideways_left := false      ## the way he last walked across: it mirrors the weapon going up and down
var safe_updates := 0           ## updates left in which nothing can hurt him (he blinks)
var picture_name := ""          ## the frame on show, e.g. "f148" (the original's picture number 148)
var _picture := Sprite2D.new()
var _weapon := Sprite2D.new()
var _attack_pressed := false    ## remembered until his next update
var _attack_slide := Vector2i.ZERO   ## the way he was walking when the attack began: he keeps going that way

func _init() -> void:
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.position = Vector2(0, 24)   # the HUD strip covers the bottom 48 pixels
	add_child(camera)
	_picture.centered = false
	add_child(_picture)
	_weapon.centered = false
	_weapon.visible = false
	add_child(_weapon)

func _ready() -> void:
	sprites = SpriteSet.cached("LeonardoOverworld")
	_show_picture(false)

func _physics_process(_delta: float) -> void:
	_update()
	moved.emit()

func _update() -> void:
	updated = false
	if Input.is_action_just_pressed("attack"):
		_attack_pressed = true
	if rest_frames > 0:
		rest_frames -= 1
		return
	_frame += 1
	if _frame % TICK_FRAMES != 0:
		return
	updated = true
	if safe_updates > 0:
		safe_updates -= 1
	visible = safe_updates == 0 or safe_updates % 2 == 0   # he blinks while nothing can hurt him
	if attack_tick >= 0:
		_attack_pressed = false
		attack_tick += 1
		if attack_tick >= attack_length():
			attack_tick = -1
			_slide()   # the update that ends it still carries him on
			stand()
		else:
			_slide()
			_show_attack()
		return
	var across := int(signf(Input.get_axis("move_left", "move_right")))
	var down := int(signf(Input.get_axis("move_up", "move_down")))
	var way := Vector2i(across, 0) if across != 0 else Vector2i(0, down)
	if _attack_pressed and not swings.is_empty():
		# Attack with a direction held: he turns that way, and goes on
		# walking that way while the attack lasts (measured).
		_attack_pressed = false
		if way != Vector2i.ZERO:
			facing = way
			if way.x != 0:
				sideways_left = way.x < 0
		Sound.play(swing_sound)   # his weapon's swish (4:$9F5C)
		start_attack()
		_attack_slide = way
		_slide()
		return
	_attack_pressed = false
	if way != Vector2i.ZERO:
		step(way)
	else:
		stand()

## One update of walking on during an attack. A wall, water or a doorway
## ahead stops it (the doorway is not used). How the original treats walls
## here was not measured.
func _slide() -> void:
	if _attack_slide == Vector2i.ZERO or room == null:
		return
	var probe := position + Vector2(PROBES[_attack_slide])
	if room.kind_at_pixel(probe.x, probe.y) == RoomData.KIND_DOOR or room.blocks_walker(probe.x, probe.y):
		_attack_slide = Vector2i.ZERO
		return
	position += Vector2(_attack_slide * STEP)

## The direction number the original uses for the way he faces.
func direction_number() -> int:
	if facing == Vector2i.DOWN:
		return 0
	if facing == Vector2i.UP:
		return 1
	return 2 if facing == Vector2i.RIGHT else 3

## Begins the attack: he stands still while it lasts.
func start_attack() -> void:
	if swings.is_empty():
		return
	attack_direction = direction_number()
	attack_tick = 0
	_attack_slide = Vector2i.ZERO
	_animation = ""
	_steps = 0
	_show_attack()

## Out of energy: the flattened picture, for as long as the map scene leaves it up.
func show_caught() -> void:
	cancel_attack()
	visible = true
	_weapon.visible = false
	if sprites != null and sprites.textures.has("f171"):
		picture_name = "f171"
		_picture.texture = sprites.textures["f171"]
		_picture.flip_h = false
		_picture.position = sprites.offsets["f171"]

## Being hurt stops an attack at once.
func cancel_attack() -> void:
	if attack_tick >= 0:
		attack_tick = -1
		stand()

## How long he is held by an attack, in updates: its steps times the
## updates each lasts (the first is one shorter), and one more update
## before he can move again (measured: 6 for every turtle).
func attack_length() -> int:
	if swings.is_empty():
		return 0
	var swing: Dictionary = swings[attack_direction]
	return (swing.pictures as PackedInt32Array).size() * int(swing.updates)

## Which step of the attack he is on, or -1 when the weapon is not out.
## It is out from the update the attack begins until its last step ends.
func weapon_step() -> int:
	if attack_tick < 0 or swings.is_empty():
		return -1
	var swing: Dictionary = swings[attack_direction]
	var step := (attack_tick + 1) / int(swing.updates)
	return step if step < (swing.weapon_pictures as PackedInt32Array).size() else -1

## The weapon's box on the map right now (Rect2 with no size when it is not out).
func weapon_box() -> Rect2:
	var step := weapon_step()
	if step < 0:
		return Rect2()
	var swing: Dictionary = swings[attack_direction]
	var place: Vector2 = swing.places[step]
	if sideways_left:
		place.x = -place.x
	var half: Vector2 = swing.half
	return Rect2(position.floor() + place - half, half * 2.0)

func _show_attack() -> void:
	var step := weapon_step()
	_weapon.visible = false
	if sprites == null:
		queue_redraw()
		return
	var swing: Dictionary = swings[attack_direction]
	var name := "f%d" % swing.pictures[0]
	if sprites.textures.has(name):
		picture_name = name
		_picture.texture = sprites.textures[name]
		var offset: Vector2 = sprites.offsets[name]
		_picture.flip_h = sideways_left
		if sideways_left:
			offset.x = -offset.x - _picture.texture.get_width()
		_picture.position = offset
	if step < 0 or weapon_sprites == null:
		return
	var weapon_name := "w%d" % swing.weapon_pictures[step]
	if not weapon_sprites.textures.has(weapon_name):
		return
	var place: Vector2 = swing.places[step]
	var at: Vector2 = weapon_sprites.offsets[weapon_name]
	_weapon.texture = weapon_sprites.textures[weapon_name]
	_weapon.flip_h = sideways_left
	if sideways_left:
		place.x = -place.x
		at.x = -at.x - _weapon.texture.get_width()
	_weapon.position = place + at
	_weapon.visible = true

## Stops walking: the standing picture of the way he faces.
func stand() -> void:
	_animation = ""
	_steps = 0
	_weapon.visible = false
	_show_picture(false)

## Becomes another of the four turtles to look at (null pictures keep the
## placeholder block).
func set_look(colour: Color, pictures: SpriteSet) -> void:
	bandana_color = colour
	sprites = pictures
	_show_picture(_animation != "")
	queue_redraw()

func _animation_for(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "up"
	if direction == Vector2i.DOWN:
		return "down"
	return "right"

## One step in a direction, if the way is clear.
func step(direction: Vector2i) -> void:
	if room == null:
		return
	facing = direction
	if direction.x != 0:
		sideways_left = direction.x < 0
	var wanted := _animation_for(direction)
	if wanted != _animation:
		_animation = wanted
		_steps = 0
	_steps += 1
	_show_picture(true)
	queue_redraw()
	var probe := position + Vector2(PROBES[direction])
	if room.kind_at_pixel(probe.x, probe.y) == RoomData.KIND_DOOR:
		# A doorway only works close to its own spot; otherwise it is a wall.
		var door := room.door_at(position, door_reach)
		if door != null:
			door_reached.emit(door)
		return
	if room.blocks_walker(probe.x, probe.y):
		return
	position += Vector2(direction * STEP)

## Shows the frame for the way he faces. The original has pictures for
## right, up and down; left is the right-facing one mirrored. Standing
## still shows the first frame.
func _show_picture(walking: bool) -> void:
	_picture.visible = sprites != null
	if sprites == null:
		return
	var frame := sprites.frame_at(_animation_for(facing), _steps if walking else 0)
	picture_name = frame
	if not sprites.textures.has(frame):
		return
	_picture.texture = sprites.textures[frame]
	var offset: Vector2 = sprites.offsets[frame]
	_picture.flip_h = sideways_left   # the original mirrors every picture by the way he last walked across
	if _picture.flip_h:
		offset.x = -offset.x - _picture.texture.get_width()
	_picture.position = offset

func _draw() -> void:
	if sprites != null:
		return
	draw_rect(Rect2(-7, -7, 14, 14), Color(0.1, 0.3, 0.12))
	draw_rect(Rect2(-6, -6, 12, 12), Color(0.25, 0.64, 0.3))
	var band := Rect2(-6, -6, 12, 3)
	if facing == Vector2i.DOWN:
		band = Rect2(-6, 3, 12, 3)
	elif facing == Vector2i.LEFT:
		band = Rect2(-6, -6, 3, 12)
	elif facing == Vector2i.RIGHT:
		band = Rect2(3, -6, 3, 12)
	draw_rect(band, bandana_color)
	if weapon_step() >= 0:
		draw_rect(Rect2(Vector2(facing) * 10.0 - Vector2(3, 3), Vector2(6, 6)), Color.WHITE)
