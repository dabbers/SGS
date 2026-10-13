class_name NetSession
extends GameSession
## Server-authoritative multiplayer over ENet using Godot's high-level
## multiplayer API. One script plays both roles so RPC paths match.
##
## Host:   host(port) -> players join -> start_game(config)
## Client: join(address, port) -> wait for synced/prompt signals
##
## Only prompt responses travel client->server; the server validates them in
## CardEngine.respond. Clients never see hidden cards (snapshots are filtered
## per viewer on the host).

const DEFAULT_PORT := 7777

var host_runner: GameHost
var peer_seats: Dictionary = {}     ## peer_id -> seat (host only)
var seat_peers: Dictionary = {}     ## seat -> peer_id (host only)
var _peer_names: Dictionary = {}    ## peer_id -> name (host only)
var _bot_seats_after_humans: int = 0


func host(port: int = DEFAULT_PORT, p_name: String = "Host", bot_fill: int = 0) -> Error:
	my_name = p_name
	is_host = true
	_bot_seats_after_humans = bot_fill
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 8)
	if err != OK:
		error.emit("Could not host on port %d (%s)" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	peer_seats[1] = 0
	seat_peers[0] = 1
	_peer_names[1] = p_name
	my_seat = 0
	_broadcast_lobby()
	return OK


func join(address: String, port: int = DEFAULT_PORT, p_name: String = "Guest") -> Error:
	my_name = p_name
	is_host = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		error.emit("Could not connect to %s:%d (%s)" % [address, port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func(): _rpc_hello.rpc_id(1, my_name))
	multiplayer.connection_failed.connect(func(): error.emit("Connection failed"))
	multiplayer.server_disconnected.connect(func(): error.emit("Host disconnected"))
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	super()


# --- lobby (host) ------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	var seat := seat_peers.size()
	peer_seats[id] = seat
	seat_peers[seat] = id
	_peer_names[id] = "Player %d" % (seat + 1)
	if host_runner != null:
		# Late join / reconnect into a running game: seat must already exist.
		_rpc_seat.rpc_id(id, seat)
		host_runner.resync(seat)
	else:
		_rpc_seat.rpc_id(id, seat)
		_broadcast_lobby()


func _on_peer_disconnected(id: int) -> void:
	if not is_host or not peer_seats.has(id):
		return
	var seat: int = peer_seats[id]
	peer_seats.erase(id)
	if host_runner == null:
		seat_peers.erase(seat)
		_peer_names.erase(id)
		# compact seats
		var ordered := seat_peers.keys()
		ordered.sort()
		var new_seat_peers := {}
		var new_peer_seats := {}
		var s := 0
		for old_seat in ordered:
			var pid: int = seat_peers[old_seat]
			new_seat_peers[s] = pid
			new_peer_seats[pid] = s
			if pid != 1:
				_rpc_seat.rpc_id(pid, s)
			s += 1
		seat_peers = new_seat_peers
		peer_seats = new_peer_seats
		_broadcast_lobby()
	else:
		seat_peers.erase(seat)   # keeps the seat reserved for reconnect


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(p_name: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	_peer_names[id] = p_name
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	var list := []
	var seats := seat_peers.keys()
	seats.sort()
	for s in seats:
		list.append({"seat": s, "name": _peer_names.get(seat_peers[s], "?"), "is_bot": false})
	for b in _bot_seats_after_humans:
		list.append({"seat": seats.size() + b, "name": "Bot %d" % (b + 1), "is_bot": true})
	lobby = list
	lobby_changed.emit(list)
	_rpc_lobby.rpc(list)


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(list: Array) -> void:
	lobby = list
	lobby_changed.emit(list)


@rpc("authority", "call_remote", "reliable")
func _rpc_seat(seat: int) -> void:
	my_seat = seat


# --- game ----------------------------------------------------------------------

func start_game(config: Dictionary = {}) -> void:
	assert(is_host)
	var cfg := config.duplicate(true)
	var names := []
	var bots := []
	for entry in lobby:
		names.append(entry["name"])
		if entry["is_bot"]:
			bots.append(int(entry["seat"]))
	cfg["players"] = names
	cfg["bots"] = bots
	host_runner = GameHost.new()
	host_runner.sync_for_viewer.connect(_on_host_sync)
	host_runner.finished.connect(func(res): _rpc_game_over.rpc(res); game_over.emit(res))
	_rpc_started.rpc()
	game_started.emit()
	host_runner.start(cfg)


func _on_host_sync(viewer: int, snap: Dictionary, prompt_dict: Variant, events: Array) -> void:
	if viewer == my_seat:
		_apply_sync(snap, prompt_dict, events)
	elif seat_peers.has(viewer):
		_rpc_sync.rpc_id(seat_peers[viewer], snap, prompt_dict, events)


func submit(prompt_id: int, response: Dictionary) -> void:
	if is_host:
		if not host_runner.respond(my_seat, prompt_id, response):
			error.emit("That response was not accepted.")
	else:
		_rpc_submit.rpc_id(1, prompt_id, response)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit(prompt_id: int, response: Dictionary) -> void:
	if not is_host or host_runner == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peer_seats.has(id):
		return
	var seat: int = peer_seats[id]
	if not host_runner.respond(seat, prompt_id, response):
		_rpc_error.rpc_id(id, "That response was not accepted.")


@rpc("authority", "call_remote", "reliable")
func _rpc_started() -> void:
	game_started.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_sync(snap: Dictionary, prompt_dict: Variant, events: Array) -> void:
	_apply_sync(snap, prompt_dict, events)


@rpc("authority", "call_remote", "reliable")
func _rpc_game_over(result: Dictionary) -> void:
	game_over.emit(result)


@rpc("authority", "call_remote", "reliable")
func _rpc_error(message: String) -> void:
	error.emit(message)
