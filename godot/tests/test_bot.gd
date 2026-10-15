extends TestCase
## The Sanguosha bot must act on public information only and never attack a
## player it has no reason to think is an enemy.


func _game(seed_value: int, roles: Array, hands: Dictionary) -> CardEngine:
	var e := CardEngine.new()
	var cfg := {"players": roles.size(), "bots": [], "first_draw": false, "test_hands": hands,
		"heroes": {}}
	for i in roles.size():
		cfg["heroes"][i] = "liubei"   # no skills that change targeting
	e.start(SgsRules.new(), cfg, seed_value)
	# Force roles so the test is explicit. The king is always revealed.
	for i in roles.size():
		e.state.player(i).role = StringName(roles[i])
		e.state.player(i).role_revealed = roles[i] == "king"
	return e


func _strike(e: CardEngine, pid: int) -> int:
	for c in e.state.zone(Sgs.hand(pid)).cards:
		if e.card(c).def_id == &"strike":
			return c
	return -1


func _play_prompt(e: CardEngine, pid: int) -> Prompt:
	return Prompt.play(pid, "Your turn", [_strike(e, pid)])


const SEVEN := ["king", "loyalist", "rebel", "spy", "loyalist", "rebel", "rebel"]


func test_loyalist_does_not_strike_unknowns() -> void:
	# Seven players: two loyalists, so a hidden player could still be a friend.
	var e := _game(1, SEVEN, {1: ["strike"]})
	var brng := CardRng.new(5)
	var resp := SgsBot.answer(e, _play_prompt(e, 1), brng)
	assert_true(resp.get("pass", false), "loyalist with no known enemy passes: %s" % resp)
	assert_eq(SgsBot.stance(e, 1, 0), SgsBot.ALLY, "king is an ally")
	assert_eq(SgsBot.stance(e, 1, 2), SgsBot.UNKNOWN, "hidden rebel is unknown")


func test_loyalist_attacks_revealed_rebel_and_never_king() -> void:
	var e := _game(2, SEVEN, {1: ["strike"]})
	e.state.player(2).role_revealed = true
	var brng := CardRng.new(5)
	var resp := SgsBot.answer(e, _play_prompt(e, 1), brng)
	assert_true(resp.has("cards"), "loyalist plays the strike once a rebel is known")
	var tp := Prompt.choose_players(1, "Strike: choose a target", [0, 2], 1, 1, true)
	tp.data = {"harmful": true, "bot": "target"}
	for i in 10:
		var t := SgsBot.answer(e, tp, CardRng.new(i))
		assert_eq(t.get("players", [-1])[0], 2, "targets the rebel, never the king")


func test_rebel_goes_for_the_king() -> void:
	var e := _game(3, SEVEN, {2: ["strike"]})
	var tp := Prompt.choose_players(2, "Strike: choose a target", [0, 1, 3], 1, 1, true)
	tp.data = {"harmful": true, "bot": "target"}
	var t := SgsBot.answer(e, tp, CardRng.new(1))
	assert_eq(t.get("players", [-1])[0], 0, "rebel targets the king when in range")
	assert_eq(SgsBot.stance(e, 2, 1), SgsBot.UNKNOWN, "hidden loyalist is unknown to the rebel")


func test_public_evidence_changes_stance() -> void:
	var e := _game(4, SEVEN, {})
	# Seat 2 damages the king in public.
	e.emit_event(&"sgs_damage", {"source": 2, "target": 0, "amount": 1, "nature": "none", "card": -1, "hp": 3})
	assert_eq(SgsBot.stance(e, 1, 2), SgsBot.ENEMY, "loyalist now treats the attacker as an enemy")
	assert_eq(SgsBot.stance(e, 0, 2), SgsBot.ENEMY, "so does the king")
	assert_eq(SgsBot.stance(e, 3, 2), SgsBot.ALLY, "the spy props up the rebel while the king's side is ahead")
	# Seat 1 rescues the king with a Peach in public.
	e.emit_event(&"sgs_card_used", {"player": 1, "card": -1, "card_ids": [], "as": "peach", "targets": [], "reactive": true, "rescue": true, "target": 0})
	assert_eq(SgsBot.stance(e, 0, 1), SgsBot.ALLY, "king trusts the rescuer")
	assert_eq(SgsBot.stance(e, 2, 1), SgsBot.ENEMY, "rebel marks the rescuer as an enemy")


func test_rescue_only_allies() -> void:
	var e := _game(5, SEVEN, {1: ["peach"]})
	var peach: int = e.state.zone(Sgs.hand(1)).cards[0]
	var pr := Prompt.choose_cards(1, "x is dying", [peach], 0, 1, true)
	pr.data = {"bot": "rescue", "target": 0}
	assert_true(SgsBot.answer(e, pr, CardRng.new(1)).has("cards"), "loyalist saves the king")
	pr.data = {"bot": "rescue", "target": 2}
	assert_true(SgsBot.answer(e, pr, CardRng.new(1)).get("pass", false), "but not an unknown")


func test_spy_balances_the_sides() -> void:
	var e := _game(7, ["king", "loyalist", "rebel", "spy"], {})
	assert_eq(SgsBot.stance(e, 3, 1), SgsBot.UNKNOWN, "nothing known yet")
	assert_eq(SgsBot.stance(e, 3, 0), SgsBot.ALLY, "the king is left alone until the others are placed")
	# Seat 2 strikes the king: the spy now knows the rebel, and by elimination the loyalist.
	e.emit_event(&"sgs_damage", {"source": 2, "target": 0, "amount": 1, "nature": "none", "card": -1, "hp": 4})
	assert_eq(SgsBot.side_guess(e, 3, 2), Sgs.ROLE_REBEL)
	assert_eq(SgsBot.side_guess(e, 3, 1), Sgs.ROLE_KING, "the other hidden player must be the loyalist")
	assert_eq(SgsBot.stronger_side(e, 3), Sgs.ROLE_KING, "two players against one")
	assert_eq(SgsBot.stance(e, 3, 1), SgsBot.ENEMY, "so the spy attacks the loyalist")
	assert_eq(SgsBot.stance(e, 3, 2), SgsBot.ALLY, "and helps the rebel")
	assert_eq(SgsBot.stance(e, 3, 0), SgsBot.ENEMY, "a healthy king on the stronger side is chipped at")
	assert_eq(SgsBot.attack_targets(e, 3, [0, 1, 2]), [1], "but the loyalist is hit first")
	e.state.player(0).hp = 2
	assert_eq(SgsBot.stance(e, 3, 0), SgsBot.ALLY, "a weakened king is protected")
	# The loyalist dies and the king is low: the rebel's side is ahead now.
	e.state.player(1).alive = false
	e.state.player(1).role_revealed = true
	assert_eq(SgsBot.stronger_side(e, 3), Sgs.ROLE_REBEL)
	assert_eq(SgsBot.stance(e, 3, 2), SgsBot.ENEMY, "the spy turns on the rebel")
	assert_eq(SgsBot.stance(e, 3, 0), SgsBot.ALLY, "and keeps the king alive")


func test_spy_rescues_the_weaker_side() -> void:
	var e := _game(8, ["king", "loyalist", "rebel", "spy"], {3: ["peach"]})
	e.emit_event(&"sgs_damage", {"source": 2, "target": 0, "amount": 1, "nature": "none", "card": -1, "hp": 4})
	var peach: int = e.state.zone(Sgs.hand(3)).cards[0]
	var pr := Prompt.choose_cards(3, "x is dying", [peach], 0, 1, true)
	pr.data = {"bot": "rescue", "target": 2}
	assert_true(SgsBot.answer(e, pr, CardRng.new(1)).has("cards"), "the rebel is behind: saved")
	pr.data = {"bot": "rescue", "target": 1}
	assert_true(SgsBot.answer(e, pr, CardRng.new(1)).get("pass", false), "the loyalist is ahead: left to die")
	pr.data = {"bot": "rescue", "target": 0}
	assert_true(SgsBot.answer(e, pr, CardRng.new(1)).has("cards"), "the king is always saved while rebels remain")


func test_spy_turns_on_the_king_last() -> void:
	var e := _game(9, ["king", "loyalist", "rebel", "spy"], {})
	e.state.player(2).alive = false
	e.state.player(2).role_revealed = true
	assert_false(SgsBot.rebels_remain(e, 3))
	assert_eq(SgsBot.stance(e, 3, 1), SgsBot.ENEMY, "the loyalist must go")
	assert_eq(SgsBot.stance(e, 3, 0), SgsBot.ENEMY, "a healthy king can be worn down meanwhile")
	assert_eq(SgsBot.attack_targets(e, 3, [0, 1]), [1], "but the loyalist comes first")
	e.state.player(0).hp = 2
	assert_eq(SgsBot.stance(e, 3, 0), SgsBot.ALLY, "a weak king is not finished while a loyalist lives")
	e.state.player(1).alive = false
	e.state.player(1).role_revealed = true
	assert_eq(SgsBot.stance(e, 3, 0), SgsBot.ENEMY, "one on one, the king is the last target")
	assert_eq(SgsBot.stance(e, 1, 3), SgsBot.ENEMY, "the loyalist knows the last hidden player is the spy")


func test_rebel_duels_the_king_out_of_strike_range() -> void:
	# Seat 2 is two seats from the king: a Strike cannot reach, a Duel can.
	var e := _game(10, ["king", "loyalist", "rebel", "spy"], {2: ["strike", "duel"]})
	var hand := e.state.zone(Sgs.hand(2)).cards
	assert_false((e.rules as SgsRules).in_attack_range(e, 2, 0))
	for i in 5:
		var resp := SgsBot.answer(e, Prompt.play(2, "Your turn", hand), CardRng.new(i))
		assert_eq(e.card(int(resp.get("cards", [-1])[0])).def_id, &"duel", "duel beats a strike at someone else")
	var tp := Prompt.choose_players(2, "Duel: choose a target", [0, 1, 3], 1, 1, true)
	tp.data = {"harmful": true, "bot": "target"}
	assert_eq(SgsBot.answer(e, tp, CardRng.new(1)).get("players", [-1])[0], 0, "and it is aimed at the king")


func test_rebel_keeps_one_dodge_when_discarding() -> void:
	var e := _game(11, ["king", "loyalist", "rebel", "spy"], {2: ["dodge", "peach", "strike"], 1: ["dodge", "peach", "strike"]})
	for seat in [2, 1]:
		var hand := e.state.zone(Sgs.hand(seat)).cards
		var dp := Prompt.choose_cards(seat, "Discard 2 cards", hand, 2, 2)
		dp.data = {"discard": true}
		var kept := hand.duplicate()
		for c in SgsBot.answer(e, dp, CardRng.new(1))["cards"]:
			kept.erase(int(c))
		assert_eq(kept.size(), 1)
		var expect := &"dodge" if seat == 2 else &"peach"
		assert_eq(e.card(kept[0]).def_id, expect, "seat %d keeps the %s" % [seat, expect])


func test_four_player_loyalist_deduces_enemies() -> void:
	var e := _game(6, ["king", "loyalist", "rebel", "spy"], {1: ["strike"]})
	assert_eq(SgsBot.hidden_pool(e, 1), {&"rebel": 1, &"spy": 1}, "pool is rebel + spy")
	assert_eq(SgsBot.stance(e, 1, 2), SgsBot.ENEMY, "so every hidden player is an enemy")
	assert_eq(SgsBot.stance(e, 1, 0), SgsBot.ALLY)


func test_bot_games_still_finish() -> void:
	for seed_value in range(300, 306):
		var n := 3 + (seed_value % 5)
		var e := CardEngine.new()
		e.start(SgsRules.new(), {"players": n, "bots": range(n), "decks": ["standard", "expansion"]}, seed_value)
		var bot := SimpleBot.new(e, range(n), seed_value)
		assert_true(e.is_over, "seed %d finished" % seed_value)
		assert_true(e.result.get("reason", "") != "turn limit", "seed %d did not stall (turns %d)" % [seed_value, e.state.turn_number])
		assert_true(bot != null)
