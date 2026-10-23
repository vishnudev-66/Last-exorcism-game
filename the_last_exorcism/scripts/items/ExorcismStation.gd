extends Interactable
class_name ExorcismStation
## Ritual site for one entity (kitchen circle, bridal alcove, catacomb throne).
## Validates the ordered steps stored in GameState.exorcisms; wrong order fails
## gracefully with hints instead of dead-ending (§8: never impossible configs).

@export var entity := "butcher"
@export var required_item_type := ""        # e.g. "holy_water"
@export var required_clue := ""             # clue id that must be discovered
@export var step_hint := "The circle stays cold. Something is missing."

var _glow: OmniLight3D


func _ready() -> void:
	_glow = get_node_or_null("Glow")
	GameState.exorcism_progressed.connect(func(e, _p):
		if e == entity and _glow:
			_glow.light_energy = 2.0)


func get_prompt(_player: PlayerController) -> String:
	var ex = GameState.exorcisms[entity]
	return "Perform rite (%d/%d)" % [ex["progress"], ex["steps"].size()]


func interact(player: PlayerController) -> bool:
	if not can_interact(player):
		return false
	var ex = GameState.exorcisms.get(entity)
	if ex == null or ex["complete"]:
		player.show_message("This place is quiet now.")
		return false
	# Gate 1: required clue discovered?
	if required_clue != "" and not GameState.clues.has(required_clue):
		player.show_message(step_hint)
		AudioDirector.interact_fail()
		return false
	# Gate 2: required item in inventory?
	if required_item_type != "" and not player.inventory.has_item(required_item_type):
		player.show_message("You need the proper elements (%s)." % required_item_type)
		AudioDirector.interact_fail()
		return false
	if required_item_type != "":
		# consume one stack unit
		for i in player.inventory.slots.size():
			var s = player.inventory.slots[i]
			if s != null and s.get("type", "") == required_item_type:
				player.inventory.remove_one(i)
				break
	var ok := GameState.advance_exorcism(entity)
	if ok:
		AudioDirector.exorcism_chime()
		player.show_message("A verse burns itself into the floor. The room listens.")
	if ex["complete"]:
		_complete(entity, player)
	return true


func _complete(_entity_name: String, _player: PlayerController) -> void:
	# Find the matching enemy and banish it; open sealed doors as designed.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is ButcherAI and _entity_name == "butcher":
			e.begin_banishment()
	GameState.set_objective("l3_exorcism", true)
	# Route change: first exorcism unseals the bedroom wing (controlled, §4).
	for d in get_tree().get_nodes_in_group("seals"):
		if d is Door and d.door_id == "bedroom_seal":
			d.unlock()
			d._toggle(true, null)
