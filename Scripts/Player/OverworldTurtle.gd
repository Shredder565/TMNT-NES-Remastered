class_name OverworldTurtle
extends Node2D
## The small turtle that walks around the top-down overworld map.
## With a ROM he is drawn from Leonardo's own overworld sprites
## (Resources/AssetRipper/Sprites/LeonardoOverworld.json); without one he is
## a green block with the bandana on the side he faces.
##
## Movement copies the original (see Research/doors.md):
## - One update every 2 frames, 2 pixels per update, no diagonals.
##   Left/right wins when both a sideways and an up/down key are held.
## - Before each step the game looks at ONE point ahead of him. A wall or
##   water there stops him; a doorway there sends him through the door.

signal door_reached(door: Door)

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
var _steps := 0                 ## steps taken, which drives the walking animation
var _picture := Sprite2D.new()

func _init() -> void:
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.position = Vector2(0, 24)   # the HUD strip covers the bottom 48 pixels
	add_child(camera)
	_picture.centered = false
	add_child(_picture)

func _ready() -> void:
	sprites = SpriteSet.cached("LeonardoOverworld")
	_show_picture(false)

func _physics_process(_delta: float) -> void:
	if rest_frames > 0:
		rest_frames -= 1
		return
	_frame += 1
	if _frame % TICK_FRAMES != 0:
		return
	var across := int(signf(Input.get_axis("move_left", "move_right")))
	var down := int(signf(Input.get_axis("move_up", "move_down")))
	if across != 0:
		step(Vector2i(across, 0))
	elif down != 0:
		step(Vector2i(0, down))
	else:
		_show_picture(false)

## One step in a direction, if the way is clear.
func step(direction: Vector2i) -> void:
	if room == null:
		return
	facing = direction
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
	var animation := "right"
	if facing == Vector2i.UP:
		animation = "up"
	elif facing == Vector2i.DOWN:
		animation = "down"
	var frame := sprites.frame_at(animation, _steps if walking else 0)
	if not sprites.textures.has(frame):
		return
	_picture.texture = sprites.textures[frame]
	var offset: Vector2 = sprites.offsets[frame]
	_picture.flip_h = facing == Vector2i.LEFT
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
