class_name ThrownWeapon
extends Node2D
## A thrown star (object kind 1A in the original; special weapons 1 and 2),
## by the original's rules (Research/special_weapons.md; its routine is at
## bank 7, $FD5F, and it is made at bank 7, $E0AA):
## - it starts at the turtle's middle (12 lower if he threw it crouching)
##   and flies level at 5 pixels an update the way he faces; the second and
##   third of a triple throw also rise or sink 1 pixel an update;
## - each update, before it moves: if the map cell 8 above its place is
##   anything but empty, a doorway, a ladder or kind 7, it is gone; so it
##   is when it is less than 7 from the screen's left edge or 10 from its
##   right, or off the top or bottom of the room's picture;
## - it shows four pictures (one tile turned four ways), 2 updates each;
## - an enemy it meets takes the damage of the weapon in use; the star is
##   gone only if that beats the enemy.
## The room scene gives it its turn, on the enemies' frame.

const KIND := 0x1A
const ANIMATION := 0xD7
const SPEED := 5                 ## pixels an update
const LOOK_UP := 8               ## the map is looked at this far above its place
const PASSABLE := [0, 2, 9, 10, 7]
## Its pictures by update (measured): two updates each; when the list
## starts again the last picture stays one update longer and the first one
## is an update short, as with every animation of the original.
const PICTURES_FIRST := ["f73", "f73", "f74", "f74", "f75", "f75", "f76", "f76"]
const PICTURES_AFTER := ["f76", "f73", "f74", "f74", "f75", "f75", "f76", "f76"]
const SPRITE_LINES_UP := 4       ## the original's sprites do not get the background's 4-line shift

var direction := 1               ## 1 right, -1 left
var rise := 0                    ## pixels an update, down counted positive
var room: RoomData
var view_corner: Callable        ## the screen's corner in the room
var targets: Callable            ## the things it can hit: an Array of nodes
var damage: Callable             ## what a hit takes off just now
var half := Vector2(4, 4)        ## half its box (the ROM's, when the room scene has it)
var updates := 0                 ## updates it has had
var gone := false
var _picture := Sprite2D.new()
var _sprites: SpriteSet

func _ready() -> void:
	_sprites = SpriteSet.cached("Kind%02X" % KIND)
	_picture.centered = false
	_picture.visible = false     # its first picture comes with its first update
	add_child(_picture)

## One update: the map and the screen's edges, the move, what it hits.
func update() -> void:
	if gone:
		return
	if room != null and not PASSABLE.has(room.kind_at_pixel(position.x, position.y - LOOK_UP)):
		remove()
		return
	if view_corner.is_valid():
		var corner: Vector2 = view_corner.call()
		var across := int(floorf(position.x - corner.x))
		var down := int(floorf(position.y - corner.y))
		if ((across + 10) & 255) < 17 or ((down + 64) & 255) < 68:
			remove()
			return
	position += Vector2(SPEED * direction, rise)
	_show()
	updates += 1
	_hit_things()

func _show() -> void:
	if _sprites == null:
		queue_redraw()
		return
	var frame: String = PICTURES_FIRST[updates] if updates < PICTURES_FIRST.size() else PICTURES_AFTER[updates % PICTURES_AFTER.size()]
	if _sprites.textures.has(frame):
		_picture.texture = _sprites.textures[frame]
		_picture.position = _sprites.offsets[frame] - Vector2(0, SPRITE_LINES_UP)
		_picture.flip_h = direction < 0
		if direction < 0:
			# Mirrored about its own place.
			_picture.position.x = -(_sprites.offsets[frame].x + (_picture.texture as Texture2D).get_width())
		_picture.visible = true

func _draw() -> void:
	if _sprites == null:
		draw_rect(Rect2(-3, -3, 6, 6), Color(0.9, 0.9, 1.0))

## Its box against each thing's own box. A thing that was hit less than 24
## updates ago cannot be hit (it is blinking).
func _hit_things() -> void:
	if not targets.is_valid():
		return
	var box := Rect2(position - half, half * 2.0)
	for thing: Node in targets.call():
		if gone:
			return
		var foe := thing as Node2D
		if foe == null or foe.is_queued_for_deletion() or not foe.has_method("take_hit"):
			continue
		if foe.get("blinking") == true or foe.get("gone") == true or ("safe_updates" in foe and int(foe.get("safe_updates")) > 0):
			continue
		if foe is OriginalEnemy:
			# The original's own box test, as the sword has it (bank 6, $9AD3;
			# Research/hit_boxes.md): one-sided at the edges, in whole pixels,
			# with the enemy's box of the animation it shows.
			var mine: Array[int] = [floori(position.x), floori(position.y), int(half.x), int(half.y)]
			if not foe.can_touch() or not foe.touches_box(mine):
				continue
		elif not box.intersects(box_of(foe)):
			continue
		foe.take_hit(int(damage.call()) if damage.is_valid() else 1)
		if "health" in foe and int(foe.get("health")) <= 0:
			remove()

## A thing's box in the room: its collision shape, as the room scene fitted it.
static func box_of(thing: Node2D) -> Rect2:
	for found in thing.find_children("*", "CollisionShape2D", true, false):
		var shape := found as CollisionShape2D
		var rectangle := shape.shape as RectangleShape2D
		if rectangle != null:
			return Rect2(thing.position + shape.position - rectangle.size / 2.0, rectangle.size)
	return Rect2(thing.position - Vector2(8, 16), Vector2(16, 16))

func remove() -> void:
	gone = true
	queue_free()
