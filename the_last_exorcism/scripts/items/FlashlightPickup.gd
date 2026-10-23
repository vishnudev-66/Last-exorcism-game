extends Interactable
class_name FlashlightPickup
## The Level 1 objective item. Picking it up hands the player a working
## flashlight (enables the SpotLight) and completes the first objective.

@export var battery_amount := 100.0


func interact(player: PlayerController) -> bool:
	if not can_interact(player):
		return false
	player.battery = battery_amount
	var light := player.get_node_or_null("Head/Camera/Flashlight")
	if light:
		light.visible = true
	GameState.set_objective("l1_flashlight", true)
	AudioDirector.pickup()
	player.show_message("The flashlight sputters to life. [F] toggles it.")
	return true
