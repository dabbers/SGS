class_name Sgs
extends RefCounted
## Shared constants and zone helpers for the Sanguosha module.

# Timings (see ARCHITECTURE.md for the ctx each one carries)
const T_TURN_START := &"sgs_turn_start"
const T_TURN_END := &"sgs_turn_end"
const T_PHASE_START := &"sgs_phase_start"
const T_PHASE_END := &"sgs_phase_end"
const T_DRAW_COUNT := &"sgs_draw_count"          # ctx.count
const T_CARD_USED := &"sgs_card_used"            # ctx.player, card, as, targets, cancelled
const T_TRICK_TARGETED := &"sgs_trick_targeted"  # ctx.source, target, card, cancelled (before Negate)
const T_STRIKE_USED := &"sgs_strike_used"        # ctx.source, target, card, nature, dodges_needed, ignore_armor, cancelled
const T_PROVIDE_CARD := &"sgs_provide_card"      # ctx.player, as, provided (armor auto-dodge)
const T_STRIKE_DODGED := &"sgs_strike_dodged"    # ctx.source, target, card, retry
const T_STRIKE_HIT := &"sgs_strike_hit"          # ctx.source, target, card, amount, skip_damage
const T_DAMAGE_BEFORE := &"sgs_damage_before"    # ctx.source, target, amount, nature, card, cancelled
const T_DAMAGE_AFTER := &"sgs_damage_after"
const T_DYING := &"sgs_dying"
const T_DEATH := &"sgs_death"                    # ctx.player, killer
const T_JUDGE_AFTER := &"sgs_judge_after"        # ctx.player, card (replaceable), reason

const PHASE_JUDGEMENT := &"judgement"
const PHASE_DRAW := &"draw"
const PHASE_PLAY := &"play"
const PHASE_DISCARD := &"discard"
const PHASE_END := &"end"
const PHASES: Array[StringName] = [PHASE_JUDGEMENT, PHASE_DRAW, PHASE_PLAY, PHASE_DISCARD, PHASE_END]

const ROLE_KING := &"king"
const ROLE_LOYALIST := &"loyalist"
const ROLE_REBEL := &"rebel"
const ROLE_SPY := &"spy"

const NATURE_NONE := &"none"
const NATURE_FIRE := &"fire"
const NATURE_THUNDER := &"thunder"

const ZONE_DRAW := &"draw"
const ZONE_DISCARD := &"discard"

# Player flag keys reset at the end of every turn.
const TURN_FLAGS := ["strikes_used", "wine_active", "wines_used", "skip_judgement", "skip_draw",
	"skip_play", "skip_discard", "draw_bonus", "skill_uses"]


static func hand(pid: int) -> StringName:
	return StringName("hand:%d" % pid)


static func equip(pid: int) -> StringName:
	return StringName("equip:%d" % pid)


static func judge(pid: int) -> StringName:
	return StringName("judge:%d" % pid)


static func role_set(n: int) -> Array[StringName]:
	match n:
		2: return [ROLE_KING, ROLE_REBEL]
		3: return [ROLE_KING, ROLE_REBEL, ROLE_SPY]
		4: return [ROLE_KING, ROLE_LOYALIST, ROLE_REBEL, ROLE_SPY]
		5: return [ROLE_KING, ROLE_LOYALIST, ROLE_REBEL, ROLE_REBEL, ROLE_SPY]
		6: return [ROLE_KING, ROLE_LOYALIST, ROLE_REBEL, ROLE_REBEL, ROLE_REBEL, ROLE_SPY]
		7: return [ROLE_KING, ROLE_LOYALIST, ROLE_LOYALIST, ROLE_REBEL, ROLE_REBEL, ROLE_REBEL, ROLE_SPY]
		_: return [ROLE_KING, ROLE_LOYALIST, ROLE_LOYALIST, ROLE_REBEL, ROLE_REBEL, ROLE_REBEL, ROLE_REBEL, ROLE_SPY]


static func same_side(a: StringName, b: StringName) -> bool:
	var royal := [ROLE_KING, ROLE_LOYALIST]
	if royal.has(a) and royal.has(b):
		return true
	return a == b and a == ROLE_REBEL
