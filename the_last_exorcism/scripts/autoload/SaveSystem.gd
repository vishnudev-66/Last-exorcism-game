extends Node
## SaveSystem autoload - simple JSON save/load for story + puzzle state.
## Saves are versioned; unknown/missing keys fall back to defaults so old saves
## never crash the game after content updates. Works on desktop and Web
## (IndexedDB-backed user:// in HTML5 exports).

const SAVE_PATH := "user://save_slot_%d.json"
const SAVE_VERSION := 2


func save_game(slot: int = 0) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"objectives": GameState.objectives,
		"clues": GameState.clues,
		"exorcisms": GameState.exorcisms,
		"players": GameState.players,
		"spirit_energy": GameState.spirit_energy,
		"flags": {
			"truth_found": GameState.truth_found,
			"ritual_corrupted": GameState.ritual_corrupted,
			"sacrifice_offered": GameState.sacrifice_offered,
		},
	}
	var f := FileAccess.open(SAVE_PATH % slot, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: cannot open " + SAVE_PATH % slot)
		return false
	f.store_string(JSON.stringify(data))
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
	for key in ["objectives", "clues", "exorcisms"]:
		if parsed.has(key) and typeof(parsed[key]) == TYPE_DICTIONARY:
			GameState[key].merge(parsed[key], true)
	if parsed.has("players") and typeof(parsed["players"]) == TYPE_ARRAY:
		if (parsed["players"] as Array).size() > 0:
			GameState.players.clear()
			for p in parsed["players"]:
				if typeof(p) == TYPE_DICTIONARY:
					GameState.players.append(p)
	GameState.spirit_energy = float(parsed.get("spirit_energy", 100.0))
	if parsed.has("flags") and typeof(parsed["flags"]) == TYPE_DICTIONARY:
		var fl: Dictionary = parsed["flags"]
		GameState.truth_found = bool(fl.get("truth_found", false))
		GameState.ritual_corrupted = bool(fl.get("ritual_corrupted", false))
		GameState.sacrifice_offered = bool(fl.get("sacrifice_offered", false))
	GameState.check_all_banished()
	return true


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(SAVE_PATH % slot)
