extends Node
## Headless self-test. Run with run_tests.bat, or:
##   godot --headless --path . res://Tests/RunTests.tscn
## It builds a fake ROM in memory (no real game data) and checks the ROM
## reader and the tile ripper against it.

var failures := 0

func check(condition: bool, what: String) -> void:
	if condition:
		print("  ok    ", what)
	else:
		failures += 1
		printerr("  FAIL  ", what)

func fake_rom(mapper: int, prg_units: int, chr_units: int) -> PackedByteArray:
	var rom := PackedByteArray([0x4E, 0x45, 0x53, 0x1A, prg_units, chr_units, (mapper & 0x0F) << 4, mapper & 0xF0])
	rom.resize(16 + prg_units * 16384 + chr_units * 8192)
	return rom

func same(a: Color, b: Color) -> bool:
	return a.to_rgba32() == b.to_rgba32()

func _ready() -> void:
	print("ROM reader")
	var rom := fake_rom(1, 8, 16)
	var chr_start := 16 + 8 * 16384
	# Tile 300: top row = colours 1,2,3,0,0,0,0,0
	rom[chr_start + 300 * 16] = 0b10100000
	rom[chr_start + 300 * 16 + 8] = 0b01100000
	var info := RomInfo.inspect_bytes(rom)
	check(info.ok_header, "accepts a well-formed header")
	check(info.mapper == 1 and info.prg_units == 8 and info.chr_units == 16, "reads mapper and sizes")
	check(info.shape_matches and info.accepted, "TMNT-shaped ROM is accepted")
	check(info.known_name == "", "fake ROM is not reported as verified")
	check(info.sha1.length() == 40, "produces a SHA-1 fingerprint")
	check(info.chr_rom.size() == 131072, "finds 128 KB of graphics")
	check(not RomInfo.inspect_bytes(fake_rom(0, 2, 1)).accepted, "rejects an SMB1-shaped ROM")
	check(not RomInfo.inspect_bytes(PackedByteArray([1, 2, 3])).accepted, "rejects a non-NES file")
	check(not RomInfo.inspect_bytes(rom.slice(0, 5000)).accepted, "rejects a truncated file")
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update("abc".to_utf8_buffer())
	check(ctx.finish().hex_encode() == "a9993e364706816aba3e25717850c26c9cd0d89d", "SHA-1 matches the standard test value")

	print("Tile ripper")
	var ripper := ChrRipper.new(info.chr_rom)
	check(ripper.tile_count() == 8192 and ripper.bank_count() == 32, "8192 tiles in 32 banks")
	var px := ripper.tile_pixels(300)
	check(px[0] == 1 and px[1] == 2 and px[2] == 3 and px[3] == 0, "decodes the two bitplanes")
	var image := ripper.bank_image(1)
	check(image.get_size() == Vector2i(128, 128), "bank sheet is 128x128")
	# tile 300 = bank 1, tile 44 -> column 12, row 2
	check(same(image.get_pixel(96, 16), ChrRipper.PREVIEW_PALETTE[1]), "tile lands in the right cell")
	var sprite := ripper.build_sprite({"size": [8, 8], "tiles": [{"x": 0, "y": 0, "index": 300, "flip_h": true}]})
	check(same(sprite.get_pixel(7, 0), ChrRipper.PREVIEW_PALETTE[1]), "horizontal flip works")

	print("Sprite maps")
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/AssetRipper/Sprites/Leonardo.json"))
	var sprite_set := SpriteSet.build(map, ripper)
	check(sprite_set.textures.size() == 18, "Leonardo's map builds 18 frames")
	check(sprite_set.textures["stand"].get_size() == Vector2(16, 48), "standing frame is 16x48 pixels")
	check(sprite_set.offsets["stand"] == Vector2(-8, -48), "standing frame sits on the feet point")
	var all_found := true
	for anim_name: String in sprite_set.animations:
		for frame_name: String in sprite_set.animations[anim_name].frames:
			all_found = all_found and sprite_set.textures.has(frame_name)
	check(all_found, "every animation frame exists")
	check(sprite_set.frame_at("walk", 0) == "walk1" and sprite_set.frame_at("walk", 6) == "stand" and sprite_set.frame_at("walk", 24) == "walk1", "walk cycle steps every 6 updates and loops")
	check(sprite_set.frame_at("attack", 99) == "attack3" and sprite_set.length("attack") == 6, "attack lasts 6 updates and holds its last frame")
	var highest_tile := 0
	for frame_name: String in map.frames:
		for tile: Dictionary in map.frames[frame_name]:
			highest_tile = maxi(highest_tile, int(tile.index) + 1)
	check(highest_tile < ripper.tile_count(), "every tile number is inside the ROM's graphics")

	print("Scenes")
	for path: String in ["res://Scenes/Boot.tscn", "res://Scenes/UI/RomSelect.tscn",
			"res://Scenes/Tools/ChrViewer.tscn", "res://Scenes/Player/Turtle.tscn", "res://Scenes/Levels/TestRoom.tscn"]:
		var scene: PackedScene = load(path)
		check(scene != null and scene.can_instantiate(), "loads " + path)
	var room: Node = load("res://Scenes/Levels/TestRoom.tscn").instantiate()
	add_child(room)
	var turtle: Turtle = room.get_node("Turtle")
	turtle.position = Vector2(40, 150)
	for i in 90:
		await get_tree().physics_frame
	check(turtle.on_floor() and absf(turtle.position.y - 208.0) < 1.0, "turtle falls and lands on the floor")
	check(InputMap.has_action("jump") and InputMap.has_action("attack"), "key bindings are registered")
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	pad_a.device = 3
	pad_a.pressed = true
	var pad_x := InputEventJoypadButton.new()
	pad_x.button_index = JOY_BUTTON_X
	pad_x.pressed = true
	var pad_start := InputEventJoypadButton.new()
	pad_start.button_index = JOY_BUTTON_START
	pad_start.pressed = true
	var pad_left := InputEventJoypadButton.new()
	pad_left.button_index = JOY_BUTTON_DPAD_LEFT
	pad_left.pressed = true
	check(pad_a.is_action("jump") and pad_x.is_action("attack") and pad_start.is_action("pause") and pad_left.is_action("move_left"), "a controller works with no setup: A jumps, X attacks, Start pauses, the d-pad moves (on any controller number)")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.9
	var nudge := InputEventJoypadMotion.new()
	nudge.axis = JOY_AXIS_LEFT_X
	nudge.axis_value = 0.3
	check(stick.is_action_pressed("move_right") and not stick.is_action_pressed("move_left") and not nudge.is_action_pressed("move_right"), "the left stick moves too, once pushed past half way")

	print("Movement copied from the original")
	room.get_node("DummyEnemy").set_physics_process(false)
	room.get_node("DummyEnemy").position.x = 480.0
	turtle.position = Vector2(60, 208)
	for i in 10:
		await get_tree().physics_frame
	var x0 := turtle.position.x
	Input.action_press("move_right")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("move_right")
	check(absf((turtle.position.x - x0) - 67.5) <= 2.25, "walks 67.5 pixels in a second (got %.2f)" % (turtle.position.x - x0))
	for hold: Array in [[4, 33.0, "low"], [12, 57.5, "medium"], [40, 97.0, "high"]]:
		turtle.position = Vector2(256, 208)
		for i in 10:
			await get_tree().physics_frame
		var top := turtle.position.y
		Input.action_press("jump")
		for i in 140:
			if i == hold[0]:
				Input.action_release("jump")
			await get_tree().physics_frame
			top = minf(top, turtle.position.y)
		check(absf((208.0 - top) - hold[1]) <= 1.5 and turtle.on_floor(),
			"%s jump rises %.1f pixels (got %.2f)" % [hold[2], hold[1], 208.0 - top])
	room.get_node("DummyEnemy").position.x = 240.0
	room.get_node("DummyEnemy").set_physics_process(true)
	turtle.revive()
	turtle.position = Vector2(60, 208)

	print("Combat")
	var enemy: DummyEnemy = room.get_node("DummyEnemy")
	enemy.speed = 0.0
	# Stand just left of the enemy, facing right, and swing once.
	turtle.position = Vector2(enemy.position.x - 22.0, 208.0)
	for i in 5:
		await get_tree().physics_frame
	check(turtle.health == turtle.max_health, "standing next to the enemy does not hurt")
	Input.action_press("attack")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("attack")
	for i in 20:
		await get_tree().physics_frame
	check(enemy.health == enemy.max_health - 1, "one swing takes one point off the enemy")
	# Crouch
	Input.action_press("move_down")
	for i in 3:
		await get_tree().physics_frame
	check(turtle.state == Turtle.State.CROUCH, "holding down crouches")
	Input.action_release("move_down")
	for i in 3:
		await get_tree().physics_frame
	# Walk into the enemy.
	turtle.position = Vector2(enemy.position.x - 4.0, 208.0)
	for i in 6:
		await get_tree().physics_frame
	check(turtle.health == turtle.max_health - 1, "touching the enemy costs one health")
	check(turtle.position.x < enemy.position.x - 4.0, "the hit knocks the turtle away")
	for i in 30:
		await get_tree().physics_frame
	check(turtle.health == turtle.max_health - 1, "no second hit while blinking")
	turtle.invulnerable_timer = 0.0
	turtle.take_damage(99)
	check(turtle.state == Turtle.State.DEAD and turtle.health == 0, "health cannot go below zero")
	turtle.revive()
	check(turtle.health == turtle.max_health and turtle.state == Turtle.State.NORMAL, "revive restores full health")

	print("Rooms and ladders")
	room.free()
	var sewer: Node = load("res://Scenes/Levels/Area1Sewer.tscn").instantiate()
	add_child(sewer)
	sewer.show_enemies = false   # the movement and door tests want empty rooms
	# Use the hand-drawn stand-in so these tests behave the same with or without a ROM.
	var data := RoomData.from_text(sewer.STAND_IN)
	data.start = Vector2(40, 96)
	sewer.show_room(data)
	check(data.cols == 32 and data.rows == 24, "stand-in room is 32 x 24 tiles")
	check(data.solid_at(100, 180) and not data.solid_at(100, 150), "floor is solid, air is not")
	check(data.ladder_center_at(148, 120) == 152.0 and is_nan(data.ladder_center_at(100, 120)), "finds the ladder's centre line")
	var solid_cells := 0
	for r in data.rows:
		for c in data.cols:
			solid_cells += 1 if data.is_solid_cell(c, r) else 0
	var rect_area := 0
	for rect in data.solid_rects():
		rect_area += rect.get_area()
	check(rect_area == solid_cells * 64 and data.solid_rects().size() < 12, "solid blocks merge into %d rectangles covering every solid tile" % data.solid_rects().size())
	check(data.ladder_tops().has(Rect2i(144, 96, 16, 8)), "ladder through the ledge gets a climb-through top")
	check(data.find_spawn() == Vector2(24, 96), "finds a place to stand")
	var leo: Turtle = sewer.get_node("Turtle")
	for i in 20:
		await get_tree().physics_frame
	check(leo.on_floor() and floorf(leo.position.y) == 96.0, "turtle starts standing on the upper ledge")
	leo.position.x = 150.0
	for i in 6:
		await get_tree().physics_frame
	check(leo.on_floor() and floorf(leo.position.y) == 96.0, "he can stand on the ladder top")
	Input.action_press("move_down")
	for i in 6:
		await get_tree().physics_frame
	check(leo.state == Turtle.State.CLIMB and leo.position.x == 150.0, "Down grabs the ladder under him and leaves him where he stands on it")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release("move_down")
	for i in 6:
		await get_tree().physics_frame
	check(leo.state != Turtle.State.CLIMB and floorf(leo.position.y) == 176.0 and leo.on_floor(), "climbing down ends on the floor")
	Input.action_press("move_up")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release("move_up")
	for i in 6:
		await get_tree().physics_frame
	check(leo.state != Turtle.State.CLIMB and floorf(leo.position.y) == 97.0 and leo.on_floor(), "climbing up ends back on the ledge, 1 pixel into the ladder's top as in the original")
	Input.action_press("move_down")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("move_down")
	var held_at := leo.position
	Input.action_press("jump")
	for i in 8:
		await get_tree().physics_frame
	Input.action_release("jump")
	check(leo.state == Turtle.State.CLIMB and leo.position == held_at, "jump does nothing on a ladder")
	Input.action_press("move_right")
	for i in 4:
		await get_tree().physics_frame
	var let_go := leo.state != Turtle.State.CLIMB and not leo.on_floor()
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("move_right")
	check(let_go and floorf(leo.position.y) == 176.0 and leo.position.x > 160.0, "pressing sideways with room beside the ladder lets go: he drops and steers that way")
	leo.position = Vector2(150, 176)
	for i in 6:
		await get_tree().physics_frame
	leo.position = Vector2(150, 150)
	leo.grounded = false
	leo._was_grounded = false
	leo.speed = Vector2i.ZERO
	Input.action_press("move_up")
	for i in 3:
		await get_tree().physics_frame
	var grabbed_in_air := leo.state == Turtle.State.CLIMB
	Input.action_release("move_up")
	for i in 40:
		await get_tree().physics_frame
	check(not grabbed_in_air, "a ladder cannot be taken in mid-air, only from the ground")
	leo.position = Vector2(40, 96)
	leo.speed = Vector2i.ZERO
	for i in 6:
		await get_tree().physics_frame
	sewer.set_flying(true)
	Input.action_press("move_up")
	for i in 10:
		await get_tree().physics_frame
	Input.action_release("move_up")
	check(absf(leo.position.y - 56.0) < 0.5, "fly mode moves him freely")
	sewer.set_flying(false)

	print("The turtle against walls, ledges and ceilings, by the original's rules")
	leo.position = Vector2(40, 96)
	leo.speed = Vector2i.ZERO
	for i in 6:
		await get_tree().physics_frame
	Input.action_press("move_right")
	var dropped_at := 0.0
	for i in 60:
		await get_tree().physics_frame
		if leo.position.y > 96.0 and dropped_at == 0.0:
			dropped_at = leo.position.x
	check(dropped_at >= 74.0 and dropped_at < 84.0, "walking, he drops two updates after both feet (6 pixels each side) are past a ledge's end (the ledge ends at 64; he dropped at %.2f)" % dropped_at)
	Input.action_release("move_right")
	for i in 30:
		await get_tree().physics_frame
	leo.position = Vector2(107, 97.5)
	leo.grounded = false
	leo._was_grounded = false
	leo.speed = Vector2i.ZERO
	Input.action_press("move_right")
	for i in 16:
		await get_tree().physics_frame
	check(floorf(leo.position.y) == 96.0 and leo.position.x > 112.0 and leo.on_floor(), "falling beside a ledge with his feet 2 pixels below its top, he goes in and is put on top")
	Input.action_release("move_right")
	for i in 4:
		await get_tree().physics_frame
	leo.position = Vector2(100, 100)
	leo.grounded = false
	leo._was_grounded = false
	leo.speed = Vector2i.ZERO
	Input.action_press("move_right")
	var got_on := false
	for i in 60:
		await get_tree().physics_frame
		got_on = got_on or floorf(leo.position.y) == 96.0
	check(floorf(leo.position.y) == 176.0 and not got_on, "4 pixels below, its side stops him and he falls past")
	Input.action_release("move_right")
	leo.position = Vector2(40, 176)
	leo.speed = Vector2i.ZERO
	for i in 6:
		await get_tree().physics_frame
	Input.action_press("jump")
	var under_ledge := 1000.0
	for i in 70:
		await get_tree().physics_frame
		under_ledge = minf(under_ledge, leo.position.y)
	Input.action_release("jump")
	check(under_ledge >= 129.0 and under_ledge < 137.0, "jumping under a ledge he stops once the point 32 above his feet is inside it (%.1f; its underside is at 104)" % under_ledge)
	for i in 30:
		await get_tree().physics_frame
	leo.position = Vector2(100, 150)
	leo.grounded = false
	leo._was_grounded = false
	leo.speed = Vector2i(0, 1200)
	Input.action_press("move_right")
	var landed_on := 0
	var landing_x := -1.0
	var before_landing_x := -1.0
	var after_landing_x := -1.0
	for i in 40:
		var before_x := leo.position.x
		var was_up := not leo.on_floor()
		await get_tree().physics_frame
		if landing_x >= 0.0 and after_landing_x < 0.0 and Engine.get_physics_frames() % 2 == landed_on % 2:
			after_landing_x = leo.position.x
		if was_up and leo.on_floor():
			landing_x = leo.position.x
			before_landing_x = before_x
			landed_on = Engine.get_physics_frames()
	Input.action_release("move_right")
	check(landing_x > before_landing_x and after_landing_x == landing_x and leo.position.x > landing_x and leo.speed.y == 0, "he still moves sideways on the update he lands, stands for the next one, then walks on (as the original does)")
	for i in 10:
		await get_tree().physics_frame

	print("Floor kinds")
	check(data.is_solid_cell(10, 22) and RoomData.KIND_DEADLY == 15, "ordinary floor is solid")
	leo.position = Vector2(100, 176)
	for i in 10:
		await get_tree().physics_frame
	var floor_cell := 22 * data.cols + 12        # the cell under his feet
	data.kinds[floor_cell] = RoomData.KIND_MOVING_FLOOR
	var carried_from := leo.position.x
	for i in 4:
		await get_tree().physics_frame
	check(data.is_solid_cell(12, 22) and absf(leo.position.x - carried_from - 2.5) < 0.01, "a moving floor is solid and carries him 1.25 pixels an update")
	data.kinds[floor_cell] = RoomData.KIND_MOVING_FLOOR_LEFT
	carried_from = leo.position.x
	for i in 4:
		await get_tree().physics_frame
	check(data.is_solid_cell(12, 22) and absf(leo.position.x - carried_from + 2.5) < 0.01, "kind C is a floor too, and carries him the other way")
	data.kinds[floor_cell] = RoomData.KIND_SOLID
	leo.position.x = 100.0
	leo.health = 128
	data.kinds[floor_cell] = RoomData.KIND_DEADLY
	for i in 4:
		await get_tree().physics_frame
	check(leo.health == 96, "a deadly floor takes 16 energy every update, with no safe time (%d)" % leo.health)
	data.kinds[floor_cell] = RoomData.KIND_SOLID
	leo.health = 128
	leo.invulnerable_timer = 0.0
	data.kinds[19 * data.cols + 12] = RoomData.KIND_HURTS   # a cell his body is in, but none of his tests look at
	for i in 4:
		await get_tree().physics_frame
	check(leo.health == 128, "a hurting tile only hurts where the original's tests look: not at his chest while he stands")
	data.kinds[19 * data.cols + 12] = RoomData.KIND_EMPTY
	data.kinds[21 * data.cols + 12] = RoomData.KIND_HURTS   # 3 above his feet: the standing test looks here
	var hurt_state: int = leo.state
	for i in 4:
		await get_tree().physics_frame
	check(not data.is_solid_cell(12, 21) and leo.health == 112 and leo.invulnerable_timer > 0.0 and leo.state == hurt_state and leo.speed == Vector2i.ZERO, "a hurting tile at his ankles takes 16 once, he blinks, and he is not thrown")
	data.kinds[21 * data.cols + 12] = RoomData.KIND_EMPTY
	data.kinds[20 * data.cols + 12] = RoomData.KIND_EMPTY
	leo.revive()
	leo.health = 40
	var slice := Item.new()
	slice.setup(Item.SLICE, Vector2(0, 0), null)
	add_child(slice)
	slice.pick_up(leo)
	check(leo.health == 72 and slice.is_queued_for_deletion(), "a slice of pizza gives 32 energy and is gone")
	var pie := Item.new()
	pie.setup(Item.WHOLE_PIZZA, Vector2(0, 0), null)
	add_child(pie)
	pie.pick_up(leo)
	check(leo.health == 128, "a whole pizza fills his energy")
	leo.health = 40
	var half := Item.new()
	half.setup(Item.HALF_PIZZA, Vector2(0, 0), null)
	add_child(half)
	half.pick_up(leo)
	check(leo.health == 104, "half a pizza (kind 02) gives 64 energy")
	# The power item, the enemies' safe time and which shots a hit uses up
	leo.position = Vector2(100, 176)
	leo.speed = Vector2i.ZERO
	leo.invulnerable_timer = 0.0
	for i in 6:
		await get_tree().physics_frame
	var power := Item.new()
	power.setup(Item.POWER, Vector2(0, 0), null)
	add_child(power)
	power.pick_up(leo)
	check(leo.power_ticks == Turtle.POWER_UPDATES and Turtle.POWER_UPDATES == 256, "kind 0B starts the power item: 256 updates")
	var energy_before := leo.health
	var landed := leo.take_damage(10, 0.0)
	check(not landed and leo.health == energy_before and leo.state == Turtle.State.NORMAL, "nothing that touches him hurts him meanwhile")
	Input.action_press("move_right")
	Input.action_press("attack")
	for i in 4:
		await get_tree().physics_frame
	Input.action_release("attack")
	check(leo.speed.x == 768 and leo.attack_tick < 0, "he walks at 3 pixels an update and cannot swing")
	Input.action_release("move_right")
	var toucher: DummyEnemy = load("res://Scenes/Enemies/DummyEnemy.tscn").instantiate()
	add_child(toucher)
	toucher.set_physics_process(false)
	toucher.health = 200
	leo.touched_by(toucher, 5)
	check(toucher.health == 200 - Turtle.POWER_DAMAGE or toucher.is_queued_for_deletion(), "an enemy that touches him is hit for 240 instead")
	check(leo.health == energy_before, "and he loses nothing")
	leo.power_ticks = 2
	for i in 6:
		await get_tree().physics_frame
	check(leo.power_ticks == 0 and leo.art.visible, "the power item runs out")
	var target := Node2D.new()
	add_child(target)
	var first_hit := Turtle.weapon_lands(target)
	var second_hit := Turtle.weapon_lands(target)
	target.set_meta("safe_until", Engine.get_physics_frames())
	var later_hit := Turtle.weapon_lands(target)
	check(first_hit and not second_hit and later_hit and Turtle.ENEMY_SAFE_UPDATES == 24, "an enemy that was hit cannot be hit again for 24 updates")
	target.queue_free()
	check(Shot.USED_UP_BY_A_HIT == [0x99, 0x93], "only shots of kinds 99 and 93 are used up by hitting him")
	leo.invulnerable_timer = 0.0
	leo.health = 128
	check(leo.take_damage(1, 0.0) and not leo.take_damage(1, 0.0), "a hit tells the shot whether it landed (not while he blinks)")
	leo.revive()
	leo.health = 128
	leo.invulnerable_timer = 0.0
	leo.speed = Vector2i.ZERO
	leo.state = Turtle.State.NORMAL
	leo.position = Vector2(40, 96)
	for i in 30:
		await get_tree().physics_frame

	print("Doors and the overworld")
	# A made-up door table in an otherwise empty ROM: two lists, the first
	# with no end marker (one list in the real ROM is like that).
	var door_prg := PackedByteArray()
	door_prg.resize(8 * 16384)
	var put := func(address: int, bytes: Array) -> void:
		for i in bytes.size():
			door_prg[7 * 0x4000 + (address & 0x3FFF) + i] = bytes[i]
	for i in 7:
		put.call(RomLevels.T_DOORS + i * 2, [0x60, 0xE8])
	put.call(0xE860, [0x64, 0xE8, 0x6F, 0xE8])
	put.call(0xE864, [1, 0x28, 0x18, 0, 2, 0x80, 0x78, 0x00, 0x10, 0x00, 0xB0])
	put.call(0xE86F, [0, 0x30, 0x90, 1, 5, 0x2C, 0x8C, 0x01, 0x00, 0x00, 0xC0, 0xFF])
	var door_reader := RomLevels.new(door_prg)
	var door_room := RoomData.new()
	door_room.screens_wide = 2
	door_room.doors = door_reader._door_list(0xE860, 0, door_room)
	check(door_room.doors.size() == 1, "a door list with no end marker stops where the next list starts")
	var out_door: Door = door_room.doors[0]
	check(out_door.position == Vector2(296, 24) and not out_door.to_room and out_door.to_area == 2 and out_door.arrive == Vector2(144, 296), "reads a door's place and where it leads")
	var in_doors := door_reader._door_list(0xE860, 1, door_room)
	check(in_doors.size() == 1 and in_doors[0].to_room and in_doors[0].to_area == 5 and in_doors[0].arrive == Vector2(300, 332), "reads a door into a room, camera position included")
	check(door_reader._door_list(0xE860, 2, door_room).is_empty(), "a room past the end of the table has no doors")
	check(door_room.door_at(Vector2(316, 40)) == out_door, "a door answers within 32 pixels of its spot")
	check(door_room.door_at(Vector2(329, 24)) == null and door_room.door_at(Vector2(250, 24)) == null, "but not from further away, or from the next screen")
	var town := RoomData.from_text([
		"################",
		"#..............#",
		"#..............#",
		"#..............#",
		"#..............#",
		"################",
	], "Test overworld")
	town.top_down = true
	town.screen_size = Vector2i(256, 256)
	town.kinds[3 * town.cols + 3] = RoomData.KIND_DOOR
	var manhole := Door.new()
	manhole.position = Vector2(28, 28)
	manhole.to_room = true
	town.doors = [manhole]
	var walker := OverworldTurtle.new()
	add_child(walker)
	walker.set_physics_process(false)
	walker.room = town
	var reached: Array[Door] = []
	walker.door_reached.connect(func(d: Door) -> void: reached.append(d))
	walker.position = Vector2(12, 12)
	walker.step(Vector2i.LEFT)
	check(walker.position == Vector2(12, 12), "overworld turtle is stopped by a wall")
	walker.step(Vector2i.UP)
	walker.step(Vector2i.UP)
	check(walker.position == Vector2(12, 10), "he moves 2 pixels a step until the wall")
	walker.position = Vector2(44, 26)
	for i in 3:
		walker.step(Vector2i.LEFT)
	check(walker.position == Vector2(38, 26) and reached.is_empty(), "he walks up to the manhole")
	walker.step(Vector2i.LEFT)
	check(reached == [manhole] and walker.position == Vector2(38, 26), "stepping onto the manhole uses it")
	walker.free()
	check(town.door_cell_near(Vector2(36, 28)) and not town.door_cell_near(Vector2(48, 28)), "a doorway counts as in front of him within 8 pixels")

	print("Enemy places")
	# A made-up placement table: one room of two screens, two enemy line-ups.
	var foe_prg := PackedByteArray()
	foe_prg.resize(8 * 16384)
	var put6 := func(address: int, bytes: Array) -> void:
		for i in bytes.size():
			foe_prg[6 * 0x4000 + (address & 0x3FFF) + i] = bytes[i]
	put6.call(0x9010, [0x20, 0x90, 0x30, 0x90])                       # one list per screen
	put6.call(0x9020, [0x40, 0xB4, 0x80, 0xE0, 0x64, 0x89, 0xFF])     # screen 0: slots 0 and 1
	put6.call(0x9030, [0x10, 0x20, 0x92, 0xFF])                       # screen 1: slot 2
	put6.call(RomLevels.T_ENEMY_KINDS, [0x00, 0x92, 0x08, 0x92])      # line-ups 0 and 1
	put6.call(0x9200, [0x8D, 0x81, 0x05])
	put6.call(0x9208, [0x86, 0x86, 0x4B])
	put6.call(RomLevels.T_KIND_INFO_HIGH + 0x0D * 2, [4, 1])
	put6.call(RomLevels.T_KIND_INFO_HIGH + 0x01 * 2, [9, 2])
	put6.call(RomLevels.T_KIND_INFO_LOW + 0x05 * 2, [30, 7])
	put6.call(RomLevels.T_WEAPON_DAMAGE, [7, 10, 9, 9])
	var foe_reader := RomLevels.new(foe_prg)
	var foe_room := RoomData.new()
	foe_room.screens_wide = 2
	foe_room.cols = 64
	foe_room.rows = 24
	var spots := foe_reader._enemy_spots(0x9010, foe_room, PackedInt32Array([0, 1, 1, 99]))
	check(spots.size() == 3, "reads the enemy places of both screens")
	check(spots[0].position == Vector2(64, 180) and spots[0].kind == 0x8D and spots[0].hit_points == 4 and spots[0].first_animation == 1, "first place: position, kind and hit points")
	check(spots[1].slot == 1 and spots[1].kind == 0x81 and spots[1].hit_points == 9, "the slot picks the kind from the room's line-up")
	check(spots[2].position == Vector2(272, 32) and spots[2].kind == 0x05 and spots[2].hit_points == 30, "second screen is 256 pixels along; low kind numbers use the other table")
	check(Array(spots[0].kinds) == [0x8D, 0x86, 0x86, -1], "keeps the kind for each of the 4 line-ups (-1 where the number is out of range)")
	check(foe_reader.weapon_damage(0) == Vector2i(7, 10) and foe_reader.weapon_damage(1) == Vector2i(9, 9), "reads weapon damage per turtle")
	var foe: DummyEnemy = load("res://Scenes/Enemies/DummyEnemy.tscn").instantiate()
	add_child(foe)
	foe.show_as_spot(spots[0])
	foe.weapon_damage = 3
	check(foe.position == Vector2(64, 180) and foe.health == 4 and foe.speed == 0.0, "a stand-in enemy takes the place and hit points")
	var pit := RoomData.from_text([
		"#..............#",
		"#..............#",
		"#..............#",
		"######....######",
		"#..............#",
		"################",
	], "Crawler test")
	var crawler := Crawler.new()
	var crawler_spot := EnemySpot.new()
	crawler_spot.position = Vector2(24, 28)
	crawler_spot.hit_points = 4
	crawler_spot.touch_damage = 7
	crawler.setup(crawler_spot, pit, null)
	add_child(crawler)
	crawler.set_physics_process(false)
	crawler.direction = -1
	crawler.tick()
	crawler.tick()
	check(crawler.direction == 1 and crawler.position.y == 28.0, "a crawler turns round at a wall")
	for i in 40:
		crawler.tick()
	check(crawler.position.y == 44.0 and not crawler.falling, "it walks off a ledge, falls and lands 4 pixels into the floor below")
	crawler.take_hit(7)
	check(crawler.is_queued_for_deletion(), "one sword hit finishes a 4-point crawler")
	var yard := RoomData.from_text([
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"################################",
	], "Soldier test")
	var victim := Node2D.new()
	add_child(victim)
	victim.position = Vector2(200, 56)       # the turtle's feet, on the floor
	var leaper_spot := EnemySpot.new()
	leaper_spot.position = Vector2(60, 56)   # on top of the floor, 140 pixels from the turtle
	leaper_spot.hit_points = 24
	leaper_spot.touch_damage = 16
	var leaper := Leaper.new()
	leaper.setup(leaper_spot, yard, null, victim)
	add_child(leaper)
	leaper.set_physics_process(false)
	check(leaper.position.y == 59.0, "a leaper settles 3 pixels into the floor it is placed on")
	var leapt_from := 0.0
	var leap_top := 1000.0
	var leap_ticks := 0
	for i in 140:
		var was_in_air: bool = leaper.in_air
		leaper.tick()
		if leaper.in_air and not was_in_air:
			leapt_from = victim.position.x - (leaper.position.x - 1.75)
		if leaper.in_air:
			leap_top = minf(leap_top, leaper.position.y)
			leap_ticks += 1
	check(leapt_from <= 37.0 and leapt_from > 35.0, "it walks 1.75 pixels an update and leaps from 37 pixels away (%.2f)" % leapt_from)
	check(absf((59.0 - leap_top) - 25.5) < 0.6 and leap_ticks == 33 and not leaper.in_air and leaper.position.y == 59.0, "the leap rises 26 pixels and lasts 34 updates, as recorded (%.1f, %d)" % [59.0 - leap_top, leap_ticks + 1])
	var rested_at := leaper.position.x
	for i in 30:
		leaper.tick()
	check(leaper.position.x == rested_at and not leaper.in_air, "next to the turtle it stays put until he moves away")
	leaper.free()
	var hopper_spot := EnemySpot.new()
	hopper_spot.kind = 0x9D
	hopper_spot.position = Vector2(120, 56)
	var hopper := Leaper.new()
	hopper.setup(hopper_spot, yard, null, victim)
	add_child(hopper)
	hopper.set_physics_process(false)
	var hop_ends: Array[float] = []
	for i in 160:
		var was_up: bool = hopper.in_air
		hopper.tick()
		if was_up and not hopper.in_air:
			hop_ends.append(hopper.position.x)
	check(hop_ends.size() == 3 and hop_ends[0] == 184.0 and hop_ends[1] == 120.0 and hop_ends[2] == 184.0, "kind 9D hops 64 pixels towards the turtle, rests, and hops 64 back, as recorded (%s)" % str(hop_ends))
	hopper.free()
	var walker_spot := EnemySpot.new()
	walker_spot.kind = 0x49
	walker_spot.position = Vector2(60, 56)
	var plain := LegacyWalker.new()
	plain.setup(walker_spot, yard, null, victim)
	add_child(plain)
	plain.set_physics_process(false)
	var plain_attacked := false
	for i in 220:
		plain.tick()
		plain_attacked = plain_attacked or plain.state == LegacyWalker.State.KICK or plain.state == LegacyWalker.State.PUNCH or plain.state == LegacyWalker.State.AIR
	check(absf(victim.position.x - plain.position.x) <= 16.0 and absf(victim.position.x - plain.position.x) > 15.0 and not plain_attacked, "kind 49 walks 1 pixel an update up to 16 pixels from him and stands, with no hop or attack")
	plain.free()
	var charger_spot := EnemySpot.new()
	charger_spot.position = Vector2(60, 56)
	victim.position.x = 150.0                 # leaves room for the charge to finish
	var charger := Charger.new()
	charger.setup(charger_spot, yard, null, victim)
	add_child(charger)
	charger.set_physics_process(false)
	var charge_from := 0.0
	var charge_to := 0.0
	for i in 200:
		var was_charging: bool = charger.state == Charger.State.CHARGE
		charger.tick()
		if charger.state == Charger.State.CHARGE and not was_charging and charge_from == 0.0:
			charge_from = charger.position.x
		if was_charging and charger.state != Charger.State.CHARGE and charge_to == 0.0:
			charge_to = charger.position.x
	check(victim.position.x - charge_from <= 31.0 and victim.position.x - charge_from > 29.0, "kind A0 walks to 31 pixels from him before it charges (%.2f)" % (victim.position.x - charge_from))
	check(charge_to - charge_from == 81.0 and charge_to > victim.position.x, "the charge covers 81 pixels and carries it past him")
	charger.free()
	victim.position.x = 200.0
	var lift_spot := EnemySpot.new()
	lift_spot.kind = 0x88
	lift_spot.position = Vector2(100, 48)
	var lift := PathEnemy.new()
	lift.setup(lift_spot, null)
	add_child(lift)
	lift.set_physics_process(false)
	var lift_ys: Array[float] = []
	for count in [48, 2 + 32, 5 + 3, 6 + 7, 3 + 42, 2 + 32]:
		for i in count:
			lift.tick()
		lift_ys.append(lift.position.y)
	check(lift_ys == [144.0, 80.0, 74.0, 60.0, 144.0, 80.0], "kind 88 lowers to 144, climbs to 80, 74 and 60, and lowers again, as recorded (%s)" % str(lift_ys))
	lift.free()
	var jumper_spot := EnemySpot.new()
	jumper_spot.kind = 0x9E
	jumper_spot.position = Vector2(100, 56)
	var jumper := Leaper.new()
	jumper.setup(jumper_spot, yard, null, victim)
	add_child(jumper)
	jumper.set_physics_process(false)
	var jump_top := 1000.0
	var jump_ticks := 0
	var waited := 0
	for i in 160:
		jumper.tick()
		if jumper.in_air:
			jump_top = minf(jump_top, jumper.position.y)
			jump_ticks += 1
		elif jump_ticks == 0:
			waited += 1
	check(waited == 74 and jumper.position == Vector2(100, 59) and absf((59.0 - jump_top) - 82.0) < 1.5 and absi(jump_ticks - 66) <= 2, "kind 9E waits 75 updates, then jumps straight up 82 pixels for about 66 updates (%.1f, %d)" % [59.0 - jump_top, jump_ticks])
	jumper.free()
	print("Shots, puffs and the soldier's jump")
	var count_shots := func(of_kind: int) -> int:
		var found := 0
		for child in get_children():
			if child is Shot and child.kind == of_kind and not child.is_queued_for_deletion():
				found += 1
		return found
	var clear_shots := func() -> void:
		for child in get_children():
			if child is Shot or child is Puff:
				child.free()
	var thrower := Node2D.new()
	add_child(thrower)
	thrower.position = Vector2(100, 56)
	var star := Shot.fire(thrower, 0x99, 1, yard, null)
	star.set_physics_process(false)
	for i in 10:
		star.tick()
	check(star.position == Vector2(133, 20) and star.speed == 768, "a thrown star starts 3 across and 36 up from the soldier and flies level at 3 pixels an update")
	var flame := Shot.fire(thrower, 0x4C, -1, yard, null)
	flame.set_physics_process(false)
	for i in 38:
		flame.tick()
	var flame_x := flame.position.x
	var flame_alive := not flame.is_queued_for_deletion()
	flame.tick()
	check(flame_x == 96.0 - 15 * 3.25 and flame_alive and flame.is_queued_for_deletion(), "kind 4C flies 15 updates, hangs there, and is gone after 39")
	clear_shots.call()
	var gunner_spot := EnemySpot.new()
	gunner_spot.kind = 0x94
	gunner_spot.position = Vector2(60, 56)
	var gunner := Crawler.new()
	gunner.setup(gunner_spot, yard, null)
	add_child(gunner)
	gunner.set_physics_process(false)
	for i in 16:
		gunner.tick()
	var before_pause: int = count_shots.call(0x95)
	for i in 6:
		gunner.tick()
	check(before_pause == 0 and count_shots.call(0x95) == 4, "kind 94 fires 4 shots, one an update, when it stops")
	gunner.take_hit(99)
	var puffs := 0
	for child in get_children():
		puffs += 1 if child is Puff and child.position == gunner.position else 0
	check(puffs == 1 and gunner.is_queued_for_deletion(), "a beaten enemy leaves a puff where it stood")
	clear_shots.call()
	victim.position = Vector2(120, 56)
	var rhino := Rocksteady.new()
	rhino.setup(Vector2(214, 16), yard, null, victim)
	add_child(rhino)
	rhino.set_physics_process(false)
	var shot_from := 0.0
	var shoot_ticks := 0
	var rhino_top := 1000.0
	var rhino_from := 0.0
	var rhino_to := 0.0
	for i in 150:
		var was: int = rhino.state
		rhino.tick()
		if rhino.state == Rocksteady.State.SHOOT:
			shoot_ticks += 1
			if was != Rocksteady.State.SHOOT and shot_from == 0.0:
				shot_from = rhino.position.x - victim.position.x
		if rhino.state == Rocksteady.State.JUMP and was == Rocksteady.State.CLOSE_IN:
			rhino_from = rhino.position.x
		if rhino.state == Rocksteady.State.JUMP and rhino.jumps_done == 1:
			rhino_top = minf(rhino_top, rhino.position.y)
		if rhino.state == Rocksteady.State.REST and was == Rocksteady.State.JUMP and rhino_to == 0.0:
			rhino_to = rhino.position.x
	check(rhino.position.y == 60.0 or rhino.state == Rocksteady.State.JUMP, "the boss drops in and rides 4 pixels into the floor")
	check(shot_from <= 34.0 and shot_from > 32.0 and shoot_ticks == 48 and count_shots.call(0x19) >= 0, "it walks 2 pixels an update to 34 pixels from him and stands 48 updates to shoot (%.1f, %d)" % [shot_from, shoot_ticks])
	check(absf((60.0 - rhino_top) - 82.1) < 0.5 and absf(absf(rhino_to - rhino_from) - 92.0) <= 6.0 and rhino_to < victim.position.x, "its jump rises 82 pixels, covers about 92, and carries it over him (%.1f, %.1f)" % [60.0 - rhino_top, absf(rhino_to - rhino_from)])
	var beaten := [false]
	rhino.defeated.connect(func() -> void: beaten[0] = true)
	rhino.take_hit(95)
	var alive_at_one: bool = not beaten[0]
	rhino.take_hit(7)
	check(alive_at_one and beaten[0] and rhino.is_queued_for_deletion(), "it takes 96 points of hits, then reports its defeat")
	var bullet := Shot.fire(thrower, 0x19, -1, yard, null)
	bullet.set_physics_process(false)
	bullet.tick()
	check(bullet.position == Vector2(100 - 5 - 5, 36), "its bullet starts 5 across and 20 up and flies 5 pixels an update")
	thrower.free()
	clear_shots.call()
	victim.position = Vector2(140, 56)
	var pig := Bebop.new()
	pig.setup(Vector2(100, 60), yard, null, victim)
	add_child(pig)
	pig.set_physics_process(false)
	var pig_states: Array[int] = []
	var pig_spans: Array[int] = []
	var pig_stops: Array[float] = []
	var pig_bumps := 0
	for i in 120:
		var pig_was := pig.state
		pig.tick()
		if pig.state != pig_was:
			pig_states.append(pig.state)
			pig_spans.append(i)
			if pig_was == Bebop.State.BUMP:
				pig_stops.append(victim.position.x - pig.position.x)
			pig_bumps += 1 if pig.state == Bebop.State.BUMP else 0
	check(pig.health == 72 and pig.touch_damage == 19, "the other boss (kind 70) has 72 hit points and does 19 on touch")
	check(pig_states.slice(0, 3) == [Bebop.State.WALK, Bebop.State.BUMP, Bebop.State.STAND] and pig_stops[0] == 12.0 and pig_spans[2] - pig_spans[1] == 12, "it walks 2 pixels an update up to the turtle, stops 12 pixels short and waits 12 updates (%.0f)" % pig_stops[0])
	var pig_turns := 0
	for i in pig_states.size() - 1:
		if (pig_states[i] == Bebop.State.FACE or pig_states[i] == Bebop.State.AWAY) and pig_spans[i] % 16 == 7:
			pig_turns += 1
	check(pig_bumps >= 5 and pig_turns >= 4 and pig_states.has(Bebop.State.FACE) and pig_states.has(Bebop.State.AWAY) and absf(victim.position.x - pig.position.x) < 24.0, "beside him it sets off again every 16 updates, at him and away by turns, and stops again (%d, %d)" % [pig_bumps, pig_turns])
	pig.view_left = 0.0
	victim.position = Vector2(160, 56)
	pig.position = Vector2(24, 60)
	pig.direction = -1
	pig.speed_x = -512
	pig.state = Bebop.State.WALK
	pig.state_ticks = 0
	pig.tick()
	check(pig.direction == 1 and pig.position.x == 26.0, "it turns round 25 pixels from the left edge of the fight's screen")
	pig.state_ticks = 47
	pig.direction = -1
	pig.speed_x = -512
	pig.position = Vector2(60, 60)
	pig.tick()
	pig.tick()
	check(pig.state == Bebop.State.WALK and pig.direction == 1, "after 48 updates of walking it faces the turtle again")
	pig.position = Vector2(120, 60)
	victim.position = Vector2(96, 56)
	pig.direction = -1
	pig.speed_x = -512
	pig.state_ticks = 0
	pig.clock = 0x1E
	pig.tick()
	check(pig.state == Bebop.State.WALK, "16 to 35 pixels away it does not jump while the frame counter is against it")
	pig.position = Vector2(120, 60)
	pig.clock = 0x3E
	pig.tick()
	var pig_top := 60.0
	var pig_air := 1
	check(pig.state == Bebop.State.JUMP, "and jumps when it is not")
	while pig.state == Bebop.State.JUMP and pig_air < 60:
		pig.tick()
		pig_air += 1
		pig_top = minf(pig_top, pig.position.y)
	check(absf((60.0 - pig_top) - 43.0) < 2.5 and pig_air >= 33 and pig_air <= 37 and pig.position.y == 60.0 and pig.state == Bebop.State.AWAY, "the jump rises about 43 pixels, lasts 35 updates or so, and ends in a walk away (%.1f, %d)" % [60.0 - pig_top, pig_air])
	pig.free()
	victim.position = Vector2(200, 56)
	var pacer_spot := EnemySpot.new()
	pacer_spot.kind = 0x4B
	pacer_spot.position = Vector2(60, 56)
	var pacer := Crawler.new()
	pacer.setup(pacer_spot, yard, null)
	add_child(pacer)
	pacer.set_physics_process(false)
	for i in 31:
		pacer.tick()
	var paused_at := pacer.position.x
	for i in 9:
		pacer.tick()
	var still_paused := pacer.position.x == paused_at
	pacer.tick()
	check(pacer.position.y == 59.0 and absf(paused_at - (60.0 + 31 * 296 / 256.0)) < 0.001 and still_paused and pacer.position.x > paused_at, "kind 4B walks for 31 updates, stands for 9, then walks on")
	pacer.free()
	victim.free()
	foe.take_hit(foe.weapon_damage)
	check(foe.health == 1 and not foe.is_queued_for_deletion(), "a hit takes the weapon's damage off")
	foe.take_hit(foe.weapon_damage)
	check(foe.is_queued_for_deletion(), "and it is gone when its hit points run out")

	# ---------------------------------------------------------------------
	# Enemies by the original's rules (Scripts/Enemies/OriginalEnemy.gd and
	# the kinds built on it). The side-by-side runs against the emulator are
	# in Research/enemy_routines.md; these keep the rules from slipping.
	# ---------------------------------------------------------------------
	print("Enemies by the original's rules")
	var o_court := RoomData.from_text([
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"################################",
		"################################",
	], "Court")
	OriginalEnemy.frame_counter = 0x10
	var o_prey := Node2D.new()
	add_child(o_prey)
	o_prey.position = Vector2(200, 176)        # the turtle's feet, on the floor
	var o_make_soldier := func(at: Vector2) -> Soldier:
		var spot := EnemySpot.new()
		spot.kind = 0x98
		spot.position = at
		spot.hit_points = 12
		spot.touch_damage = 17
		var made := Soldier.new()
		made.setup(spot, o_court, null, o_prey)
		add_child(made)
		made.set_physics_process(false)
		return made
	var o_stars_out := func() -> Array:
		var found := []
		for child in get_children():
			if child is Star and not child.gone:
				found.append(child)
		return found
	var o_foot: Soldier = o_make_soldier.call(Vector2(170, 100))
	o_foot.tick()
	check(o_foot.mode == Soldier.Mode.DROP and o_foot.position.y == 102.0, "a soldier with no floor under it drops, 2 pixels on the first update")
	for i in 40:
		o_foot.tick()
		if not o_foot.busy:
			break
	check(not o_foot.busy and o_foot.whole_y() == 179 and o_foot.speed_y == 0, "it comes to rest 3 pixels into the floor (%.2f)" % o_foot.position.y)
	check(o_foot.kind_at(0, -4) == RoomData.KIND_EMPTY and o_foot.kind_at(0, 0) == RoomData.KIND_SOLID and o_foot.kind_at(-160, -40) == RoomData.KIND_SOLID and o_foot.kind_at(-150, -40) == RoomData.KIND_EMPTY, "the map is felt in 16-pixel cells")
	# 30 pixels away: it walks at him, 1.25 pixels an update, and punches inside 24.
	o_foot.set_animation(Soldier.RISE)
	o_foot.tick()
	check(o_foot.animation == Soldier.WALK and o_foot.speed_x == 320 and not o_foot.facing_left, "24 to 63 pixels from the turtle it walks at him at 1.25 pixels an update")
	var o_walked := 0
	while not o_foot.busy and o_walked < 40:
		o_foot.tick()
		o_walked += 1
	check(o_foot.mode == Soldier.Mode.POSE and o_foot.animation == Soldier.PUNCH_SHORT and o_foot.speed_x == 0 and o_prey.position.x - o_foot.position.x < 24.0 and o_prey.position.x - o_foot.position.x > 22.0, "under 24 pixels away it stops and punches (%.2f away)" % (o_prey.position.x - o_foot.position.x))
	var o_punch_ticks := 1
	while o_foot.busy and o_punch_ticks < 60:
		o_foot.tick()
		o_punch_ticks += 1
	check(o_punch_ticks == 19, "the short punch holds it for 19 updates (%d)" % o_punch_ticks)
	OriginalEnemy.frame_counter = 0x60
	o_foot.tick()
	check(o_foot.animation == Soldier.PUNCH_LONG, "which punch depends on the frame counter: the long one from 96 up")
	o_punch_ticks = 1
	while o_foot.busy and o_punch_ticks < 60:
		o_foot.tick()
		o_punch_ticks += 1
	check(o_punch_ticks == 25, "the long punch holds it for 25 updates (%d)" % o_punch_ticks)
	# Hit: stunned for 16 updates, then it jumps; it blinks for 24.
	o_foot.take_hit(7)
	check(o_foot.health == 5 and o_foot.blinking and not o_foot.gone, "a sword hit takes 7 of its 12 hit points and starts it blinking")
	o_foot.tick()
	check(o_foot.animation == Soldier.STUNNED and o_foot.speed_x == 0, "hit, it stands stunned")
	var o_stunned_for := 1
	while o_foot.mode != Soldier.Mode.JUMP and o_stunned_for < 40:
		o_foot.tick()
		o_stunned_for += 1
	check(o_stunned_for == 17 and o_foot.speed_y == -1536 and o_foot.speed_x == 320, "after 16 updates of that it jumps, 6 pixels an update upward (%d)" % o_stunned_for)
	var o_blink_left := 0
	while o_foot.blinking and o_blink_left < 40:
		o_foot.tick()
		o_blink_left += 1
	check(o_stunned_for + o_blink_left == 24, "the blink lasts 24 updates (%d)" % (o_stunned_for + o_blink_left))
	while o_foot.busy:
		o_foot.tick()
	check(o_foot.whole_y() == 179 and o_foot.animation == Soldier.WALK and o_foot.speed_x == 0, "it lands with its walking animation already on")
	o_foot.take_hit(7)
	check(o_foot.gone, "a second hit finishes it")
	o_foot.free()
	# The jump towards a turtle far away, and the walk on the spot after it.
	o_prey.position = Vector2(220, 176)
	var o_jumper: Soldier = o_make_soldier.call(Vector2(60, 179))
	o_jumper.tick()
	check(o_jumper.mode == Soldier.Mode.JUMP and o_jumper.speed_x == 320 and o_jumper.position == Vector2(61.25, 173.0), "96 pixels or more from the turtle it jumps towards him")
	var o_top := 1000.0
	while o_jumper.busy:
		o_jumper.tick()
		o_top = minf(o_top, o_jumper.position.y)
	check(absf(179.0 - o_top - 131.02) < 0.01 and o_jumper.whole_y() == 179, "a jump with nothing in the way rises 131 pixels (%.2f)" % (179.0 - o_top))
	var o_landed_at: float = o_jumper.position.x
	check(absf(o_landed_at - 60.0 - 107.5) < 0.01, "and carries it 107.5 pixels (%.2f)" % (o_landed_at - 60.0))
	for i in 10:
		o_jumper.tick()
	check(o_jumper.position.x == o_landed_at and o_jumper.animation == Soldier.WALK and not o_jumper.busy, "landing in walking range it walks on the spot: the speed is only set when the walking animation starts")
	o_jumper.free()
	# The o_star.
	o_prey.position = Vector2(200, 176)
	OriginalEnemy.frame_counter = 0x10
	var o_thrower: Soldier = o_make_soldier.call(Vector2(120, 179))
	o_thrower.tick()
	var o_thrown: Array = o_stars_out.call()
	check(o_thrower.animation == Soldier.THROW and o_thrown.size() == 1 and o_thrown[0].position == Vector2(123, 143) and o_thrown[0].speed_x == 768, "64 to 95 pixels away it throws a o_star, which starts 36 above it and flies at 3 pixels an update")
	var o_throw_ticks := 1
	while o_thrower.busy and o_throw_ticks < 40:
		o_thrower.tick()
		o_throw_ticks += 1
	check(o_throw_ticks == 13, "the throw holds it for 13 updates (%d)" % o_throw_ticks)
	for i in 80:
		o_thrower.tick()
	check(o_stars_out.call().size() <= 4, "there are never more than four stars")
	var o_star: Star = o_thrown[0]
	while not o_star.gone and o_star.ticks < 200:
		o_star.tick()
	check(o_star.gone and o_star.position.x >= 240.0 and o_star.position.x < 243.0, "a o_star is gone when it meets a wall (%.0f)" % o_star.position.x)
	for o_old_star: Star in o_stars_out.call():
		o_old_star.free()
	OriginalEnemy.frame_counter = 0xC0
	o_thrower.busy = false
	o_thrower.set_animation(Soldier.RISE)
	o_thrower.tick()
	check(o_stars_out.call().is_empty() and o_thrower.animation == Soldier.WALK and o_thrower.speed_x == 320, "with the frame counter at 192 or more it walks instead of throwing")
	o_thrower.free()
	# Walls.
	o_prey.position = Vector2(60, 176)
	var o_turner: Soldier = o_make_soldier.call(Vector2(214, 179))
	o_turner.facing_left = false
	o_turner.go_forward(320)
	var o_clear_at_214: bool = not o_turner.wall_ahead(24, -16)
	o_turner.place(Vector2(215, 179))
	check(o_clear_at_214 and o_turner.wall_ahead(24, -16), "a wall is looked for 24 pixels ahead, plus the whole pixels of its speed")
	o_turner.turn_round()
	check(o_turner.facing_left and o_turner.speed_x == -320 and not o_turner.wall_ahead(24, -16), "at a wall it turns round")
	o_turner.free()
	# Kinds 81 and 96: level fliers.
	var o_bat := Flier.new()
	var o_bat_spot := EnemySpot.new()
	o_bat_spot.kind = 0x81
	o_bat_spot.position = Vector2(100, 80)
	o_bat.setup(o_bat_spot, o_court, null, o_prey)
	add_child(o_bat)
	o_bat.set_physics_process(false)
	OriginalEnemy.scroll_step = 0
	o_bat.tick()
	check(o_bat.facing_left and o_bat.position == Vector2(97.5, 80), "kind 81 sets off to the left when the screen is still, 2.5 pixels an update, level")
	var o_bat_turn := 0.0
	for i in 40:
		o_bat.tick()
		if not o_bat.facing_left and o_bat_turn == 0.0:
			o_bat_turn = o_bat.position.x
	check(o_bat_turn == 30.0 and o_bat.position.y == 80.0, "it turns round with a wall 10 pixels ahead, plus the whole pixels of its speed (%.1f)" % o_bat_turn)
	o_bat.free()
	# Kinds 8D and 84: walkers that drop off ledges.
	var o_step := RoomData.from_text([
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##########....................##",
		"##########....................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"################################",
		"################################",
	], "Step")
	var o_mouse := LedgeWalker.new()
	var o_mouse_spot := EnemySpot.new()
	o_mouse_spot.kind = 0x8D
	o_mouse_spot.position = Vector2(40, 68)
	o_mouse.setup(o_mouse_spot, o_step, null, o_prey)
	add_child(o_mouse)
	o_mouse.set_physics_process(false)
	o_mouse.tick()
	check(not o_mouse.facing_left and o_mouse.position == Vector2(41.375, 68), "kind 8D walks the way it faces at 1.375 pixels an update")
	var o_fell_at := 0.0
	var o_fall_ticks := 0
	for i in 120:
		var o_was: bool = o_mouse.falling
		o_mouse.tick()
		if o_mouse.falling and not o_was:
			o_fell_at = o_mouse.position.x
		if o_mouse.falling:
			o_fall_ticks += 1
		elif o_fell_at > 0.0:
			break
	check(o_fell_at >= 92.0 and o_fell_at < 93.4 and o_mouse.whole_y() == 116, "it walks on until nothing is under its back end, 12 pixels behind, then drops and lands 4 pixels into the floor below (%.2f, %d)" % [o_fell_at, o_mouse.whole_y()])
	check(o_mouse.speed_x == 352 and not o_mouse.falling, "and walks on the way it was going")
	o_mouse.kind = 0x84
	o_mouse.busy = false
	o_mouse.tick()
	check(o_mouse.speed_x == 768, "kind 84 does the same at 3 pixels an update")
	o_mouse.free()
	# Kind 86: along the ceiling, and the swoop.
	var o_cave := RoomData.from_text([
		"################################",
		"################################",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"##............................##",
		"################################",
		"################################",
	], "Cave")
	o_prey.position = Vector2(200, 112)
	var o_hanger := CeilingCrawler.new()
	var o_hanger_spot := EnemySpot.new()
	o_hanger_spot.kind = 0x86
	o_hanger_spot.position = Vector2(120, 70)
	o_hanger.setup(o_hanger_spot, o_cave, null, o_prey)
	add_child(o_hanger)
	o_hanger.set_physics_process(false)
	OriginalEnemy.scroll_step = -1
	for i in 12:
		o_hanger.tick()
	check(o_hanger.mode == CeilingCrawler.Mode.CRAWL and o_hanger.whole_y() == 40 and o_hanger.speed_x == 352, "kind 86 rises to the ceiling and crawls along it, 24 pixels below it (%d)" % o_hanger.whole_y())
	var o_lowest := 0.0
	var o_swooped := false
	for i in 120:
		o_hanger.tick()
		if o_hanger.mode == CeilingCrawler.Mode.SWOOP:
			o_swooped = true
			o_lowest = maxf(o_lowest, o_hanger.position.y)
		elif o_swooped:
			break
	check(o_swooped and absf(o_lowest - 112.2) < 0.5 and o_hanger.whole_y() == 40 and o_hanger.mode == CeilingCrawler.Mode.CRAWL, "with the turtle under 40 pixels away it swoops, stopped by the floor, and climbs back to the ceiling (%.1f)" % o_lowest)
	o_hanger.free()
	OriginalEnemy.scroll_step = 0
	# The frames enemies are updated on, and the sixteen map columns to hand.
	OriginalEnemy.frame_counter = 0x11
	var o_idle: Soldier = o_make_soldier.call(Vector2(100, 179))
	check(not o_idle._is_update_frame(), "enemies are not updated on odd frames of the counter")
	OriginalEnemy.frame_counter = 0x12
	check(o_idle._is_update_frame(), "and are on even ones")
	o_idle.free()
	OriginalEnemy._first_column = -1
	OriginalEnemy.screen_moved_to(0)
	OriginalEnemy.screen_moved_to(7)
	var o_early: int = OriginalEnemy._first_column
	OriginalEnemy.screen_moved_to(8)
	var o_late: int = OriginalEnemy._first_column
	OriginalEnemy.screen_moved_to(3)
	check(o_early == 0 and o_late == 1 and OriginalEnemy._first_column == 1, "scrolling right, the map column coming in replaces the one going out 8 pixels in; scrolling back does not undo it")
	OriginalEnemy.screen_moved_to(0)
	check(OriginalEnemy._first_column == 0, "scrolling left, a column is taken up once it is wholly on the screen")
	OriginalEnemy._first_column = -1
	OriginalEnemy.frame_counter = -1
	o_prey.free()

	print("Levels read from the ROM")
	var levels := RomLevels.open_installed()
	if levels == null:
		print("  skip  no verified ROM is installed, so the ROM level reader is not exercised")
	else:
		var counts: Array[int] = []
		var total := 0
		for wd in RomLevels.WORLDS:
			counts.append(levels.area_count(wd))
			total += counts[wd]
		check(counts == [6, 2, 7, 18, 9, 4], "finds 46 areas in 6 worlds (%s)" % str(counts))
		var first := levels.room(0, 0)
		check(first.cols == 128 and first.rows == 24, "first sewer is 4 screens wide (1024 x 192 pixels)")
		check(first.chr_page == 21 and first.palettes[1] == [15, 6, 38, 54], "first sewer uses graphics page 21 and the brick colours")
		check(first.is_solid_cell(10, 22) and first.is_ladder_cell(4, 5) and first.is_ladder_cell(24, 16) and not first.is_solid_cell(14, 12), "first sewer's floor, ladders and gap are where the original has them")
		check(first.is_solid_cell(60, 16), "the pillar at x=480 is there")
		var all_ok := true
		for wd in RomLevels.WORLDS:
			for ar in counts[wd]:
				var any_room := levels.room(wd, ar)
				all_ok = all_ok and any_room.cols > 0 and any_room.rows > 0 and any_room.tiles.size() == any_room.cols * any_room.rows
		check(all_ok, "every area decodes without error")
		sewer.load_area(0, 0)
		for i in 20:
			await get_tree().physics_frame
		# The screen must sit where his scroll number says on every frame,
		# also on the frames he moves without it scrolling.
		leo.position = Vector2(200, 176)
		for i in 6:
			await get_tree().physics_frame
		var lens: Camera2D = leo.get_node("Camera2D")
		var steady := true
		var walked_from := leo.position.x
		for way in ["move_left", "move_right", "move_left"]:
			Input.action_press(way)
			for i in 14:
				await get_tree().physics_frame
				steady = steady and lens.global_position.x - 128.0 == floorf(leo.scroll_x)
			Input.action_release(way)
		check(steady and leo.position.x != walked_from, "the screen does not shake as he walks to and fro in the middle of it")
		leo.position = Vector2(440, 176)
		Input.action_press("move_right")
		for i in 60:
			await get_tree().physics_frame
		Input.action_release("move_right")
		check(leo.position.x < 480.0 and leo.position.x > 465.0, "the pillar blocks him where it blocks him in the original (x=%.1f)" % leo.position.x)
		sewer.step_area(1)
		check(sewer.world == 0 and sewer.area == 1 and sewer.room.cols == 96, "F4 moves to the next area")

		print("Doors read from the ROM")
		var first_map := levels.overworld(0)
		check(first_map.top_down and first_map.cols == 64 and first_map.rows == 64 and first_map.chr_page == 18, "first overworld is 2 x 2 screens of 256 x 256")
		check(first_map.start == Vector2(160, 296), "the game begins at (160, 296), beside the first manhole")
		check(levels.overworld(5) == null, "the sixth world has no overworld")
		var door_total := 0
		var doors_ok := true
		for wd in RomLevels.WORLDS:
			var maps: Array[RoomData] = []
			if levels.has_overworld(wd):
				maps.append(levels.overworld(wd))
			for ar in counts[wd]:
				maps.append(levels.room(wd, ar))
			for one_map in maps:
				door_total += one_map.doors.size()
				for door in one_map.doors:
					var inside := Rect2(Vector2.ZERO, one_map.size_pixels()).has_point(door.position)
					# Into a room that exists, or out of a room to this world's map.
					var leads := door.to_area < counts[wd] if door.to_room else (door.to_area == wd and not one_map.top_down)
					doors_ok = doors_ok and inside and leads
		check(door_total == 135, "finds 135 doors: 60 on the overworlds, 75 in rooms (%d)" % door_total)
		check(doors_ok, "every door sits inside its map and leads somewhere that exists")
		check(first_map.doors.size() == 9 and first_map.doors[4].position == Vector2(135, 296) and first_map.doors[4].to_area == 0 and first_map.doors[4].arrive == Vector2(40, 24), "the first manhole leads to the top of the first sewer's ladder")
		var sewer_doors := levels.room(0, 0).doors
		check(sewer_doors.size() == 2 and sewer_doors[0].arrive == Vector2(144, 296) and sewer_doors[1].arrive == Vector2(208, 440), "the first sewer's two ladders come out at two different manholes")
		check(levels.room(3, 16).doors.size() == 2 and levels.room(3, 17).doors.is_empty() and levels.room(1, 1).doors.is_empty(), "the unterminated list and the door-less rooms read correctly")

		sewer.load_overworld(0)
		var small: OverworldTurtle = sewer.walker
		check(sewer.room.top_down and small.position == Vector2(160, 296) and not leo.visible, "the map opens with the small turtle at the start")
		check(small.sprites != null and small.sprites.animations.has("right") and small.sprites.animations.has("up") and small.sprites.animations.has("down") and small._picture.texture != null, "he is drawn from Leonardo's overworld sprites")
		small.step(Vector2i.RIGHT)
		var facing_right_x := small._picture.position.x
		small.step(Vector2i.LEFT)
		check(small._picture.flip_h and small._picture.position.x == -facing_right_x - small._picture.texture.get_width(), "walking left mirrors the right-facing picture")
		small.position = Vector2(160, 296)
		Input.action_press("move_left")
		for i in 14:
			await get_tree().physics_frame
		Input.action_release("move_left")
		check(not sewer.room.top_down and sewer.area == 0 and leo.state == Turtle.State.CLIMB and leo.position == Vector2(40, 44), "walking left onto the manhole puts him on the sewer ladder, as in the original")
		await get_tree().physics_frame
		Input.action_press("move_up")
		for i in 12:
			await get_tree().physics_frame
			if sewer.room.top_down:
				break
		Input.action_release("move_up")
		check(sewer.room.top_down and small.position == Vector2(144, 296), "climbing out of the top returns him to the map at (144, 296)")
		sewer.load_area(0, 4)
		leo.position = Vector2(60, 160)
		for i in 6:
			await get_tree().physics_frame
		Input.action_press("move_up")
		for i in 4:
			await get_tree().physics_frame
		check(not sewer.room.top_down, "Up does nothing away from a doorway")
		Input.action_release("move_up")
		leo.position = Vector2(40, 160)
		for i in 6:
			await get_tree().physics_frame
		Input.action_press("move_up")
		for i in 4:
			await get_tree().physics_frame
			if sewer.room.top_down:
				break
		Input.action_release("move_up")
		check(sewer.room.top_down and small.position == Vector2(424, 296), "Up at the building's doorway leads out to the map at (424, 296)")
		print("Enemies read from the ROM")
		var room_spots := 0
		var map_spots := 0
		var spots_ok := true
		for wd in RomLevels.WORLDS:
			if levels.has_overworld(wd):
				var world_map := levels.overworld(wd)
				map_spots += world_map.enemy_spots.size()
				for spot in world_map.enemy_spots:
					spots_ok = spots_ok and spot.kind >= 0 and Rect2(Vector2.ZERO, world_map.size_pixels()).has_point(spot.position)
			for ar in counts[wd]:
				var one_room := levels.room(wd, ar)
				room_spots += one_room.enemy_spots.size()
				for spot in one_room.enemy_spots:
					spots_ok = spots_ok and spot.kind >= 0 and Rect2(Vector2.ZERO, one_room.size_pixels()).has_point(spot.position)
		check(room_spots == 760 and map_spots == 80, "finds 760 enemy places in rooms and 80 on the overworlds (%d, %d)" % [room_spots, map_spots])
		check(spots_ok, "every enemy place is inside its map and has a kind")
		var sewer_spots := levels.room(0, 0).enemy_spots
		check(sewer_spots.size() == 21 and sewer_spots[0].position == Vector2(64, 180) and sewer_spots[0].kind == 0x8D and sewer_spots[0].hit_points == 4, "first sewer: 21 places, the first a kind 8D with 4 hit points at (64, 180)")
		check(sewer_spots[5].position == Vector2(289, 64) and sewer_spots[5].kind == 0x81, "its second kind, 81, hangs at (289, 64)")
		check(levels.weapon_damage(0) == Vector2i(7, 10) and levels.weapon_damage(3) == Vector2i(15, 16), "Leonardo's sword takes 7 (10 when he is weak), Donatello's staff 15")
		sewer.enemies_follow_camera = false   # these checks want the whole room filled
		sewer.show_enemies = true
		sewer.load_area(0, 0)
		var first_foe: LedgeWalker = sewer.enemies.get_child(0)
		check(sewer.enemies.get_child_count() == 21 and first_foe.health == 4 and first_foe.weapon_damage == 7 and first_foe.touch_damage == 7, "the first sewer shows 21 enemies with real hit points; the first is a crawler")
		var flyer: Flier = sewer.enemies.get_child(5)
		check(sewer_spots[5].touch_damage == 9 and flyer.kind == 0x81 and flyer.touch_damage == 9, "kind 81 is a flyer, with its own touch damage of 9")
		flyer.set_physics_process(false)
		var flyer_y := flyer.position.y
		var flyer_x := flyer.position.x
		OriginalEnemy.scroll_step = -2
		flyer.tick()
		OriginalEnemy.scroll_step = 0
		check(flyer.position == Vector2(flyer_x + 2.5, flyer_y) and not flyer.facing_left, "it flies 2.5 pixels an update and keeps its height; made while the screen scrolls left, it sets off to the right")
		var kinds_drawn := 0
		var kinds_missing: Array[String] = []
		var kinds_used := {}
		for wd in RomLevels.WORLDS:
			var all_maps: Array[RoomData] = []
			if levels.has_overworld(wd):
				all_maps.append(levels.overworld(wd))
			for ar in counts[wd]:
				all_maps.append(levels.room(wd, ar))
			for any_map in all_maps:
				for spot in any_map.enemy_spots:
					kinds_used[spot.kind] = true
		for used_kind: int in kinds_used:
			var pictures := SpriteSet.cached("Kind%02X" % used_kind)
			if pictures != null and pictures.bounds("walk").has_area():
				kinds_drawn += 1
			else:
				kinds_missing.append("%02X" % used_kind)
		kinds_missing.sort()
		check(kinds_used.size() == 29 and kinds_drawn == 24, "24 of the 29 enemy kinds in use are drawn from their own sprites (blocks: %s)" % ", ".join(kinds_missing))
		sewer.load_area(0, 2)
		var troop := 0
		for foe_node in sewer.enemies.get_children():
			if foe_node is Soldier and foe_node.health == 12 and foe_node.touch_damage == 17 and foe_node.sprites != null:
				troop += 1
		var placed_soldiers := 0
		for spot in sewer.room.enemy_spots:
			placed_soldiers += 1 if spot.kind == 0x98 else 0
		check(troop == 6 and placed_soldiers == 6, "the third sewer room has its 6 soldiers, with 12 hit points and 17 touch damage (%d)" % troop)
		sewer.load_area(4, 2)
		var still_one: DummyEnemy = null
		for foe_node in sewer.enemies.get_children():
			if foe_node is DummyEnemy and still_one == null:
				still_one = foe_node
		check(still_one != null and still_one.sprites != null and still_one.get_node("Art").visible == false, "a kind that does not move yet still shows its own picture")
		sewer.load_area(0, 0)
		check(leo.max_health == 128 and sewer.health_bar.max_health == 8 and sewer.health_bar.health == 8, "the turtle has 128 energy, shown as 8 blocks")
		# Kind 8D by the original's rules, in the first sewer's own map.
		sewer.set_show_enemies(false)
		var bug := LedgeWalker.new()
		bug.setup(sewer_spots[0], sewer.room, null, null)
		sewer.enemies.add_child(bug)
		bug.set_physics_process(false)
		check(bug.direction == 1, "placed on the left half of a screen, it starts off to the right")
		bug.position = Vector2(139.625, 180)
		for i in 77:
			bug.tick()
		check(bug.position == Vector2(245.5, 180) and bug.direction == 1, "it walks 1.375 pixels an update along the floor")
		bug.position = Vector2(40, 180)
		bug.facing_left = true
		bug.busy = false
		var turn_x := 0.0
		for i in 12:
			bug.tick()
			if bug.direction == 1 and turn_x == 0.0:
				turn_x = bug.position.x
		check(turn_x >= 30.0 and turn_x < 32.0, "it turns at the left wall where the original turns (x=%.2f; the original showed 30 and 31)" % turn_x)
		bug.position = Vector2(186, 100)
		bug.facing_left = true
		bug.busy = false
		var fall_from := Vector2.ZERO
		var fall_ticks := 0
		for i in 80:
			var was_falling: bool = bug.falling
			bug.tick()
			if bug.falling and not was_falling:
				fall_from = bug.position
			if bug.falling:
				fall_ticks += 1
			if fall_from != Vector2.ZERO and not bug.falling:
				break
		check(absf(fall_from.x - 131.0) < 1.0 and fall_from.y == 102.0, "it walks off the ledge and starts to fall at x=131, as in the original (x=%.2f)" % fall_from.x)
		check(bug.whole_y() == 180 and bug.direction == -1 and absi(fall_ticks - 26) <= 1, "it lands on the floor at y=180 after about 26 updates and keeps its direction (%d)" % fall_ticks)
		bug.free()
		sewer.set_show_enemies(false)
		check(sewer.enemies.get_child_count() == 0, "F8 clears them away")

		print("Enemies follow the camera")
		sewer.enemies_follow_camera = true
		sewer.show_enemies = true
		sewer.set_flying(true)   # so nothing hurts him while the camera is moved about
		sewer.load_area(0, 0)
		leo.position = Vector2(40, 96)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(sewer.enemies.get_child_count() == 4, "the first sewer starts with only the 4 enemies on screen (%d)" % sewer.enemies.get_child_count())
		var far_spot: EnemySpot = sewer.room.enemy_spots[4]     # at (288, 180)
		var made_at := -1.0
		while leo.position.x < 300.0:
			leo.position.x += 4.0
			await get_tree().physics_frame
			if made_at < 0.0 and sewer._spot_enemies.has(far_spot):
				made_at = sewer._view_corner().x
		check(made_at >= 40.0 and made_at <= 44.0, "the enemy at x=288 is made when the camera reaches 40, as in the original (%d)" % made_at)
		var behind := 0
		for foe_node in sewer.enemies.get_children():
			if not foe_node.is_queued_for_deletion() and foe_node.position.x < sewer._view_corner().x:
				behind += 1
		check(behind == 0, "enemies that leave the screen are removed")
		var first_one: Node = sewer._spot_enemies[far_spot]
		first_one.free()
		while leo.position.x > 60.0:
			leo.position.x -= 4.0
			await get_tree().physics_frame
		while leo.position.x < 300.0:
			leo.position.x += 4.0
			await get_tree().physics_frame
		check(is_instance_valid(sewer._spot_enemies.get(far_spot)), "going away and coming back makes that enemy again")
		sewer.set_flying(false)
		check(Shot.damage_of.get(0x99) == 9 and Shot.damage_of.get(0x9F) == 30 and Shot.damage_of.get(0x4C) == 5, "shots take their damage from the ROM (a star 9, kind 9F 30)")
		var shot_maps := 0
		for map_kind in [0x4A, 0x4C, 0x95, 0x9F, 0x99, 0x15]:
			var shot_pictures := SpriteSet.cached("Kind%02X" % map_kind)
			shot_maps += 1 if shot_pictures != null and shot_pictures.bounds("walk").has_area() else 0
		check(shot_maps == 6, "the five kinds of shot and the puff are drawn from their own sprites")
		sewer.set_show_enemies(false)

		print("World 1: items, the boss, and finishing")
		sewer.enemies_follow_camera = true
		sewer.show_enemies = true
		sewer.load_area(0, 4)
		check(sewer.items.get_child_count() == 2 and sewer.items.get_child(0).kind == Item.WHOLE_PIZZA and sewer.items.get_child(0).position == Vector2(32, 48), "the building room has its whole pizza and its slice")
		var chainsaws := 0
		for spot in sewer.room.enemy_spots:
			chainsaws += 1 if spot.kind == 0x91 and Crawler.KINDS.has(spot.kind) else 0
		check(chainsaws == 3, "its 3 chainsaw carriers (kind 91) now move")
		var first_room := levels.room(0, 1)
		var bosses_listed := 0
		for w in RomLevels.WORLDS:
			for a in levels.area_count(w):
				for entry in levels.room(w, a).encounters:
					bosses_listed += 1 if entry.is_boss else 0
		check(first_room.encounters.size() == 1 and first_room.encounters[0].kind == 0x70 and first_room.encounters[0].position == Vector2(608, 180) and first_room.encounters[0].camera_x() == 508.0, "the ROM's encounter table puts kind 70 at (608, 180) in the second room, for a camera at 508")
		var last_room := levels.room(0, 5)
		check(last_room.encounters.size() == 1 and last_room.encounters[0].kind == 0x71 and last_room.encounters[0].position == Vector2(208, 68) and last_room.encounters[0].hit_points == 96, "and kind 71 at (208, 68) in the last room, for a camera at the left end")
		check(bosses_listed == 6, "the table names 6 bosses in the whole game (%d)" % bosses_listed)
		sewer.load_area(0, 1)
		leo.position = Vector2(700, 170)
		for i in 4:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(sewer.boss == null and not sewer.fighting, "arriving with the screen already at the room's right end brings no boss")
		leo.position = Vector2(600, 170)
		for i in 3:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		leo.position = Vector2(637, 170)
		for i in 3:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(sewer.boss is Bebop and sewer.boss.health == 72 and sewer.boss.touch_damage == 19 and sewer.boss.sprites != null, "the screen reaching 508 from the left brings kind 70 in, with 72 hit points and 19 touch damage from the ROM")
		check(sewer.fighting and sewer.fight_corner.y == 0.0 and absf(sewer.fight_corner.x - 508.0) <= 1.0 and sewer.boss_bar.visible and sewer._company != null and sewer._company.position == sewer.fight_corner + Vector2(196, 83), "the screen is held there, the boss's energy shows, and the two on the ledge stand by")
		leo.position = Vector2(400, 170)
		for i in 3:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(leo.position.x >= sewer.fight_corner.x + 20.0, "the turtle cannot leave the fight's screen (%.0f)" % leo.position.x)
		sewer.boss.take_hit(36)
		for i in 2:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(sewer.boss_bar.health == 4, "half its energy gone shows as 4 blocks of 8")
		sewer.boss.take_hit(999)
		for i in 4:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(not sewer.fighting and not sewer.boss_bar.visible and sewer._company == null and sewer.world == 0 and not sewer.room.top_down, "beating it frees the screen and the world goes on")
		leo.position = Vector2(600, 170)
		for i in 3:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		leo.position = Vector2(637, 170)
		for i in 3:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(not sewer.fighting, "and it does not come back")
		var forward_swing := levels.weapon_swing(0, 1)
		var up_swing := levels.weapon_swing(0, 0)
		check(forward_swing.places == [Vector2(-6, -23), Vector2(27, -8), Vector2(23, 17)] and forward_swing.half == Vector2(14, 12) and up_swing.places.size() == 4 and up_swing.half == Vector2(14, 14) and levels.weapon_swing(0, 2).places.size() == 4, "the ROM gives Leonardo's sword 3 places for the forward swing and 4 for the swings up and down")
		var soldier_box := Vector2i.ZERO
		var bug_box := Vector2i.ZERO
		for spot in levels.room(0, 0).enemy_spots:
			if spot.kind == 0x98:
				soldier_box = spot.half_size
			elif spot.kind == 0x8D:
				bug_box = spot.half_size
		check(levels.box_half_size(0, 0x80) == Vector2i(5, 16) and levels.box_half_size(0, 0x83) == Vector2i(5, 11) and soldier_box == Vector2i(3, 32) and bug_box == Vector2i(7, 13) and levels.room(0, 1).encounters[0].half_size == Vector2i(8, 30), "and hit boxes: the turtle 10 x 32, crouching 10 x 22, kind 98 6 wide, kind 8D 14 wide, the boss 16 x 60")
		sewer.enemies_follow_camera = false
		sewer.load_area(0, 0)
		var fitted := Vector2.ZERO
		var fitted_at := Vector2.ZERO
		for thing in sewer.enemies.get_children():
			if thing is LedgeWalker and thing.kind == 0x8D:
				var found_shape := thing.find_children("*", "CollisionShape2D", true, false)[0] as CollisionShape2D
				fitted = (found_shape.shape as RectangleShape2D).size
				fitted_at = found_shape.position
				break
		check(fitted == Vector2(14, 11) and fitted_at == Vector2(0, -7.5), "an enemy's box runs from its half height above its position down to 2 above it (%s at %s)" % [fitted, fitted_at])
		sewer.set_show_enemies(false)
		leo.position = Vector2(136, 176)
		for i in 6:
			await get_tree().physics_frame
		Input.action_press("move_up")
		Input.action_press("attack")
		for i in 3:
			await get_tree().physics_frame
		Input.action_release("attack")
		var sword: CollisionShape2D = leo.get_node("WeaponHitbox/CollisionShape2D")
		check(leo.attack_direction == 0 and leo.anim == "attack_up" and leo.attack_length == 8 and (sword.shape as RectangleShape2D).size == Vector2(28, 28) and not sword.disabled, "Up with attack swings upward: 4 frames, the sword's box 28 x 28")
		check(sword.position == Vector2(11, -25) or sword.position == Vector2(22, -22), "and the box is where the ROM puts the sword on that frame (%s)" % sword.position)
		Input.action_release("move_up")
		for i in 24:
			await get_tree().physics_frame
		var body: CollisionShape2D = leo.get_node("CollisionShape2D")
		check((body.shape as RectangleShape2D).size == Vector2(10, 32) and body.position == Vector2(0, -20), "standing, his own box is 10 x 32 around his middle")
		sewer.enemies_follow_camera = true
		sewer.show_enemies = true
		var held_room := levels.room(0, 0)
		check(held_room.encounters.size() == 1 and not held_room.encounters[0].is_boss and held_room.encounters[0].kind == 0x98 and held_room.encounters[0].offset == Vector2(24, 100) and levels.room(0, 3).encounters[0].kind == 0x91, "the table's other entries are held fights: kind 98 in the first sewer, kind 91 in the fourth room")
		sewer.load_area(0, 0)
		leo.position = Vector2(600, 170)
		for i in 3:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		leo.position = Vector2(637, 170)
		for i in 3:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(sewer.fighting and sewer.hold_stage == 1 and absf(sewer.fight_corner.x - 508.0) <= 1.0 and sewer.boss == null, "the first sewer's screen stops at 508, give or take a pixel, for a held fight")
		for i in 30:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(sewer.hold_stage == 1 and sewer.living_enemies() > 0, "nothing more happens while enemies are on the screen")
		for thing in sewer.enemies.get_children():
			thing.free()
		for i in 20:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		var extra: Node2D = sewer.enemies.get_child(0) if sewer.enemies.get_child_count() > 0 else null
		check(sewer.hold_stage == 2 and sewer.living_enemies() == 1 and extra is Soldier and absf(extra.position.x - 532.0) < 40.0, "with the screen clear one more enemy comes in, of kind 98")
		leo.position = Vector2(400, 170)
		for i in 3:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(leo.position.x >= 528.0, "and the turtle is kept on that screen")
		for thing in sewer.enemies.get_children():
			thing.free()
		for i in 60:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(sewer.fighting, "the screen stays held for 64 frames after it is beaten")
		for i in 8:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(not sewer.fighting and sewer.hold == null, "then it is freed")
		sewer.load_area(0, 5)
		sewer.set_flying(true)
		leo.position = Vector2(300, 160)
		for i in 4:
			await get_tree().physics_frame
		check(sewer.boss == null, "the last room's boss is not there until he reaches its corner")
		sewer.set_flying(false)
		leo.position = Vector2(60, 160)
		for i in 4:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(sewer.boss != null and sewer.boss.health == 96 and sewer.boss.touch_damage == 23 and sewer.boss.sprites != null, "then it appears, with 96 hit points and 23 touch damage from the ROM")
		check(Shot.damage_of.get(0x19) == 9, "its bullet does 9")
		sewer.clear_message_seconds = 0.05
		sewer.boss.take_hit(999)
		for i in 30:
			leo.invulnerable_timer = 1.0
			await get_tree().physics_frame
		check(sewer.world == 1 and sewer.room.top_down, "beating it ends world 1 and opens world 2's overworld")
		sewer.set_show_enemies(false)

		sewer.world = 4
		sewer.area = 3
		sewer.technodrome_cave = 3
		sewer.enter_door(levels.room(4, 3).doors[1])
		check(sewer.area == 6, "in world 5 the chosen cave's inner door leads to the Technodrome room")
		sewer.world = 4
		sewer.area = 2
		sewer.enter_door(levels.room(4, 2).doors[1])
		check(sewer.area == 5, "and the other caves' inner doors lead to their own back rooms")
	sewer.free()

	print("ROM screen")
	var rom_path := "user://_test_fake.nes"
	var f := FileAccess.open(rom_path, FileAccess.WRITE)
	f.store_buffer(rom)
	f.close()
	var had_rom := FileAccess.file_exists(Game.ROM_PATH)
	var screen: Control = load("res://Scenes/UI/RomSelect.tscn").instantiate()
	add_child(screen)
	if had_rom:
		print("  skip  a real ROM is installed, so the copy step is not exercised")
	else:
		screen.handle_rom(ProjectSettings.globalize_path(rom_path))
		check(screen.ready_to_continue, "accepting a ROM waits for Enter")
		check(screen.status.text.contains("Fingerprint (SHA-1)"), "the fingerprint stays on screen")
		check(FileAccess.file_exists(Game.ROM_ASSETS_PATH.path_join("chr_bank_31.png")), "32 tile sheets are written")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.ROM_PATH))
		for i in 32:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.ROM_ASSETS_PATH.path_join("chr_bank_%02d.png" % i)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://rom_check.txt"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(rom_path))
	screen.free()

	print("FAILED: %d" % failures if failures > 0 else "ALL TESTS PASSED")
	get_tree().quit(1 if failures > 0 else 0)
