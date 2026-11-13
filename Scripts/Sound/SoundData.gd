class_name SoundData
extends RefCounted
## Finds the sound and music data in the player's ROM. Nothing is copied
## into the project: every table here is looked up in the ROM when the game
## runs. Research/sound.md says what each table is.
##
## The sound program and all its data are in program bank 0; the one drum
## sample is in bank 7. Addresses are the console's: $8000-$BFFF is bank 0,
## $C000-$FFFF is bank 7.

const T_TABLE_POINTER := 0x9014   ## the word here is the address of the table of sounds
const T_PITCHES := 0x8FE4         ## 24 notes, two bytes each (the chip's pitch number)
const T_LOW_PITCHES := 0x8FCC     ## the 12 notes below those
const T_SHAPES := 0xBEB0          ## addresses of the loudness-shape tables
const T_WOBBLES := 0xBEE2         ## addresses of the pitch-wobble tables
const T_DRUMS := 0x89C1           ## per drum number: the effect (or sample) it starts
const T_SAMPLES := 0xFE41         ## per sample: the four values for $4010-$4013

const T_OVERWORLD_TUNES := 0xCC0C ## per world: the overworld's tune
const T_ROOM_TUNES := 0xCC12      ## per world: the tune of its rooms
const ODD_ROOM_WORLD := 1         ## this world's room 0 has a tune of its own ...
const ODD_ROOM_TUNE := 0x6B       ## ... this one (the number is in the program at 7:$CBF7, not in a table)

const SLOTS := 6
const FIRST_TUNE := 0x4B          ## numbers from here on silence everything before they start
const FIRST_SAMPLE := 0x8F        ## numbers from here on are samples
const MUSIC_FIRST_BYTE := 0x30    ## data starting with a byte below this is in the effects' format

var prg: PackedByteArray

func _init(prg_rom: PackedByteArray) -> void:
	prg = prg_rom

## The whole program part of a ROM file's bytes (the file has a 16-byte
## header in front), or an empty array if the file is too short.
static func prg_of_file(file_bytes: PackedByteArray) -> PackedByteArray:
	if file_bytes.size() < 16 + 0x20000:
		return PackedByteArray()
	return file_bytes.slice(16, 16 + 0x20000)

## True when there is enough here to read sounds from.
func usable() -> bool:
	if prg.size() < 0x20000:
		return false
	var table := word(T_TABLE_POINTER)
	return table >= 0x8000 and table < 0xC000

func byte(address: int) -> int:
	address &= 0xFFFF
	if address >= 0xC000:
		return prg[0x1C000 + (address - 0xC000)]
	return prg[address & 0x3FFF]

func word(address: int) -> int:
	return byte(address) | (byte(address + 1) << 8)

## The voices of sound `number`: a list of [slot, address of its data].
## The table has three bytes for each number: a byte whose bits 0-2 are the
## slot and bits 3-4 how many of the following entries also belong to this
## sound, then the address.
func voices(number: int) -> Array:
	var list: Array = []
	var entry := word(T_TABLE_POINTER) + number * 3
	var more := (byte(entry) >> 3) & 3
	for i in more + 1:
		var slot := byte(entry + i * 3) & 7
		list.append([slot, word(entry + i * 3 + 1)])
	return list

## True when the data at `address` is written in the effects' format.
func is_effect_format(address: int) -> bool:
	return byte(address) < MUSIC_FIRST_BYTE

func shape_table(number: int) -> int:
	return word(T_SHAPES + number * 2)

func wobble_table(number: int) -> int:
	return word(T_WOBBLES + number * 2)

## What drum `drum` (0-11) of a drum track starts: an effect number, or a
## sample number (FIRST_SAMPLE and up).
func drum_sound(drum: int) -> int:
	return byte(T_DRUMS + drum)

## The four chip values of sample `sample` (for $4010, $4011, $4012, $4013).
func sample_values(sample: int) -> PackedByteArray:
	var values := PackedByteArray()
	for i in 4:
		values.append(byte(T_SAMPLES + sample * 4 + i))
	return values

## The tune of a place (7:$CBE7): the world's overworld tune, or the tune
## of its rooms.
func area_tune(world: int, area: int, inside: bool) -> int:
	if not inside:
		return byte(T_OVERWORLD_TUNES + world)
	if world == ODD_ROOM_WORLD and area == 0:
		return ODD_ROOM_TUNE
	return byte(T_ROOM_TUNES + world)
