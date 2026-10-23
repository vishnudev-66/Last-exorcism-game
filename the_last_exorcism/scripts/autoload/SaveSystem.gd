extends Node
## SaveSystem autoload - simple JSON save/load for story + puzzle state.
## Saves are versioned; unknown/missing keys fall back to defaults so old saves
## never crash the game after content updates.

const SAVE_PATH := "user://save_slot_%d.json"
const SAVE_VERSION := 1


func save_game(slot: int = 0) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"level": GameState.current_level,
		"objectives": _plain(GameState.objectives),
		"clues": GameState.clues.duplicate(true),
		"journal": GameState.journal_entries.duplicate(true),
		"exorcisms": _plain(GameState.exorcisms),
		"puzzle_flags": GameState.puzzle_flags.duplicate(true),
		"players": GameState.players.duplicate(true),
		"ghost_slot": GameState.ghost_slot,
		"spiritual_energy": GameState.spiritual_energy,
		"evidence_found": GameState.evidence_found,
	}
	var f := FileAccess.open(SAVE_PATH % slot, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: cannot open " + SAVE_PATH % slot)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_game(slot: int = 0) -> bool:
	var path := SAVE_PATH % slot
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Corrupt save file ignored: " + path)
		return false
	# Merge defensively - only overwrite keys we still recognize.
	for key in ["objectives", "clues", "exorcisms", "puzzle_flags"]:
		if parsed.has(key) and typeof(parsed[key]) == TYPE_DICTIONARY:
			GameState[key].merge(parsed[key], true)
	if parsed.has("journal"):
		GameState.journal_entries = parsed["journal"]
	if parsed.has("players"):
		GameState.players = parsed["players"]
	GameState.current_level = int(parsed.get("level", GameState.current_level))
	GameState.ghost_slot = int(parsed.get("ghost_slot", -1))
	GameState.spiritual_energy = float(parsed.get("spiritual_energy", 100.0))
	GameState.evidence_found = int(parsed.get("evidence_found", 0))
	return true


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(SAVE_PATH % slot)


func delete_save(slot: int = 0) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH % slot))


## Deep-copy nested Dictionary/Array structures into plain JSON-safe variants.
func _plain(v):
	return JSON.parse_string(JSON.stringify(v))
