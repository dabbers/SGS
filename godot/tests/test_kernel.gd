extends TestCase


func _new_game(seed_value: int = 42, bots: Array = []) -> CardEngine:
	var e := CardEngine.new()
	e.start(ToyRules.new(), {"players": 2, "bots": bots}, seed_value)
	return e


func test_start_suspends_on_first_prompt() -> void:
	var e := _new_game()
	assert_true(e.pending != null, "a prompt should be pending")
	assert_eq(e.pending.player, 0, "first prompt goes to player 0")
	assert_eq(e.pending.kind, Prompt.KIND_PLAY)
	assert_eq(e.state.zone(&"hand:0").size(), 1, "drew one card")
	assert_eq(e.state.zone(&"draw").size(), 9)


func test_invalid_responses_are_rejected() -> void:
	var e := _new_game()
	var pid := e.pending.id
	assert_false(e.respond(1, pid, {"pass": true}), "wrong player")
	assert_false(e.respond(0, pid + 7, {"pass": true}), "wrong prompt id")
	assert_false(e.respond(0, pid, {"cards": [999]}), "card not in hand")
	assert_false(e.respond(0, pid, {"cards": []}), "play needs 1 card or pass")
	assert_true(e.pending != null and e.pending.id == pid, "still waiting")
	assert_true(e.respond(0, pid, {"pass": true}), "pass is valid")
	assert_eq(e.pending.player, 1, "turn moved to player 1")


func test_play_moves_card_and_fires_trigger() -> void:
	var e := _new_game()
	var card_id: int = e.state.zone(&"hand:0").cards[0]
	assert_true(e.respond(0, e.pending.id, {"cards": [card_id]}))
	assert_eq(e.state.card(card_id).zone, &"discard")
	assert_true(e.state.card(card_id).face_up, "public zone flips face up")
	assert_eq(e.state.vars["plays"].get(0, 0), 1, "trigger counted the play")
	var types := e.log.map(func(ev): return ev["type"])
	assert_true(types.has("cards_moved") and types.has("responded"), "events logged")


func test_game_finishes_and_is_deterministic() -> void:
	var e := _new_game(7, [0, 1])
	var bot := SimpleBot.new(e, [0, 1], 3)
	assert_true(e.is_over, "bots should finish the game synchronously")
	assert_true(e.result.has("winner"))
	# Replay from the recorded inputs must give an identical log.
	var r := CardEngine.replay(ToyRules.new(), {"players": 2}, 7, e.inputs)
	assert_true(r.is_over, "replay finished")
	assert_eq(r.log.size(), e.log.size(), "same number of events")
	assert_eq(JSON.stringify(r.log), JSON.stringify(e.log), "identical event log")
	assert_true(bot != null)


func test_seed_changes_shuffle() -> void:
	var a := _new_game(1)
	var b := _new_game(2)
	assert_ne(a.state.zone(&"draw").cards, b.state.zone(&"draw").cards, "different seeds shuffle differently")
	var c := _new_game(1)
	assert_eq(a.state.zone(&"draw").cards, c.state.zone(&"draw").cards, "same seed same shuffle")


func test_visibility_filtering() -> void:
	var e := _new_game()
	var snap0 := e.state.snapshot(0)
	var snap1 := e.state.snapshot(1)
	var hand0: int = e.state.zone(&"hand:0").cards[0]
	assert_true(snap0["cards"].has(hand0), "owner sees own hand")
	assert_false(snap1["cards"].has(hand0), "opponent does not see it")
	assert_false(snap1["cards"].has(e.state.zone(&"draw").cards[0]), "draw pile hidden")
	e.respond(0, e.pending.id, {"cards": [hand0]})
	assert_true(e.state.snapshot(1)["cards"].has(hand0), "discarded card is public")
	var ev := e.event_for_viewer(e.log[-2], 1)
	assert_true(ev.get("known_cards", {}).has(hand0), "move event reveals card to viewer")


func test_prompt_roundtrip() -> void:
	var p := Prompt.choose_cards(2, "Discard", [5, 6, 7], 1, 2, true)
	p.id = 9
	var q := Prompt.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(q.id, 9)
	assert_eq(q.player, 2)
	assert_eq(q.cards, [5, 6, 7] as Array[int])
	assert_true(q.validate({"cards": [5, 7]}))
	assert_false(q.validate({"cards": [5, 6, 7]}), "too many")
	assert_false(q.validate({"cards": [5, 5]}), "duplicate")
	assert_true(q.validate({"pass": true}))
