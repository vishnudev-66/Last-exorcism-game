extends Node
## NetHost - multiplayer host/join logic (Phase 8 scaffold).
## Desktop builds use ENet (UDP). Web/HTML5 builds have no UDP, so they use
## WebRTC signaling via a lobby relay ("wss://" service you host yourself).
## Server-authoritative: the host owns GameState mutations; clients send input
## requests and receive replicated state. See docs/MULTIPLAYER.md.

const PORT := 24570

enum Status { OFFLINE, HOSTING, JOINED }
var status: Status = Status.OFFLINE
var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed(reason: String)


func _is_web() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_linux") 		or OS.has_feature("web_macos") or OS.has_feature("web_windows") or OS.has_feature("web_ios")


func host_game(max_players := 5) -> Error:
	if _is_web():
		connection_failed.emit("Browser build: direct hosting needs a WebRTC signaling server. Use single-player.")
		return ERR_UNAVAILABLE
	peer = ENetMultiplayerPeer.new()
	var err := (peer as ENetMultiplayerPeer).create_server(PORT, max_players)
	if err != OK:
		connection_failed.emit("Port %d in use or unavailable." % PORT)
		return err
	_finish_connect()
	print("[Net] Hosting on port ", PORT)
	return OK


func join_game(address: String) -> Error:
	if _is_web():
		connection_failed.emit("Browser build cannot open raw sockets. Use single-player or a WebRTC relay.")
		return ERR_UNAVAILABLE
	peer = ENetMultiplayerPeer.new()
	var err := (peer as ENetMultiplayerPeer).create_client(address, PORT)
	if err != OK:
		connection_failed.emit("Cannot reach host at " + address)
		return err
	_finish_connect()
	print("[Net] Joining ", address)
	return OK


func _finish_connect() -> void:
	multiplayer.multiplayer_peer = peer
	status = Status.HOSTING if multiplayer.is_server() else Status.JOINED
	set_meta("local_slot", 0 if multiplayer.is_server() else 1)
	peer.peer_connected.connect(_on_connected)
	peer.peer_disconnected.connect(_on_disconnected)


func leave() -> void:
	if peer is not OfflineMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	status = Status.OFFLINE


func _on_connected(id: int) -> void:
	player_connected.emit(id)


## Graceful disconnect handling: slot marked "left", never crashes the session.
func _on_disconnected(id: int) -> void:
	for i in GameState.players.size():
		if int(GameState.players[i].get("peer_id", -1)) == id:
			GameState.set_player_state(i, "left")
	player_disconnected.emit(id)
