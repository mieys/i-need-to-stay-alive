extends Node

## Yaratık altını yere düşmez, öldürene "+N" yazısı + sesle verilir (2026-10-15, bkz. scripts/kill_gold.gd).

const KillGold = preload("res://scripts/kill_gold.gd")


func test_amount_is_guaranteed_and_scales_with_creature_tier() -> void:
	## Düşük kademe (1-2 altın, %15 şans): beklenen değer 1'in altında olsa da her ölüm en az 1 altın verir.
	assert(KillGold.amount_for(1, 2, 0.1512) == 1, "düşük kademe en az 1 altın")
	## Yüksek kademe: şans x ortalama (6-10, %65,5 -> 5,24 -> 5), kademe yükseldikçe miktar artar.
	var low: int = KillGold.amount_for(1, 2, 0.15)
	var mid: int = KillGold.amount_for(3, 5, 0.4)
	var high: int = KillGold.amount_for(6, 10, 0.6552)
	assert(low <= mid and mid <= high and high == 5, "miktar kademeyle artar: %d %d %d" % [low, mid, high])


func test_boss_chance_one_rolls_inside_range() -> void:
	for i in 40:
		var v: int = KillGold.amount_for(20, 30, 1.0)
		assert(v >= 20 and v <= 30, "boss altını [min,max] içinde: %d" % v)


func test_summon_roll_can_give_nothing() -> void:
	var zeros: int = 0
	for i in 400:
		if KillGold.amount_for(1, 2, 0.05, true) == 0:
			zeros += 1
	assert(zeros > 300, "minyon şansa bağlı kalır, çoğu ölüm altın vermez: %d/400" % zeros)
	assert(KillGold.amount_for(3, 4, 1.0, true) >= 3, "şans 1 ise minyon da verir")


func test_enemy_no_longer_spawns_gold_drops() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/enemy.gd")
	if source.length() == 0:
		return
	var g: int = source.find("func _drop_gold()")
	var end: int = source.find("func _roll_extra_item_gold()")
	assert(g != -1 and end > g, "_drop_gold bulunamadı")
	var body: String = source.substr(g, end - g)
	assert(body.find("GoldDrop") == -1 and body.find("broadcast_drop") == -1, "yaratık altını artık yere düşmemeli")
	assert(body.find("KillGold.") != -1, "altın KillGold ile verilmeli")


func test_award_adds_gold_to_local_player() -> void:
	var before: int = GameManager.gold
	KillGold.award_now(get_tree(), 7, Vector2(10, 10), null)
	assert(GameManager.gold == before + 7, "altın hemen eklenmeli")
	GameManager.gold = before
	KillGold.award_now(get_tree(), 0, Vector2.ZERO, null)
	assert(GameManager.gold == before, "0 altın bir şey eklemez")


func test_off_view_gold_shows_over_player() -> void:
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = Vector2(500, 500)
	var near: Vector2 = KillGold.resolve_pos(get_tree(), Vector2(520, 500))
	assert(near == Vector2(520, 500), "görüş içindeki altın kaynağında gösterilir")
	var far: Vector2 = KillGold.resolve_pos(get_tree(), Vector2(5000, 500))
	assert(far.distance_to(Vector2(500, 500)) < 20.0, "görüş dışı altın karakterin üstünde gösterilir: %s" % [far])
	p.remove_from_group("player")
	p.queue_free()


func test_world_give_adds_gold_without_flying_coins() -> void:
	const GoldFx = preload("res://scripts/gold_reward_fx.gd")
	var before: int = GameManager.gold
	GoldFx.give(get_tree(), 12, Vector2(100, 100))
	assert(GameManager.gold == before + 12, "dünya konumlu altın anında eklenir")
	assert(GoldFx.display_gold() == GameManager.gold, "panel sayacı beklemez (uçan para yok)")
	GameManager.gold = before


func test_award_is_delayed_briefly() -> void:
	assert(is_equal_approx(KillGold.SHOW_DELAY, 0.2), "altın ölümden 0,2 sn sonra gelir")
	var before: int = GameManager.gold
	KillGold.award(get_tree(), 9, Vector2(10, 10), null)
	assert(GameManager.gold == before, "gecikmeli: hemen eklenmez")
	await get_tree().create_timer(KillGold.SHOW_DELAY + 0.3).timeout
	assert(GameManager.gold == before + 9, "gecikmeden sonra eklenir")
	GameManager.gold = before


func test_icon_is_static_and_beside_text() -> void:
	if get_tree().current_scene == null:
		return
	KillGold.show_at(get_tree(), 4, Vector2(0, 0))
	var icon: Sprite2D = null
	for n in get_tree().current_scene.get_children():
		for c in n.get_children():
			if c is AnimatedSprite2D:
				assert(false, "altın simgesi animasyonlu olmamalı")
			if c is Sprite2D and (c as Sprite2D).texture == KillGold.COIN_FRAMES.get_frame_texture("spin", 0):
				icon = c
	assert(icon != null, "yazının yanında sabit altın simgesi olmalı")
	## Simge yazının solunda ve metnin dikey ortasında (Label üst hizalı: -22 ... -22+yükseklik).
	assert(icon.position.x < 0.0 and icon.position.y > -22.0 and icon.position.y < 8.0, "simge yazıya bitişik: %s" % [icon.position])
