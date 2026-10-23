extends Interactable
class_name ClueNote
## Readable environmental clue (letters, diaries, ledgers). Adds a journal entry
## and can complete objectives / unlock exorcism gates via GameState.

@export var clue_id := "note_generic"
@export var clue_text := "A damp page, half-rotted."
@export var completes_objective := ""


func interact(player: PlayerController) -> bool:
	if not can_interact(player):
		return false
	var fresh := not GameState.clues.has(clue_id)
	GameState.discover_clue(clue_id, clue_text)
	if completes_objective != "":
		GameState.set_objective(completes_objective, true)
	player.show_message(clue_text)
	get_tree().call_group("hud", "show_subtitle", "[Reading] " + clue_text)
	if fresh:
		AudioDirector.whisper()
	return true
