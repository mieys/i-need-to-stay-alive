extends RefCounted

## OYUN MODU (PvPvE 2v2, plan docs/pvp/PLAN.md, madde 607): "coop" = bugünkü oyun (HER ŞEY eskisi gibi), "pvp" = iki takım aynı haritada,
## her takımın kampı / üssü (scripts/pvp/team_bases.gd). Mod odanın özelliğidir: host oda kurarken seçer (room_browser.gd), istemci host'tan
## alır (pvp_net.gd). PvP yalnız çok oyunculuda açıktır; tek oyunculu koşu (ya da odadan çıkıldıktan sonraki tek oyunculu oyun) hep coop.
## Geliştirmede MOD=pvp|coop ortam değişkeni ezer (tek oyunculuda da: kamp/üs görüntüsü ve testler için).
## Bu betik autoload'lardan ÖNCE derlenebilir (map_profiles.gd onu preload eder): NetworkManager'a tanımlayıcıyla değil kök düğümden erişilir.

const COOP := "coop"
const PVP := "pvp"
const MODES: Array[String] = [COOP, PVP]

## Modun harita özellik bayraklarını ezmesi (map_profiles.gd feature()): PvP'de açılış evi + kuşatma + babaanne kapalı (takımlar kendi
## kamplarında başlar, PLAN.md K2).
const FEATURE_OVERRIDES := {
	PVP: {"ev_acilisi": false},
}

## Host'un oda kurarken seçtiği / istemcinin host'tan aldığı mod.
static var room_mode: String = COOP


static func set_room_mode(mode: String) -> void:
	room_mode = mode if MODES.has(mode) else COOP


static func current() -> String:
	var env: String = preload("res://scripts/security/security_guard.gd").dev_env("MOD") ## yalnız editörde (hile koruması, 2026-11-12)
	if MODES.has(env):
		return env
	return room_mode if _multiplayer_active() else COOP


static func is_pvp() -> bool:
	return current() == PVP


## Harita özellik bayrağının mod ezmesi; ezme yoksa null.
static func feature_override(name: String) -> Variant:
	var o: Dictionary = FEATURE_OVERRIDES.get(current(), {})
	if o.has(name):
		return bool(o[name])
	return null


static func display_name(mode: String) -> String:
	return "2v2 Takım" if mode == PVP else "Ortak"


static func _multiplayer_active() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var nm: Node = (loop as SceneTree).root.get_node_or_null("NetworkManager")
	return nm != null and bool(nm.get("is_multiplayer_active"))
