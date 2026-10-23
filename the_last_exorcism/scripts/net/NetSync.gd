extends Node
## NetSync - replication layer attached to the level root in multiplayer runs.
## RPCs carry authoritative events from host to every peer. IMPORTANT design
## rule: enemy AI & damage are simulated ONLY on the host (server-authoritative),
## then broadcast. Clients never own authoritative state.

var is_server := false


func _ready() -> void:
	is_server = multiplayer.has_multiplayer_peer() and multiplayer.is_server()


# --- Client -> server requests (validated server-side before applying) --------
@rpc("any_peer", "call_local", "reliable")
func request_interact(target_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var node := get_node_or_null(target_path)
	if node == null:
		return  # stale path after scene change - ignore gracefully
	var sender := multiplayer.get_remote_sender_id()
	var player := _player_by_peer(sender)
	if player != null and node.has_method("interact"):
		node.interact(player)


@rpc("authority", "call_local", "reliable")
func broadcast_objective(id: String, done: bool) -> void:
	GameState.set_objective(id, done)


@rpc("authority", "call_local", "reliable")
func broadcast_clue(clue_id: String, text: String) -> void:
	GameState.discover_clue(clue_id, text)


@rpc("authority", "call_local", "reliable")
func broadcast_player_state(index: int, state: String) -> void:
	GameState.set_player_state(index, state)


func _player_by_peer(peer_id: int) -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == peer_id:
			return p
	return null
