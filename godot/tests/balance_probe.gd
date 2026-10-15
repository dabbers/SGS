extends SceneTree
## Balance probe: plays seeded all-bot games and prints win rates per side.
## Not a test; run it by hand when touching the bot policy:
##   godot --headless --path . -s tests/balance_probe.gd [games=200] [players=4] [first_seed=1000]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 200
	var players := int(args[1]) if args.size() > 1 else 4
	var first_seed := int(args[2]) if args.size() > 2 else 1000
	var wins := {"king": 0, "rebel": 0, "spy": 0, "draw": 0}
	var turns := 0
	var deaths := {}   # role -> how many of that role died, to see who gets killed
	var first := {}    # death sequence and winner per game, to see how games go
	var rescues := {}  # "rescuer->saved" role pairs, to see who spends Peaches on whom
	var draws := []    # seeds that hit the turn limit
	var dmg := {}      # "source->target" role pairs, total damage dealt
	for seed_value in range(first_seed, first_seed + games):
		var e := CardEngine.new()
		var cfg := {"players": players, "bots": range(players), "decks": ["standard", "expansion"]}
		e.start(SgsRules.new(), cfg, seed_value)
		var bot := SimpleBot.new(e, range(players), seed_value)
		assert(bot != null and e.is_over, "seed %d did not finish synchronously" % seed_value)
		var side: String = e.result.get("winner", "")
		if side == "" or e.result.get("reason", "") == "turn limit":
			side = "draw"
		wins[side] = int(wins.get(side, 0)) + 1
		turns += e.state.turn_number
		for p in e.state.players:
			if not p.alive:
				deaths[String(p.role)] = int(deaths.get(String(p.role), 0)) + 1
		if side == "draw":
			draws.append(seed_value)
		var path := []
		for ev in e.log:
			if ev.get("type", "") == "sgs_card_used" and ev.get("rescue", false) and int(ev["player"]) != int(ev["target"]):
				var rk := "%s->%s" % [String(e.state.player(int(ev["player"])).role).left(3), String(e.state.player(int(ev["target"])).role).left(3)]
				rescues[rk] = int(rescues.get(rk, 0)) + 1
			if ev.get("type", "") == "sgs_damage" and int(ev.get("source", -1)) >= 0:
				var dk := "%s->%s" % [String(e.state.player(int(ev["source"])).role).left(3), String(e.state.player(int(ev["target"])).role).left(3)]
				dmg[dk] = int(dmg.get(dk, 0)) + int(ev["amount"])
			if ev.get("type", "") == "sgs_death":
				var killer := int(ev.get("killer", -1))
				path.append("%s<-%s" % [String(ev["role"]).left(3), String(e.state.player(killer).role).left(3) if killer >= 0 else "none"])
		var key := "%s => %s" % [" ".join(path), side]
		first[key] = int(first.get(key, 0)) + 1
	print("%d games, %d players, seeds %d..%d, avg %.1f turns" % [games, players, first_seed, first_seed + games - 1, float(turns) / games])
	for side in ["king", "rebel", "spy", "draw"]:
		print("  %-6s %4d  %5.1f%%" % [side, wins[side], 100.0 * wins[side] / games])
	var dl := []
	for role in ["king", "loyalist", "rebel", "spy"]:
		dl.append("%s %d" % [role, int(deaths.get(role, 0))])
	print("  deaths: " + ", ".join(dl))
	var rl := []
	for k in rescues:
		rl.append("%s %d" % [k, rescues[k]])
	print("  rescues (rescuer->saved): " + ", ".join(rl))
	var dk := dmg.keys()
	dk.sort_custom(func(a, b): return dmg[a] > dmg[b])
	var dml := []
	for k in dk:
		dml.append("%s %d" % [k, dmg[k]])
	print("  damage (source->target, total): " + ", ".join(dml))
	if not draws.is_empty():
		print("  turn-limit seeds: " + str(draws))
	var keys := first.keys()
	keys.sort_custom(func(a, b): return first[a] > first[b])
	var fl := []
	for k in keys:
		fl.append("%s %d" % [k, first[k]])
	print("  paths (victim<-killer ... => winner):\n    " + "\n    ".join(fl))
	quit(0)
