extends Interactable
class_name SupplyPickup
## Generic usable supply: holy water vials, medkits, batteries, the book, chalk...
## `item_type` maps to PlayerController.use_selected_item behaviour.

@export var item_type := "holy_water"
@export var item_display := "Holy Water"
@export var stackable := true


func interact(player: PlayerController) -> bool:
	if not can_interact(player):
		return false
	var item := {"type": item_type, "id": item_type, "name": item_display}
	if stackable:
		item["count"] = 1
	var ok := player.inventory.add_item(item)
	if not ok:
		player.show_message("Your satchel is full. Drop something first.")
		AudioDirector.interact_fail()
		return false
	AudioDirector.pickup()
	player.show_message("Took the %s." % item_display)
	if item_type == "book":
		GameState.set_objective("l1_flashlight", GameState.objectives["l1_flashlight"]["done"])
		player.show_message("The Exorcism Book hums. Press J to read what it records.")
	return true
