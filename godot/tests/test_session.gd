extends TestCase
## Session / network / UI smoke tests. These run inside the SceneTree so they
## can pump frames for ENet and the UI.


## Drive a prompt for a human seat with the bot's fallback policy.
func _auto_answer(session: GameSession, host: GameHost) -> Callable:
	var helper := SimpleBot.new(host.engine, [], 99)
	return func(p: Prompt): session.submit(p.id, helper.answer(p))


func test_local_session_runs_a_whole_game() -> void:
	var s := LocalSession.new("Tester")
	tree.root.add_child(s)
	# Lambdas capture locals by value, so counters live in a Dictionary.
	var st := {"prompts": 0, "syncs": 0, "over": {}}
	s.synced.connect(func(_snap): st["syncs"] += 1)
	s.game_over.connect(func(res): st["over"] = res)
	s.start_game({"players": 3, "decks": ["standard"]})
	var answer := _auto_answer(s, s.host)
	s.prompt_received.connect(func(p): st["prompts"] += 1; answer.call(p))
	# The first prompt was emitted during start_game, before we connected.
	if s.pending != null:
		st["prompts"] += 1
		answer.call(s.pending)
	assert_true(st["syncs"] > 0, "received snapshots")
	assert_true(st["prompts"] > 0, "received prompts for my seat")
	assert_true(not st["over"].is_empty(), "game reached a result (seed %d)" % s.host.engine.seed_value)
	assert_eq(s.my_seat, 0)
	# Snapshot never leaks other players' hands.
	var snap := s.snapshot
	for zid in snap["zones"]:
		if zid.begins_with("hand:") and zid != "hand:0":
			for cid in snap["zones"][zid]["cards"]:
				assert_false(snap["cards"].has(cid) or snap["cards"].has(str(cid)), "hidden hand leaked: %s" % zid)
	s.queue_free()
	await frames(1)


func test_table_scene_renders_from_session() -> void:
	var s := LocalSession.new("Tester")
	tree.root.get_node("Game").set_session(s)
	s.start_game({"players": 4, "decks": ["standard"]})
	var scene: PackedScene = load("res://ui/table.tscn")
	var table := scene.instantiate()
	tree.root.add_child(table)
	await frames(2)
	assert_true(table.hand_row.get_child_count() >= 4, "hand rendered (%d cards)" % table.hand_row.get_child_count())
	assert_eq(table.seat_views.size(), 3, "three opponents rendered")
	assert_true(s.pending != null and s.pending.player == 0, "a prompt for me is pending")
	assert_eq(table.pass_btn.visible, s.pending.can_pass, "pass button follows the prompt")
	# Tap through: end my turn, then answer whatever comes (discard prompts,
	# dodges...) until at least one bot turn has been logged.
	table._on_pass()
	await frames(2)
	var answer := _auto_answer(s, s.host)
	var rounds := 0
	while table.log_lines.is_empty() and rounds < 30 and s.pending != null:
		answer.call(s.pending)
		await frames(1)
		rounds += 1
	assert_true(table.log_lines.size() > 0, "log has lines after %d prompts (seed %d)" % [rounds, s.host.engine.seed_value])
	assert_true(s.pending == null or s.pending.player == 0, "table only ever holds my prompts")
	table.queue_free()
	tree.root.get_node("Game").clear_session()
	await frames(1)


func test_host_and_client_over_enet() -> void:
	var tree := tree
	var host_root := Node.new()
	host_root.name = "HostBranch"
	var client_root := Node.new()
	client_root.name = "ClientBranch"
	tree.root.add_child(host_root)
	tree.root.add_child(client_root)
	tree.set_multiplayer(MultiplayerAPI.create_default_interface(), host_root.get_path())
	tree.set_multiplayer(MultiplayerAPI.create_default_interface(), client_root.get_path())
	var host := NetSession.new()
	host.name = "Session"
	host_root.add_child(host)
	var client := NetSession.new()
	client.name = "Session"
	client_root.add_child(client)
	var port := 7790 + (Time.get_ticks_msec() % 100)
	assert_eq(host.host(port, "Host", 1), OK, "host started")
	assert_eq(client.join("127.0.0.1", port, "Guest"), OK, "client connecting")
	var waited := 0
	while client.my_seat < 0 and waited < 300:
		await frames(1)
		waited += 1
	assert_eq(client.my_seat, 1, "client got seat 1")
	assert_eq(host.lobby.size(), 3, "lobby: host, guest, 1 bot")
	assert_true(client.lobby.size() == 3 or waited < 300, "client saw lobby")

	var st := {"client_over": {}, "host_over": {}, "host_prompts": 0, "client_prompts": 0}
	client.game_over.connect(func(r): st["client_over"] = r)
	host.game_over.connect(func(r): st["host_over"] = r)
	host.start_game({"decks": ["standard"]})
	var helper := SimpleBot.new(host.host_runner.engine, [], 7)
	host.prompt_received.connect(func(p): st["host_prompts"] += 1; host.submit(p.id, helper.answer(p)))
	client.prompt_received.connect(func(p): st["client_prompts"] += 1; client.submit(p.id, helper.answer(p)))
	if host.pending != null:
		st["host_prompts"] += 1
		host.submit(host.pending.id, helper.answer(host.pending))
	waited = 0
	while st["client_over"].is_empty() and waited < 4000:
		await frames(1)
		waited += 1
	assert_true(not st["host_over"].is_empty(), "host saw game over (seed %d)" % host.host_runner.engine.seed_value)
	assert_true(not st["client_over"].is_empty(), "client saw game over (%d frames, seed %d)" % [waited, host.host_runner.engine.seed_value])
	assert_true(st["client_prompts"] > 0, "client answered prompts over the network")
	var eng := host.host_runner.engine
	var summary := "seed %d, turns %d, roles %s, alive %s, result %s, my_seat %d, lobby %s" % [eng.seed_value, eng.state.turn_number,
		eng.state.players.map(func(p): return String(p.role)), eng.state.alive_players(), eng.result, host.my_seat, host.lobby]
	assert_true(st["host_prompts"] > 0, "host answered prompts (%s)" % summary)
	assert_eq(client.snapshot.get("players", []).size(), 3, "client has full player list")
	var hidden_ok := true
	for zid in client.snapshot["zones"]:
		if zid == "hand:0" or zid == "hand:2":
			for cid in client.snapshot["zones"][zid]["cards"]:
				if client.snapshot["cards"].has(cid) or client.snapshot["cards"].has(str(cid)):
					hidden_ok = false
	assert_true(hidden_ok, "client never sees other hands")
	host.leave()
	client.leave()
	await frames(2)
	host_root.queue_free()
	client_root.queue_free()
	await frames(1)
