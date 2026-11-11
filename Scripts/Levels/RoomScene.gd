extends Node2D
## The playable map: a side-scrolling room or a world's top-down overworld.
## With a verified ROM both are read from the ROM's own level data and the
## doors between them work as in the original; without one it uses a small
## hand-drawn stand-in room.
##
## Doors (see Research/doors.md):
## - Overworld: walk into a manhole or doorway.
## - Room: press Up in front of a doorway, or climb a ladder out of the top.
##
## Enemies (Research/enemy_kinds.md): every kind that could be recorded is
## drawn with its own sprites from the ROM. The scripts in Scripts/Enemies
## move 18 of the kinds (each script lists its kinds in KINDS); the rest
## stand where the original puts them. In a room, enemies are made as the
## screen reaches their places and removed when they leave it, as in the
## original (Research/shots_spawning_tiles.md). Kinds with no recording are purple blocks. All hurt
## on touch, by the original's amounts, and can be hit.
##
## Study keys: F3 / F4 previous / next area, F7 this world's overworld,
## F6 fly (move freely through walls), F8 enemies on / off.

const STAND_IN: PackedStringArray = [
	"################################",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"#..............................#",
	"########......####HH############",
	"#.................HH...........#",
	"#.................HH...........#",
	"#.................HH...........#",
	"#.................HH...........#",
	"#.................HH...........#",
	"#.................HH...........#",
	"#.................HH...........#",
	"#.................HH...........#",
	"#.................HH...........#",
	"################################",
	"################################",
]

## The original lets a ladder take him out once his middle is this close to
## the top of the screen (he left at 15 and was still inside at 17).
const LADDER_EXIT_HEIGHT := 16.0
const ARRIVAL_REST_FRAMES := 10
const ENEMY_SCENE := preload("res://Scenes/Enemies/DummyEnemy.tscn")
const VIEW_SIZE := Vector2i(256, 192)  ## what the camera shows of a room, above the HUD strip
const SPAWN_MARGIN := 8.0            ## an enemy is made when its place is this far inside the screen's edge
const REMOVE_MARGIN := 4.0           ## and removed when it is this close to leaving
const TURTLE_ENERGY := 128           ## the original's full energy; the bar shows it as 8 blocks
const ENERGY_BLOCKS := 8

@export var world := 0
@export var area := 0
## Begin on the world's overworld, as the original does (needs a ROM).
@export var start_on_overworld := true

var levels: RomLevels
var room: RoomData
var flying := false
var walker: OverworldTurtle          ## the overworld turtle; the big one rests meanwhile
var show_enemies := true             ## F8: stand-in enemies where the original has them
var enemies: Node2D                  ## holds the enemies of the map on show, and what they throw
var enemies_follow_camera := true    ## false: every enemy of a room is there from the start
var _spot_enemies := {}              ## enemy place -> the enemy it last made
var _camera_corner := Vector2.ZERO
var _floor_frame := 0
## World 5 hides the Technodrome behind the inner door of one of three caves
## (areas 2, 3 and 4), chosen afresh each game.
var technodrome_cave := 2
var _wait_for_up_release := false    ## no second door until Up is let go

@onready var background: Sprite2D = $Background
@onready var solids: Node2D = $Solids
@onready var turtle: Turtle = $Turtle
@onready var hud: Label = $HUD/Label
@onready var health_bar: Control = $HUD/HealthBar

func _ready() -> void:
	levels = RomLevels.open_installed()
	turtle.max_health = TURTLE_ENERGY
	turtle.health = TURTLE_ENERGY
	turtle.health_changed.connect(_show_energy)
	turtle.died.connect(_on_turtle_died)
	_show_energy(turtle.health, turtle.max_health)
	if levels != null:
		for shot_kind: int in Shot.KINDS:
			Shot.damage_of[shot_kind] = levels.touch_damage(shot_kind)
	enemies = Node2D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	walker = OverworldTurtle.new()
	walker.bandana_color = turtle.bandana_color
	walker.door_reached.connect(enter_door)
	add_child(walker)
	technodrome_cave = randi_range(2, 4)
	if start_on_overworld and levels != null and levels.has_overworld(world):
		load_overworld(world)
	else:
		load_area(world, area)

func load_area(new_world: int, new_area: int) -> void:
	world = new_world
	area = new_area
	if levels != null:
		room = levels.room(world, area)
		if world == 0 and area == 0:
			room.start = Vector2(40, 96)  # by the entrance ladder, as in the original
	else:
		room = RoomData.from_text(STAND_IN, "Stand-in room (no ROM)")
		room.start = Vector2(40, 96)
	show_room(room)

## Shows a world's top-down map. Does nothing without a ROM.
func load_overworld(new_world: int) -> void:
	if levels == null or not levels.has_overworld(new_world):
		return
	world = new_world
	area = 0
	show_room(levels.overworld(world))

func show_room(new_room: RoomData) -> void:
	room = new_room
	var ripper: ChrRipper = null
	if levels != null:
		ripper = ChrRipper.new(RomInfo.inspect_file(Game.ROM_PATH).chr_rom)
	background.texture = ImageTexture.create_from_image(room.build_image(ripper))
	for child in solids.get_children():
		child.queue_free()
	if not room.top_down:   # the overworld turtle checks the map's cells itself
		for rect in room.solid_rects():
			solids.add_child(_make_body(rect, false))
		for rect in room.ladder_tops():
			solids.add_child(_make_body(rect, true))

	# Only one of the two turtles is awake: the big one in a room, the small
	# one on the overworld.
	turtle.visible = not room.top_down
	turtle.process_mode = Node.PROCESS_MODE_DISABLED if room.top_down else Node.PROCESS_MODE_INHERIT
	walker.visible = room.top_down
	walker.process_mode = Node.PROCESS_MODE_INHERIT if room.top_down else Node.PROCESS_MODE_DISABLED
	walker.room = room
	walker.door_reach = _door_reach()
	turtle.room = room
	turtle.speed = Vector2i.ZERO
	turtle.state = Turtle.State.NORMAL
	if room.top_down:
		walker.position = room.start
	else:
		turtle.position = room.start
	var camera: Camera2D = walker.camera if room.top_down else turtle.get_node("Camera2D")
	camera.limit_right = room.size_pixels().x
	camera.limit_bottom = room.size_pixels().y + 48   # room, then the HUD strip
	camera.make_current()
	camera.reset_smoothing()
	_place_enemies()
	_wait_for_up_release = true
	var door_hint := "walk into a door" if room.top_down else "Up at a door"
	hud.text = "%s   %s\n%s  F3/F4 area  F7 map  F6 fly  F8 foes  b%d" % [turtle.turtle_name, room.name, door_hint, Game.BUILD]

## Fills the map with its enemies. In a room they follow the camera as in
## the original: only the places on screen get an enemy now, and the rest
## as the screen reaches them (see _follow_camera). Overworlds, and rooms
## with `enemies_follow_camera` off, get all of theirs at once.
func _place_enemies() -> void:
	for child in enemies.get_children():
		enemies.remove_child(child)
		child.queue_free()
	_spot_enemies.clear()
	_camera_corner = _view_corner()
	if not show_enemies or room == null:
		return
	var view := Rect2(_camera_corner, Vector2(VIEW_SIZE))
	for spot in room.enemy_spots:
		if room.top_down or not enemies_follow_camera or view.has_point(spot.position):
			_make_enemy(spot)

## Makes the enemy for one of the ROM's enemy places.
func _make_enemy(spot: EnemySpot) -> void:
	var damage := levels.weapon_damage(0) if levels != null else Vector2i.ONE  # 0 = Leonardo
	var enemy: Node2D
	var pictures := SpriteSet.cached("Kind%02X" % spot.kind) if spot.kind >= 0 else null
	if room.top_down:
		enemy = _make_stand_in(spot)
	elif Crawler.KINDS.has(spot.kind):
		var crawler := Crawler.new()
		crawler.setup(spot, room, pictures)
		enemy = crawler
	elif Leaper.KINDS.has(spot.kind):
		var leaper := Leaper.new()
		leaper.setup(spot, room, pictures, turtle)
		enemy = leaper
	elif spot.kind == Charger.KIND:
		var charger := Charger.new()
		charger.setup(spot, room, pictures, turtle)
		enemy = charger
	elif PathEnemy.KINDS.has(spot.kind):
		var mover := PathEnemy.new()
		mover.setup(spot, pictures)
		enemy = mover
	elif Soldier.KINDS.has(spot.kind):
		var soldier := Soldier.new()
		soldier.setup(spot, room, pictures, turtle)
		enemy = soldier
	else:
		enemy = _make_stand_in(spot)
	enemy.set("weapon_damage", damage.x)
	enemy.set("weapon_damage_low", damage.y)
	if enemy.get_parent() == null:
		enemies.add_child(enemy)
	_spot_enemies[spot] = enemy

## A kind with no behaviour yet: it stands at its place.
func _make_stand_in(spot: EnemySpot) -> DummyEnemy:
	var enemy: DummyEnemy = ENEMY_SCENE.instantiate()
	enemies.add_child(enemy)
	enemy.show_as_spot(spot)
	enemy.monitoring = not room.top_down   # the overworld turtle cannot fight yet
	return enemy

## The top-left corner of what the camera shows of a room.
func _view_corner() -> Vector2:
	if room == null or room.top_down:
		return Vector2.ZERO
	var size := room.size_pixels()
	return Vector2(
		clampf(turtle.position.x - VIEW_SIZE.x / 2.0, 0.0, maxf(size.x - VIEW_SIZE.x, 0.0)),
		clampf(turtle.position.y - 24.0 - 120.0, 0.0, maxf(size.y - VIEW_SIZE.y, 0.0)))

## The original makes an enemy when the screen's edge reaches its place
## (8 pixels inside either edge), again every time that happens, and removes
## anything that goes off the screen. Measured in the first sewer.
func _follow_camera() -> void:
	var corner := _view_corner()
	var old := _camera_corner
	if corner.distance_to(old) > 64.0:
		_place_enemies()   # the view jumped (a door, a fall, the fly key): start afresh
		return
	_camera_corner = corner
	for spot in room.enemy_spots:
		var place := spot.position
		var in_rows := place.y >= corner.y and place.y < corner.y + VIEW_SIZE.y
		var was_in_rows := place.y >= old.y and place.y < old.y + VIEW_SIZE.y
		var from_right := place.x > old.x + VIEW_SIZE.x - SPAWN_MARGIN and place.x <= corner.x + VIEW_SIZE.x - SPAWN_MARGIN
		var from_left := place.x >= corner.x + SPAWN_MARGIN and place.x < old.x + SPAWN_MARGIN
		var from_rows := in_rows and not was_in_rows and place.x >= corner.x and place.x < corner.x + VIEW_SIZE.x
		if ((from_right or from_left) and in_rows) or from_rows:
			var living: Variant = _spot_enemies.get(spot)
			if living == null or not is_instance_valid(living) or living.is_queued_for_deletion():
				_make_enemy(spot)
	for thing in enemies.get_children():
		if thing is Puff:
			continue
		var across: float = thing.position.x - corner.x
		var down: float = thing.position.y - corner.y
		if across < REMOVE_MARGIN or across > VIEW_SIZE.x - REMOVE_MARGIN or down < -40.0 or down > VIEW_SIZE.y + 40.0:
			thing.queue_free()

## The floor kinds that act on the turtle (Research/shots_spawning_tiles.md).
func _apply_floor_kinds() -> void:
	if turtle.state == Turtle.State.DEAD:
		return
	_floor_frame += 1
	var feet := turtle.position
	if turtle.is_on_floor():
		var under := room.kind_at_pixel(feet.x, feet.y + 1.0)
		if under == RoomData.KIND_DEADLY and _floor_frame % Turtle.TICK_FRAMES == 0:
			turtle.drain(RoomData.HURT_DAMAGE)
		elif under == RoomData.KIND_MOVING_FLOOR and not room.solid_at(feet.x + 8.0, feet.y - 8.0):
			turtle.position.x += RoomData.MOVING_FLOOR_SPEED / 256.0 / Turtle.TICK_FRAMES
	for up in range(4, 45, 8):   # every cell his body is in
		if room.kind_at_pixel(feet.x, feet.y - up) == RoomData.KIND_HURTS:
			turtle.take_damage(RoomData.HURT_DAMAGE)
			break

## The bar shows the turtle's energy as 8 blocks, a part-used block still lit.
func _show_energy(energy: int, full: int) -> void:
	health_bar.set_health(ceili(energy * float(ENERGY_BLOCKS) / maxi(full, 1)), ENERGY_BLOCKS)

func set_show_enemies(on: bool) -> void:
	show_enemies = on
	_place_enemies()

## The original accepts a door within 32 pixels of its spot (40 in world 6).
func _door_reach() -> float:
	return 40.0 if world == 5 else 32.0

## Goes through a door: loads the other side and puts the turtle where the
## original puts him.
func enter_door(door: Door) -> void:
	if levels == null:
		return
	if not door.to_room:
		load_overworld(door.to_area)
		walker.position = door.arrive
		# Stands in for the original's fade between screens (length not measured).
		walker.rest_frames = ARRIVAL_REST_FRAMES
		walker.camera.reset_smoothing()
		return
	var target := door.to_area
	if world == 4 and target >= 5 and target <= 8 and area == technodrome_cave:
		target = 6  # this cave's inner door is the one that hides the Technodrome
	load_area(world, target)
	_place_turtle(door.arrive)

## Stands (or hangs) the big turtle with his middle at `centre`.
func _place_turtle(centre: Vector2) -> void:
	var feet := centre + Vector2(0, RoomData.CENTRE_TO_FEET)
	# A doorway can leave him a pixel or two inside the floor: lift him out.
	while feet.y > 0.0 and room.solid_at(feet.x, feet.y - 0.01):
		feet.y = floorf((feet.y - 0.01) / RoomData.TILE) * RoomData.TILE
	var ladder := room.ladder_center_at(feet.x, feet.y - 1.0)
	if not is_nan(ladder) and not room.solid_at(feet.x, feet.y + 1.0):
		# He arrives hanging on a ladder (coming down a manhole).
		feet.x = ladder
		turtle.state = Turtle.State.CLIMB
	turtle.position = feet
	turtle.speed = Vector2i.ZERO
	room.start = feet
	_place_enemies()   # the view has moved to where he arrived
	(turtle.get_node("Camera2D") as Camera2D).reset_smoothing()

## The door the big turtle is using right now, or null.
## Up at a doorway while standing, or climbing a ladder out of the top.
func _room_door_in_use() -> Door:
	if room == null or room.top_down or room.doors.is_empty():
		return null
	if not Input.is_action_pressed("move_up"):
		_wait_for_up_release = false
		return null
	if _wait_for_up_release:
		return null
	var centre := turtle.position - Vector2(0, RoomData.CENTRE_TO_FEET)
	if turtle.state == Turtle.State.CLIMB:
		if fposmod(centre.y, room.screen_size.y) >= LADDER_EXIT_HEIGHT:
			return null
	elif turtle.state != Turtle.State.NORMAL or not turtle.is_on_floor() or not room.door_cell_near(centre):
		return null
	return room.door_at(centre, _door_reach())

func _make_body(rect: Rect2i, one_way: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(rect.size)
	shape.shape = box
	shape.position = Vector2(rect.position) + Vector2(rect.size) / 2.0
	# One-way: solid from above only, so a ladder can come up through it.
	shape.one_way_collision = one_way
	body.add_child(shape)
	return body

func _physics_process(_delta: float) -> void:
	if flying:
		var mover: Node2D = walker if room.top_down else turtle
		mover.position += Input.get_vector("move_left", "move_right", "move_up", "move_down") * 4.0
		if not room.top_down and show_enemies and enemies_follow_camera:
			_follow_camera()
		return
	if room.top_down:
		return
	if turtle.position.y > room.size_pixels().y + 200.0:
		turtle.position = room.start
		turtle.speed = Vector2i.ZERO
		return
	var door := _room_door_in_use()
	if door != null:
		enter_door(door)
		return
	_apply_floor_kinds()
	if show_enemies and enemies_follow_camera:
		_follow_camera()

func set_flying(on: bool) -> void:
	flying = on
	turtle.set_physics_process(not on)
	walker.set_physics_process(not on)
	turtle.speed = Vector2i.ZERO

func _on_turtle_died() -> void:
	# Placeholder for the real "switch turtle / game over" flow.
	await get_tree().create_timer(1.5).timeout
	turtle.position = room.start
	turtle.revive()

## Moves to the next or previous area, running on into the neighbouring world.
func step_area(direction: int) -> void:
	if levels == null:
		return
	if room.top_down and direction > 0:
		load_area(world, 0)  # from the map, "next" is the world's first room
		return
	var w := world
	var a := area + direction
	if a < 0:
		w = posmod(w - 1, RomLevels.WORLDS)
		a = levels.area_count(w) - 1
	elif a >= levels.area_count(w):
		w = posmod(w + 1, RomLevels.WORLDS)
		a = 0
	load_area(w, a)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_chr_viewer"):
		Game.go_to(Game.SCENE_CHR_VIEWER)
	elif event.is_action_pressed("switch_room"):
		Game.go_to(Game.SCENE_PRACTICE_ROOM)
	elif event.is_action_pressed("previous_area"):
		step_area(-1)
	elif event.is_action_pressed("next_area"):
		step_area(1)
	elif event.is_action_pressed("toggle_enemies"):
		set_show_enemies(not show_enemies)
	elif event.is_action_pressed("go_overworld"):
		load_overworld(world)
	elif event.is_action_pressed("toggle_fly"):
		set_flying(not flying)
