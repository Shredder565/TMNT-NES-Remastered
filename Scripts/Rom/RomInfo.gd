class_name RomInfo
extends RefCounted
## Reads a .nes file and decides whether it is the game we expect.
##
## A .nes file is: a 16-byte header, then the program code (PRG ROM), then the
## graphics tiles (CHR ROM). We check the header's shape first, then a SHA-1
## fingerprint of everything after the header.

const HEADER_SIZE := 16
const TRAINER_SIZE := 512
const PRG_UNIT := 16384  # header byte 4 counts PRG ROM in 16 KB units
const CHR_UNIT := 8192   # header byte 5 counts CHR ROM in 8 KB units

## What the TMNT cartridge looks like (sources: Data Crystal, NES Directory).
const EXPECTED_MAPPER := 1       # Nintendo MMC1
const EXPECTED_PRG_UNITS := 8    # 128 KB of code
const EXPECTED_CHR_UNITS := 16   # 128 KB of tiles

## SHA-1 of the file WITHOUT its 16-byte header -> a human name.
## The USA value is quoted from NES Directory and matched a real dump on
## 10 November 2026. Add more versions here once you have confirmed them.
const KNOWN_ROMS := {
	"b239c2d48e84ca676dee4461d4d6a1f77f34255d": "Teenage Mutant Ninja Turtles (USA)",
}
## SHA-1 of only the graphics block. Lets us say "the tiles are the USA tiles"
## even when the code differs.
const KNOWN_CHR := {
	"171ed0792f3ca3f195145000d96b91aa57898773": "USA graphics",
}

var ok_header := false       ## starts with "NES" + 0x1A and is long enough
var mapper := -1
var prg_units := 0
var chr_units := 0
var has_trainer := false
var sha1 := ""               ## fingerprint of everything after the header
var chr_sha1 := ""           ## fingerprint of the graphics block
var known_name := ""         ## filled in when sha1 is in KNOWN_ROMS
var chr_name := ""
var shape_matches := false   ## right mapper and sizes for TMNT
var accepted := false        ## good enough to use
var message := ""            ## plain-English result for the screen
var chr_rom := PackedByteArray()
var prg_rom := PackedByteArray()   ## the program code and level data

static func inspect_file(path: String) -> RomInfo:
	return inspect_bytes(FileAccess.get_file_as_bytes(path))

static func inspect_bytes(rom: PackedByteArray) -> RomInfo:
	var info := RomInfo.new()
	if rom.size() < HEADER_SIZE or rom[0] != 0x4E or rom[1] != 0x45 or rom[2] != 0x53 or rom[3] != 0x1A:
		info.message = "This is not a .nes file (the iNES header is missing)."
		return info
	info.prg_units = rom[4]
	info.chr_units = rom[5]
	info.has_trainer = (rom[6] & 0x04) != 0
	info.mapper = (rom[7] & 0xF0) | (rom[6] >> 4)
	var prg_start := HEADER_SIZE + (TRAINER_SIZE if info.has_trainer else 0)
	var chr_start := prg_start + info.prg_units * PRG_UNIT
	var chr_end := chr_start + info.chr_units * CHR_UNIT
	if rom.size() < chr_end:
		info.message = "The file is shorter than its header says. It may be damaged."
		return info
	info.ok_header = true
	info.chr_rom = rom.slice(chr_start, chr_end)
	info.prg_rom = rom.slice(prg_start, chr_start)
	info.sha1 = _sha1(rom.slice(prg_start, chr_end))
	info.chr_sha1 = _sha1(info.chr_rom)
	info.known_name = KNOWN_ROMS.get(info.sha1, "")
	info.chr_name = KNOWN_CHR.get(info.chr_sha1, "")
	info.shape_matches = (
		info.mapper == EXPECTED_MAPPER
		and info.prg_units == EXPECTED_PRG_UNITS
		and info.chr_units == EXPECTED_CHR_UNITS
	)
	if info.known_name != "":
		info.accepted = true
		info.message = "Verified: %s." % info.known_name
	elif info.shape_matches:
		# Right cartridge type but a fingerprint we have not recorded yet
		# (another region, a revision, or the quoted hash is wrong).
		info.accepted = true
		info.message = "Looks like TMNT (MMC1, 128 KB code, 128 KB graphics) but the fingerprint is not on the known list. Sprite maps made for the USA version may not line up."
	else:
		info.message = "This is a different game: mapper %d, %d KB code, %d KB graphics. TMNT is mapper 1, 128 KB, 128 KB." % [
			info.mapper, info.prg_units * 16, info.chr_units * 8]
	return info

static func _sha1(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(data)
	return ctx.finish().hex_encode()
