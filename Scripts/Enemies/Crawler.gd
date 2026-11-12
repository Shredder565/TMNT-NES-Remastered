class_name Crawler
extends Area2D
## Enemy kind 8D, the small crawler of the first sewer, and the other kinds
## that move the same simple way: a steady speed, turning round at walls.
## The table KINDS lists them (see Research/enemy_kinds.md).
##
## For kind 8D everything here was measured from the USA ROM running in an
## emulator (see Research/enemy_8D.md), unless a line says it is a guess:
## - Like the turtle it is updated every 2nd frame, with speeds in 1/256ths
##   of a pixel per update.
## - It walks at a steady 352 (1.375 pixels), turns round at a wall, and
##   walks straight off ledges. It does not react to the turtle.
## - Its position value is its middle across and its bottom edge, and it
##   rides 4 pixels below the top edge of the floor it walks on.

const KIND := 0x8D
const SPRITE_MAP := "Kind8D"
## The kinds this script moves. Speeds (1/256 pixel per update) and whether
## the kind flies were read from recordings of the original. `look` is how
## far ahead a wall turns it round, fitted to where each kind turned.
## Guess for the three other walkers: that they fall off ledges as 8D does.
const KINDS := {
	0x8D: { "speed": 352, "flies": false, "look": 15.0 },
	0x86: { "speed": 352, "flies": false, "look": 15.0 },
	0x85: { "speed": 352, "flies": false, "look": 15.0 },
	0x84: { "speed": 768, "flies": false, "look": 15.0 },
	0x81: { "speed": 640, "flies": true, "look": 13.0 },
	0x96: { "speed": 640, "flies": true, "look": 13.0 },
	0xA7: { "speed": 768, "flies": true, "look": 12.0 },
	0xA8: { "speed": 768, "flies": true, "look": 12.0 },
	0x8F: { "speed": 640, "flies": true, "look": 13.0 },
	# 4B walks for 31 updates, stands for 9, and so on. It rides 3 pixels
	# into the floor it is placed on top of.
	0x4B: { "speed": 296, "flies": false, "look": 15.0, "walk": 31, "pause": 9, "sink": 3.0, "shot": 0x4C, "shots": 1 },
	# 94 walks for 16 updates and stands for 16, riding 4 pixels into the floor.
	0x94: { "speed": 352, "flies": false, "look": 15.0, "walk": 16, "pause": 16, "sink": 4.0, "shot": 0x95, "shots": 4 },
	# 91 (it carries a chainsaw) walks for 31 updates and stands for 33.
	0x91: { "speed": 448, "flies": false, "look": 15.0, "walk": 31, "pause": 33 },
}

const TICK_FRAMES := 2
const WALK_SPEED := 352          ## 1.375 px per update = 41.25 px per second
const FALL_START_SPEED := 512    ## 2 px per update on the first update of a fall
const GRAVITY := 24              ## added to the fall speed every update
const FRAME_TICKS := 3           ## updates per animation frame
const HALF_WIDTH := 12.0         ## the wider frame is 24 pixels across
const WALL_LOOK := 15.0          ## turns when a wall is this close ahead
const SINK := 4.0                ## how far below the floor's top edge it rides
const LANDING_REST := 1          ## updates it stands still after landing
## Guesses: the boxes that touch the turtle and that his weapon can reach.
const TOUCH_BOX := Rect2(-6, -16, 12, 16)
const HURT_BOX := Rect2(-12, -40, 24, 40)

var room: RoomData
var kind := KIND
var walk_speed := WALK_SPEED
var flies := false               ## true: keeps its height, never falls
var wall_look := WALL_LOOK
var half_width := HALF_WIDTH
var sink := SINK
var walk_ticks := 0              ## above 0: walks this many updates, then stands for pause_ticks
var pause_ticks := 0
var shot_kind := -1              ## what it fires at the start of each pause, if anything
var shot_count := 0              ## how many, one per update
var _cycle := 0
var direction := 1               ## 1 = right, -1 = left
var falling := false
var fall_speed := 0
var rest_ticks := 0
var health := 4
var touch_damage := 7
var weapon_damage := 7           ## hit points lost to one swing
var weapon_damage_low := 10      ## the same when the turtle is below half health
var sprites: SpriteSet           ## null: draw a plain block instead
var _frame := 0
var _ticks := 0
var _art := Node2D.new()
var _picture := Sprite2D.new()

## Puts the crawler on one of the ROM's enemy places.
func setup(spot: EnemySpot, in_room: RoomData, sprite_set: SpriteSet) -> void:
	room = in_room
	position = spot.position
	kind = spot.kind if KINDS.has(spot.kind) else KIND
	var how: Dictionary = KINDS[kind]
	walk_speed = how.speed
	flies = how.flies
	wall_look = how.look
	walk_ticks = how.get("walk", 0)
	pause_ticks = how.get("pause", 0)
	shot_kind = how.get("shot", -1)
	shot_count = how.get("shots", 0)
	if sprite_set != null:
		half_width = maxf(sprite_set.bounds("walk").size.x / 2.0, 4.0)
	# How deep it rides in the floor it is placed on (4 pixels for kind 8D).
	if room.solid_at(position.x, position.y):
		var top := floori(position.y / RoomData.TILE)
		while top > 0 and room.is_solid_cell(floori(position.x / RoomData.TILE), top - 1) and position.y - (top - 1) * RoomData.TILE <= 12.0:
			top -= 1
		sink = position.y - top * RoomData.TILE
		if how.has("sink"):
			sink = how.sink
			position.y = top * RoomData.TILE + sink
	health = maxi(spot.hit_points, 1)
	touch_damage = spot.touch_damage
	sprites = sprite_set
	# The original starts an enemy walking towards the middle of the screen.
	direction = 1 if fposmod(position.x, room.screen_size.x) < room.screen_size.x / 2.0 else -1

func _ready() -> void:
	var touch := TOUCH_BOX
	var reach := HURT_BOX
	if kind != KIND and sprites != null:
		# Other kinds: boxes guessed from the size of the picture.
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
		block.position = Vector2(-half_width, -12)
		block.size = Vector2(half_width * 2, 12)
		block.color = Color(0.3, 0.45, 0.9)
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
	# Hurt any turtle we are touching. The turtle ignores this while blinking.
	for body in get_overlapping_bodies():
		if body is Turtle:
			body.touched_by(self, touch_damage)

## One game update.
func tick() -> void:
	_ticks += 1
	if room == null:
		return
	if rest_ticks > 0:
		rest_ticks -= 1
	elif falling:
		_fall()
	elif not flies and not (room.solid_at(position.x - half_width, position.y) or room.solid_at(position.x + half_width, position.y)):
		# Nothing under either end: it has walked right off the ledge.
		falling = true
		fall_speed = FALL_START_SPEED
		_fall()
	else:
		var standing := walk_ticks > 0 and _cycle % (walk_ticks + pause_ticks) >= walk_ticks
		if standing and shot_kind >= 0 and _cycle % (walk_ticks + pause_ticks) - walk_ticks < shot_count:
			Shot.fire(self, shot_kind, direction, room, null)
		_cycle += 1
		if not standing:
			var ahead := position.x + direction * wall_look
			if ahead < 0.0 or ahead >= room.size_pixels().x or room.solid_at(ahead, position.y - 8.0):
				direction = -direction
			position.x += direction * walk_speed / 256.0
	_show_frame()

func _fall() -> void:
	position.y += fall_speed / 256.0
	fall_speed += GRAVITY
	if room.solid_at(position.x, position.y - sink):
		position.y = floorf((position.y - sink) / RoomData.TILE) * RoomData.TILE + sink
		falling = false
		rest_ticks = LANDING_REST
	elif position.y > room.size_pixels().y + 64.0:
		queue_free()   # fell out of the bottom of the room

func _show_frame() -> void:
	_art.scale.x = direction   # the tiles are drawn facing right
	if sprites == null:
		return
	var frame := sprites.frame_at("walk", _ticks)
	if sprites.textures.has(frame):
		_picture.texture = sprites.textures[frame]
		_picture.position = sprites.offsets[frame]

func _on_weapon_entered(area: Area2D) -> void:
	# The turtle's weapon is the only Area2D named WeaponHitbox.
	if area.name == "WeaponHitbox" and Turtle.weapon_lands(self):
		var turtle := area.get_parent() as Turtle
		var weakened := turtle != null and turtle.health * 2 < turtle.max_health
		take_hit(weapon_damage_low if weakened else weapon_damage)

func take_hit(amount: int) -> void:
	health -= amount
	if health <= 0:
		Puff.leave(self)
		queue_free()
