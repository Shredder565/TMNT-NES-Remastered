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
const SPAWN_MARGIN := 8.0            ## (overworld) an enemy is made when its place is this far inside the screen's edge
const SPAWN_RIGHT := 0xF8            ## in a room: the edge that makes enemies, across the screen, scrolling right
const SPAWN_LEFT := 0x07             ## ...and scrolling left
const SPAWN_TOP := 0x17              ## which row of screens: this far down the screen, or
const SPAWN_BOTTOM := 0xB8           ## this far when the screen is not scrolling up
const ROW_TOP := 11                  ## the turtle's middle this near the screen's top (climbing, Up held) changes the screen
const ROW_BOTTOM := 172              ## ...or this far down it
const ROW_SCROLL := 4                ## pixels an update while it changes
const CAMERA_DOWN := 120.0           ## the camera's middle below the screen's top (the HUD strip is under the room)
const PLACED_AT_ONCE := 6            ## the original's object slots 5 to 10
const REMOVE_MARGIN := 4.0           ## and removed when it is this close to leaving
const ITEM_KINDS_BELOW := 0x10       ## of the ROM's things at fixed places, these kinds are items to pick up
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
## A fight the screen is held for (bank 6, $9C1D; Research/encounters.md),
## counted in updates: from the screen being clear to the extra enemy or
## the boss coming in, and from that enemy being gone to the screen being freed.
const HOLD_ENTER_UPDATES := 8
const HOLD_LEAVE_UPDATES := 64
const BOSS_LEAVE_UPDATES := 32
const LEDGE_SCENE_UPDATES := 32
const LEDGE_SCENE_FRAMES := 65
const LEDGE_GONE_AT := 8             ## updates left when the last figure goes
const BOSS_LEAVE_MORE_UPDATES := 63   ## the count runs from $C0 to $80; the update that sets it takes one off
## The line-up level (bank 6, $8174; Research/enemy_placement.md): the
## points made in this room pick a row, and the row's four times (in units
## of 128 frames) say how many steps up the level goes if the room's clock
## is still short of them.
const LEVEL_POINTS := [2000, 4000, 7000, 10000, 14000, 20000, 28000, 35000]
const LEVEL_TIMES := [
	[32, 24, 16, 8], [96, 48, 40, 32], [96, 80, 72, 64], [128, 112, 104, 96],
	[160, 144, 136, 128], [192, 176, 168, 160], [224, 208, 200, 192], [256, 240, 232, 224],
]
const LEVEL_STEPS_BACK := 2          ## what the original then takes off again (see _check_lineup)
const LINEUP_FIXED := 7              ## a room on this line-up never changes it
const CLOCK_FRAMES := 128
## The overworld (Research/overworld.md): the original's screen there is
## 256 x 240 with the turtle kept near its middle. An enemy is made when
## the screen's edge reaches its place, 8 pixels inside any of the four
## edges, and removed within 4 pixels of leaving. None is there when the
## map first comes up.
const OVERWORLD_VIEW := Vector2(256, 240)
## That screen scrolls only while he walks with his place on it beyond
## these (measured): right at 126 or more across, left at 124 or less,
## up at 116 or less down the screen, down at 118 or more.
## Going through a door (measured): rows of tiles drawn in, one a frame.
const WIPE_ROWS_ROOM := 24
const WIPE_ROWS_OVERWORLD := 32      ## the original's overworld picture is taller; ours shows its first 24 rows
const WIPE_HOLD_FRAMES := 16         ## everything stands still this long once the picture is whole
const WIPE_APPEAR_ROOM := 7          ## then the turtle appears, this many frames later in a room, on a ladder
const WIPE_APPEAR_ROOM_STANDING := 4 ## ...or this many when the door leaves him standing (a doorway; 3 in one recording)
const WIPE_APPEAR_OVERWORLD := 1
## When a world begins (measured at world 2's start after April's words)
## the map is drawn in the same way, but the turtle appears 4 frames later
## than after a door, and the eight energy sprites are on show meanwhile,
## all empty, from the fifth frame.
const WIPE_APPEAR_WORLD_BEGIN := 5
const WIPE_WORLD_BEGIN_ENERGY_FROM := 5
## Losing a turtle (measured): frames from the blow to the Start screen
## (or GAME OVER), and how long the overworld's flattened picture shows.
const CAPTURE_SCREEN_FRAMES := 147
const CAPTURE_OVERWORLD_PICTURE_FRAMES := 62
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
var _coming_up_facing_left := false
var _screen_row := 0                 ## which row of screens is on show
var _row_way := 0                    ## -1 or 1 while the screen changes row
var _row_frame := 0
var _view_top := 0.0                 ## the top of the screen in the room
var _made: Node2D                    ## what _make_enemy_at has just made, if anything
var _camera_corner := Vector2.ZERO
var _floor_frame := 0
var _stood_before := false         ## was the turtle on the ground an update ago
var items: Node2D                    ## holds the items of the room on show
var _ledge_frame := 0
var _ledge_updates := 0               ## updates left of the scene on the ledge after the first boss
var _boss_end_stage := 0              ## after a boss is beaten: 1 the first wait, 2 the second
var boss: Boss                       ## the room's boss while it is alive
var boss_bar: Control                ## the boss's energy, under the turtle's
## With a ROM the screen is laid out as the original's (Research/hud.md):
## a room's picture starts 4 lines down and is 191 lines, with the
## original's strip under it; the overworld fills all 240 lines and has no
## strip; the left and right 8 pixels are dark. The help text (and the
## plain bars) show only without a ROM, or when F9 asks for the text.
var hud_strip: HudStrip
var overworld_energy: OverworldEnergyBar
var show_help_text := false
## The score (Research/score.md). Only beating something adds to it: the
## points go by the slot the enemy was made from, not its kind.
const SCORE_LIMIT := 9999990         ## six decimal digits and a fixed nought
const THROWN_SLOT_BYTE := 0x80       ## what a thrown thing carries as its slot byte (measured for kinds 99 and 4A)
var high_score := 0                  ## the best since the program started (kept in Game)
var _points := {}                    ## enemy (its instance number) -> what beating it gives, for those that do not say so themselves
var _hud_ripper: ChrRipper
var _top_bar: ColorRect
var _left_edge: ColorRect
var _right_edge: ColorRect
const ROOM_TOP_LINE := 4             ## the original writes its scroll 4 lines short (bank 7, $C47A)
const ROOM_LINES := 191              ## lines of a room that show above the strip
const RIGHT_EDGE_FROM_LINE := 2      ## the sprites that hide the right edge start here
var fight_corner := Vector2.ZERO     ## where the screen is held during a boss fight
var fighting := false
var _company: Node2D                 ## what stands by during the fight
var hold: Encounter                  ## the held fight going on, if any
var hold_stage := 0                  ## 1: clear the screen. 2: beat the enemy that came in. 3: beat the boss
var _hold_count := 0                 ## updates left in the wait going on
var _encounter: Encounter            ## the table entry the screen is held for (a held fight or a boss)
var _encounter_index := -1
var hold_bound := false              ## the original's $B0: set once the held screen was first clear
## Points and the line-up level (Research/enemy_placement.md).
var score := 0                       ## points made this game
var room_points := 0                 ## points made since this room was entered
var room_clock := 0                  ## counts every 128th frame since this room was entered
var lineup_level := 0                ## 0 to 3: which of a room's four line-ups a change turns to
var lineup := -1                     ## the line-up enemies are made from just now
var _lineup_pending := false         ## the level has changed; the line-up follows once the screen is clear
var _typed_spots := {}               ## [place, line-up] -> the place as that line-up fills it
var _holds_done := {}                ## this room's held fights already fought (by number)
var _boss_done := {}                 ## (world, area) -> true once that room's boss has appeared
var _clearing := false               ## true from the last boss's fall until the next world is on show
## The end of world 1 (Research/world_end.md; measured frame by frame and
## read from bank 6, $9DD1 and $A070): the buttons go dead when the last
## boss falls; once nothing is left on the screen and 64 frames more have
## passed the turtle walks to April by himself, a pixel every second
## frame; she stands up; 250 frames later the room goes dark and the
## Start screen comes up with April's words; when they are typed out the
## next world begins.
enum EndStage { NONE, WAIT, WALK, FREED, MESSAGE }
const END_WAIT_FRAMES := 64          ## from the screen being clear to the walk: the program waits 32 updates (bank 6, $9DD1); set so that the first step comes on the frame it does in a whole recorded fight (Research/encounters.md)
const END_FREED_FRAMES := 249        ## from her standing up to the dark
const END_BAR_GOES := 8             ## frames into the walk at which the boss's empty bar leaves the strip (its parts are written every 8th frame)
const END_FLOOR_MIDDLE := 140        ## his middle, down the screen, while he walks
const END_STOP_GAP := 16             ## he stops when less than this far right of her
const END_STAND_AT := 50             ## and is then put this far across the screen
const END_WALK_PHASE := 30           ## the original picks the picture by its frame counter; this is where it stood in the recording
const END_WALK_PICTURES := ["walk1", "stand", "walk2", "stand"]   ## 8 frames each
const APRIL_AT := Vector2(26, 166)   ## where she sits on the fight's screen (object slot 15)
const MUTED_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "pause", "select"]
var end_stage := EndStage.NONE
var _end_frames := 0
var april: Sprite2D                  ## April in the last room, while the fight and the scene after it last
var _boss_key := Vector2i(-1, -1)    ## the room the living boss belongs to
var _boss_camera_x := 0.0            ## where the camera was a frame ago
## World 5 hides the Technodrome behind the inner door of one of three caves
## (areas 2, 3 and 4), chosen afresh each game.
var technodrome_cave := 2
var _door_seen := false               ## his last update found Up held at a doorway
var _wait_for_up_release := false    ## no second door until Up is let go
var current_turtle := 0              ## who is playing: 0 Leonardo, 1 Raphael, 2 Michelangelo, 3 Donatello
var turtle_energy: Array = [TURTLE_ENERGY, TURTLE_ENERGY, TURTLE_ENERGY, TURTLE_ENERGY]
var start_screen: StartScreen        ## the Start (information) screen
var overworld_spot := Vector2.ZERO   ## where he last stood on the overworld: the Start screen's map marks it
var overworld_screen := Vector2.ZERO ## the corner of the original's screen on the overworld (enemies come and go by it)
var _overworld_last := Vector2.ZERO  ## where the overworld turtle was a frame ago
var _overworld_turtle_half := Vector2(4, 4)   ## half the overworld turtle's box (the ROM's, when there is one)
var game_over: GameOverScreen        ## GAME OVER, CONTINUE / END
## The special weapons (Research/special_weapons.md): which one each turtle
## has (0 none, 1 the star, 2 the triple star, 3 the boomerang, 4 the
## scroll), how many, and whether the playing turtle's is the weapon in use
## (the original's $73, $A8 and $5B).
const SPECIAL_ITEM_FIRST := 0x05     ## item kinds 05 to 08 give special weapons 1 to 4
const SPECIAL_ITEM_LAST := 0x08
const SPECIAL_PICKED_UP := 20        ## an item gives 20, or 20 more of the same
const SPECIAL_MOST := 99
const SPECIAL_THROWN_AT_ONCE := 3    ## object slots 2 to 4
const SPECIAL_CAN_THROW := [1, 2]    ## the ones the remake can throw so far
const SPECIAL_DAMAGE_ROW := 3        ## the damage table's row for special weapon n is n + 3
var special_kind: Array = [0, 0, 0, 0]
var special_count: Array = [0, 0, 0, 0]
var special_in_use := false
var thrown: Node2D                   ## holds what the turtle has thrown
var rescued_one := false             ## a captured turtle has been rescued (the original's $56): no captive is shown while this is set
var continues_left := 3              ## the original starts with 3 and takes one off at every GAME OVER; at 0 the game ends
var _capture_frame := -1             ## frames since the playing turtle ran out of energy, -1 when he has not
var _after_capture := false          ## the Start screen on show was forced by a capture
var door_wipe := true                ## false: doors change sides at once (tests, study keys)
var _wipe_frame := -1                ## frames into a door's change of sides, -1 when none is on show
var _wipe_rows := 0
var _wipe_world_begin := false       ## the wipe on show is a world beginning, not a door
var _wipe_cover: ColorRect
var frame_clock := 0                 ## counts frames on the overworld as the original's frame counter does (one byte)
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
	OriginalEnemy.pace_maker = turtle
	_build_hud_strip()
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
	thrown = Node2D.new()
	thrown.name = "Thrown"
	add_child(thrown)
	turtle.throw_started.connect(_on_throw_started)
	enemies.child_entered_tree.connect(_on_thing_entered.bind(enemies))
	items.child_entered_tree.connect(_on_thing_entered.bind(items))
	high_score = Game.high_score
	walker = OverworldTurtle.new()
	walker.bandana_color = turtle.bandana_color
	walker.door_reached.connect(use_door)
	var wipe_layer := CanvasLayer.new()
	wipe_layer.layer = 0   # over the map and everything on it, under the HUD strip and the Start screen
	add_child(wipe_layer)
	_wipe_cover = ColorRect.new()
	_wipe_cover.color = Color.BLACK
	_wipe_cover.size = Vector2(VIEW_SIZE)
	_wipe_cover.visible = false
	wipe_layer.add_child(_wipe_cover)
	walker.moved.connect(_on_walker_moved)
	add_child(walker)
	start_screen = StartScreen.new()
	start_screen.use_installed_rom()
	start_screen.turtle_chosen.connect(set_turtle)
	start_screen.closed.connect(_on_start_screen_closed)
	start_screen.event_finished.connect(_on_event_finished)
	add_child(start_screen)
	game_over = GameOverScreen.new()
	game_over.use_installed_rom()
	game_over.chosen.connect(_on_game_over_chosen)
	add_child(game_over)
	_show_turtle_look()
	technodrome_cave = randi_range(2, 4)
	if start_on_overworld and levels != null and levels.has_overworld(world):
		load_overworld(world)
		if Game.draw_first_world_in and door_wipe:
			_start_wipe(true)   # from the title: black, then the map drawn in, as when any world begins
	else:
		load_area(world, area)
	Game.draw_first_world_in = false

func load_area(new_world: int, new_area: int) -> void:
	world = new_world
	area = new_area
	OriginalEnemy.left_over = PackedByteArray()   # a door fills this in afterwards
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
	if end_stage != EndStage.NONE:
		# The room was changed under the scene after the last boss (a study key).
		end_stage = EndStage.NONE
		_clearing = false
		turtle.set_physics_process(not flying)
	var ripper: ChrRipper = null
	if levels != null:
		if _hud_ripper == null:
			_hud_ripper = ChrRipper.new(RomInfo.inspect_file(Game.ROM_PATH).chr_rom)
		ripper = _hud_ripper
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
	# Entering a map starts its points and its clock afresh, and it comes up
	# with its own line-up whatever the level is (bank 7, $E7F9 and $D551).
	room_points = 0
	room_clock = 0
	lineup = room.entry_lineup
	_lineup_pending = false
	_typed_spots.clear()
	_place_enemies()
	_place_items()
	_boss_camera_x = _view_corner().x
	_wait_for_up_release = true
	if room.top_down:
		overworld_spot = walker.position
	_lay_out_screen()
	_show_hud_text()

## Makes the strip and the dark edges (hidden until a ROM's room is shown).
func _build_hud_strip() -> void:
	var layer: Node = health_bar.get_parent()
	hud_strip = HudStrip.new()
	hud_strip.visible = false
	layer.add_child(hud_strip)
	layer.move_child(hud_strip, hud.get_index())   # the help text, when asked for, goes over it
	overworld_energy = OverworldEnergyBar.new()
	overworld_energy.visible = false
	layer.add_child(overworld_energy)
	layer.move_child(overworld_energy, hud.get_index())
	_top_bar = ColorRect.new()
	_top_bar.size = Vector2(256, ROOM_TOP_LINE)
	_left_edge = ColorRect.new()
	_left_edge.size = Vector2(8, 240)
	_right_edge = ColorRect.new()
	_right_edge.position = Vector2(248, RIGHT_EDGE_FROM_LINE)
	_right_edge.size = Vector2(8, 240 - RIGHT_EDGE_FROM_LINE)
	for bar: ColorRect in [_top_bar, _left_edge, _right_edge]:
		bar.color = Color.BLACK
		bar.visible = false
		layer.add_child(bar)

## Does the screen follow the original's layout (it does with a ROM)?
func original_layout() -> bool:
	return levels != null and room != null

## Places the picture, the strip and the dark edges for the room or the
## overworld that has just been loaded.
func _lay_out_screen() -> void:
	var as_original := original_layout()
	var in_room := as_original and not room.top_down
	var panel: ColorRect = health_bar.get_parent().get_node("Panel")
	panel.visible = not as_original or in_room
	panel.position.y = HudStrip.FIRST_LINE if in_room else float(VIEW_SIZE.y)
	panel.size.y = 240.0 - panel.position.y
	hud_strip.visible = in_room
	overworld_energy.visible = as_original and room.top_down
	if overworld_energy.visible:
		overworld_energy.use(_hud_ripper)
		overworld_energy.show_energy(turtle.health)
	_top_bar.visible = in_room
	_left_edge.visible = as_original
	_right_edge.visible = as_original
	health_bar.visible = not as_original
	if boss_bar != null:
		boss_bar.modulate.a = 0.0 if as_original else 1.0   # its own show and hide stay as the fight sets them
	hud.visible = not as_original or show_help_text
	var room_camera: Camera2D = turtle.get_node("Camera2D")
	room_camera.offset.y = -ROOM_TOP_LINE if in_room else 0.0
	# The original's sprites do not get that shift: enemies, thrown things,
	# puffs and items are drawn that much higher than their places (measured:
	# a kind 8D at 180 down is drawn on lines 164 to 179).
	OriginalEnemy.sprite_lift = ROOM_TOP_LINE if in_room else 0
	# A room's places are counted on its picture, so the whole view goes down
	# 4 lines. The overworld's are the original's own numbers, which its
	# sprites follow and its map does not: there only the map goes down.
	background.position.y = ROOM_TOP_LINE if as_original and room.top_down else 0.0
	if in_room:
		hud_strip.third_box = world == 2 or world == 3
		hud_strip.use(_hud_ripper, room.chr_page, room.palettes[0] if not room.palettes.is_empty() else [])
		hud_strip.show_turtle(current_turtle, turtle.health)
		hud_strip.show_scores(score, high_score)
	if as_original and room.top_down:
		walker.camera.top_level = true
		walker.camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		for side: int in [SIDE_LEFT, SIDE_TOP]:
			walker.camera.set_limit(side, -10000000)
		for side: int in [SIDE_RIGHT, SIDE_BOTTOM]:
			walker.camera.set_limit(side, 10000000)
		_overworld_corner()

## The overworld's picture is the original's screen: its corner on the map.
func _place_overworld_camera() -> void:
	if original_layout() and room.top_down and walker.camera.top_level:
		walker.camera.position = overworld_screen

## F9: the help text over the picture, on or off.
func set_help_text(on: bool) -> void:
	show_help_text = on
	hud.visible = not original_layout() or on

## The two lines of help under the picture.
func _show_hud_text() -> void:
	var door_hint := "walk into a door" if room.top_down else "Up at a door"
	hud.text = "%s   %s\n%s  F3/F4 area  F7 map  F6 fly  F8 foes  b%d" % [turtle.turtle_name, room.name, door_hint, Game.BUILD]

## Opens the Start screen (Research/start_screen.md). The original refuses
## while the playing turtle has no energy left; the remake also waits out
## its own "world clear" message.
func open_start_screen() -> void:
	if start_screen.is_open() or game_over.is_open() or _clearing or wiping() or room == null or turtle.state == Turtle.State.DEAD:
		return
	turtle_energy[current_turtle] = turtle.health
	if room.top_down:
		overworld_spot = walker.position
	var leftovers: Array = room.palettes.slice(6, 8) if room.palettes.size() >= 8 else []
	start_screen.open({
		"world": world, "area": area, "inside": not room.top_down,
		"held_fight": hold != null, "spot": overworld_spot,
		"energies": turtle_energy, "turtle": current_turtle, "sprite_colours": leftovers,
		"weapons": special_kind, "counts": special_counts_shown(),
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
	_show_special()
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
	var swings: SpriteSet = null
	if start_screen.data != null:
		var number := start_screen.data.bandana(current_turtle)
		colour = NesPalette.color(number)
		big = SpriteSet.cached_with_colour("Leonardo", "0", 2, number)
		swings = SpriteSet.cached_with_colour("TurtleSwings", "0", 2, number)
		small = SpriteSet.cached_with_colour("LeonardoOverworld", "0", 2, number)
	elif levels != null:
		big = SpriteSet.cached("Leonardo")
		small = SpriteSet.cached("LeonardoOverworld")
	turtle.set_look(TURTLE_NAMES[current_turtle], colour, big, swings, SpriteSet.cached("TurtleWeapons") if swings != null else null)
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
	_points.clear()
	if _row_way == 0:
		_settle_row()
	_camera_corner = _view_corner()
	if not show_enemies or room == null:
		return
	if room.top_down:
		_overworld_last = Vector2(-1000, -1000)   # the screen is placed afresh around him
		_camera_corner = _overworld_corner()
		if enemies_follow_camera:
			return   # the original's map comes up empty; they come in as the screen moves
	if room.top_down or not enemies_follow_camera:
		for spot in room.enemy_spots:
			_make_enemy(spot)
		return
	# A room coming up (bank 6, $85CC): the places of the screen its left
	# edge is in, from 7 pixels inside that edge rightward; and, if the
	# screen straddles two, the places of the next one up to 8 pixels short
	# of the right edge. Each enemy stands as far across the *screen* as its
	# place is across its own screen, so when the screen straddles two they
	# are not where their places are. No more than six.
	var left := int(_camera_corner.x)
	var top := int(_camera_corner.y)
	var first_edge := left + SPAWN_LEFT
	_coming_up_facing_left = false   # those of the first pass face right
	for spot in _screen_spots(first_edge >> 8, (top + SPAWN_TOP) / VIEW_SIZE.y):
		if (int(spot.position.x) & 255) >= (first_edge & 255):
			_make_enemy(spot, Vector2(left + (int(spot.position.x) & 255), top + int(spot.position.y) % VIEW_SIZE.y), false)
	if left & 255 != 0:
		var second_edge := left + SPAWN_RIGHT
		_coming_up_facing_left = true    # ...and those of the second pass face left
		for spot in _screen_spots(second_edge >> 8, (top + SPAWN_TOP) / VIEW_SIZE.y):
			if (int(spot.position.x) & 255) < (second_edge & 255):
				_make_enemy(spot, Vector2(left + (int(spot.position.x) & 255), top + int(spot.position.y) % VIEW_SIZE.y), false)

## The enemy places of one screen of the room, in the ROM's order.
func _screen_spots(column: int, row: int) -> Array[EnemySpot]:
	var found: Array[EnemySpot] = []
	for spot in room.enemy_spots:
		if int(spot.position.x) >> 8 == column and int(spot.position.y) / VIEW_SIZE.y == row:
			found.append(spot)
	return found

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
		# He was put here: the start, the fly key.
		if room.start_camera != Vector2.INF and spot == room.start.floor():
			overworld_screen = room.start_camera
		else:
			overworld_screen = spot - OVERWORLD_START_ON_SCREEN
	else:
		var before := _overworld_last - overworld_screen
		if (step.x > 0.0 and before.x >= OVERWORLD_SCROLL_RIGHT) or (step.x < 0.0 and before.x <= OVERWORLD_SCROLL_LEFT):
			overworld_screen.x += step.x
		if (step.y > 0.0 and before.y >= OVERWORLD_SCROLL_DOWN) or (step.y < 0.0 and before.y <= OVERWORLD_SCROLL_UP):
			overworld_screen.y += step.y
	_overworld_last = spot
	overworld_screen = overworld_screen.clamp(Vector2.ZERO, limit)
	_place_overworld_camera()
	return overworld_screen

## Puts the original's screen somewhere on the overworld (a door's record, a test).
func set_overworld_screen(corner: Vector2) -> void:
	overworld_screen = corner
	_overworld_last = walker.position.floor()
	_camera_corner = corner
	_place_overworld_camera()

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
	frame_clock = (frame_clock + 1) & 255
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
					made.frame_clock = frame_clock
					made.position -= corner - old
					made.tick()
					_just_made[made] = true
	for thing in enemies.get_children():
		if thing is OverworldEnemy and not thing.is_queued_for_deletion():
			thing.screen_corner = corner
			thing.frame_clock = frame_clock
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
	_clear_thrown()
	OriginalEnemy.sprite_lift = ROOM_TOP_LINE if original_layout() and not room.top_down else 0
	for child in items.get_children():
		items.remove_child(child)
		child.queue_free()
	if boss != null and is_instance_valid(boss) and not boss.is_queued_for_deletion():
		_boss_done.erase(_boss_key)   # he left with the boss still standing: it will be back
	boss = null
	_company = null
	if _ledge_updates > 0:
		_ledge_updates = 0
		turtle.set_physics_process(true)
	_end_fight()
	_holds_done.clear()
	if levels == null or room == null or room.top_down or not room.name.begins_with("World"):
		return
	# The ROM's own list (bank 4, $ACCD), which used to be copied here by hand.
	for entry: Array in room.fixed_things:
		if entry[0] >= ITEM_KINDS_BELOW:
			continue
		var item := Item.new()
		if entry[0] == Item.CAPTIVE:
			# A captured turtle to rescue: only there if one is captured and
			# none has been rescued since the flag was last cleared.
			var who := captive_to_show(randi() & 3)
			if who < 0:
				item.free()
				continue
			var bandana := start_screen.data.bandana(who) if start_screen.data != null else 0x16
			item.setup(entry[0], entry[1], SpriteSet.cached_with_colour("Captive", "2", 2, bandana))
			item.set_meta("turtle", who)
			item.taken.connect(_on_captive_freed)
		else:
			item.setup(entry[0], entry[1], SpriteSet.cached("Kind%02X" % entry[0]))
			item.taken.connect(_on_item_taken)
		items.add_child(item)

## --- the special weapons (Research/special_weapons.md) ---

## An item has been picked up. Kinds 05 to 08 give a special weapon (bank
## 6, $96E3): a different one from the one he has replaces it, with 20, and
## becomes the weapon in use; the same one adds 20, to 99 at most.
func _on_item_taken(item: Item) -> void:
	if item.kind >= SPECIAL_ITEM_FIRST and item.kind <= SPECIAL_ITEM_LAST:
		give_special(item.kind - SPECIAL_ITEM_FIRST + 1)

func give_special(number: int) -> void:
	if special_kind[current_turtle] == number:
		special_count[current_turtle] = mini(int(special_count[current_turtle]) + SPECIAL_PICKED_UP, SPECIAL_MOST)
	else:
		special_kind[current_turtle] = number
		special_count[current_turtle] = SPECIAL_PICKED_UP
		special_in_use = true
	_show_special()

## Select, in a room (bank 4, $982C): changes between his own weapon and
## his special weapon, if he has any of it.
func press_select() -> void:
	if room == null or room.top_down or _clearing or wiping() or start_screen.is_open() or game_over.is_open() or turtle.state == Turtle.State.DEAD:
		return
	special_in_use = not special_in_use and int(special_count[current_turtle]) > 0
	_show_special()

func special_counts_shown() -> Array:
	return special_count.duplicate()

## Tells the strip and the turtle how things stand. The box blinks while
## the special weapon is the one in use: blank while bit 3 of the frame
## count is 0.
func _show_special() -> void:
	if special_in_use and int(special_kind[current_turtle]) == 0:
		special_in_use = false   # the original looks at this when a swing begins and when the Start screen is left
	turtle.special_ready = special_in_use and SPECIAL_CAN_THROW.has(int(special_kind[current_turtle]))
	if hud_strip != null:
		hud_strip.show_special(int(special_kind[current_turtle]), int(special_count[current_turtle]), special_in_use and (turtle._frame & 8) == 0)

## A throw has begun (bank 7, $E066). One star, or for the triple star up
## to three (level, rising, sinking), as far as the three places for thrown
## things allow; with no place free nothing is thrown and nothing is used
## up. One is taken off the count; at 0 the weapon is gone.
func _on_throw_started(crouching: bool) -> void:
	var number := int(special_kind[current_turtle])
	if not SPECIAL_CAN_THROW.has(number):
		return
	var free_places := SPECIAL_THROWN_AT_ONCE
	for thing in thrown.get_children():
		if not thing.is_queued_for_deletion():
			free_places -= 1
	if free_places <= 0:
		return
	var rises: Array = [0, -1, 1] if number == 2 else [0]
	for index in mini(rises.size(), free_places):
		var star := ThrownWeapon.new()
		star.position = turtle.position.floor() - Vector2(0, RoomData.CENTRE_TO_FEET - (12 if crouching else 0))
		star.direction = turtle.facing
		star.rise = rises[index]
		star.room = room
		star.view_corner = _view_corner
		star.targets = _thrown_targets
		star.damage = weapon_damage_now
		if levels != null:
			star.half = Vector2(levels.box_half_size(ThrownWeapon.KIND, ThrownWeapon.ANIMATION))
		thrown.add_child(star)
	special_count[current_turtle] = int(special_count[current_turtle]) - 1
	if int(special_count[current_turtle]) <= 0:
		special_count[current_turtle] = 0
		special_kind[current_turtle] = 0
		special_in_use = false
	_show_special()

## What a thrown thing can hit: the enemies, and a boss.
func _thrown_targets() -> Array:
	var found: Array = enemies.get_children()
	if boss != null and is_instance_valid(boss) and not found.has(boss):
		found.append(boss)
	return found

## What a hit takes off just now (bank 6, $996D): the damage table's row for
## the playing turtle, or for his special weapon while that is the weapon
## in use; the row's second number when his energy is under half.
func weapon_damage_now() -> int:
	if levels == null:
		return 1
	var row := current_turtle
	if special_in_use and int(special_kind[current_turtle]) > 0:
		row = int(special_kind[current_turtle]) + SPECIAL_DAMAGE_ROW
	var pair := levels.weapon_damage(row)
	return pair.y if turtle.health * 2 < turtle.max_health else pair.x

func _clear_thrown() -> void:
	for thing in thrown.get_children():
		thrown.remove_child(thing)
		thing.queue_free()

## Which captured turtle waits at a rescue place (bank 4, $B934), or -1 for
## none. None if one has been rescued already (the flag at $56). Otherwise
## the four are gone through from a start that the frame counter picks (0
## to 3), and the first with no energy is the one. The original's way of
## going round has a slip: from start 2 it looks at turtles 2, 3, 0 and 2
## again, never at turtle 1.
func captive_to_show(start: int) -> int:
	if rescued_one:
		return -1
	var energies: Array = turtle_energy.duplicate()
	energies[current_turtle] = turtle.health
	var offset := start & 3
	for count in 4:
		var who := count + offset
		if who >= 4:
			offset = -1
			who = 0
		if int(energies[who]) == 0:
			return who
	return -1

## Touching the captive (bank 6, $9756): he is back with full energy, to be
## chosen on the Start screen, and the flag is set.
func _on_captive_freed(item: Item) -> void:
	var who := int(item.get_meta("turtle", -1))
	if who < 0 or who >= turtle_energy.size():
		return
	turtle_energy[who] = TURTLE_ENERGY
	rescued_one = true

## Is this one of the frames on which the original sees to its enemies?
## (They and the turtle take turns; the room scene runs before both.)
func _enemies_frame() -> bool:
	return turtle._frame % Turtle.TICK_FRAMES == 0

## Nothing on the screen but items: no enemy, nothing thrown, no puff of
## a beaten one, no boss (bank 7, $EEE9).
func _screen_clear() -> bool:
	for thing in enemies.get_children():
		if not thing.is_queued_for_deletion() and not (thing is OriginalEnemy and thing.gone):
			return false
	for thing in items.get_children():
		if thing is Puff and not thing.is_queued_for_deletion():
			return false
	return boss == null or not is_instance_valid(boss) or boss.is_queued_for_deletion()

## The table entry whose place the camera is on, or -1 (bank 6, $9C4D).
## An entry in column 0 wants the camera at the room's left end; any other
## wants it 3 to 5 pixels short of that screen. Entries already fought are
## passed over.
func _find_encounter() -> int:
	var key := Vector2i(world, area)
	var corner := _view_corner()
	for index in room.encounters.size():
		var entry := room.encounters[index]
		if entry.is_boss:
			if _boss_done.has(key) or not BOSS_KINDS.has(entry.kind):
				continue
		elif _holds_done.has(index) or entry.kind <= 0:
			continue
		if floori(corner.y / VIEW_SIZE.y) != entry.row:
			continue
		var short := entry.column * 256 - int(corner.x)
		if (entry.column == 0 and int(corner.x) == 0) or (entry.column != 0 and short >= 3 and short <= 5):
			return index
	return -1

## The fights the screen is held for, by the original's routine (bank 6,
## $9C1D), once an update on the enemies' frame before any of them moves:
## - the camera comes to an entry's place: the screen stops;
## - nothing more while anything is on the screen. The eighth update that
##   finds it clear brings in the entry's enemy, or its boss;
## - a held fight's enemy gone (its puff too): 64 updates later the entry
##   is marked as fought and the screen is freed. A boss's end is the
##   boss's own business (_on_boss_defeated).
func _check_boss() -> void:
	if boss != null and is_instance_valid(boss):
		boss_bar.set_health(ceili(maxi(boss.health, 0) * float(ENERGY_BLOCKS) / maxi(boss.full_health, 1)), ENERGY_BLOCKS)
		hud_strip.show_boss(maxi(boss.health, 0))
	if levels == null or room.top_down or not room.name.begins_with("World"):
		return
	if not show_enemies:
		if hold_stage != 0:
			_end_fight()
		return
	if not _enemies_frame():
		return
	if hold_stage == 2:
		if not _screen_clear():
			return
		if _hold_count == 0:
			_hold_count = HOLD_LEAVE_UPDATES
		_hold_count -= 1
		if _hold_count == 0:
			_holds_done[_encounter_index] = true
			_end_fight()
		return
	if hold_stage == 3:
		_after_boss()
		return
	var index := _find_encounter()
	if index < 0:
		return
	var entry := room.encounters[index]
	if hold_stage == 0:
		_start_hold(entry, index)
	if not _screen_clear():
		return
	hold_bound = true
	_hold_count -= 1
	if _hold_count > 0:
		return
	if entry.is_boss:
		hold_stage = 3
		_start_fight(entry, Vector2i(world, area))
	else:
		hold_stage = 2
		_bring_in(entry)

## A boss beaten (bank 6, $9DD1): nothing while it, its puff or anything
## else is on the screen. Then 32 updates; after the first boss of the
## table (code F0, kind 70) 64 more; then the screen is freed. After the
## boss that ends the world the scene below takes over instead.
func _after_boss() -> void:
	if (boss != null and is_instance_valid(boss) and not boss.gone) or not _screen_clear():
		return
	if _encounter == null or _encounter.kind == WORLD_END_BOSS or world_ending():
		return
	if _boss_end_stage == 0:
		_boss_end_stage = 1
		_hold_count = BOSS_LEAVE_UPDATES
	_hold_count -= 1
	if _hold_count > 0:
		return
	if _boss_end_stage == 1 and _encounter.code == 0:
		_boss_end_stage = 2
		_hold_count = BOSS_LEAVE_MORE_UPDATES
		return
	var with_scene := _encounter.code == 0
	_end_fight()
	if with_scene:
		_ledge_frame = 0
		_ledge_updates = LEDGE_SCENE_UPDATES
		turtle.set_physics_process(false)

## After the first boss (bank 6, $A019 and $A037; measured): for 32
## updates nothing else runs, the turtle included. The one who stood by on
## the ledge walks left a pixel an update; 16 updates in, the other figure
## is gone and his picture changes; 8 later he is gone too. (The remake
## has no pictures for the second figure or the changed one.)
func _step_ledge_scene() -> void:
	_ledge_frame += 1
	if _ledge_frame % Turtle.TICK_FRAMES == 1 and _ledge_frame >= 3:
		_ledge_updates -= 1
		if _company != null and is_instance_valid(_company):
			_company.position.x -= 1.0
			if _ledge_updates <= LEDGE_GONE_AT:
				_company.queue_free()
				_company = null
	if _ledge_frame >= LEDGE_SCENE_FRAMES:
		_ledge_updates = 0
		# The frame counter ran on meanwhile (measured: he moves again 68
		# frames after his last step before the scene).
		turtle._frame += LEDGE_SCENE_FRAMES + 1
		turtle.set_physics_process(true)

## The screen stops for an entry of the table; see _check_boss for the rest.
func _start_hold(entry: Encounter, index: int) -> void:
	_encounter = entry
	_encounter_index = index
	hold = null if entry.is_boss else entry
	hold_stage = 1
	_hold_count = HOLD_ENTER_UPDATES
	_hold_screen(Vector2(entry.camera_x(), entry.row * VIEW_SIZE.y))

## A held fight's extra enemy (bank 6, $81F4 and $82DB). Its kind is the
## entry's slot in the line-up of the line-up level as it stands now, which
## the room turns to at this moment. It appears at the entry's place counted
## from the screen's corner, also if that is inside a wall, and is updated
## in the same round.
func _bring_in(entry: Encounter) -> void:
	_turn_to_level_lineup()
	var spot := EnemySpot.new()
	spot.position = fight_corner + entry.offset
	spot.slot = entry.slot & 7
	spot.points = entry.points
	levels._set_kind(spot, levels.kind_in_slot(lineup, spot.slot))
	spot.kinds = PackedInt32Array([spot.kind, spot.kind, spot.kind, spot.kind])
	_make_enemy_at(spot, false)
	if _made is OriginalEnemy:
		_made.held_on_screen = true
		_made.update_now()

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

## The boss comes in (bank 6, $9D05 and $82C9): an object like any other,
## at the entry's place, with its first update in the same round. What it
## brings with it (kind 11 beside kind 70) its own first update makes.
func _start_fight(entry: Encounter, key: Vector2i) -> void:
	_boss_key = key
	boss = Bebop.new() if entry.kind == Bebop.KIND else Rocksteady.new()
	var spot := EnemySpot.new()
	spot.position = entry.position
	spot.kind = entry.kind
	spot.hit_points = entry.hit_points
	spot.touch_damage = entry.touch_damage
	spot.points = entry.points
	boss.view_corner = _view_corner
	boss.setup(spot, room, SpriteSet.cached("Kind%02X" % entry.kind), turtle)
	boss.full_health = entry.hit_points
	boss.points = entry.points
	boss.held_on_screen = true
	var damage := levels.weapon_damage(current_turtle)
	boss.weapon_damage = damage.x
	boss.weapon_damage_low = damage.y
	boss.beaten.connect(add_points)
	boss.defeated.connect(_on_boss_defeated.bind(entry.kind))
	_hold_screen(Vector2(entry.camera_x(), entry.row * VIEW_SIZE.y))
	_boss_end_stage = 0
	enemies.add_child(boss)
	boss.update_now()
	if boss is Bebop:
		_company = boss.company
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
	if hud_strip != null:
		hud_strip.show_boss(-1)
	hold = null
	hold_stage = 0
	_hold_count = 0
	_encounter = null
	hold_bound = false
	turtle.scroll_locked = false
	if not fighting:
		return
	fighting = false
	if room != null and not room.top_down:
		var camera: Camera2D = turtle.get_node("Camera2D")
		camera.limit_left = 0
		camera.limit_right = room.size_pixels().x

## Beating the first boss frees the screen, and those who stood by are
## gone. Beating the last one ends the world: see the scene below.
func _on_boss_defeated(kind: int) -> void:
	_boss_done[_boss_key] = true
	if kind != WORLD_END_BOSS:
		return   # the screen is freed later: see _after_boss
	if _clearing:
		return
	# The screen stays held, with the boss's empty bar, until the walk begins.
	rescued_one = false   # the original clears its rescue flag here (bank 6, $9E48)
	_clearing = true
	end_stage = EndStage.WAIT
	_end_frames = 0

## --- the end of world 1 (Research/world_end.md) ---

## April is in the last room from the moment the boss is (the boss makes
## her, as object slot 15): tied up on the crate at the left of its screen.
func _see_to_april() -> void:
	var wanted := boss != null and is_instance_valid(boss) and int(boss.get("kind")) == WORLD_END_BOSS
	if april != null and (not is_instance_valid(april) or april.is_queued_for_deletion()):
		april = null
	if wanted and april == null:
		var pictures := SpriteSet.cached("April")
		if pictures == null:
			return
		april = Sprite2D.new()
		april.centered = false
		april.set_meta("at", fight_corner + APRIL_AT)
		items.add_child(april)
		_show_april("f144", Vector2.ZERO)

func _show_april(frame: String, shift: Vector2) -> void:
	var pictures := SpriteSet.cached("April")
	if april == null or pictures == null or not pictures.textures.has(frame):
		return
	var at: Vector2 = april.get_meta("at")
	april.texture = pictures.textures[frame]
	# The original's sprites do not get the 4-line shift its background
	# gets; the remake moves a whole room down 4 lines, so she goes 4 up.
	april.position = at + shift + pictures.offsets[frame] - Vector2(0, ROOM_TOP_LINE)

## Is the scene after the last boss running?
func world_ending() -> bool:
	return end_stage != EndStage.NONE

## The original clears the buttons before the turtle's routine sees them
## while this goes on (bank 4, $9757), so he does nothing of his own.
func _mute_buttons() -> void:
	for action: String in MUTED_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)

## One frame of the scene. Returns true while it has the turtle in hand.
func _step_world_end() -> bool:
	_end_frames += 1
	match end_stage:
		EndStage.WAIT:
			_mute_buttons()
			if _anything_left_on_screen():
				_end_frames = 0
			elif _end_frames >= END_WAIT_FRAMES:
				_begin_end_walk()
			return false
		EndStage.WALK:
			_mute_buttons()
			if _end_frames == END_BAR_GOES:
				boss_bar.hide()
				hud_strip.show_boss(-1)
			if _end_frames % Turtle.TICK_FRAMES != 1:
				return true
			var across := floorf(turtle.position.x) - fight_corner.x
			if across < APRIL_AT.x or across - APRIL_AT.x < END_STOP_GAP:
				turtle.position.x = fight_corner.x + END_STAND_AT + turtle.position.x - floorf(turtle.position.x)   # the fraction stays
				turtle.pose("stand", -1)
				_show_april("f145", Vector2(0, -1))
				end_stage = EndStage.FREED
				_end_frames = 0
				boss_bar.hide()
				hud_strip.show_boss(-1)
			else:
				turtle.position.x -= 1.0   # the fraction of his place is kept (measured)
				turtle.pose(END_WALK_PICTURES[((_end_frames + END_WALK_PHASE) >> 3) & 3], -1)
			return true
		EndStage.FREED:
			_mute_buttons()
			if _end_frames >= END_FREED_FRAMES:
				end_stage = EndStage.MESSAGE
				var leftovers: Array = room.palettes.slice(6, 8) if room.palettes.size() >= 8 else []
				turtle_energy[current_turtle] = turtle.health
				start_screen.open({
					"world": world, "area": area, "inside": true, "spot": overworld_spot, "event": true,
					"energies": turtle_energy, "turtle": current_turtle, "sprite_colours": leftovers,
		"weapons": special_kind, "counts": special_counts_shown(),
				})
			return true
		EndStage.MESSAGE:
			return true
	return false

## Is an enemy, a thrown thing or a puff still on the screen?
func _anything_left_on_screen() -> bool:
	for thing in enemies.get_children():
		if not thing.is_queued_for_deletion():
			return true
	for thing in items.get_children():
		if (thing is Puff or thing is Boss) and not thing.is_queued_for_deletion():
			return true
	return false

## The walk begins: everything else is cleared away and he is put on the
## floor facing left.
func _begin_end_walk() -> void:
	# The screen stays where the fight held it.
	for child in enemies.get_children():
		enemies.remove_child(child)
		child.queue_free()
	_spot_enemies.clear()
	end_stage = EndStage.WALK
	_end_frames = 0
	turtle.set_physics_process(false)
	turtle.state = Turtle.State.NORMAL
	turtle.speed = Vector2i.ZERO
	turtle.attack_tick = -1
	turtle.power_ticks = 0
	turtle.art.visible = true
	turtle.position = Vector2(turtle.position.x, fight_corner.y + END_FLOOR_MIDDLE + RoomData.CENTRE_TO_FEET)   # the fraction across is kept (measured)

## April's words are done: the next world begins on its overworld, drawn
## in as after a door.
func _on_event_finished() -> void:
	if end_stage != EndStage.MESSAGE:
		return
	_begin_next_world()

func _begin_next_world() -> void:
	var cleared := world
	end_stage = EndStage.NONE
	_clearing = false
	_end_fight()
	turtle.set_physics_process(not flying)
	turtle.revive()
	turtle.health = int(turtle_energy[current_turtle])
	turtle.health_changed.emit(turtle.health, turtle.max_health)
	if april != null and is_instance_valid(april):
		april.queue_free()
	april = null
	if levels != null and levels.has_overworld(cleared + 1):
		load_overworld(cleared + 1)
		if door_wipe:
			_start_wipe(true)

## Goes straight to the next world from anywhere in the scene (tests, study).
func finish_world_end() -> void:
	if end_stage == EndStage.NONE:
		return
	if start_screen.is_open():
		start_screen.finish_message()
		for i in 3:
			if start_screen.is_open():
				start_screen.tick()
	if end_stage != EndStage.NONE:
		_begin_next_world()

## --- the score (Research/score.md) ---

## A beaten enemy leaves a puff beside itself the moment it is beaten: that
## is where the points are given. What gives how much: a placed enemy, the
## points of the slot it was made from; a boss or a held fight's enemy,
## those of its entry in the encounter table; a thrown thing that can be
## hit, the first row of the table.
func _on_thing_entered(thing: Node, group: Node2D) -> void:
	if not (thing is Puff):
		return
	for other in group.get_children():
		if other == thing or other is Puff or not ("health" in other):
			continue
		if other.position == thing.position and int(other.get("health")) <= 0:
			add_points(points_for_beating(other))
			_points.erase(other.get_instance_id())
			return

func points_for_beating(enemy: Node) -> int:
	if levels == null:
		return 0
	if enemy is OriginalEnemy and enemy.points > 0:
		return 0   # it gives its own points through its `beaten` signal
	if _points.has(enemy.get_instance_id()):
		return int(_points[enemy.get_instance_id()])
	if enemy is Boss and room != null:
		for entry in room.encounters:
			if entry.is_boss and entry.kind == int(enemy.get("kind")):
				return entry.points
	return levels.points_for(THROWN_SLOT_BYTE)

## Sets the score (a new game, CONTINUE, tests); the best score follows it up.
func set_score(new_score: int) -> void:
	score = clampi(new_score, 0, SCORE_LIMIT)
	high_score = maxi(maxi(high_score, Game.high_score), score)
	Game.high_score = high_score
	if hud_strip != null:
		hud_strip.show_scores(score, high_score)

## Items as objects (bank 4, $AB94; measured: Research/doors.md). An item
## on the screen holds an object slot, the first free one from 5 up when
## it comes on: one of the six for placed enemies if any is free (then
## only five enemies fit beside it), else one of the four for thrown
## things. It gives the slot up when it leaves the screen or is taken.
## Looked at once an update, after the enemies of that update are made.
## (Guess: "on the screen" is taken as the object rule, 4 pixels inside;
## the original's list takes an item up 10 pixels inside.)
func _see_to_item_slots() -> void:
	var corner := _view_corner()
	var thrown_held := 0
	for item in items.get_children():
		if not (item is Item) or item.is_queued_for_deletion():
			continue
		var across: float = item.position.x - corner.x
		var down: float = item.position.y - corner.y
		var on_screen := across >= REMOVE_MARGIN and across < VIEW_SIZE.x - REMOVE_MARGIN and down >= REMOVE_MARGIN and down < VIEW_SIZE.y
		if not on_screen:
			item.slot_group = -1
		elif item.slot_group < 0:
			item.slot_group = 0 if placed_enemies() < PLACED_AT_ONCE else 1
		if item.slot_group == 1:
			thrown_held += 1
	OriginalEnemy.thrown_slots_taken = thrown_held

## How many of the original's six places for placed enemies are taken:
## everything on the map but what enemies have thrown. A beaten enemy's
## puff still holds its place.
func placed_enemies() -> int:
	var count := 0
	for item in items.get_children():
		if item is Item and item.slot_group == 0 and not item.is_queued_for_deletion():
			count += 1
	for thing in enemies.get_children():
		if thing.is_queued_for_deletion() or thing is Shot or (thing is OriginalEnemy and thing.is_thrown):
			continue
		count += 1
	return count

## Makes the enemy for one of the ROM's enemy places. In a room whose
## enemies follow the camera there are only six places for them, as in
## the original (bank 7, $EED3): with all six taken, none is made.
## `at` is where it appears, if not at its place. `scrolled_in` is true for
## one made as the screen scrolls: such a one is not made inside a wall,
## and gets its first update in the same round.
func _make_enemy(spot: EnemySpot, at := Vector2.INF, scrolled_in := false) -> void:
	var place := spot
	if not room.top_down and enemies_follow_camera:
		_check_lineup()
		place = _in_lineup(spot)
		if placed_enemies() >= PLACED_AT_ONCE:
			return
	if at != Vector2.INF and at != spot.position:
		place = place.moved_to(at)
	_make_enemy_at(place, scrolled_in)
	if at != Vector2.INF and not scrolled_in and _made is OriginalEnemy:
		# One made as the room comes up does not face by where it stands:
		# the original decides its facing before it puts it at its place.
		_made.facing_left = _coming_up_facing_left
	if _made != null:
		_spot_enemies[spot] = _made

## The room's clock (bank 7, $CC31): one more every 128th frame.
func _run_clock() -> void:
	if OriginalEnemy.counter() % CLOCK_FRAMES == 0 and room_clock < 0xFF00:
		room_clock += 1

## Points for a beaten enemy: to the score, and to the room's own count,
## which the line-up level looks at.
func add_points(points: int) -> void:
	room_points += points
	set_score(score + points)

## A place of the room as the line-up in use fills it.
func _in_lineup(spot: EnemySpot) -> EnemySpot:
	if levels == null or lineup < 0 or lineup == room.entry_lineup or spot.kinds.is_empty() or spot.kinds[0] < 0x10:
		return spot
	var key := [spot, lineup]
	if not _typed_spots.has(key):
		_typed_spots[key] = levels.spot_in_lineup(spot, lineup)
	return _typed_spots[key]

## The line-up level, looked at each time a place is about to make its
## enemy (bank 6, $816A to $8222; read from code, checked in the emulator).
## - With 2000 points or more made in this room, the points pick a row of
##   four times; the level worked out is how many of them, from the first,
##   the room's clock is still short of (0 to 4).
## - If that is not the level in force, it becomes the level, less 2 and
##   not below 0. (The original takes one off below half and another
##   below a quarter of the hit points of object 0, the turtle, whose hit
##   points are kept elsewhere: that number is always 0.) A change of
##   line-up is then due.
## - A change that is due happens the next time a place makes its enemy
##   with the screen clear of enemies: the room turns to its line-up for
##   the level.
func _check_lineup() -> void:
	if levels == null or lineup < 0 or lineup == LINEUP_FIXED:
		return
	if _lineup_pending:
		if _screen_clear():
			_turn_to_level_lineup()
		return
	var row := -1
	for points: int in LEVEL_POINTS:
		if room_points < points:
			break
		row += 1
	if row < 0:
		return
	var worked_out := 0
	for time: int in LEVEL_TIMES[row]:
		if room_clock >= time:
			break
		worked_out += 1
	if worked_out != lineup_level:
		lineup_level = maxi(worked_out - LEVEL_STEPS_BACK, 0)
		_lineup_pending = true

func _turn_to_level_lineup() -> void:
	if levels != null and room.lineups.size() == 4:
		lineup = room.lineups[lineup_level & 3]
	_lineup_pending = false

func _make_enemy_at(spot: EnemySpot, scrolled_in: bool) -> void:
	_made = null
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
		original.points = spot.points
		original.beaten.connect(add_points)
		if scrolled_in and original.kind_at(0, -8) == RoomData.KIND_SOLID:
			original.free()   # its place is in a wall (bank 6, $82B1)
			return
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
	else:
		enemy = _make_stand_in(spot)
	enemy.set("weapon_damage", damage.x)
	enemy.set("weapon_damage_low", damage.y)
	_points[enemy.get_instance_id()] = spot.points
	if hold != null and spot.kind == hold.kind and spot.position == fight_corner + hold.offset:
		_points[enemy.get_instance_id()] = hold.points   # the one a held fight brings in: its entry's own slot byte
	if enemy.get_parent() == null:
		enemies.add_child(enemy)
	if not room.top_down:
		_fit_box(enemy, spot.half_size, spot.kind)
	_made = enemy
	if scrolled_in and enemy is OriginalEnemy:
		enemy.update_now()

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
	var down := _view_top
	if fighting:
		down = fight_corner.y
	return Vector2(floorf(turtle.scroll_x), down)

## --- the screen up and down (Research/scrolling.md, read from 4:$9906) ---
## A room taller than one screen is shown a whole screen at a time. The
## screen does not follow a jump. It changes when the turtle's middle is
## less than 11 from the screen's top while he climbs with Up held, or 172
## or more down it: everything on the screen is cleared and the screen
## moves 4 pixels an update for 48 updates, the turtle held meanwhile.

## Puts the screen on the row of screens the turtle is in, at once.
func _settle_row() -> void:
	_row_way = 0
	if room == null or room.top_down:
		_screen_row = 0
		_view_top = 0.0
		return
	var rows := maxi(room.size_pixels().y / VIEW_SIZE.y, 1)
	_screen_row = clampi(floori((turtle.position.y - RoomData.CENTRE_TO_FEET) / VIEW_SIZE.y), 0, rows - 1)
	_view_top = _screen_row * VIEW_SIZE.y

## Starts a change of screen if the turtle has reached the top or bottom.
func _check_row() -> void:
	if fighting or turtle.state == Turtle.State.DEAD:
		return
	var rows := room.size_pixels().y / VIEW_SIZE.y
	var middle := floori(turtle.position.y) - RoomData.CENTRE_TO_FEET - _screen_row * VIEW_SIZE.y
	var way := 0
	if middle < ROW_TOP and _screen_row > 0 and turtle.state == Turtle.State.CLIMB and Input.is_action_pressed("move_up"):
		way = -1
	elif middle >= ROW_BOTTOM and _screen_row < rows - 1:
		way = 1
	if way == 0:
		return
	_row_way = way
	_row_frame = 0
	turtle.set_physics_process(false)
	for child in enemies.get_children():   # the original clears every object
		enemies.remove_child(child)
		child.queue_free()
	_spot_enemies.clear()

## One frame of a change of screen: every second frame the screen moves 4
## pixels. The turtle keeps his place in the room for the first 40 of the
## 48 updates and is then carried along, so he ends 32 pixels on (measured).
func _step_row_change() -> void:
	_row_frame += 1
	if _row_frame % Turtle.TICK_FRAMES != 0:
		return
	var step := _row_frame / Turtle.TICK_FRAMES
	_view_top += _row_way * ROW_SCROLL
	var middle := mini(ROW_TOP + ROW_SCROLL * step, ROW_BOTTOM - 1) if _row_way < 0 else maxi(ROW_BOTTOM - ROW_SCROLL * step, ROW_TOP + 1)
	turtle.position.y = _view_top + middle + RoomData.CENTRE_TO_FEET + turtle.position.y - floorf(turtle.position.y)
	if step >= VIEW_SIZE.y / ROW_SCROLL:
		_screen_row += _row_way
		_view_top = _screen_row * VIEW_SIZE.y
		_row_way = 0
		turtle.set_physics_process(true)
		_place_enemies()   # guess: the new screen's enemies come up as when a room does

## Enemies coming and going as the screen scrolls, by the original's rule
## (bank 6, $80F6 and $8112; Research/enemy_spawning.md). Once an update,
## on the enemies' frame, before they move: if the screen scrolled in the
## turtle's last update, the places of the screen its leading edge is in
## are gone through. Scrolling right the edge is 248 across the screen,
## scrolling left it is 7. A place the edge has just passed makes its
## enemy, at the edge, if one of the six slots is free. Nothing remembers
## that a place has made one already, and nothing is made while the screen
## is held for a fight or when it does not scroll.
func _follow_camera() -> void:
	var corner := _view_corner()
	var old := _camera_corner
	if corner.distance_to(old) > 64.0:
		_place_enemies()   # the view jumped (a door, a fall, the fly key): start afresh
		return
	if not flying and turtle._frame % Turtle.TICK_FRAMES != 0:
		return   # the turtle's frame: enemies are seen to on the other one
	_see_to_item_slots.call_deferred()   # after this update's enemies are made
	_camera_corner = corner
	var step := int(corner.x) - int(old.x)
	if step != 0 and not fighting:
		var edge := int(corner.x) + (SPAWN_RIGHT if step > 0 else SPAWN_LEFT)
		var edge_across := edge & 255
		var row := (int(corner.y) + (SPAWN_BOTTOM if corner.y >= old.y else SPAWN_TOP)) / VIEW_SIZE.y
		for spot in _screen_spots(edge >> 8, row):
			# How far the edge is past the place, counted round 256 as the
			# original does. Scrolling left the test is one short at each
			# end, so a place can be stepped over.
			var gap := (edge_across - (int(spot.position.x) & 255)) & 255
			var passed := gap < step if step > 0 else gap > (step & 255)
			if passed:
				var down := (int(spot.position.y) % VIEW_SIZE.y - int(corner.y) % VIEW_SIZE.y) & 255
				# It is put at the edge and then, like every object, moved back
				# by the scroll in its first update: so it ends a step short.
				_make_enemy(spot, Vector2(edge - step, int(corner.y) + down), true)
	# Things not run by the original's own code are taken off at the
	# screen's edge here; the others see to it themselves.
	for thing in enemies.get_children():
		if thing is Puff or thing is OriginalEnemy:
			continue
		var across: float = thing.position.x - corner.x
		var down: float = thing.position.y - corner.y
		if across < REMOVE_MARGIN or across >= VIEW_SIZE.x - REMOVE_MARGIN or down < REMOVE_MARGIN or down >= VIEW_SIZE.y:
			thing.queue_free()

## The floor kinds that act on the turtle (Research/shots_spawning_tiles.md).
## A moving floor (bank 4, $A4BF) adds its 1.25 pixels to the sideways
## speed his ground routine sets, so it moves him once an update, with his
## own step, and first on the second update after he lands (measured).
func _apply_floor_kinds() -> void:
	if turtle.state == Turtle.State.DEAD:
		return
	_floor_frame += 1
	var his_update := (turtle._frame + 1) % Turtle.TICK_FRAMES == 0   # his update comes later this frame
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
		elif (under == RoomData.KIND_MOVING_FLOOR or under == RoomData.KIND_MOVING_FLOOR_LEFT) and his_update and _stood_before:
			# Kind D carries him right and kind C left, 1.25 pixels an update,
			# unless a wall is on that side (9 ahead at 7 and 24 up, 6 ahead at 32 up).
			var way := 1.0 if under == RoomData.KIND_MOVING_FLOOR else -1.0
			if not (room.solid_at(x + way * 9.0, y - 7.0) or room.solid_at(x + way * 9.0, y - 24.0) or room.solid_at(x + way * 6.0, y - 32.0)):
				turtle.move_across(way * RoomData.MOVING_FLOOR_SPEED / 256.0)
	if his_update:
		_stood_before = turtle.on_floor()

## The bar shows the turtle's energy as 8 blocks, a part-used block still lit.
func _show_energy(energy: int, full: int) -> void:
	health_bar.set_health(ceili(energy * float(ENERGY_BLOCKS) / maxi(full, 1)), ENERGY_BLOCKS)
	if hud_strip != null:
		hud_strip.show_turtle(current_turtle, energy)
		overworld_energy.show_energy(energy)

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
	var left_over := _cells_left_over()
	load_area(world, target)
	OriginalEnemy.left_over = left_over
	_arrive(door.arrive, door.arrive_camera)

## The original keeps the map as cells in memory: sixteen columns, and
## rows that wrap every 480 pixels (two pages of 15 rows; bank 7, $C7C7). A
## one-screen room fills only its own twelve rows, so under it (and, round
## the wrap, just above it) an enemy's map tests find what the overworld
## left there: its cells 192 to 255 down the first page. Measured after
## two doors of world 1: under the building it is partly empty, and a kind
## 86 on that room's ceiling rises out of the room there. The columns are
## taken as those on the overworld's screen when the door was used (they
## were, in the two measured; otherwise a guess).
func _cells_left_over() -> PackedByteArray:
	var rows := PackedByteArray()
	if room == null or not room.top_down:
		return rows
	rows.resize(64)
	var left := int(overworld_screen.x)
	var middle := int(overworld_screen.y) + 120
	for row in 4:
		# The overworld row with this place in the cell memory, nearest the screen.
		var down := 192 + row * 16
		while down + 240 < middle:
			down += 480
		for column in 16:
			var across := ((left + 8) >> 4 << 4) + posmod(column * 16 - ((left + 8) >> 4 << 4), 256)
			rows[row * 16 + column] = room.kind_at((across >> 4) * 2, (down >> 4) * 2)
	return rows

## Arriving in a room through a door (bank 7, $E755 to $E837; checked for
## every door of world 1, Research/doors.md). The door's record gives his
## place on the screen and the screen's corner, and both are taken as they
## are: he is not stood on a floor and the screen is not centred on him.
## With ladder at his middle he hangs on it; over a floor he stands; in
## the air he falls. For his first 7 updates his speeds do not move him.
func _arrive(centre: Vector2, corner: Vector2) -> void:
	var feet := centre + Vector2(0, RoomData.CENTRE_TO_FEET)
	turtle.position = feet
	turtle.speed = Vector2i.ZERO
	turtle.put_screen(corner.x)
	_row_way = 0
	_screen_row = floori(corner.y / VIEW_SIZE.y)
	_view_top = _screen_row * VIEW_SIZE.y
	var at_middle := room.kind_at_pixel(centre.x, centre.y)
	turtle.arrive(at_middle == RoomData.KIND_LADDER or at_middle == RoomData.KIND_LADDER_SIDE, room.kind_at_pixel(feet.x, feet.y + 1.0) != RoomData.KIND_EMPTY)
	room.start = feet
	_place_camera()
	_place_enemies()   # the room comes up around the screen the door gives
	_boss_camera_x = _view_corner().x
	(turtle.get_node("Camera2D") as Camera2D).reset_smoothing()

## Stands the big turtle with his middle at `centre`, the screen centred on
## him as far as the room allows (study keys, tests; a door uses _arrive).
## He is put exactly there: the original never lifts him out of a floor.
func _place_turtle(centre: Vector2) -> void:
	var feet := centre + Vector2(0, RoomData.CENTRE_TO_FEET)
	turtle.position = feet
	turtle.speed = Vector2i.ZERO
	var at_middle := room.kind_at_pixel(centre.x, centre.y)
	if (at_middle == RoomData.KIND_LADDER or at_middle == RoomData.KIND_LADDER_SIDE) and not room.solid_at(feet.x, feet.y + 1.0):
		turtle.arrive(true, false)   # he hangs on a ladder
		turtle.hold_updates = 0
	room.start = feet
	_place_enemies()   # the view has moved to where he is
	(turtle.get_node("Camera2D") as Camera2D).reset_smoothing()

## Goes through a door as the player sees it in the original (measured,
## Research/overworld.md): the turtle is gone at once and the screen goes
## black; the other side is drawn in from the top, one row of tiles a
## frame; everything then stands still for 16 frames; and the turtle
## appears (in a room 7 frames after that, hanging on the ladder if that
## is where the door leaves him). There is no climbing picture at a
## manhole. `enter_door` alone changes sides at once, with none of this.
func use_door(door: Door) -> void:
	enter_door(door)
	if door_wipe and levels != null:
		_start_wipe()

func _start_wipe(world_begin := false) -> void:
	_wipe_world_begin = world_begin and room.top_down
	_wipe_frame = 0
	_wipe_rows = WIPE_ROWS_OVERWORLD if room.top_down else WIPE_ROWS_ROOM
	_wipe_cover.position = Vector2(0, _picture_top())
	_wipe_cover.size = Vector2(VIEW_SIZE.x, _picture_lines())
	_wipe_cover.visible = true
	turtle.visible = false
	walker.visible = false
	# The original shows nothing but the picture being drawn: no strip and
	# no energy sprites until the turtle is back.
	hud_strip.visible = false
	overworld_energy.visible = false
	for held: Node in [turtle, walker, enemies, items]:
		held.process_mode = Node.PROCESS_MODE_DISABLED

## Where the map's picture starts on the screen and how many lines it has.
func _picture_top() -> float:
	return float(ROOM_TOP_LINE) if original_layout() and not room.top_down else 0.0

func _picture_lines() -> float:
	if not original_layout():
		return float(VIEW_SIZE.y)
	return 240.0 if room.top_down else float(ROOM_LINES)

## Frames from the end of the hold to the turtle's being drawn (measured:
## 1 on the overworld; in a room 7 hanging on a ladder, 4 standing).
func wipe_appear_frames() -> int:
	if room.top_down:
		return WIPE_APPEAR_WORLD_BEGIN if _wipe_world_begin else WIPE_APPEAR_OVERWORLD
	return WIPE_APPEAR_ROOM if turtle.state == Turtle.State.CLIMB else WIPE_APPEAR_ROOM_STANDING

## Is a door's change of sides still being shown?
func wiping() -> bool:
	return _wipe_frame >= 0

func _step_wipe() -> void:
	_wipe_frame += 1
	var lines := _picture_lines()
	var drawn := minf((_wipe_frame - 1) * RoomData.TILE, lines)
	if _wipe_world_begin:
		# Measured: two frames later than after a door, and the rows end on
		# the map's own lines, which are 4 lower than the screen's.
		drawn = clampf((_wipe_frame - 3) * RoomData.TILE + ROOM_TOP_LINE, 0.0, lines)
	_wipe_cover.position.y = _picture_top() + drawn
	_wipe_cover.size.y = lines - drawn
	_wipe_cover.visible = drawn < lines
	if _wipe_world_begin and original_layout() and _wipe_frame == WIPE_WORLD_BEGIN_ENERGY_FROM:
		overworld_energy.show_energy(0)
		overworld_energy.visible = true
	if _wipe_frame < 1 + _wipe_rows + WIPE_HOLD_FRAMES + wipe_appear_frames():
		return
	_wipe_frame = -1
	_wipe_world_begin = false
	_wipe_cover.visible = false
	hud_strip.visible = original_layout() and not room.top_down
	overworld_energy.visible = original_layout() and room.top_down
	overworld_energy.show_energy(turtle.health)
	turtle.visible = not room.top_down
	walker.visible = room.top_down
	turtle.process_mode = Node.PROCESS_MODE_DISABLED if room.top_down else Node.PROCESS_MODE_INHERIT
	walker.process_mode = Node.PROCESS_MODE_INHERIT if room.top_down else Node.PROCESS_MODE_DISABLED
	enemies.process_mode = Node.PROCESS_MODE_INHERIT
	items.process_mode = Node.PROCESS_MODE_INHERIT
	walker.rest_frames = 0

## The door the big turtle is using right now, or null.
## Up at a doorway while standing, or climbing a ladder out of the top.
func _room_door_in_use() -> Door:
	if room == null or room.top_down or room.doors.is_empty():
		return null
	if not Input.is_action_pressed("move_up"):
		_wait_for_up_release = false
		_door_seen = false
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
		_door_seen = false
		return null   # the original tests the one point at his middle, 28 above his feet
	elif door_wipe:
		# A doorway is taken by his own routine: the update that finds Up at
		# a door only notes it, and the next one goes through (measured: 3
		# or 4 frames from the button, where a ladder's top takes 1).
		if (turtle._frame + 1) % Turtle.TICK_FRAMES != 0:
			return null
		if not _door_seen:
			_door_seen = true
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
	if _capture_frame >= 0:
		_step_capture()
	if _wipe_frame >= 0:
		_step_wipe()
		return
	_see_to_april()
	if not room.top_down:
		_show_special()
		if _enemies_frame():
			for star in thrown.get_children():
				if star is ThrownWeapon:
					star.update()
	if end_stage != EndStage.NONE and _step_world_end():
		_place_camera()
		return
	if flying:
		var mover: Node2D = walker if room.top_down else turtle
		mover.position += Input.get_vector("move_left", "move_right", "move_up", "move_down") * 4.0
		_settle_row()
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
	if _ledge_updates > 0:
		_step_ledge_scene()
		return
	var door := _room_door_in_use()
	if door != null:
		use_door(door)
		return
	if _row_way != 0:
		_step_row_change()
		_place_camera()
		return
	_check_row()
	_apply_floor_kinds()
	_place_camera()
	_run_clock()
	_check_boss()
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
	camera.position.y = _view_top + CAMERA_DOWN - turtle.position.y
	OriginalEnemy.screen_moved_to(floori(turtle.scroll_x))

func set_flying(on: bool) -> void:
	flying = on
	turtle.set_physics_process(not on)
	walker.set_physics_process(not on)
	turtle.speed = Vector2i.ZERO

## A turtle has run out of energy (Research/losing_a_turtle.md, measured).
## He shows his defeat pictures and is gone; 147 frames after the blow the
## Start screen comes up by itself, with him covered and "<name> GOT
## CAUGHT. WHO FIGHTS NEXT?". Start there carries on with the chosen
## turtle from the world's overworld start. If he was the last, GAME OVER
## comes up instead, then CONTINUE or END.
func _on_turtle_died() -> void:
	turtle_energy[current_turtle] = 0
	_capture_frame = 0
	if room != null and room.top_down:
		walker.show_caught()
		walker.process_mode = Node.PROCESS_MODE_DISABLED

func _step_capture() -> void:
	if turtle.state != Turtle.State.DEAD:
		_capture_frame = -1   # he was put back on his feet meanwhile (a test, a study key)
		return
	_capture_frame += 1
	if room != null and room.top_down and _capture_frame == CAPTURE_OVERWORLD_PICTURE_FRAMES:
		walker.visible = false
	if _capture_frame < CAPTURE_SCREEN_FRAMES:
		return
	_capture_frame = -1
	var caught := current_turtle
	var anyone := false
	for energy: int in turtle_energy:
		anyone = anyone or energy > 0
	if not anyone:
		continues_left -= 1
		game_over.open(continues_left)
		return
	var leftovers: Array = room.palettes.slice(6, 8) if room.palettes.size() >= 8 else []
	_after_capture = true
	start_screen.open({
		"world": world, "area": area, "inside": not room.top_down, "spot": overworld_spot,
		"energies": turtle_energy, "turtle": current_turtle, "sprite_colours": leftovers,
		"weapons": special_kind, "counts": special_counts_shown(), "caught": caught,
	})

## The forced Start screen has been left: on with the chosen turtle from
## the world's start (measured: the overworld's start, with the others'
## energy as it was).
func _on_start_screen_closed() -> void:
	if not _after_capture:
		return
	_after_capture = false
	_restart_world()

## CONTINUE: all four turtles back with full energy, from the world's
## start. END, or no continues left: the game begins again.
func _on_game_over_chosen(carry_on: bool) -> void:
	if not carry_on:
		Game.go_to(Game.SCENE_TITLE)   # END: back to the title, as the original
		return
	turtle_energy = [TURTLE_ENERGY, TURTLE_ENERGY, TURTLE_ENERGY, TURTLE_ENERGY]
	current_turtle = 0
	set_score(0)   # CONTINUE starts the score again; the best score stays
	rescued_one = false
	special_kind = [0, 0, 0, 0]
	special_count = [0, 0, 0, 0]
	special_in_use = false
	_show_turtle_look()
	if levels != null:
		turtle.weapon_swings = [levels.weapon_swing(0, 0), levels.weapon_swing(0, 1), levels.weapon_swing(0, 2)]
	_restart_world()

## Puts the playing turtle on his feet with his own energy at the start of
## the world: its overworld with a ROM, the stand-in room without.
func _restart_world() -> void:
	var energy := int(turtle_energy[current_turtle])
	turtle.revive()
	turtle.health = energy
	turtle.health_changed.emit(turtle.health, turtle.max_health)
	walker.safe_updates = 0
	if levels != null and levels.has_overworld(world):
		load_overworld(world)
		if door_wipe:
			_start_wipe(true)   # the same "begin the world" step as at a world's start
	else:
		load_area(world, 0 if levels != null else area)


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
	elif event.is_action_pressed("select"):
		press_select()
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
	elif event.is_action_pressed("toggle_help"):
		set_help_text(not show_help_text)
	elif event.is_action_pressed("toggle_fly"):
		set_flying(not flying)
