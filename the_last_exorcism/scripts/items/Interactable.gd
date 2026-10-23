extends Node
class_name Interactable
## Base class for anything the player can interact with (E key).
## Subclasses override `interact()`. The HUD reads `prompt_text` each frame to
## show "Press E ..." prompts when the player's raycast hovers this node.

@export var prompt_text := "Interact"
@export var enabled := true
@export var one_shot := false      # disappears after successful use
@export var single_use_done := false

signal used(player: PlayerController)


func can_interact(_player: PlayerController) -> bool:
	return enabled and not (one_shot and single_use_done)


## Called by the player controller on E press. Return true if the interaction
## was valid (consumes the input + plays success sound). Invalid interactions
## must fail gracefully with a message, never crash.
func interact(player: PlayerController) -> bool:
	if not can_interact(player):
		return false
	single_use_done = single_use_done or one_shot
	used.emit(player)
	return true


func get_prompt(_player: PlayerController) -> String:
	return prompt_text
