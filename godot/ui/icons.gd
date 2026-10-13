class_name SgsIcons
extends RefCounted
## Maps game ids to icon textures in ui/assets/icons (game-icons.net, CC BY 3.0).

const ICON_DIR := "res://ui/assets/icons/"

const CARD_ICONS := {
	"strike": "sword-brandish", "strike_fire": "fire-dash", "strike_thunder": "thunder-blade",
	"dodge": "dodging", "peach": "peach", "wine": "wine-glass",
	"negate": "cancel", "dismantle": "hammer-drop", "snatch": "snatch", "windfall": "two-coins",
	"peach_garden": "fruit-bowl", "harvest": "bowl-of-rice", "barbarians": "barbarian",
	"arrows": "arrow-cluster", "duel": "crossed-swords", "borrowed_sword": "saber-slash",
	"blaze": "fire-ray", "chain": "chain-lightning", "lightning": "lightning-storm",
	"contentment": "bed", "starvation": "cooking-pot",
	"crossbow": "crossbow", "double_swords": "swords-emblem", "ice_sword": "ice-bolt",
	"black_pommel": "pointy-sword", "axe": "battle-axe", "green_dragon": "dragon-head",
	"serpent_spear": "spear-hook", "sky_scorcher": "halberd", "kylin_bow": "bow-arrow",
	"ancient_scimitar": "broadsword", "fire_fan": "fire-ring",
	"eight_trigrams": "yin-yang", "black_shield": "bordered-shield", "wooden_armor": "round-shield",
	"silver_helmet": "crested-helmet", "horse_plus": "horse-head", "horse_minus": "horseshoe",
}

const ROLE_ICONS := {"king": "crown", "loyalist": "shield", "rebel": "skull-crossed-bones", "spy": "spy"}

const TYPE_COLORS := {
	"basic": Color(0.18, 0.46, 0.30), "trick": Color(0.22, 0.30, 0.56), "equipment": Color(0.55, 0.38, 0.14),
}

const FACTION_COLORS := {
	"shu": Color(0.72, 0.18, 0.14), "wei": Color(0.16, 0.34, 0.62), "wu": Color(0.14, 0.50, 0.30), "qun": Color(0.45, 0.42, 0.40),
}

static var _cache: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if name == "":
		return null
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D = load(ICON_DIR + name + ".svg")
	_cache[name] = t
	return t


static func card(def_id: String) -> Texture2D:
	return tex(CARD_ICONS.get(def_id, "scroll-unfurled"))


static func role(role_id: String) -> Texture2D:
	return tex(ROLE_ICONS.get(role_id, ""))


static func type_color(type_id: String) -> Color:
	return TYPE_COLORS.get(type_id, Color(0.3, 0.3, 0.3))
