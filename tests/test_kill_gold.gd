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


## 2026-10-24: yaratık altını yine yere düşer (GoldDrop), karaktere otomatik gönderilmez; miktar hesabı (amount_for) aynı.
func test_enemy_drops_gold_on_the_ground() -> void:
	assert(KillGold.GROUND_DROPS, "yaratık altını yere düşmeli")
	var source: String = FileAccess.get_file_as_string("res://scripts/enemy.gd")
	if source.length() == 0:
		return
	var g: int = source.find("func _drop_gold()")
	var end: int = source.find("func _award_gold_directly(")
	assert(g != -1 and end > g, "_drop_gold bulunamadı")
	var body: String = source.substr(g, end - g)
	assert(body.find("KillGold.amount_for(") != -1, "miktar hesabı değişmedi")
	assert(body.find("GoldDrop.instantiate()") != -1 and body.find("broadcast_drop.rpc(\"gold\"") != -1, "altın GoldDrop olarak düşüp yayınlanmalı")
	assert(body.find("KillGold.award") == -1, "ana yolda otomatik teslim olmamalı")


## Ölen yaratık yerde GoldDrop bırakır, altın o zaman eklenmez; toplama mesafesine girince (XP gibi) oyuncuya çekilir, toplanınca
## karakterin üstünde "+N" yazısı çıkar.
func test_dead_enemy_leaves_gold_that_is_collected_by_proximity() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var was_active: bool = NetworkManager.is_multiplayer_active
	NetworkManager.is_multiplayer_active = false
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.gold_min = 3
	e.gold_max = 3
	e.gold_chance = 1.0
	add_child(e)
	e.global_position = Vector2(5000, 5000)
	var before: int = GameManager.gold
	e.call("_drop_gold")
	Enemy.drain_drop_spawn_queue() ## kuyruğu normalde ana sahne boşaltır
	for i in 3:
		await get_tree().process_frame
	var drops: Array = get_tree().get_nodes_in_group("gold_drops").filter(func(n: Node) -> bool: return n.global_position.distance_to(Vector2(5000, 5000)) < 40.0)
	assert(drops.size() == 1, "yerde tek altın düşmeli: %d" % drops.size())
	assert(GameManager.gold == before, "düşen altın yerdeyken eklenmez")
	assert(int(drops[0].amount) == 3, "miktar aynı: %d" % int(drops[0].amount))
	## Toplama: oyuncu gövdesi altına değer.
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = drops[0].global_position
	drops[0].call("_on_body_entered", p)
	assert(GameManager.gold == before + 3, "toplanınca altın eklenir")
	var texts: Array = []
	for n in get_children():
		if "label" in n and n.get("label") is Label:
			texts.append((n.get("label") as Label).text)
	assert(texts.has("+3"), "karakterin üstünde +N yazısı: %s" % [texts])
	GameManager.gold = before
	NetworkManager.is_multiplayer_active = was_active
	p.remove_from_group("player")
	p.free()
	e.free()
	get_tree().current_scene = prev_scene


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


## Oyuncu yoksa (ya da görüş dışı) para gösterilemez: altın eski gibi anında verilir.
func test_award_without_player_gives_instantly() -> void:
	var before: int = GameManager.gold
	KillGold.award(get_tree(), 9, Vector2(10, 10), null)
	assert(GameManager.gold == before + 9, "oyuncu yoksa anında eklenir")
	GameManager.gold = before


## Yaratık altını yere düşen dönen paradır: 0,5 sn bekler, sonra oyuncuya uçar, VARINCA altın eklenir (kullanıcı 2026-10-21).
func test_award_drops_spinning_coin_that_flies_to_player_after_half_second() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = Vector2(300, 0)
	var before: int = GameManager.gold
	var coins_before: int = KillGold.active_coins
	KillGold.award(get_tree(), 9, Vector2(60, 0), null)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(KillGold.active_coins == coins_before + 1, "yerde bir para belirmeli")
	assert(GameManager.gold == before, "para yerdeyken altın henüz eklenmez")
	var coin: Node2D = null
	for c in get_children():
		if c.get_script() == KillGold.COIN_SCRIPT:
			coin = c
	assert(coin != null, "para düğümü sahnede")
	assert(is_equal_approx(coin.HOVER_TIME, 0.5), "0,5 sn bekleme")
	await get_tree().create_timer(0.35).timeout
	assert(coin.global_position.distance_to(Vector2(60, 0)) < 20.0, "ilk 0,5 sn içinde yerinde durur")
	assert(GameManager.gold == before, "uçuş başlamadan altın eklenmez")
	await get_tree().create_timer(0.3).timeout ## 0,65 sn: uçuş başlamış, henüz varmamış olabilir
	assert(not is_instance_valid(coin) or coin.global_position.x > 90.0, "0,5 sn sonra oyuncuya doğru uçar")
	await get_tree().create_timer(KillGold.COIN_SCRIPT.MAX_FLIGHT + 0.2).timeout
	assert(GameManager.gold == before + 9, "varınca altın eklenir")
	assert(KillGold.active_coins == coins_before, "para varınca silinir")
	GameManager.gold = before
	p.remove_from_group("player")
	p.free()
	get_tree().current_scene = prev_scene


## Çok para olunca düğüm sayısı patlamasın: sınırdan sonrası anında verilir.
func test_coin_cap_falls_back_to_instant_gold() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	var saved: int = KillGold.active_coins
	KillGold.active_coins = KillGold.MAX_ACTIVE_COINS
	var before: int = GameManager.gold
	KillGold.award(get_tree(), 4, Vector2(20, 0), null)
	assert(GameManager.gold == before + 4, "para sınırı dolunca altın anında verilir")
	KillGold.active_coins = saved
	GameManager.gold = before
	p.remove_from_group("player")
	p.free()
	get_tree().current_scene = prev_scene


## peer_id alanı olan sahte uzak oyuncu kuklası.
func _peer_node(peer: int) -> Node2D:
	var n := Node2D.new()
	var src := GDScript.new()
	src.source_code = "extends Node2D\nvar peer_id: int = 0\n"
	src.reload()
	n.set_script(src)
	n.set("peer_id", peer)
	return n


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


## 2026-10-19 (madde 308): takım payı "TAKIM +N", asist "ASİST +N", kendi öldürme "+N".
func test_team_share_text_is_labelled() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	KillGold.show_at(get_tree(), 3, Vector2(0, 0), KillGold.TEAM_KIND)
	KillGold.show_at(get_tree(), 5, Vector2(0, 0), 1)
	KillGold.show_at(get_tree(), 7, Vector2(0, 0))
	var texts: Array = []
	for n in get_children():
		if "label" in n and n.get("label") is Label:
			texts.append((n.get("label") as Label).text)
	assert(texts.has("TAKIM +3") and texts.has("ASİST +5") and texts.has("+7"), "yazı türleri: %s" % [texts])
	get_tree().current_scene = prev_scene


## Çok oyunculu bayrak açık + yalnız yerel oyuncu: takım payı çalışmaz (grup tek kişi), altının tamamı öldürene (yerel) gider; yeni kod yolu hatasız koşar.
func test_enemy_award_with_assists_alone_in_multiplayer_flag() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var was_active: bool = NetworkManager.is_multiplayer_active
	NetworkManager.is_multiplayer_active = true
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	var e: Node2D = (load("res://scenes/creatures/enemy_agac1.tscn") as PackedScene).instantiate()
	add_child(e)
	var before: int = GameManager.gold
	e.call("_award_with_assists", 10, Vector2.ZERO)
	await get_tree().create_timer(KillGold.COIN_SCRIPT.HOVER_TIME + 0.4).timeout ## dönen para bekler, oyuncuya uçar, varınca verilir
	assert(GameManager.gold == before + 10, "tek başına: 10 altının tamamı yerel öldürene: %d" % (GameManager.gold - before))
	GameManager.gold = before
	NetworkManager.is_multiplayer_active = was_active
	p.remove_from_group("player")
	p.free()
	e.free()
	get_tree().current_scene = prev_scene
