extends Node

## DASH YETENEKLERİ E'DE (kullanıcı kararı 2026-11-12, KALICI): "dash atma ile ilgili tüm yetenekler E ile değişsin (Elara Q, Assasin Q,
## Talon Q) - Q'ya basıp dash atmak E'ye göre çok zor ... ilerde 'E yeteneğini güçlendir' denince E = dash yeteneğidir."
## Bu test yerleşimi (DEFS, zamanlama tabloları, evrim yuvaları + kimlikleri, kalkan bedeli, bitiş temizliği) kilitler - biri yanlışlıkla
## dash'i Q'ya geri taşırsa burada kırılır.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SkillEvolutions := preload("res://scripts/skill_evolutions.gd")

## roster id -> [Q yetenek id, E yetenek id]
const LAYOUT := {1: [36, 38], 8: [11, 12], 5: [30, 5]}
## roster id -> evrim kimliği öneki
const EVO_PREFIX := {1: "talon", 8: "elara", 5: "assasin"}
## E'deki dash'in adı (evrim ipucu / seçim ekranı) ve Q'nun adı
const NAMES := {1: ["Silah Salvosu", "Hamle Vuruşu"], 8: ["Gerçek Hasar", "Sıvışma"], 5: ["Gölge Adımı", "Şahin Hamlesi"]}

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player(roster_id: int) -> Node:
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = roster_id
	GameManager.selected_character = int(Characters.DEFS[roster_id]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	p.item_shield_max = 1000.0
	p.item_shield_hp = 1000.0
	p.level = 10
	return p


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_character_definitions_put_dash_on_e() -> void:
	for cid in LAYOUT:
		var d: Dictionary = Characters.DEFS[cid]
		assert(int(d["skill"]) == int(LAYOUT[cid][0]), "roster %d: Q id %s olmalı" % [cid, LAYOUT[cid][0]])
		assert(int(d["skill2"]) == int(LAYOUT[cid][1]), "roster %d: E id %s olmalı" % [cid, LAYOUT[cid][1]])
		assert(str(d["skill_name"]) == str(NAMES[cid][0]) and str(d["skill2_name"]) == str(NAMES[cid][1]), "roster %d: Q/E adları" % cid)
		assert(str(d["skill_desc"]).begins_with("YETENEK:") and str(d["skill2_desc"]).begins_with("TEMEL:"), "roster %d: açıklama etiketi yuvayla aynı (Q YETENEK / E TEMEL)" % cid)


func test_evolution_slots_and_ids_follow_the_slot() -> void:
	for cid in EVO_PREFIX:
		var prefix: String = EVO_PREFIX[cid]
		var q_list: Array = SkillEvolutions.slot_list(cid, "skill")
		var e_list: Array = SkillEvolutions.slot_list(cid, "skill2")
		assert(q_list.size() == 5 and e_list.size() == 5, "roster %d: Q/E evrim yuvaları 4+1" % cid)
		for i in range(5):
			var want_q: String = "%s_q%s" % [prefix, "f" if i == 4 else str(i + 1)]
			var want_e: String = "%s_e%s" % [prefix, "f" if i == 4 else str(i + 1)]
			assert(str(q_list[i]["id"]) == want_q, "roster %d: Q yuvası %s olmalı, bulundu %s" % [cid, want_q, q_list[i]["id"]])
			assert(str(e_list[i]["id"]) == want_e, "roster %d: E yuvası %s olmalı, bulundu %s" % [cid, want_e, e_list[i]["id"]])
	## E yuvasının evrimleri DASH'i güçlendirir (ad/açıklamadan doğrulanır).
	assert(str(SkillEvolutions.slot_list(1, "skill2")[1]["name"]) == "Çevik Hamle", "Talon E2 = Çevik Hamle (Hamle Vuruşu)")
	assert(str(SkillEvolutions.slot_list(1, "skill")[1]["name"]) == "Uzun Girdap", "Talon Q2 = Uzun Girdap (Silah Salvosu)")
	assert(str(SkillEvolutions.slot_list(8, "skill2")[0]["name"]) == "Rüzgar Adımı", "Elara E1 = Rüzgar Adımı (Sıvışma)")
	assert(str(SkillEvolutions.slot_list(5, "skill2")[0]["name"]) == "Üçüncü Hamle", "Assasin E1 = Üçüncü Hamle (Şahin Hamlesi)")
	assert(str(SkillEvolutions.slot_list(5, "skill")[1]["name"]) == "Pusu", "Assasin Q2 = Pusu (Gölge Adımı)")


func test_unlock_levels_follow_the_slot() -> void:
	## Açılış seviyesi yuvaya bağlı: dash artık E (5. seviye).
	for cid in LAYOUT:
		assert(Characters.skill_unlock_level(cid, "skill") == 1 and Characters.skill_unlock_level(cid, "skill2") == 5, "roster %d: Q 1, E 5. seviye" % cid)


func test_timing_tables_follow_the_slot() -> void:
	var p := _make_player(1)
	assert(p.SKILL_TIMING.has(36) and not p.SKILL_TIMING.has(38), "Talon: Silah Salvosu SKILL_TIMING'de, Hamle Vuruşu değil")
	assert(p.SKILL2_TIMING.has(38) and not p.SKILL2_TIMING.has(36), "Talon: Hamle Vuruşu SKILL2_TIMING'de, Silah Salvosu değil")
	assert(p.SKILL_TIMING.has(11) and p.SKILL2_TIMING.has(12) and not p.SKILL2_TIMING.has(11) and not p.SKILL_TIMING.has(12), "Elara: Gerçek Hasar Q, Sıvışma E tablosunda")
	assert(p.SKILL_TIMING.has(30) and not p.SKILL2_TIMING.has(30), "Assasin: Gölge Adımı Q tablosunda")
	assert(is_equal_approx(float(p.SKILL2_TIMING[38]["cooldown"]), 10.0) and is_equal_approx(float(p.SKILL_TIMING[36]["cooldown"]), 20.0), "Talon bekleme süreleri taşındı")
	assert(is_equal_approx(float(p.SKILL2_TIMING[12]["cooldown"]), 10.0) and is_equal_approx(float(p.SKILL_TIMING[11]["cooldown"]), 20.0), "Elara bekleme süreleri taşındı")
	_cleanup()


## Talon: Q = Silah Salvosu standart makineden başlar/biter; E (Hamle Vuruşu) kalkan harcamaz.
func test_talon_q_is_salvo() -> void:
	var p := _make_player(1)
	var shield0: float = p.item_shield_hp
	p._activate_skill()
	assert(p.skill_state == "active" and p._talon_weapon_salvo_active, "Q Silah Salvosu'nu başlatmalı")
	assert(p.skill2_state == "ready", "Q, E yuvasına dokunmamalı")
	assert(p.item_shield_hp < shield0, "Silah Salvosu (Q) temel tarifeyi öder")
	p.skill_timer = 0.001
	p._process_skill(0.01)
	assert(not p._talon_weapon_salvo_active and p.skill_state == "cooldown", "Q süresi dolunca salvo bitmeli")
	_cleanup()


## Elara: Q = Gerçek Hasar (bayrak Q'nun bitişinde kapanır, kalkan öder); E = Sıvışma (kalkan harcamaz, içinden geçme/hız).
func test_elara_q_true_damage_and_e_evasion() -> void:
	var p := _make_player(8)
	var shield0: float = p.item_shield_hp
	p._activate_skill()
	assert(p.skill_state == "active" and p.elara_true_damage_active, "Q Gerçek Hasar'ı açmalı")
	assert(p.item_shield_hp < shield0, "Gerçek Hasar (Q) kalkan öder (eski Şovalye id 11 muafiyeti Elara'ya bulaşmamalı)")
	assert(p._elara_evasion_timer <= 0.0 and p.skill2_state == "ready", "Q Sıvışma'yı başlatmamalı")
	p.skill_timer = 0.001
	p._process_skill(0.01)
	assert(not p.elara_true_damage_active and p.skill_state == "cooldown", "Q bitince Gerçek Hasar kapanmalı")
	var shield1: float = p.item_shield_hp
	p._activate_skill2()
	assert(p.skill2_state == "active" and p._elara_evasion_timer > 0.0, "E Sıvışma'yı başlatmalı")
	assert(is_equal_approx(p.item_shield_hp, shield1), "Sıvışma (E) kalkan harcamaz")
	_cleanup()


## Assasin: Q = Gölge Adımı (standart makine, odak + görünmezlik, bitince temizlik); E = Şahin Hamlesi (yük tabanlı, makineyi kullanmaz).
func test_assasin_q_shadow_step_and_e_dash_charges() -> void:
	var p := _make_player(5)
	assert(not p.get_assasin_dash_charge_state().is_empty(), "E yük sözlüğü (HUD'un E ikonu) dolu olmalı")
	p._activate_skill()
	assert(p.skill_state == "active" and is_equal_approx(p.skill_timer, 6.0 + p.ASSASIN_INVIS_FOCUS_TIME), "Q Gölge Adımı: odak + 6 sn")
	assert(p.skill2_state == "ready", "Q, E (hamle) yuvasına dokunmamalı")
	assert(p.assasin_guaranteed_crit_active(), "Q kullanımı da Bıçak Uzmanlığı'nı tetiklemeli")
	p._process_assasin_invis_focus(float(p.ASSASIN_INVIS_FOCUS_TIME) + 0.01)
	assert(p.is_invisible and p._assasin_invis_active(), "odaktan sonra görünmez")
	p.skill_timer = 0.001
	p._process_skill(0.01)
	assert(not p.is_invisible and p.skill_state == "cooldown", "Q bitince görünmezlik kapanmalı")
	var charges0: int = p.assasin_dash2_charges
	p._try_assasin_dash2()
	assert(p.assasin_dash2_charges == charges0 - 1 and p.skill2_state == "ready", "E hamle yük harcar, standart E makinesine girmez")
	_cleanup()
