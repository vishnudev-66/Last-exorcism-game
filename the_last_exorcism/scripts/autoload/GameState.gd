extends Node
## GameState (autoload) - server-authoritative story/session state (sec 10).
## Objectives registry, clues/journal, three exorcism step-machines, per-player
## states, shared spiritual energy, ending computation A/B/C/D (sec 12).

enum PlayerState { ALIVE, DOWNED, GHOST, LEFT }

signal objective_updated(id, done)
signal clue_added(clue_id, text)
signal player_state_changed(index, new_state)
signal exorcism_progressed(entity_id, step)
signal spirit_changed(value)

var difficulty := 1.0

## Objective registry: id -> {text, done}. Completed ids flip done=true.
var objectives := {
	"l1_flashlight": {"text": "Find the flashlight in the entrance hall.", "done": false},
	"l1_door": {"text": "Unlock the hallway door and go deeper.", "done": false},
	"l3_exorcism": {"text": "Complete the Butcher's exorcism at the ritual circle.", "done": false},
}

var exorcisms := {
	"butcher": {"name": "The Butcher", "steps": ["identify_identity", "gather_holy_water", "prepare_salt_circle", "speak_rite"], "done": 0},
	"bride": {"name": "The Weeping Bride", "steps": ["recover_wedding_relic", "arrange_candles", "reconstruct_final_night", "speak_rite"], "done": 0},
	"hollow_king": {"name": "The Hollow King", "steps": ["recover_artifact_1", "recover_artifact_2", "recover_artifact_3", "read_original_rite", "speak_rite"], "done": 0},
}

var clues := {}              # clue_id -> text
var current_objective := ""

var players: Array[Dictionary] = []
var spirit_energy := 100.0
var spirit_max := 100.0

var truth_found := false
var ritual_corrupted := false
var sacrifice_offered := false
var all_banished := false


func _init() -> void:
	register_player_count(5)
	current_objective = String(objectives["l1_flashlight"]["text"])


func register_player_count(n: int) -> void:
	players.clear()
	for i in range(maxi(1, n)):
		players.append({"name": "Friend %d" % (i + 1), "state": PlayerState.ALIVE, "peer_id": -1})


## Set or complete an objective. Accepts both calling styles used across the
## codebase: set_objective(id, done) or set_objective(free_text).
func set_objective(id_or_text: String, done: bool = false) -> void:
	if objectives.has(id_or_text):
		objectives[id_or_text]["done"] = done or true
		current_objective = String(objectives[id_or_text]["text"])
	else:
		# free-form text: register it dynamically
		var nid := "obj_%d" % objectives.size()
		objectives[nid] = {"text": id_or_text, "done": done}
		current_objective = id_or_text
	objective_updated.emit(id_or_text, done)


func discover_clue(cid: String, text: String) -> void:
	if clues.has(cid):
		return
	clues[cid] = text
	clue_added.emit(cid, text)


func add_clue(cid: String, title: String, body: String) -> void:
	discover_clue(cid, title + " - " + body)


func journal_text() -> String:
	var t := "== EXORCISM BOOK ==\n\n"
	for eid in exorcisms:
		var d: Dictionary = exorcisms[eid]
		t += "--- %s (%d/%d) ---\n" % [d["name"], d["done"], (d["steps"] as Array).size()]
		var steps: Array = d["steps"]
		for i in steps.size():
			t += ("  [x] " if i < int(d["done"]) else "  [ ] ") + String(steps[i]) + "\n"
	t += "\n== CLUES ==\n"
	for cid in clues:
		t += "- " + String(clues[cid]) + "\n"
	return t


func advance_exorcism(eid: String, step: String) -> bool:
	if not exorcisms.has(eid):
		return false
	var d: Dictionary = exorcisms[eid]
	var steps: Array = d["steps"]
	if int(d["done"]) >= steps.size():
		return false
	if steps[int(d["done"])] != step:
		return false  # strict ordering; caller shows a hint instead
	d["done"] = int(d["done"]) + 1
	exorcism_progressed.emit(eid, d["done"])
	if d["done"] == steps.size():
		check_all_banished()
	return true


func next_exorcism_step(eid: String) -> String:
	if not exorcisms.has(eid):
		return ""
	var d: Dictionary = exorcisms[eid]
	var steps: Array = d["steps"]
	if int(d["done"]) >= steps.size():
		return ""
	return String(steps[int(d["done"])])


func exorcism_done(eid: String) -> bool:
	var d: Dictionary = exorcisms[eid]
	return int(d["done"]) >= (d["steps"] as Array).size()


func check_all_banished() -> void:
	all_banished = exorcism_done("butcher") and exorcism_done("bride") and exorcism_done("hollow_king")


## State may be passed as string ("alive"/"downed"/"ghost"/"left") or enum int.
func set_player_state(index: int, st) -> void:
	if index < 0 or index >= players.size():
		return
	var code := _state_code(st)
	players[index]["state"] = code
	player_state_changed.emit(index, code)


func _state_code(st) -> int:
	if st is String:
		match st:
			"alive": return PlayerState.ALIVE
			"downed": return PlayerState.DOWNED
			"ghost": return PlayerState.GHOST
			"left": return PlayerState.LEFT
		return PlayerState.ALIVE
	return int(st)


func alive_count() -> int:
	var c := 0
	for p in players:
		if int(p["state"]) == PlayerState.ALIVE:
			c += 1
	return c


func ghost_count() -> int:
	var c := 0
	for p in players:
		if int(p["state"]) == PlayerState.GHOST:
			c += 1
	return c


func spend_spirit(amount: float) -> bool:
	if spirit_energy < amount:
		return false
	spirit_energy -= amount
	spirit_changed.emit(spirit_energy)
	return true


func regen_spirit(dt: float) -> void:
	if spirit_energy < spirit_max:
		spirit_energy = minf(spirit_max, spirit_energy + dt * 2.0)
		spirit_changed.emit(spirit_energy)


## Ending decision (sec 12). Evaluated at the final door.
func compute_ending() -> String:
	if all_banished and ritual_corrupted:
		return "D"
	if not all_banished:
		return "B"
	if sacrifice_offered:
		return "C"
	if truth_found and clues.size() >= 6:
		return "A"
	return "B"


func reset_run() -> void:
	difficulty = 1.0
	for eid in exorcisms:
		exorcisms[eid]["done"] = 0
	clues.clear()
	for oid in ["l1_flashlight", "l1_door", "l3_exorcism"]:
		if objectives.has(oid):
			objectives[oid]["done"] = false
	register_player_count(5)
	spirit_energy = spirit_max
	truth_found = false
	ritual_corrupted = false
	sacrifice_offered = false
	all_banished = false
