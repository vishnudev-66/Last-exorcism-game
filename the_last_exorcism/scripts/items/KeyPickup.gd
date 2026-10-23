extends Interactable
class_name KeyPickup
## A key item that unlocks a specific door (matched by `door_id`).
## Duplicate pickup prevention lives in Inventory.add_item stacking + one_shot.

@export var door_id := ""
@export var key_name := "Rusty Key"


func interact(player: PlayerController) -> bool:
	if not can_interact(player):
		return false
	var ok := player.inventory.add_item({"type": "key", "id": door_id, "name": key_name})
	if not ok:
		player.show_message("Your hands are full.")
		return false
	AudioDirector.pickup()
	GameState.discover_clue("key_" + door_id, "Picked up the %s." % key_name)
	return true
