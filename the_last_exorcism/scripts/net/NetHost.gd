extends Node
## NetHost autoload - ENet multiplayer host/join logic (Phase 8).
## Server-authoritative: the host owns GameState mutations; clients send input
## and receive replicated state. See docs/MULTIPLAYER.md for test procedure.

const PORT := 24570

enum Status { OFFLINE, HOSTING, JOINED }
var status: Status = Status.OFFLINE
var peer := ENetMultiplayerPeer.new()

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed(reason: String)


func host_game(max_players := 5) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, max_players)
	if err != OK:
		connection_failed.emit("Port %d in use or unavailable." % PORT)
		return err
	multiplayer.multiplayer_peer = peer
	status = Status.HOSTING
	set_meta("local_slot", 0)
	peer.peer_connected.connect(_on_connected)
	peer.peer_disconnected.connect(_on_disconnected)
	print("[Net] Hosting on port ", PORT)
	return OK


func join_game(address: String) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		connection_failed.emit("Cannot reach host at " + address)
		return err
	multiplayer.multiplayer_peer = peer
	status = Status.JOINED
	# Clients derive a stable local slot from their ENet peer id.
	set_meta("local_slot", 1 + multiplayer.get_unique_id() % 4)
	peer.peer_connected.connect(_on_connected)
	peer.peer_disconnected.connect(_on_disconnected)
	print("[Net] Joining ", address)
	return OK


func leave() -> void:
	peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	status = Status.OFFLINE


func _on_connected(id: int) -> void:
	player_connected.emit(id)


## Graceful disconnect handling: slot marked "left", never crashes the session.
func _on_disconnected(id: int) -> void:
	for i in GameState.players.size():
		if GameState.players[i].get("peer_id", -1) == id:
			GameState.set_player_state(i, "left")
	player_disconnected.emit(id)
