class_name SgsHeroes
extends RefCounted
## Hero definitions and their skills. Skills are Triggers, virtual-card rules,
## or active skills offered as options in the play prompt.


static func all() -> Array[SgsHero]:
	return [
		SgsHero.new(&"liubei", "Liu Bei", 4, &"shu", &"male", [&"rende"]),
		SgsHero.new(&"guanyu", "Guan Yu", 4, &"shu", &"male", [&"wusheng"]),
		SgsHero.new(&"zhangfei", "Zhang Fei", 4, &"shu", &"male", [&"paoxiao"]),
		SgsHero.new(&"zhaoyun", "Zhao Yun", 4, &"shu", &"male", [&"longdan"]),
		SgsHero.new(&"caocao", "Cao Cao", 4, &"wei", &"male", [&"jianxiong"]),
		SgsHero.new(&"zhouyu", "Zhou Yu", 3, &"wu", &"male", [&"yingzi"]),
		SgsHero.new(&"lvmeng", "Lü Meng", 4, &"wu", &"male", [&"keji"]),
		SgsHero.new(&"sunquan", "Sun Quan", 4, &"wu", &"male", [&"zhiheng"]),
		SgsHero.new(&"diaochan", "Diao Chan", 3, &"qun", &"female", [&"biyue"]),
		SgsHero.new(&"huatuo", "Hua Tuo", 3, &"qun", &"male", [&"qingnang"]),
	]


static func by_id(id: StringName) -> SgsHero:
	for h in all():
		if h.id == id:
			return h
	return null


static func skill_label(skill: StringName) -> String:
	match skill:
		&"rende": return "Benevolence: give hand cards to another player (heal 1 after giving 2+ this turn)"
		&"wusheng": return "Warrior Saint: red cards count as Strike"
		&"paoxiao": return "Roar: no limit on Strikes per turn"
		&"longdan": return "Dragon Heart: Strike and Dodge are interchangeable"
		&"jianxiong": return "Villainous Hero: take the card that damaged you"
		&"yingzi": return "Handsome: draw 1 extra card"
		&"keji": return "Self Restraint: skip discard phase if you used no Strike"
		&"zhiheng": return "Balance of Power: discard any cards, draw that many (once per turn)"
		&"biyue": return "Moon Envy: draw 1 at end of turn"
		&"qingnang": return "Green Satchel: discard 1 hand card to heal a player 1 (once per turn)"
	return String(skill)


class SgsHero extends RefCounted:
	var id: StringName
	var name: String
	var hp: int
	var faction: StringName
	var gender: StringName
	var skills: Array[StringName] = []

	func _init(p_id: StringName, p_name: String, p_hp: int, p_faction: StringName, p_gender: StringName, p_skills: Array) -> void:
		id = p_id
		name = p_name
		hp = p_hp
		faction = p_faction
		gender = p_gender
		for s in p_skills:
			skills.append(StringName(s))

	func to_dict() -> Dictionary:
		return {"id": String(id), "name": name, "hp": hp, "faction": String(faction), "gender": String(gender),
			"skills": skills.map(func(s): return {"id": String(s), "label": SgsHeroes.skill_label(s)})}

	## Install passive skills for seat `pid`.
	func apply(e: CardEngine, r: SgsRules, pid: int) -> void:
		for s in skills:
			match s:
				&"paoxiao":
					e.state.player(pid).flags["unlimited_strikes"] = true
				&"wusheng":
					r.add_virtual_rule(pid, &"strike", func(_eng, c: Card): return c.is_red())
				&"longdan":
					r.add_virtual_rule(pid, &"strike", func(eng, c: Card): return eng.def_of(c.id).id == &"dodge")
					r.add_virtual_rule(pid, &"dodge", func(eng, c: Card): return eng.def_of(c.id).id == &"strike")
				&"jianxiong":
					e.register_trigger(Jianxiong.new(pid))
				&"yingzi":
					e.register_trigger(Trigger.make([Sgs.T_DRAW_COUNT], pid, "Yingzi",
						func(_eng, _t, ctx): ctx["count"] = int(ctx["count"]) + 1,
						func(_eng, _t, ctx): return ctx["player"] == pid))
				&"keji":
					e.register_trigger(Trigger.make([Sgs.T_PHASE_START], pid, "Keji",
						func(eng: CardEngine, _t, _ctx): eng.state.player(pid).flags["skip_discard"] = true,
						func(eng: CardEngine, _t, ctx): return ctx["player"] == pid and ctx["phase"] == Sgs.PHASE_DISCARD and eng.rules.strikes_used(eng, pid) == 0))
				&"biyue":
					e.register_trigger(Biyue.new(pid))

	## Active skills currently usable in the play phase, as prompt options.
	func active_skills(e: CardEngine, _r: SgsRules, pid: int) -> Array:
		var out := []
		var p := e.state.player(pid)
		var uses: Dictionary = p.flags.get("skill_uses", {})
		for s in skills:
			match s:
				&"rende":
					if not e.state.zone(Sgs.hand(pid)).is_empty() and e.state.alive_players().size() > 1:
						out.append({"id": "skill:rende", "label": "Benevolence (give cards)"})
				&"zhiheng":
					if int(uses.get("zhiheng", 0)) == 0 and (not e.state.zone(Sgs.hand(pid)).is_empty() or not e.state.zone(Sgs.equip(pid)).is_empty()):
						out.append({"id": "skill:zhiheng", "label": "Balance of Power (discard & redraw)"})
				&"qingnang":
					if int(uses.get("qingnang", 0)) == 0 and not e.state.zone(Sgs.hand(pid)).is_empty() and _wounded(e).size() > 0:
						out.append({"id": "skill:qingnang", "label": "Green Satchel (heal)"})
		return out

	func _wounded(e: CardEngine) -> Array:
		return e.state.alive_players().filter(func(q): return e.state.player(q).hp < e.state.player(q).max_hp)

	func use_skill(e: CardEngine, r: SgsRules, pid: int, skill: String) -> void:
		var p := e.state.player(pid)
		if not p.flags.has("skill_uses"):
			p.flags["skill_uses"] = {}
		match skill:
			"skill:rende":
				var resp := await e.ask(Prompt.choose_cards(pid, "Benevolence: choose cards to give", e.state.zone(Sgs.hand(pid)).cards, 1, 99, true))
				if resp.get("pass", false):
					return
				var who := await e.ask(Prompt.choose_players(pid, "Benevolence: give to whom?", r.others(e, pid), 1, 1, true))
				if who.get("pass", false):
					return
				var target: int = who["players"][0]
				e.emit_event(&"sgs_skill", {"player": pid, "skill": "rende", "target": target})
				await e.move_cards(resp["cards"], Sgs.hand(target), {"why": "give", "by": pid})
				var before: int = p.flags.get("rende_given", 0)
				p.flags["rende_given"] = before + resp["cards"].size()
				if before < 2 and p.flags["rende_given"] >= 2:
					await r.heal(e, pid, 1)
			"skill:zhiheng":
				var pool := e.state.zone(Sgs.hand(pid)).cards + e.state.zone(Sgs.equip(pid)).cards
				var zp := Prompt.choose_cards(pid, "Balance of Power: discard any number of cards", pool, 1, 99, true)
				zp.data = {"discard": true}
				var resp := await e.ask(zp)
				if resp.get("pass", false):
					return
				p.flags["skill_uses"]["zhiheng"] = 1
				e.emit_event(&"sgs_skill", {"player": pid, "skill": "zhiheng"})
				await r.discard_cards(e, resp["cards"], pid)
				await r.draw_cards(e, pid, resp["cards"].size())
			"skill:qingnang":
				var qp := Prompt.choose_cards(pid, "Green Satchel: discard a hand card", e.state.zone(Sgs.hand(pid)).cards, 1, 1, true)
				qp.data = {"discard": true}
				var resp := await e.ask(qp)
				if resp.get("pass", false):
					return
				var wp := Prompt.choose_players(pid, "Green Satchel: heal whom?", _wounded(e), 1, 1, true)
				wp.data = {"bot": "help"}
				var who := await e.ask(wp)
				if who.get("pass", false):
					return
				p.flags["skill_uses"]["qingnang"] = 1
				e.emit_event(&"sgs_skill", {"player": pid, "skill": "qingnang", "target": who["players"][0]})
				await r.discard_cards(e, resp["cards"], pid)
				await r.heal(e, int(who["players"][0]), 1)


class Jianxiong extends Trigger:
	func _init(pid: int) -> void:
		super([Sgs.T_DAMAGE_AFTER], pid, "Jianxiong")

	func is_active(e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		if ctx["target"] != owner or int(ctx["card"]) < 0 or not e.state.player(owner).alive:
			return false
		return e.card(int(ctx["card"])).zone == CardEngine.ZONE_PROCESSING

	func on_trigger(e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		var p := Prompt.confirm(owner, "Villainous Hero: take %s?" % e.def_of(int(ctx["card"])).name)
		p.data = {"bot": "accept"}
		var resp := await e.ask(p)
		if resp.get("option", "no") == "yes":
			e.emit_event(&"sgs_skill", {"player": owner, "skill": "jianxiong"})
			await e.move_cards([int(ctx["card"])], Sgs.hand(owner), {"why": "jianxiong", "by": owner})


class Biyue extends Trigger:
	func _init(pid: int) -> void:
		super([Sgs.T_PHASE_END], pid, "Biyue")

	func is_active(e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["player"] == owner and ctx["phase"] == Sgs.PHASE_END and e.state.player(owner).alive

	func on_trigger(e: CardEngine, _t: StringName, _ctx: Dictionary) -> void:
		e.emit_event(&"sgs_skill", {"player": owner, "skill": "biyue"})
		await (e.rules as SgsRules).draw_cards(e, owner, 1)
