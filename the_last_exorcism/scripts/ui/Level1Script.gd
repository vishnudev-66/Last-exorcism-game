extends Node
## Level1Script - orchestrates the Level 1 "Sealed Entrance" story beats:
## first haunting, entrance sealing (scripted emergency closure), whisper
## subtitles and the objective chain. Kept out of the player controller so
## every system stays modular (§14).

@export var entrance_door_path := NodePath("EntranceDoor")
@export var seal_after_seconds := 6.0

var _player: PlayerController
var _entrance_door: Door


func _ready() -> void:
	_entrance_door = get_node_or_null(entrance_door_path) as Door
	for p in get_tree().get_nodes_in_group("players"):
		_player = p
		break
	if _player:
		_player.tree_entered.connect(func(): pass)
	# First haunting: a distant whisper + subtitle after a few seconds.
	get_tree().create_timer(seal_after_seconds).timeout.connect(_seal_entrance)
	GameState.discover_clue("l1_intro",
		"The Voss family vanished here in 1911. Their house still breathes.")


func _seal_entrance() -> void:
	if _entrance_door == null:
		return
	_entrance_door.slam_shut()
	_entrance_door.reseal()
	if GameSettings.subtitles_enabled:
		get_tree().call_group("hud", "show_subtitle",
			"[A voice, everywhere at once]: You were invited.")
	GameState.set_objective("l1_flashlight", false)
