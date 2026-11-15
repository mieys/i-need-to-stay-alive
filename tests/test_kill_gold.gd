extends Node

## Yaratık altını yere düşmez, öldürene "+N" yazısı + sesle verilir (2026-10-15, bkz. scripts/kill_gold.gd).

const KillGold = preload("res://scripts/kill_gold.gd")
const Loc = preload("res://scripts/localization.gd")


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
	var source: String = FileAccess.get_file_as_string("res://scripts/enemy.gd")
	if source.length() == 0:
		return
	var g: int = source.find("func _drop_gold()")
	var end: int = source.find("func _roll_extra_item_gold(")
	assert(g != -1 and end > g, "_drop_gold bulunamadı")
	var body: String = source.substr(g, end - g)
	assert(body.find("KillGold.amount_for(") != -1, "miktar hesabı değişmedi")
	assert(body.find("GoldDrop.instantiate()") != -1 and body.find("broadcast_drop.rpc(\"gold\"") != -1, "altın GoldDrop olarak düşüp yayınlanmalı")
	assert(body.find("KillGold.award") == -1, "ana yolda otomatik teslim olmamalı")
	## 2026-11-15: eski doğrudan teslim + asist yolu (GROUND_DROPS = false) silindi
	assert(source.find("_award_gold_directly") == -1 and source.find("_award_with_assists") == -1 and source.find("_assist_damage") == -1, "eski asist yolu kalmamalı")
	assert(not FileAccess.file_exists("res://scripts/assist.gd") and not FileAccess.file_exists("res://scripts/kill_gold_coin.gd"), "asist / dönen para dosyaları silindi")


## Ölen yaratık yerde GoldDrop bırakır, altın o zaman eklenmez; toplama mesafesine girince (XP gibi) oyuncuya çekilir, toplanınca
## karakterin üstünde "+N" yazısı çıkar.
func test_dead_enemy_leaves_gold_that_is_collected_by_proximity() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var was_active: bool = NetworkManager.is_multiplayer_active
	NetworkManager.is_multiplayer_active = false
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.gold_min = 20
	e.gold_max = 20
	e.gold_chance = 1.0
	KillGold.reset_pool()
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
	assert(int(drops[0].amount) == 23, "miktar +%%15 (20 -> 23): %d" % int(drops[0].amount))
	## Toplama: oyuncu gövdesi altına değer.
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = drops[0].global_position
	drops[0].call("_on_body_entered", p)
	var got: int = int(drops[0].amount)
	assert(GameManager.gold == before + got, "toplanınca altın eklenir")
	var texts: Array = []
	for n in get_children():
		if "label" in n and n.get("label") is Label:
			texts.append((n.get("label") as Label).text)
	assert(not texts.has("+3") and texts.is_empty(), "2026-11-06: toplayınca karakterin üstünde +N yazısı çıkmaz: %s" % [texts])
	GameManager.gold = before
	NetworkManager.is_multiplayer_active = was_active
	p.remove_from_group("player")
	p.free()
	e.free()
	get_tree().current_scene = prev_scene


## 2026-11-13: gelir +%15 (beklenen değer) ve küçük paylar havuzda birikip MIN_COIN'de tek altın olur.
func test_income_mult_expected_value_and_pool() -> void:
	var total: int = 0
	for i in 2000:
		total += KillGold.scale_amount(3)
	var avg: float = float(total) / 2000.0
	assert(absf(avg - 3.45) < 0.08, "3 x 1,15 beklenen değer ~3,45: %f" % avg)
	KillGold.reset_pool()
	for i in 4:
		assert(KillGold.pool_take(3) == 0, "MIN_COIN altında düşme yok")
	assert(KillGold.pool_take(3) == 15, "havuz dolunca tek altın birikmiş değeri taşır")
	assert(KillGold.pool_take(1) == 0, "havuz boşaldı")
	KillGold.reset_pool()
	assert(KillGold.pool_take(20) == 20, "büyük pay hemen düşer")


func test_credit_adds_gold_to_local_player() -> void:
	var before: int = GameManager.gold
	KillGold.credit(get_tree(), 7, Vector2(10, 10))
	assert(GameManager.gold == before + 7, "altın hemen eklenmeli")
	GameManager.gold = before
	KillGold.credit(get_tree(), 0, Vector2.ZERO)
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


## peer_id alanı olan sahte uzak oyuncu kuklası.
func _peer_node(peer: int) -> Node2D:
	var n := Node2D.new()
	var src := GDScript.new()
	src.source_code = "extends Node2D\nvar peer_id: int = 0\n"
	src.reload()
	n.set_script(src)
	n.set("peer_id", peer)
	return n


## Düz toplama yazısı kapalı (SHOW_PICKUP_TEXT): yazı da simge de çıkmaz, ses/balans kaydı sürer.
func test_pickup_text_is_hidden() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	assert(not KillGold.SHOW_PICKUP_TEXT, "kullanıcı isteği: toplayınca +altın yazısı yok")
	KillGold.show_at(get_tree(), 4, Vector2(0, 0))
	for n in get_children():
		assert(not ("label" in n and n.get("label") is Label), "düz toplama için yazı sahnesi eklenmemeli")
	get_tree().current_scene = prev_scene


## 2026-11-15: çok oyunculuda yerden toplanan sıradan yaratık altını takımca bölünür, toplayanın payı diğerlerinin 1,5 katı; kesirler birikir
## (15 altınlık parada aşağı yuvarlayıp artanı toplayana vermek onun payını %47'ye çıkarırdı).
func test_split_shares_picker_gets_a_bit_more_and_fractions_carry() -> void:
	KillGold.reset_pool()
	assert(is_equal_approx(KillGold.PICKER_SHARE_WEIGHT, 1.5), "toplayan ağırlığı 1,5")
	var total: Dictionary = {}
	for i in 1000:
		var sh: Dictionary = KillGold.split_shares(15, [1, 2, 3, 4, 5], 2)
		for pid in sh.keys():
			total[pid] = int(total.get(pid, 0)) + int(sh[pid])
	var paid: int = 0
	for pid in total.keys():
		paid += int(total[pid])
	assert(paid <= 15000 and paid >= 15000 - 5, "ödenen toplam = düşen altın (en çok oyuncu başına 1 altın kesir bekler): %d" % paid)
	assert(absi(int(total[2]) - 4091) <= 1, "toplayan %%27,3 (15000 x 1,5 / 5,5 = 4091): %d" % int(total[2]))
	for pid in [1, 3, 4, 5]:
		assert(absi(int(total[pid]) - 2727) <= 1, "diğerleri %%18,2 (2727): %d" % int(total[pid]))
	## Tek katılımcı tamamını alır; toplayan listede değilse herkes eşit.
	KillGold.reset_pool()
	assert(int(KillGold.split_shares(50, [7], 7)[7]) == 50, "tek katılımcı hepsini alır")
	var eq: Dictionary = KillGold.split_shares(90, [1, 2, 3], 99)
	assert(int(eq[1]) == 30 and int(eq[2]) == 30 and int(eq[3]) == 30, "toplayan listede yok: eşit: %s" % [eq])
	## 2 oyuncu: %60 / %40.
	var two: Dictionary = KillGold.split_shares(100, [1, 2], 1)
	assert(int(two[1]) == 60 and int(two[2]) == 40, "2 oyuncu 60 / 40: %s" % [two])
	KillGold.reset_pool()


## Host: toplayan kendi payını hemen alır, takım arkadaşının payı birikip TEAM_GOLD_FLUSH_INTERVAL sonra cüzdanına girer (yazısız, uçan parayla).
func test_creature_gold_is_split_with_teammates_in_multiplayer() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var was_active: bool = NetworkManager.is_multiplayer_active
	var was_host: bool = NetworkManager.is_host
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	KillGold.reset_pool()
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	var r: Node2D = _peer_node(77)
	r.add_to_group("remote_players")
	add_child(r)
	var before: int = GameManager.gold
	var old_children: Array = get_children() ## önceki testlerin bıraktığı yazılar sayılmasın
	## Yerel oyuncu yerden toplar (gerçek GoldDrop): 100 altının 60'ı ona, 40'ı uzak oyuncuya ayrılır.
	var drop: Node2D = (load("res://scenes/gold_drop.tscn") as PackedScene).instantiate()
	drop.set("amount", 100)
	add_child(drop)
	drop.call("_on_body_entered", p)
	assert(GameManager.gold == before + 60, "toplayan (yerel) 60 alır: %d" % (GameManager.gold - before))
	## Uzak oyuncu toplar: onun payı 60 (çağırana döner), yerel oyuncunun 40'ı bekler ve süre dolunca eklenir.
	var keep: int = NetworkManager.host_split_creature_gold(100, Vector2(40, 0), r)
	assert(keep == 60, "uzak toplayanın payı 60: %d" % keep)
	assert(GameManager.gold == before + 60, "takım payı hemen eklenmez (toplu gider)")
	NetworkManager._process_team_gold(NetworkManager.TEAM_GOLD_FLUSH_INTERVAL + 0.01)
	assert(GameManager.gold == before + 100, "yerel oyuncunun takım payı 40 eklendi: %d" % (GameManager.gold - before))
	var texts: Array = []
	var coins: int = 0
	for n in get_children():
		if old_children.has(n):
			continue
		if "label" in n and n.get("label") is Label:
			texts.append((n.get("label") as Label).text)
		if n.get_script() == NetworkManager.GoldShareFxScript:
			coins += 1
			n.free()
	assert(texts.is_empty(), "takım payında karakterin üstünde yazı çıkmaz: %s" % [texts])
	assert(coins == 1, "takım payı için tek bir uçan altın: %d" % coins)
	## Boss altını bu yoldan geçmez; tek oyunculuda / host değilken altın bölünmez.
	NetworkManager.is_host = false
	assert(NetworkManager.host_split_creature_gold(100, Vector2.ZERO, p) == 100, "host değil: bölünmez")
	NetworkManager.is_host = true
	r.remove_from_group("remote_players")
	assert(NetworkManager.host_split_creature_gold(100, Vector2.ZERO, p) == 100, "tek katılımcı: tamamı toplayana")
	NetworkManager._process_team_gold(1.0)
	GameManager.gold = before
	NetworkManager.is_multiplayer_active = was_active
	NetworkManager.is_host = was_host
	KillGold.reset_pool()
	p.remove_from_group("player")
	p.free()
	r.free()
	get_tree().current_scene = prev_scene
