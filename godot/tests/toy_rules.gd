class_name ToyRules
extends GameRules
## Tiny game used only to test the kernel: each turn draw 1 then play 1.
## The game ends after `turns` turns; the player with most plays wins.

var turns := 4


class ToyDef extends CardDef:
	func can_play(_e, _p, _c) -> bool:
		return true


func id() -> StringName:
	return &"toy"


func create_defs() -> Dictionary:
	var d := ToyDef.new(&"num", "Number", &"basic")
	return {d.id: d}


func setup(e: CardEngine, cfg: Dictionary) -> void:
	var n: int = cfg.get("players", 2)
	e.state.add_zone(Zone.new(&"draw", &"draw", -1, Zone.Visibility.HIDDEN))
	e.state.add_zone(Zone.new(&"discard", &"discard", -1, Zone.Visibility.PUBLIC))
	for i in n:
		var p := e.state.add_player("P%d" % i, cfg.get("bots", []).has(i))
		p.hp = 1
		p.max_hp = 1
		e.state.add_zone(Zone.new(StringName("hand:%d" % i), &"hand", i, Zone.Visibility.OWNER))
	for r in range(1, 11):
		e.create_card(&"num", &"spade", r, &"draw")
	e.rng.shuffle(e.state.zone(&"draw").cards)
	e.state.vars["plays"] = {}
	e.register_trigger(Trigger.make([&"cards_moved"], -1, "counter", func(eng: CardEngine, _t, ctx: Dictionary):
		if ctx.reason.get("why", "") == "play":
			var by: int = ctx.reason["by"]
			eng.state.vars["plays"][by] = eng.state.vars["plays"].get(by, 0) + 1
	))


func play(e: CardEngine) -> Dictionary:
	var pid := 0
	for t in turns:
		e.state.current_player = pid
		e.state.turn_number = t + 1
		var hand := StringName("hand:%d" % pid)
		await e.move_cards(e.top_cards(&"draw", 1), hand, {"why": "draw"})
		var resp := await e.ask(Prompt.play(pid, "Play a card", e.state.zone(hand).cards))
		if not resp.get("pass", false):
			await e.move_cards(resp["cards"], &"discard", {"why": "play", "by": pid})
		pid = e.state.next_alive(pid)
	var best := -1
	var winner := -1
	for p in e.state.vars["plays"]:
		if e.state.vars["plays"][p] > best:
			best = e.state.vars["plays"][p]
			winner = p
	return {"winner": winner}
