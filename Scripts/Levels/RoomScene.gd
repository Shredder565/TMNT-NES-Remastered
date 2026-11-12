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
## drawn with its own sprites from the ROM. The kinds of world 1's rooms
## are run by scripts written from the original's own code
## (OriginalEnemy.for_kind; Research/enemy_routines.md). Other scripts in
## Scripts/Enemies move more kinds by rules fitted to measurements (each
## lists its kinds in KINDS); the rest stand where the original puts them. In a room, enemies are made as the
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
const PLACED_AT_ONCE := 6            ## the original's object slots 5 to 10
const REMOVE_MARGIN := 4.0           ## and removed when it is this close to leaving
## World 1's items and boss, as seen in the original (Research/world1.md).
## The ROM tables these come from have not been found, so they are listed
## here by hand: [kind, where] for each item of a room, keyed by (world, area).
const ITEMS := {
	Vector2i(0, 0): [[0x03, Vector2(928, 32)]],
	Vector2i(0, 2): [[0x0B, Vector2(560, 64)]],
	Vector2i(0, 3): [[0x03, Vector2(640, 40)]],
	Vector2i(0, 4): [[0x01, Vector2(32, 48)], [0x03, Vector2(304, 64)]],
}
## Which script runs each boss kind the ROM's encounter table names.
const BOSS_KINDS := [Bebop.KIND, Rocksteady.KIND]
## Beating this kind ends the world.
const WORLD_END_BOSS := Rocksteady.KIND
## What stands by while a boss is fought: [kind, where on the fight's
## screen, facing left]. The boss's own routine puts it there (bank 5, $AAFF).
const BOSS_COMPANY := {
	Bebop.KIND: [0x11, Vector2(196, 83), true],
}
## The turtle is kept between these two distances from the screen's left
## edge (measured: 20 from a room's ends, and from the edge of the screen
## a boss fight is held on).
const SCREEN_LEFT := 20.0
const SCREEN_RIGHT := 236.0
const HOLD_ENTER_FRAMES := 16       ## clear screen to the extra enemy coming in
const HOLD_LEAVE_FRAMES := 64       ## that enemy beaten to the screen being freed
## The overworld (Research/overworld.md): the original's screen there is
## 256 x 240 with the turtle kept near its middle. An enemy is made when
## the screen's edge reaches its place, 8 pixels inside any of the four
## edges, and removed within 4 pixels of leaving. None is there when the
## map first comes up.
const OVERWORLD_VIEW := Vector2(256, 240)
## That screen scrolls only while he walks with his place on it beyond
## these (measured): right at 126 or more across, left at 124 or less,
## up at 116 or less down the screen, down at 118 or more.
const OVERWORLD_SAFE_UPDATES := 24   ## after being hurt on the overworld nothing hurts him for this long (measured)
const OVERWORLD_SCROLL_RIGHT := 126.0
const OVERWORLD_START_ON_SCREEN := Vector2(144, 120)   ## where he stands on it when a world begins
const OVERWORLD_SCROLL_LEFT := 124.0
const OVERWORLD_SCROLL_UP := 116.0
const OVERWORLD_SCROLL_DOWN := 118.0
const TURTLE_ENERGY := 128           ## the original's full energy; the bar shows it as 8 blocks
const ENERGY_BLOCKS := 8
## The four turtles, in the original's order (its number 0 to 3).
const TURTLE_NAMES := ["Leonardo", "Raphael", "Michelangelo", "Donatello"]

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
var items: Node2D                    ## holds the items of the room on show
var boss: Boss                       ## the room's boss while it is alive
var boss_bar: Control                ## the boss's energy, under the turtle's
var fight_corner := Vector2.ZERO     ## where the screen is held during a boss fight
var fighting := false
var _company: Node2D                 ## what stands by during the fight
var hold: Encounter                  ## the held fight going on, if any
var hold_stage := 0                  ## 1: clear the screen. 2: beat the enemy that came in
var _hold_frames := 0
var _holds_done := {}                ## this room's held fights already fought (by number)
var _boss_done := {}                 ## (world, area) -> true once that room's boss has appeared
var _clearing := false               ## true while the "world clear" message is up
var _boss_key := Vector2i(-1, -1)    ## the room the living boss belongs to
var _boss_camera_x := 0.0            ## where the camera was a frame ago
var clear_message_seconds := 3.0     ## how long "WORLD n CLEAR" stays up
## World 5 hides the Technodrome behind the inner door of one of three caves
## (areas 2, 3 and 4), chosen afresh each game.
var technodrome_cave := 2
var _wait_for_up_release := false    ## no second door until Up is let go
var current_turtle := 0              ## who is playing: 0 Leonardo, 1 Raphael, 2 Michelangelo, 3 Donatello
var turtle_energy: Array = [TURTLE_ENERGY, TURTLE_ENERGY, TURTLE_ENERGY, TURTLE_ENERGY]
var start_screen: StartScreen        ## the Start (information) screen
var overworld_spot := Vector2.ZERO   ## where he last stood on the overworld: the Start screen's map marks it
var overworld_screen := Vector2.ZERO ## the corner of the original's screen on the overworld (enemies come and go by it)
var _overworld_last := Vector2.ZERO  ## where the overworld turtle was a frame ago
var _overworld_turtle_half := Vector2(4, 4)   ## half the overworld turtle's box (the ROM's, when there is one)
var _overworld_frame := 0            ## frames on the overworld
var _overworld_turn := 0             ## which of every two frames is the enemies' (the one after the turtle's)

@onready var background: Sprite2D = $Background
@onready var solids: Node2D = $Solids
@onready var turtle: Turtle = $Turtle
@onready var hud: Label = $HUD/Label
@onready var health_bar: Control = $HUD/HealthBar

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE   # the Start screen stops the game by pausing the tree
	levels = RomLevels.open_installed()
	turtle.max_health = TURTLE_ENERGY
	turtle.health = TURTLE_ENERGY
	turtle.health_changed.connect(_show_energy)
	turtle.died.connect(_on_turtle_died)
	turtle.moved.connect(_place_camera)
	_show_energy(turtle.health, turtle.max_health)
	boss_bar = health_bar.duplicate()
	boss_bar.position.y += 10.0
	boss_bar.hide()
	health_bar.get_parent().add_child(boss_bar)
	OriginalEnemy.levels = levels
	if levels != null:
		for shot_kind: int in Shot.KINDS:
			Shot.damage_of[shot_kind] = levels.touch_damage(shot_kind)
			Shot.box_of[shot_kind] = levels.box_half_size(shot_kind, levels.first_animation(shot_kind))
		# The turtle's own boxes and his weapon's swings, as the ROM has them (0 = Leonardo).
		turtle.body_boxes = {
			"stand": levels.box_half_size(0, 0x80),
			"crouch": levels.box_half_size(0, 0x83),
			"ball": levels.box_half_size(0, 0x87),
		}
		turtle.weapon_swings = [levels.weapon_swing(0, 0), levels.weapon_swing(0, 1), levels.weapon_swing(0, 2)]
	enemies = Node2D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	items = Node2D.new()
	items.name = "Items"
	add_child(items)
	walker = OverworldTurtle.new()
	walker.bandana_color = turtle.bandana_color
	walker.door_reached.connect(enter_door)
	walker.moved.connect(_on_walker_moved)
	add_child(walker)
	start_screen = StartScreen.new()
	start_screen.use_installed_rom()
	start_screen.turtle_chosen.connect(set_turtle)
	add_child(start_screen)
	_show_turtle_look()
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
	camera.limit_left = 0
	camera.limit_right = room.size_pixels().x
	camera.limit_bottom = room.size_pixels().y + 48   # room, then the HUD strip
	camera.make_current()
	camera.reset_smoothing()
	turtle.scroll_locked = false
	turtle.scroll_max = 0.0 if room.top_down else maxf(room.size_pixels().x - VIEW_SIZE.x, 0.0)
	turtle.scroll_x = -1000.0   # forces the screen to be placed afresh around him
	turtle.sync_screen()
	_place_camera()
	_place_enemies()
	_place_items()
	_boss_camera_x = _view_corner().x
	_wait_for_up_release = true
	if room.top_down:
		overworld_spot = walker.position
	_show_hud_text()

## The two lines of help under the picture.
func _show_hud_text() -> void:
	var door_hint := "walk into a door" if room.top_down else "Up at a door"
	hud.text = "%s   %s\n%s  F3/F4 area  F7 map  F6 fly  F8 foes  b%d" % [turtle.turtle_name, room.name, door_hint, Game.BUILD]

## Opens the Start screen (Research/start_screen.md). The original refuses
## while the playing turtle has no energy left; the remake also waits out
## its own "world clear" message.
func open_start_screen() -> void:
	if start_screen.is_open() or _clearing or room == null or turtle.state == Turtle.State.DEAD:
		return
	turtle_energy[current_turtle] = turtle.health
	if room.top_down:
		overworld_spot = walker.position
	var leftovers: Array = room.palettes.slice(6, 8) if room.palettes.size() >= 8 else []
	start_screen.open({
		"world": world, "area": area, "inside": not room.top_down,
		"held_fight": hold != null, "spot": overworld_spot,
		"energies": turtle_energy, "turtle": current_turtle, "sprite_colours": leftovers,
	})

## Makes another turtle the one who plays: his name, his energy, what his
## weapon does (the ROM's damage row and swing boxes for him) and his
## bandana's colour. The Start screen calls this when it is left.
func set_turtle(index: int) -> void:
	index = clampi(index, 0, TURTLE_NAMES.size() - 1)
	if index == current_turtle:
		return
	turtle_energy[current_turtle] = turtle.health
	current_turtle = index
	turtle.health = int(turtle_energy[index])
	turtle.health_changed.emit(turtle.health, turtle.max_health)
	if levels != null:
		turtle.weapon_swings = [levels.weapon_swing(index, 0), levels.weapon_swing(index, 1), levels.weapon_swing(index, 2)]
		var damage := levels.weapon_damage(index)
		for group: Node in [enemies, items]:
			for thing in group.get_children():
				if "weapon_damage" in thing:
					thing.set("weapon_damage", damage.x)
					thing.set("weapon_damage_low", damage.y)
	_show_turtle_look()
	if room != null:
		_show_hud_text()

## Dresses both turtles (the big one and the overworld one) as the one who
## is playing. The four share their body pictures; with a ROM the bandana
## takes the colour number the ROM keeps for him.
func _show_turtle_look() -> void:
	var colour: Color = StartScreen.PLACEHOLDER_COLOURS[current_turtle]
	var big: SpriteSet = null
	var small: SpriteSet = null
	if start_screen.data != null:
		var number := start_screen.data.bandana(current_turtle)
		colour = NesPalette.color(number)
		big = SpriteSet.cached_with_colour("Leonardo", "0", 2, number)
		small = SpriteSet.cached_with_colour("LeonardoOverworld", "0", 2, number)
	elif levels != null:
		big = SpriteSet.cached("Leonardo")
		small = SpriteSet.cached("LeonardoOverworld")
	turtle.set_look(TURTLE_NAMES[current_turtle], colour, big)
	if levels != null:
		walker.swings = [levels.overworld_swing(current_turtle, 0), levels.overworld_swing(current_turtle, 1),
			levels.overworld_swing(current_turtle, 2), levels.overworld_swing(current_turtle, 3)]
		walker.weapon_sprites = SpriteSet.cached("OverworldWeapons")
		_overworld_turtle_half = levels.overworld_turtle_half()
	walker.set_look(colour, small)

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
	if room.top_down:
		_overworld_last = Vector2(-1000, -1000)   # the screen is placed afresh around him
		_camera_corner = _overworld_corner()
		if enemies_follow_camera:
			return   # the original's map comes up empty; they come in as the screen moves
	var view := Rect2(_camera_corner, Vector2(VIEW_SIZE))
	for spot in room.enemy_spots:
		if room.top_down or not enemies_follow_camera or view.has_point(spot.position):
			_make_enemy(spot)

## The corner of the original's screen on the overworld. A step he takes
## while beyond one of the marks above moves the screen instead of his
## place on it; the screen stops at the map's edges. At the start of a
## world he stands 144 across and 120 down it (measured in world 1);
## through a door, the screen is where the door's record puts it.
func _overworld_corner() -> Vector2:
	var size := Vector2(room.size_pixels())
	var limit := Vector2(maxf(size.x - OVERWORLD_VIEW.x, 0.0), maxf(size.y - OVERWORLD_VIEW.y, 0.0))
	var spot := walker.position.floor()
	var step := spot - _overworld_last
	if step.length() > 16.0:
		overworld_screen = spot - OVERWORLD_START_ON_SCREEN   # he was put here: the start, the fly key
	else:
		var before := _overworld_last - overworld_screen
		if (step.x > 0.0 and before.x >= OVERWORLD_SCROLL_RIGHT) or (step.x < 0.0 and before.x <= OVERWORLD_SCROLL_LEFT):
			overworld_screen.x += step.x
		if (step.y > 0.0 and before.y >= OVERWORLD_SCROLL_DOWN) or (step.y < 0.0 and before.y <= OVERWORLD_SCROLL_UP):
			overworld_screen.y += step.y
	_overworld_last = spot
	overworld_screen = overworld_screen.clamp(Vector2.ZERO, limit)
	return overworld_screen

## Puts the original's screen somewhere on the overworld (a door's record, a test).
func set_overworld_screen(corner: Vector2) -> void:
	overworld_screen = corner
	_overworld_last = walker.position.floor()
	_camera_corner = corner

## The original updates the turtle on one frame and everything else on
## the next, in turn. The enemies' frame is where they come in, act and go.
## The fight on the overworld, on the enemies' frame (Research/overworld.md).
## Boxes overlap as the original tests them. While the turtle attacks, an
## enemy his weapon's box or his own box reaches takes his weapon's damage,
## unless it was hit less than 24 updates ago. Otherwise an enemy touching
## him takes its touch damage off his energy, stops his attack, and he is
## safe for 24 updates.
func _overworld_fight() -> void:
	if turtle.state == Turtle.State.DEAD:
		return
	var body := Rect2(walker.position.floor() - _overworld_turtle_half, _overworld_turtle_half * 2.0)
	var attacking := walker.attack_tick >= 0
	var weapon := walker.weapon_box()
	for thing in enemies.get_children():
		var foe := thing as OverworldEnemy
		if foe == null or foe.is_queued_for_deletion():
			continue
		var box := foe.box()
		var touching := _boxes_meet(box, foe.position, body, walker.position)
		if attacking and foe.safe_updates == 0 and ((weapon.has_area() and _boxes_meet(box, foe.position, weapon, weapon.get_center())) or touching):
			var weakened := turtle.health * 2 < turtle.max_health
			foe.take_hit(foe.weapon_damage_low if weakened else foe.weapon_damage)
		elif touching and walker.safe_updates == 0:
			walker.safe_updates = OVERWORLD_SAFE_UPDATES
			walker.cancel_attack()
			attacking = false
			turtle.drain(foe.touch_damage)

## The original's test for two boxes meeting (bank 6, $9AE1), for an
## enemy's box against the turtle's or his weapon's. Edges that only
## touch count when the enemy is the one to the left or above, and not
## when it is to the right or below.
func _boxes_meet(enemy_box: Rect2, enemy_at: Vector2, other: Rect2, other_at: Vector2) -> bool:
	if floorf(enemy_at.x) >= floorf(other_at.x):
		if enemy_box.position.x >= other.end.x:
			return false
	elif enemy_box.end.x < other.position.x:
		return false
	if floorf(enemy_at.y) >= floorf(other_at.y):
		return enemy_box.position.y < other.end.y
	return enemy_box.end.y >= other.position.y

func _on_walker_moved() -> void:
	_overworld_frame += 1
	if room == null or not room.top_down:
		return
	var corner := _overworld_corner()
	if walker.updated:
		_overworld_turn = (_overworld_frame + 1) % 2
	elif _overworld_frame % 2 == _overworld_turn and show_enemies and enemies_follow_camera:
		_follow_overworld(corner)

## The overworld's enemies come and go with the screen, as in a room, but
## through all four edges. A new one starts one screen step away from its
## place, against the way the screen moved, and acts at once (measured).
func _follow_overworld(corner: Vector2) -> void:
	var old := _camera_corner
	_camera_corner = corner
	if corner.distance_to(old) > 64.0:
		old = corner   # the view jumped (a door, the fly key): nothing comes in this time
	var view := OVERWORLD_VIEW
	var _just_made := {}
	for spot in room.enemy_spots:
		var place := spot.position
		var across_now := place.x >= corner.x + SPAWN_MARGIN and place.x <= corner.x + view.x - SPAWN_MARGIN
		var across_before := place.x >= old.x + SPAWN_MARGIN and place.x <= old.x + view.x - SPAWN_MARGIN
		var down_now := place.y >= corner.y + SPAWN_MARGIN and place.y <= corner.y + view.y - SPAWN_MARGIN
		var down_before := place.y >= old.y + SPAWN_MARGIN and place.y <= old.y + view.y - SPAWN_MARGIN
		if across_now and down_now and not (across_before and down_before):
			var living: Variant = _spot_enemies.get(spot)
			if living == null or not is_instance_valid(living) or living.is_queued_for_deletion():
				_make_enemy(spot)
				var made: Variant = _spot_enemies.get(spot)
				if made is OverworldEnemy:
					made.screen_corner = corner
					made.position -= corner - old
					made.tick()
					_just_made[made] = true
	for thing in enemies.get_children():
		if thing is OverworldEnemy and not thing.is_queued_for_deletion():
			thing.screen_corner = corner
			if not _just_made.has(thing):
				thing.tick()
		var across: float = thing.position.x - corner.x
		var down: float = thing.position.y - corner.y
		# The original keeps a thing whose place on the screen is 4 to 251 both ways.
		if across < REMOVE_MARGIN or across >= 256.0 - REMOVE_MARGIN or down < REMOVE_MARGIN or down >= 256.0 - REMOVE_MARGIN:
			thing.queue_free()
	_overworld_fight()

## Puts the room's items out. They are there from the start and stay until
## picked up; leaving the room and coming back brings them back.
func _place_items() -> void:
	for child in items.get_children():
		items.remove_child(child)
		child.queue_free()
	if boss != null and is_instance_valid(boss) and not boss.is_queued_for_deletion():
		_boss_done.erase(_boss_key)   # he left with the boss still standing: it will be back
	boss = null
	_company = null
	_end_fight()
	_holds_done.clear()
	if levels == null or room == null or room.top_down or not room.name.begins_with("World"):
		return
	for entry: Array in ITEMS.get(Vector2i(world, area), []):
		var item := Item.new()
		item.setup(entry[0], entry[1], SpriteSet.cached("Kind%02X" % entry[0]))
		items.add_child(item)

## Starts a fight when the camera reaches a place the ROM's encounter
## table names (Research/encounters.md), and holds the screen there.
func _check_boss() -> void:
	if levels == null or not show_enemies or fighting or room.top_down or not room.name.begins_with("World"):
		return
	var key := Vector2i(world, area)
	var corner := _view_corner()
	var before := _boss_camera_x
	_boss_camera_x = corner.x
	for index in room.encounters.size():
		var entry := room.encounters[index]
		if entry.is_boss:
			if _boss_done.has(key) or not BOSS_KINDS.has(entry.kind):
				continue
		elif _holds_done.has(index) or entry.kind <= 0:
			continue
		if floori(corner.y / VIEW_SIZE.y) != entry.row:
			continue
		var wanted := entry.camera_x()
		if entry.column == 0:
			if corner.x > 0.0:
				continue
		else:
			# The camera must be on that spot, give or take a pixel. It
			# scrolls at most 4 pixels at a time, so a step that small
			# across the spot counts too.
			var on_it := absf(corner.x - wanted) <= 1.0
			var stepped_over := absf(corner.x - before) <= 4.0 and minf(corner.x, before) < wanted and maxf(corner.x, before) > wanted
			if not on_it and not stepped_over:
				continue
		if entry.is_boss:
			_start_fight(entry, key)
		else:
			_start_hold(entry, index)
		break

## A held fight: the screen stops; see _run_fight for the rest.
func _start_hold(entry: Encounter, index: int) -> void:
	_holds_done[index] = true
	hold = entry
	hold_stage = 1
	_hold_frames = 0
	_hold_screen(Vector2(entry.camera_x(), entry.row * VIEW_SIZE.y))

func _hold_screen(corner: Vector2) -> void:
	turtle.sync_screen()
	fight_corner = Vector2(floorf(turtle.scroll_x), corner.y)   # the screen stops where it is
	fighting = true
	turtle.scroll_locked = true
	var camera: Camera2D = turtle.get_node("Camera2D")
	camera.limit_left = int(fight_corner.x)
	camera.limit_right = int(fight_corner.x) + VIEW_SIZE.x

## How many enemies (and things they threw) are on the map just now.
func living_enemies() -> int:
	var count := 0
	for thing in enemies.get_children():
		if not (thing is Puff) and not thing.is_queued_for_deletion():
			count += 1
	return count

func _start_fight(entry: Encounter, key: Vector2i) -> void:
	_boss_done[key] = true
	_boss_key = key
	boss = Bebop.new() if entry.kind == Bebop.KIND else Rocksteady.new()
	boss.setup(entry.position, room, SpriteSet.cached("Kind%02X" % entry.kind), turtle)
	boss.health = entry.hit_points
	boss.full_health = entry.hit_points
	boss.touch_damage = entry.touch_damage
	var damage := levels.weapon_damage(current_turtle)
	boss.weapon_damage = damage.x
	boss.weapon_damage_low = damage.y
	boss.defeated.connect(_on_boss_defeated.bind(entry.kind))
	_hold_screen(Vector2(entry.camera_x(), entry.row * VIEW_SIZE.y))
	boss.view_left = fight_corner.x
	items.add_child(boss)   # kept apart from the enemies so the camera rule never removes it
	_fit_box(boss, entry.half_size, entry.kind)
	if BOSS_COMPANY.has(entry.kind):
		var company: Array = BOSS_COMPANY[entry.kind]
		_company = _make_prop(company[0], fight_corner + company[1])
		_company.scale.x = -1.0 if company[2] else 1.0
		items.add_child(_company)
	boss_bar.show()

## A picture that only stands there.
func _make_prop(kind: int, at: Vector2) -> Node2D:
	var prop := Node2D.new()
	prop.position = at
	var pictures := SpriteSet.cached("Kind%02X" % kind)
	if pictures != null:
		var frame := pictures.frame_at("stand", 0)
		if pictures.textures.has(frame):
			var picture := Sprite2D.new()
			picture.centered = false
			picture.texture = pictures.textures[frame]
			picture.position = pictures.offsets[frame]
			prop.add_child(picture)
	return prop

## Lets the screen move again.
func _end_fight() -> void:
	if boss_bar != null:
		boss_bar.hide()
	hold = null
	hold_stage = 0
	turtle.scroll_locked = false
	if not fighting:
		return
	fighting = false
	if room != null and not room.top_down:
		var camera: Camera2D = turtle.get_node("Camera2D")
		camera.limit_left = 0
		camera.limit_right = room.size_pixels().x

## Keeps the turtle on the screen; shows a boss's energy; and runs a held
## fight: once the screen is clear of enemies, one more comes in after 16
## frames, and 64 frames after that one is beaten the screen is freed.
func _run_fight() -> void:
	if not fighting:
		return
	if boss != null and is_instance_valid(boss):
		boss_bar.set_health(ceili(maxi(boss.health, 0) * float(ENERGY_BLOCKS) / maxi(boss.full_health, 1)), ENERGY_BLOCKS)
	if hold == null:
		return
	if not show_enemies:
		_end_fight()
		return
	if living_enemies() > 0:
		_hold_frames = 0
		return
	_hold_frames += 1
	if hold_stage == 1 and _hold_frames >= HOLD_ENTER_FRAMES:
		var spot := EnemySpot.new()
		spot.position = fight_corner + hold.offset
		spot.kind = hold.kind
		spot.kinds = PackedInt32Array([hold.kind, hold.kind, hold.kind, hold.kind])
		spot.hit_points = hold.hit_points
		spot.touch_damage = hold.touch_damage
		spot.half_size = hold.half_size
		_make_enemy(spot)
		hold_stage = 2
		_hold_frames = 0
	elif hold_stage == 2 and _hold_frames >= HOLD_LEAVE_FRAMES:
		_end_fight()

## Beating the first boss frees the screen, and those who stood by are
## gone. Beating the last one ends the world: the original then starts the
## next world on its overworld. (What it shows in between is not done.)
func _on_boss_defeated(kind: int) -> void:
	if _company != null and is_instance_valid(_company):
		_company.queue_free()
	_company = null
	_end_fight()
	if kind != WORLD_END_BOSS or _clearing:
		return
	_clearing = true
	var cleared := world
	hud.text = "WORLD %d CLEAR" % (cleared + 1)
	await get_tree().create_timer(clear_message_seconds).timeout
	_clearing = false
	if levels != null and levels.has_overworld(cleared + 1):
		load_overworld(cleared + 1)

## How many of the original's six places for placed enemies are taken:
## everything on the map but what enemies have thrown. A beaten enemy's
## puff still holds its place.
func placed_enemies() -> int:
	var count := 0
	for thing in enemies.get_children():
		if thing.is_queued_for_deletion() or thing is Shot or (thing is OriginalEnemy and thing.is_thrown):
			continue
		count += 1
	return count

## Makes the enemy for one of the ROM's enemy places. In a room whose
## enemies follow the camera there are only six places for them, as in
## the original (bank 7, $EED3): with all six taken, none is made.
func _make_enemy(spot: EnemySpot) -> void:
	if not room.top_down and enemies_follow_camera and placed_enemies() >= PLACED_AT_ONCE:
		return
	var damage := levels.weapon_damage(current_turtle) if levels != null else Vector2i.ONE
	var enemy: Node2D
	var pictures := SpriteSet.cached("Kind%02X" % spot.kind) if spot.kind >= 0 else null
	var original := OriginalEnemy.for_kind(spot.kind) if not room.top_down else null
	if room.top_down and OverworldEnemy.KINDS.has(spot.kind):
		var mover := OverworldEnemy.new()
		mover.setup(spot, room, pictures, walker)
		mover.self_driven = false   # the map scene gives them their turn
		enemy = mover
	elif room.top_down:
		enemy = _make_stand_in(spot)
	elif original != null:
		# A kind written from the original's own code.
		if enemies_follow_camera:
			original.view_corner = _view_corner
		original.setup(spot, room, pictures, turtle)
		enemy = original
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
	elif LegacyWalker.KINDS.has(spot.kind):
		var walker_enemy := LegacyWalker.new()
		walker_enemy.setup(spot, room, pictures, turtle)
		enemy = walker_enemy
	else:
		enemy = _make_stand_in(spot)
	enemy.set("weapon_damage", damage.x)
	enemy.set("weapon_damage_low", damage.y)
	if enemy.get_parent() == null:
		enemies.add_child(enemy)
	if not room.top_down:
		_fit_box(enemy, spot.half_size, spot.kind)
	_spot_enemies[spot] = enemy

## Gives an enemy the hit box the ROM has for its kind: as wide as the
## pair says to each side, and from its half height above its position
## value down to 2 above it. A few kinds have the box centred instead.
## The one box serves for touching the turtle and for being hit.
func _fit_box(enemy: Node, half: Vector2i, kind: int) -> void:
	if half == Vector2i.ZERO:
		return
	var box := Rect2(-half.x, -half.y, half.x * 2, maxi(half.y - 2, 1))
	if (kind >= 0x23 and kind < 0x27) or kind == 0x89:
		box = Rect2(-half.x, -half.y, half.x * 2, half.y * 2)
	for found in enemy.find_children("*", "CollisionShape2D", true, false):
		var shape := found as CollisionShape2D
		var rectangle := RectangleShape2D.new()
		rectangle.size = box.size
		shape.shape = rectangle
		shape.position = box.get_center()

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
	turtle.sync_screen()
	var size := room.size_pixels()
	var down := clampf(turtle.position.y - 24.0 - 120.0, 0.0, maxf(size.y - VIEW_SIZE.y, 0.0))
	if fighting:
		down = fight_corner.y
	return Vector2(floorf(turtle.scroll_x), down)

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
	if turtle.on_floor():
		var x := floorf(feet.x)
		var y := floorf(feet.y)
		# The original looks under his right foot first when he walks, then
		# his left; standing still, under his middle (bank 4, $9DC6, $9F95).
		var under := room.kind_at_pixel(x, y + 1.0)
		if turtle.speed.x != 0:
			under = room.kind_at_pixel(x + 6.0, y + 1.0)
			if under == RoomData.KIND_EMPTY:
				under = room.kind_at_pixel(x - 6.0, y + 1.0)
		if under == RoomData.KIND_DEADLY and _floor_frame % Turtle.TICK_FRAMES == 0:
			turtle.drain(RoomData.HURT_DAMAGE)
		elif under == RoomData.KIND_MOVING_FLOOR or under == RoomData.KIND_MOVING_FLOOR_LEFT:
			# Kind D carries him right and kind C left, 1.25 pixels an update,
			# unless a wall is on that side (9 ahead at 7 and 24 up, 6 ahead at 32 up).
			var way := 1.0 if under == RoomData.KIND_MOVING_FLOOR else -1.0
			if not (room.solid_at(x + way * 9.0, y - 7.0) or room.solid_at(x + way * 9.0, y - 24.0) or room.solid_at(x + way * 6.0, y - 32.0)):
				turtle.move_across(way * RoomData.MOVING_FLOOR_SPEED / 256.0 / Turtle.TICK_FRAMES)

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
	if room != null and room.top_down and door.to_room:
		overworld_spot = walker.position   # the Start screen's map keeps marking this spot
	if not door.to_room:
		load_overworld(door.to_area)
		walker.position = door.arrive
		set_overworld_screen(door.arrive_camera)
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
	elif fighting:
		return null   # no doors while the screen is held for a fight
	elif turtle.state != Turtle.State.NORMAL or not turtle.on_floor():
		return null
	elif not room.is_door_cell(floori(turtle.position.x / RoomData.TILE), floori((floorf(turtle.position.y) - 28.0) / RoomData.TILE)):
		return null   # the original tests the one point at his middle, 28 above his feet
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
		_place_camera()
		if not room.top_down and show_enemies and enemies_follow_camera:
			_follow_camera()
		return
	if room.top_down:
		return   # the overworld's enemies are seen to when the small turtle has moved
	if turtle.position.y > room.size_pixels().y + 200.0:
		turtle.position = room.start
		turtle.speed = Vector2i.ZERO
		return
	var door := _room_door_in_use()
	if door != null:
		enter_door(door)
		return
	_apply_floor_kinds()
	_place_camera()
	_check_boss()
	_run_fight()
	if show_enemies and enemies_follow_camera:
		_follow_camera()

## Shows the part of the room the original would: the screen's left edge
## is where the turtle's scroll number says, not centred on him.
func _place_camera() -> void:
	if room == null or room.top_down:
		return
	turtle.sync_screen()
	var camera: Camera2D = turtle.get_node("Camera2D")
	camera.position.x = floorf(turtle.scroll_x) + VIEW_SIZE.x / 2.0 - turtle.position.x
	OriginalEnemy.screen_moved_to(floori(turtle.scroll_x))

func set_flying(on: bool) -> void:
	flying = on
	turtle.set_physics_process(not on)
	walker.set_physics_process(not on)
	turtle.speed = Vector2i.ZERO

func _on_turtle_died() -> void:
	# Placeholder for the real "switch turtle / game over" flow.
	await get_tree().create_timer(1.5).timeout
	if room.top_down:
		walker.position = room.start
		walker.safe_updates = 0
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
	if event.is_action_pressed("pause"):
		open_start_screen()
	elif event.is_action_pressed("open_chr_viewer"):
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
