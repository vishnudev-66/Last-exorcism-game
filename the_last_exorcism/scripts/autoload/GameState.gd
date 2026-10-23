extends Node
## GameState autoload - single source of truth for story/objective/puzzle state.
## In multiplayer this node is server-authoritative; clients request changes via RPC
## (see scripts/net/ for the synchronization layer added in Phase 8).

signal objective_updated(id: String, done: bool)
signal clue_discovered(clue_id: String)
signal exorcism_progressed(entity: String, step: int)
signal level_advanced(level: int)
signal player_state_changed(index: int, state: String)
signal ending_ready(ending: String)

enum Level { MENU, L1_SEALED_ENTRANCE, L2_SERVANTS, L3_KITCHEN, L4_BEDROOM,
	L5_NURSERY, L6_LIBRARY, L7_CHAPEL, L8_BASEMENT, L9_CATACOMBS,
	L10_FINAL_EXORCISM, L11_LAST_DOOR }

const MAX_PLAYERS := 10  # prototype ships tuned for 5; architecture allows 10

# ---- Objectives -------------------------------------------------------------
var objectives := {
	"l1_flashlight": {"text": "Find the flashlight in the entrance hall", "done": false},
	"l1_door": {"text": "Unlock the servants' corridor door", "done": false},
	"l2_butcher_key": {"text": "Recover the iron key from the servants' quarters", "done": false},
	"l3_holy_water": {"text": "Prepare holy water and salt for the Butcher ritual", "done": false},
	"l3_exorcism": {"text": "Perform the first exorcism in the kitchen", "done": false},
}

# ---- Clues / journal --------------------------------------------------------
var clues := {}          # clue_id -> discovered text
var journal_entries := []

# ---- Exorcisms --------------------------------------------------------------
# Each entity has ordered ritual steps; completing them out of order fails safely.
var exorcisms := {
	"butcher": {"steps": ["identify_name", "gather_weakness", "draw_circle", "banish"],
				"progress": 0, "complete": false},
	"bride": {"steps": ["recover_relic", "arrange_candles", "reconstruct_night", "banish"],
			  "progress": 0, "complete": false},
	"hollow_king": {"steps": ["artifacts_1", "artifacts_2", "artifacts_3", "read_original_ritual", "banish"],
					"progress": 0, "complete": false},
}

# ---- Players ----------------------------------------------------------------
# Per-slot status used by UI + ghost system. States: alive / downed / ghost / left
var players: Array = []

func _init() -> void:
	# Top-level `for` loops are illegal in a GDScript class body; build the
	# player slots in the constructor instead.
	for _i in MAX_PLAYERS:
		players.append({"name": "", "state": "alive", "health": 100.0})

# ---- Puzzle flags (persisted by SaveSystem) ---------------------------------
var puzzle_flags := {}   # e.g. {"kitchen_circuit_repaired": true}
var visited_levels := {}
var current_level: int = Level.L1_SEALED_ENTRANCE

# ---- Ghost friend -----------------------------------------------------------
var ghost_slot := -1                 # which player index became the ghost
var spiritual_energy := 100.0        # shared ghost resource pool
const GHOST_ENERGY_MAX := 100.0

# ---- Ending tracking ---------------------------------------------------------
var evidence_found := 0
var evidence_total := 12             # set fully when mansion content lands
var sacrifice_made := false
var corrupted_ritual := false


func _ready() -> void:
	# Prototype convenience: name local slots.
	for i in 5:
		players[i]["name"] = "Friend %d" % (i + 1)


func set_objective(id: String, done: bool) -> void:
	if not objectives.has(id):
		push_warning("Unknown objective id: " + id)
		return
	objectives[id]["done"] = done
	objective_updated.emit(id, done)


func discover_clue(clue_id: String, text: String) -> void:
	if clues.has(clue_id):
		return  # already found - prevents duplicate journal spam
	clues[clue_id] = text
	journal_entries.append({"id": clue_id, "text": text})
	evidence_found += 1
	clue_discovered.emit(clue_id)


func advance_exorcism(entity: String) -> bool:
	var ex = exorcisms.get(entity)
	if ex == null or ex["complete"]:
		return false
	ex["progress"] += 1
	exorcism_progressed.emit(entity, ex["progress"])
	if ex["progress"] >= ex["steps"].size():
		ex["complete"] = true
	return true


func set_player_state(index: int, state: String) -> void:
	if index < 0 or index >= players.size():
		return
	players[index]["state"] = state
	if state == "ghost":
		ghost_slot = index
	player_state_changed.emit(index, state)


func living_count() -> int:
	var n := 0
	for p in players:
		if p["state"] == "alive" or p["state"] == "downed":
			n += 1
	return n


func compute_ending() -> String:
	## Endings depend on actual play: see docs/STORY.md.
	var all_banished: bool = exorcisms["butcher"]["complete"] \
		and exorcisms["bride"]["complete"] and exorcisms["hollow_king"]["complete"]
	if all_banished and evidence_found >= evidence_total * 0.8 and not corrupted_ritual:
		return "A_FRIENDSHIP"
	if corrupted_ritual:
		return "D_HOLLOW_SUCCESSOR"
	if sacrifice_made:
		return "C_SACRIFICE"
	return "B_FORGOTTEN"


func announce_ending() -> void:
	ending_ready.emit(compute_ending())
