extends Node
## Level1Script - orchestrates the Level 1 "Sealed Entrance" story beats:
## first haunting, entrance sealing (scripted emergency closure), whisper
## subtitles and the objective chain. Kept out of the player controller so
## every system stays modular (§14).

@export var seal_after_seconds := 6.0

var _player: PlayerController
var _entrance_door: Door


func _ready() -> void:
    GameState.discover_clue("l1_intro",
        "The Voss family vanished here in 1911. Their house still breathes.")
    GameState.set_objective("Find the flashlight", true)
    # Doors/players are spawned one frame later by the LevelBuilder, so poll
    # until both exist, then run the scripted beats.
    _poll_targets.call_deferred()


func _poll_targets() -> void:
    for _i in 120:  # up to ~2s at 60fps
        if _player == null:
            var ps := get_tree().get_nodes_in_group("players")
            if not ps.is_empty():
                _player = ps[0] as PlayerController
        if _entrance_door == null:
            _entrance_door = _find_door("EntranceDoor")
        if _player != null and _entrance_door != null:
            break
        await get_tree().process_frame
    if _entrance_door != null:
        get_tree().create_timer(seal_after_seconds).timeout.connect(_seal_entrance)


func _find_door(id: String) -> Door:
    for n in get_tree().get_nodes_in_group("interactable"):
        if n is Door and (n as Door).door_id == id.to_lower():
            return n as Door
    var lvl := get_tree().current_scene
    if lvl != null:
        return lvl.find_child(id, true, false) as Door
    return null


func _seal_entrance() -> void:
    if _entrance_door == null or not is_instance_valid(_entrance_door):
        return
    _entrance_door.slam_shut()
    _entrance_door.reseal()
    if GameSettings.subtitles_enabled:
        get_tree().call_group("hud", "show_subtitle",
            "[A voice, everywhere at once]: You were invited.")
    if _player != null and is_instance_valid(_player):
        _player.show_message("The front door SLAMS shut. The handle is frozen black.")
    GameState.set_objective("Survive. Find a way deeper into the house.", true)
