extends Node

## Kullanıcı isteği (2026-09-28): her 5 takım seviyesinde oynanan karaktere göre 3 rastgele YETENEK EVRİMİ kartı (normal
## stat kartlarının yerine). Temel yeteneklerin (Q/E) 4 geliştirme + 1 finali, ultinin (R) 2 geliştirme + 1 finali var;
## final ancak o yuvanın diğer tüm geliştirmeleri alınınca havuza girer; sadece açık yeteneklerin evrimleri çıkar.
## Bu test tek kaynağı (skill_evolutions.gd) ve player.gd'nin süre/bekleme/sayı okuyan yüzeyini doğrular.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SkillEvolutions: GDScript = preload("res://scripts/skill_evolutions.gd")
const HadimeMath: GDScript = preload("res://scripts/hadime_math.gd")
const VampirMath: GDScript = preload("res://scripts/vampir_math.gd")

## Kullanıcının evrimlerini yazdığı karakterler (roster id) - 2026-09-30: Assasin Çocuk (5) eklendi.
const EVO_CHARS := [14, 13, 10, 1, 8, 9, 7, 3, 5, 12, 4] ## 12 = Shaman, 4 = Büyücü Kız (2026-10-04)

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player(char_id: int) -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = char_id
	GameManager.selected_character = int(Characters.DEFS[char_id]["skill"])
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	return player


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _ids(list: Array) -> Array:
	var out: Array = []
	for e in list:
		out.append(str(e["id"]))
	return out


# ------------------------------------------------------------------ veri

func test_defs_shape_matches_request() -> void:
	var seen: Dictionary = {}
	for char_id in EVO_CHARS:
		assert(SkillEvolutions.has_evolutions(char_id), "evrimi yazılan karakter eksik: %d" % char_id)
		assert(Characters.DEFS.has(char_id), "roster'da olmayan karakter: %d" % char_id)
		for slot in SkillEvolutions.SLOTS:
			var list: Array = SkillEvolutions.slot_list(char_id, slot)
			## Temel yetenek: 4 + final, ulti: 2 + final (Elara R / Matthew R'de kullanıcı "3. geliştirme final" dedi).
			var expected: int = 3 if slot == "skill3" else 5
			assert(list.size() == expected, "%d %s: %d evrim (beklenen %d)" % [char_id, slot, list.size(), expected])
			for i in range(list.size()):
				var e: Dictionary = list[i]
				var is_final: bool = bool(e.get("final", false))
				assert(is_final == (i == list.size() - 1), "%s: final yalnız ve her zaman listenin sonunda olmalı" % str(e["id"]))
				assert(not str(e.get("name", "")).is_empty() and not str(e.get("desc", "")).is_empty(), "%s: ad/açıklama boş" % str(e["id"]))
				assert(not seen.has(str(e["id"])), "tekrarlanan evrim id: %s" % str(e["id"]))
				seen[str(e["id"])] = true
				var found: Dictionary = SkillEvolutions.find(str(e["id"]))
				assert(int(found.get("char_id", -1)) == char_id and str(found.get("slot", "")) == slot, "find() yanlış yer: %s" % str(e["id"]))
				assert(int(found.get("index", 0)) == i + 1 and int(found.get("count", 0)) == list.size(), "find() sıra/sayı yanlış: %s" % str(e["id"]))
	## Evrimi henüz yazılmamış karakterler kart görmez (kullanıcı: "o zamana kadar sadece bu herolar").
	for char_id in Characters.DEFS:
		if not EVO_CHARS.has(int(char_id)):
			assert(not SkillEvolutions.has_evolutions(int(char_id)), "evrimi yazılmamış karakterde DEFS girdisi: %d" % int(char_id))
	assert(SkillEvolutions.find("yok_boyle_bir_evrim").is_empty(), "bilinmeyen id boş sözlük döndürmeli")


func test_evolution_levels_every_five() -> void:
	for lv in [5, 10, 15, 20, 45]:
		assert(SkillEvolutions.is_evolution_level(lv), "%d evrim seviyesi olmalı" % lv)
	for lv in [0, 1, 4, 6, 9, 11, 14, 16]:
		assert(not SkillEvolutions.is_evolution_level(lv), "%d evrim seviyesi olmamalı" % lv)


# ------------------------------------------------------------------ havuz kuralı

func test_pool_only_unlocked_slots() -> void:
	## Hadime: Q 1, E 5, R 10. seviyede açılır -> 5. seviyede R evrimi çıkmaz, 10'da çıkar.
	var at5: Array = SkillEvolutions.available(14, {}, 5)
	var at10: Array = SkillEvolutions.available(14, {}, 10)
	for e in at5:
		assert(str(e["slot"]) != "skill3", "R 10. seviyeden önce havuzda: %s" % str(e["id"]))
	var r_count: int = 0
	for e in at10:
		if str(e["slot"]) == "skill3":
			r_count += 1
	assert(r_count == 2, "10. seviyede R'nin 2 geliştirmesi havuzda olmalı (final değil), var: %d" % r_count)
	assert(at5.size() == 8, "5. seviye: Q 4 + E 4 geliştirme, final yok (var: %d)" % at5.size())


func test_final_enters_pool_only_after_all_regulars() -> void:
	var owned: Dictionary = {}
	var q_list: Array = SkillEvolutions.slot_list(13, "skill")
	for i in range(q_list.size() - 1):
		assert(not _ids(SkillEvolutions.available(13, owned, 20)).has("vampir_qf"), "final %d geliştirmeyle havuza girdi" % i)
		owned[str(q_list[i]["id"])] = true
		assert(not _ids(SkillEvolutions.available(13, owned, 20)).has(str(q_list[i]["id"])), "alınan evrim havuzda kaldı")
	assert(_ids(SkillEvolutions.available(13, owned, 20)).has("vampir_qf"), "4 geliştirme sonrası final havuzda olmalı")
	owned["vampir_qf"] = true
	for e in SkillEvolutions.available(13, owned, 20):
		assert(str(e["slot"]) != "skill", "Q'nun tüm evrimleri alınınca Q havuzda kalmamalı")
	assert(SkillEvolutions.owned_count(13, "skill", owned) == 5, "owned_count Q = 5 olmalı")


func test_roll_offer_unique_and_capped() -> void:
	for _i in range(30):
		var offer: Array = SkillEvolutions.roll_offer(1, {}, 10)
		assert(offer.size() == SkillEvolutions.OFFER_COUNT, "3 kart sunulmalı")
		var ids: Array = _ids(offer)
		for id in ids:
			assert(ids.count(id) == 1, "aynı kart iki kez: %s" % id)
			assert(not bool(SkillEvolutions.find(id).get("final", false)), "hiç geliştirme yokken final sunuldu: %s" % id)
	## Havuz 3'ten küçükse elde kalan kadar (ve boşsa hiç) kart.
	var owned: Dictionary = {}
	for slot in SkillEvolutions.SLOTS:
		for e in SkillEvolutions.slot_list(1, slot):
			owned[str(e["id"])] = true
	owned.erase("talon_rf")
	assert(SkillEvolutions.roll_offer(1, owned, 10).size() == 1, "tek evrim kaldıysa tek kart")
	owned["talon_rf"] = true
	assert(SkillEvolutions.roll_offer(1, owned, 10).is_empty(), "havuz bitince evrim kartı yok (normal kartlara düşer)")


# ------------------------------------------------------------------ player.gd yüzeyi

func test_apply_is_idempotent_and_tracks_progress() -> void:
	var player := _make_player(14)
	assert(player.get_evolution_progress("skill") == Vector2i(0, 5), "başlangıç Q ilerlemesi 0/5")
	player.apply_skill_evolution("hadime_q1", true)
	player.apply_skill_evolution("hadime_q1", true)
	player.apply_skill_evolution("yok_boyle_bir_evrim", true)
	assert(player.has_evo("hadime_q1"), "evrim uygulanmadı")
	assert(player.skill_evolutions.size() == 1, "aynı evrim iki kez ya da bilinmeyen id eklendi: %s" % str(player.skill_evolutions))
	assert(player.get_evolution_progress("skill") == Vector2i(1, 5), "Q ilerlemesi 1/5 olmalı")
	assert(player.get_evolution_progress("skill3") == Vector2i(0, 3), "R ilerlemesi 0/3 olmalı")
	player.apply_skill_evolution("hadime_e1", true)
	assert(player.get_skill_evolution_ids() == ["hadime_e1", "hadime_q1"], "ağ listesi sıralı olmalı (değişmedikçe aynı paket)")
	_cleanup()


func test_hadime_timings_and_costs() -> void:
	var player := _make_player(14)
	var r0: Dictionary = player._skill3_timing_for(48)
	assert(is_equal_approx(float(r0["duration"]), 12.0), "Karabasan temel süresi 15 -> 12 sn (var: %s)" % str(r0["duration"]))
	var e0: Dictionary = player._skill2_timing_for(47)
	player.apply_skill_evolution("hadime_r1", true)
	player.apply_skill_evolution("hadime_r2", true)
	player.apply_skill_evolution("hadime_e4", true)
	var r1: Dictionary = player._skill3_timing_for(48)
	assert(is_equal_approx(float(r1["duration"]), 17.0), "Uzun Kabus +5 sn")
	assert(is_equal_approx(float(r1["cooldown"]), float(r0["cooldown"]) * 0.75), "Tekrarlayan Kabus bekleme -%25")
	assert(is_equal_approx(float(player._skill2_timing_for(47)["cooldown"]), float(e0["cooldown"]) * 0.7), "Hızlı Çöküş bekleme -%30")
	## Q: yavaşlatma yerine +%10, saniyelik bedel yarıya, Karabasan'da (final) bedelsiz.
	player.item_shield_max = 200.0
	var cost0: float = player._hadime_q_cost()
	player._hadime_q_active = true
	var slow_mult: float = player._hadime_move_mult()
	assert(slow_mult < 1.0, "temel Q yavaşlatır")
	player.apply_skill_evolution("hadime_q2", true)
	player.apply_skill_evolution("hadime_q3", true)
	assert(is_equal_approx(player._hadime_move_mult(), 1.1), "Hafif Süzülüş: +%10 hareket")
	assert(is_equal_approx(player._hadime_q_cost(), cost0 * 0.5), "Tutumlu Okuma: bedel yarıya")
	player._hadime_q_active = false
	player.apply_skill_evolution("hadime_rf", true)
	assert(not player._evo_skill_free("skill"), "Bedelsiz Kabus yalnız Karabasan formunda")
	player._hadime_nightmare_active = true
	assert(player._evo_skill_free("skill") and player._evo_skill_free("skill2"), "Karabasan formunda yetenekler bedelsiz")
	assert(is_equal_approx(player._hadime_q_cost(), 0.0), "Karabasan formunda Q bedeli 0")
	player._hadime_nightmare_active = false
	assert(not player._evo_skill_free("skill"), "form bitince bedel geri gelir")
	_cleanup()


func test_talon_matthew_base_nerfs_and_cooldowns() -> void:
	var talon := _make_player(1)
	assert(is_equal_approx(float(talon._skill_timing_for(38)["cooldown"]), 10.0), "Talon Q temel bekleme 10 sn")
	var e0: Dictionary = talon._skill2_timing_for(36)
	var r0: Dictionary = talon._skill3_timing_for(37)
	talon.apply_skill_evolution("talon_q2", true)
	talon.apply_skill_evolution("talon_e2", true)
	talon.apply_skill_evolution("talon_r2", true)
	assert(is_equal_approx(float(talon._skill_timing_for(38)["cooldown"]), 7.0), "Çevik Hamle -%30")
	assert(is_equal_approx(float(talon._skill2_timing_for(36)["duration"]), float(e0["duration"]) + 2.0), "Uzun Girdap +2 sn")
	assert(is_equal_approx(float(talon._skill3_timing_for(37)["duration"]), float(r0["duration"]) + 4.0), "Uzun Yansıma +4 sn")
	_cleanup()
	var matthew := _make_player(3)
	assert(is_equal_approx(float(matthew._skill_timing_for(43)["cooldown"]), 10.0), "Matthew Q temel bekleme 10 sn")
	assert(is_equal_approx(float(matthew._skill2_timing_for(21)["duration"]), 6.0), "Matthew E temel süre 6 sn")
	var move0: float = matthew.matthew_haste_bonus("move")
	matthew.apply_skill_evolution("matthew_q2", true)
	matthew.apply_skill_evolution("matthew_q4", true)
	matthew.apply_skill_evolution("matthew_e1", true)
	matthew.apply_skill_evolution("matthew_e2", true)
	matthew.apply_skill_evolution("matthew_e3", true)
	assert(is_equal_approx(float(matthew._skill_timing_for(43)["cooldown"]), 7.0), "Çevik Köpek -%30")
	assert(is_equal_approx(float(matthew._skill2_timing_for(21)["duration"]), 10.0), "Uzun Av +4 sn")
	assert(matthew._evo_skill_free("skill") and not matthew._evo_skill_free("skill2"), "Bedava Av yalnız Q")
	assert(is_equal_approx(matthew.matthew_haste_bonus("move"), 0.3) and move0 < 0.3, "Vahşi Koşu hareket %30")
	assert(is_equal_approx(matthew.matthew_haste_bonus("attack"), 0.5), "Vahşi Koşu saldırı %50")
	assert(is_equal_approx(matthew.matthew_haste_bonus("move", true), 0.6), "Köpek Ruhu: köpek 2 kat")
	_cleanup()


func test_korsan_vampir_counts() -> void:
	var korsan := _make_player(9)
	var charges0: int = korsan.get_korsan_max_bomb_charges()
	var radius0: float = korsan._korsan_bombardment_radius()
	korsan.apply_skill_evolution("korsan_e1", true)
	korsan.apply_skill_evolution("korsan_r1", true)
	assert(korsan.get_korsan_max_bomb_charges() == 5 and charges0 < 5, "Dolu Cephanelik: 5 yük")
	assert(is_equal_approx(korsan._korsan_bombardment_radius(), radius0 * 1.5), "Geniş Bombardıman +%50")
	_cleanup()
	var vampir := _make_player(13)
	assert(VampirMath.BAT_COUNT == 3 and vampir._vampir_bat_count() == 3, "R temel 3 yarasa")
	vampir.apply_skill_evolution("vampir_r1", true)
	assert(vampir._vampir_bat_count() == 5, "Büyüyen Sürü +2 yarasa")
	_cleanup()


func test_timing_untouched_without_evolutions() -> void:
	## Evrimi olmayan karakterlerin (ve evrimsiz oyuncunun) zamanlamaları birebir aynı sözlük olmalı - fazladan anahtar yok.
	var player := _make_player(8)
	var before: Dictionary = player._skill2_timing_for(11)
	assert(player._evo_timing(11, before) == before, "evrimsiz _evo_timing değer değiştirmemeli")
	player.apply_skill_evolution("elara_q1", true)
	assert(player._skill2_timing_for(11) == before, "ilgisiz evrim E zamanlamasını değiştirmemeli")
	player.apply_skill_evolution("elara_e4", true)
	var after: Dictionary = player._skill2_timing_for(11)
	assert(is_equal_approx(float(after["duration"]), float(before["duration"]) + 2.0), "Uzun Odak +2 sn")
	assert(is_equal_approx(float(after["cooldown"]), float(before["cooldown"])), "Uzun Odak bekleme süresine dokunmaz")
	_cleanup()
