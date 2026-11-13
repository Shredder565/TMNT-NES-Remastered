class_name Item
extends Area2D
## Something lying in a room for the turtle to pick up.
##
## What each kind gives was found by touching it in the emulator
## (Research/world1.md) and then read from the ROM's own item routine
## (bank 6, $965C; Research/items_and_hits.md): a whole pizza fills his
## energy, half a pizza gives 64, a slice 32, and kind 0B makes him
## untouchable for a while.

const SLICE := 0x03
const WHOLE_PIZZA := 0x01
const HALF_PIZZA := 0x02
const POWER := 0x0B
const CAPTIVE := 0x0E           ## a captured turtle, tied up: touching him brings him back (Research/losing_a_turtle.md)
const SPRITE_LINES_UP := 4
const SLICE_ENERGY := 32
const HALF_ENERGY := 64

## Picked up (the room scene sees to what a captive gives).
signal taken(item: Item)

var kind := SLICE
## The original makes an item an object while it is on the screen, in the
## first free slot from 5 up: 0 here if that is one of the six enemy
## slots, 1 if one of the four for thrown things, -1 while it has none.
var slot_group := -1
var sprites: SpriteSet

func setup(item_kind: int, at: Vector2, sprite_set: SpriteSet) -> void:
	kind = item_kind
	position = at
	sprites = sprite_set

func _ready() -> void:
	var box := Rect2(-8, -16, 16, 16)
	if sprites != null and sprites.bounds("walk").has_area():
		box = sprites.bounds("walk")
		var picture := Sprite2D.new()
		picture.centered = false
		var frame := sprites.frame_at("walk", 0)
		picture.texture = sprites.textures[frame]
		# The original's sprites do not get the 4-line shift its background
		# gets (Research/hud.md), so in a room the picture goes 4 up. Its box stays.
		picture.position = sprites.offsets[frame] - Vector2(0, OriginalEnemy.sprite_lift)
		add_child(picture)
	else:
		var block := ColorRect.new()
		block.position = box.position
		block.size = box.size
		block.color = Color(0.95, 0.75, 0.2)
		add_child(block)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = box.size
	shape.shape = rectangle
	shape.position = box.get_center()
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is Turtle:
		pick_up(body)

## Gives the turtle what this item gives, and removes it.
func pick_up(turtle: Turtle) -> void:
	if kind == SLICE:
		turtle.heal(SLICE_ENERGY)
	elif kind == HALF_PIZZA:
		turtle.heal(HALF_ENERGY)
	elif kind == WHOLE_PIZZA:
		turtle.heal(turtle.max_health)
	elif kind == POWER:
		turtle.start_power()
	taken.emit(self)
	queue_free()
