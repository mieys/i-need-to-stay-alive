extends Node

## Madde 725 (kullanıcı 2026-11-16: "Cozy_Status_Icons klasöründe oyundaki buff-debuff etkileri için yeni ikonlar al... çalıda saklanınca da"):
## rozeti olmayan etkiler skill barın üstündeki durum satırında görünür. Her türün açıklaması + Cozy ikonu olmalı; oyuncu durumu doğru satıra
## (buff / debuff) düşmeli; Taşlaşma / Taş Ağırlığı kendi rozetini gösterirken genel sersemleme / yavaşlama tekrar edilmez.

const Badge := preload("res://scripts/status_effect_badge.gd")
const HideBrushScript := preload("res://scripts/hide_brush.gd")

const NEW_KINDS := ["stun", "slow", "wade", "brush_hidden", "brush_spotted", "item_regen", "gunes", "item_invuln", "light_guard", "urkek", "kemik"]


func _entries(player: Node) -> Dictionary:
	var out: Dictionary = {}
	for s: Dictionary in player.get_status_effects():
		out[str(s["kind"])] = s
	return out


func test_every_new_kind_has_text_and_48px_icon() -> void:
	for kind: String in NEW_KINDS:
		assert(Badge.INFO.has(kind), "rozet açıklaması: " + kind)
		var tex: Texture2D = load(Badge.ICON_DIR + kind + ".png") as Texture2D
		assert(tex != null, "rozet ikonu: " + kind)
		assert(tex.get_width() == 48 and tex.get_height() == 48, "Cozy 16 px x3 = 48 px: " + kind)


func test_player_states_map_to_badges() -> void:
	var player: Node2D = (preload("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	assert(_entries(player).keys().filter(func(k: String) -> bool: return NEW_KINDS.has(k)).is_empty(), "başlangıçta yeni rozet yok")
	## debuff'lar
	player.apply_stun(2.0)
	player.apply_pvp_slow(0.3, 3.0)
	player.wade_slow_active = true
	var e: Dictionary = _entries(player)
	for kind: String in ["stun", "slow", "wade"]:
		assert(e.has(kind) and not bool(e[kind]["is_buff"]), "debuff satırında: " + kind)
	assert(is_equal_approx(float(e["stun"]["remaining"]), 2.0) and is_equal_approx(float(e["slow"]["remaining"]), 3.0), "kalan süre")
	## Taşlaşma kendi rozetini gösterir -> genel sersemleme / yavaşlama gizli
	player._petrify_left = 1.0
	player._stone_slow_left = 1.0
	e = _entries(player)
	assert(not e.has("stun") and not e.has("slow"), "taşlaşma varken tekrar yok")
	player._petrify_left = 0.0
	player._stone_slow_left = 0.0
	player.wade_slow_active = false
	## çalı: saklı = buff, görüldü = debuff, çalı dışı = yok
	player.set_brush_state(HideBrushScript.STATE_HIDDEN)
	e = _entries(player)
	assert(e.has("brush_hidden") and bool(e["brush_hidden"]["is_buff"]) and not e.has("brush_spotted"), "saklı rozeti")
	player.set_brush_state(HideBrushScript.STATE_SPOTTED)
	e = _entries(player)
	assert(e.has("brush_spotted") and not bool(e["brush_spotted"]["is_buff"]) and not e.has("brush_hidden"), "görüldü rozeti")
	player.set_brush_state(HideBrushScript.STATE_NONE)
	e = _entries(player)
	assert(not e.has("brush_hidden") and not e.has("brush_spotted"), "çalı dışında rozet yok")
	## eşya buff'ları
	player.item_vitamin_regen_bonus = 1.0
	player.item_vitamin_regen_timer = 4.0
	player._item_gunes_heal_left = 30.0
	player._item_gunes_heal_rate = 10.0
	player._item_invuln_timer = 1.0
	player._light_guard_timer = 5.0
	player._item_urkek_timer = 6.0
	player._owned_item_counts["kemik_kolye"] = 1
	player._item_kemik_charges = 4
	e = _entries(player)
	for kind: String in ["item_regen", "gunes", "item_invuln", "light_guard", "urkek", "kemik"]:
		assert(e.has(kind) and bool(e[kind]["is_buff"]), "buff satırında: " + kind)
	assert(is_equal_approx(float(e["gunes"]["remaining"]), 3.0), "Güneşin İradesi kalan süre = kalan can / hız")
	assert(int(e["kemik"]["stacks"]) == 4, "Kemik Kolye yük sayısı")
	player._owned_item_counts.erase("kemik_kolye")
	assert(not _entries(player).has("kemik"), "eşya satılınca Kemik Kolye rozeti yok")
	player.queue_free()
