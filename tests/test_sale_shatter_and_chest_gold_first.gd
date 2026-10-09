extends Node

## Kullanıcı isteği (2026-10-08): (1) "sandık açma animasyonunda önce para animasyonu görünsün sonra item çıksın, tıpkı item satarkenki sandıktan
## altın çıkma animasyonu gibi", (2) "item satınca itemin parçalanıp altına dönüşme animasyonuna sahip olmasını istiyorum, item satışındaki
## sandıktan altın çıkma animasyonu yerine". Kapsam: gold_reward_fx.gd (coin_count / burst_duration / give_shattered / show_shatter /
## parçalanma + para dönüşümü), chest_menu.gd (chest_card_delay: altın önce, kart sonra), inventory_panel.gd (_do_sell_item ikonu parçalar).

const FxScript: GDScript = preload("res://scripts/gold_reward_fx.gd")
const ChestMenuScript: GDScript = preload("res://scripts/chest_menu.gd")
const InventoryPanelScene: PackedScene = preload("res://scenes/inventory_panel.tscn")
const ChestOpenAnimScript: GDScript = preload("res://scripts/chest_open_anim.gd")

var _saved_gold: int = 0
var _nodes: Array[Node] = []


class FakePlayer extends Node2D:
	func get_max_item_slots() -> int:
		return 3

	func sell_owned_item(index: int) -> int:
		var key: String = str((GameManager.owned_items[index] as Dictionary).get("key", ""))
		GameManager.owned_items.remove_at(index)
		var refund: int = Items.sell_refund(key)
		GameManager.gold += refund
		return refund


func _begin() -> void:
	_saved_gold = GameManager.gold


func _end() -> void:
	FxScript.set(&"_inst", null)
	GameManager.gold = _saved_gold
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _fx() -> Node:
	var fx: Node = FxScript.new()
	add_child(fx)
	_nodes.append(fx)
	return fx


func _tex() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.3, 0.9, 1.0))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ zamanlama (sandık: önce altın, sonra eşya)

func test_coin_count_and_burst_duration_are_the_single_source() -> void:
	assert(FxScript.coin_count(0) == 0, "altın yok -> para yok")
	assert(FxScript.coin_count(2) == 2, "para sayısı altından fazla olamaz")
	assert(FxScript.coin_count(5) == 5, "sqrt(5)*2.5 = 6 ama para sayısı altından fazla olamaz: %d" % FxScript.coin_count(5))
	assert(FxScript.coin_count(9) == 8, "sqrt(9)*2.5 = 7,5 -> 8: %d" % FxScript.coin_count(9))
	assert(FxScript.coin_count(100) == FxScript.MAX_COINS, "büyük altında üst sınır")
	assert(is_equal_approx(FxScript.burst_duration(100), FxScript.LAUNCH_GAP * float(FxScript.MAX_COINS)), "fırlama süresi = para x aralık")


func test_chest_card_comes_out_after_the_gold_burst_and_is_capped() -> void:
	assert(ChestMenuScript.chest_card_delay(0, false) == 0.0, "altın yoksa kart hemen")
	assert(is_equal_approx(ChestMenuScript.chest_card_delay(100, true), ChestMenuScript.CHEST_GOLD_SKIPPED_DELAY), "animasyon atlandıysa kısa bekleme")
	var small: float = ChestMenuScript.chest_card_delay(4, false)
	assert(is_equal_approx(small, FxScript.burst_duration(4) + ChestMenuScript.CHEST_GOLD_CARD_DELAY), "küçük altın: fırlama + pay: %s" % small)
	assert(ChestMenuScript.chest_card_delay(100000, false) <= ChestMenuScript.CHEST_GOLD_CARD_DELAY_MAX + 0.0001, "büyük altında bile kart en geç ~1 sn")
	assert(ChestMenuScript.chest_card_delay(100, false) > ChestMenuScript.chest_card_delay(100, true), "atlama beklemeyi kısaltır")


# ------------------------------------------------------------------ kart sesi: kart ekrana inip oturunca (kapak patlayınca değil)

## Kökteki ödül çınlaması oynatıcılarını sayar (Reward.wav / elitte Magic Seal) ve temizler.
func _take_chimes(stream_path: String) -> int:
	var n: int = 0
	for c in get_tree().root.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).stream != null and (c as AudioStreamPlayer).stream.resource_path == stream_path:
			n += 1
			c.free()
	return n


func test_reward_chime_plays_at_burst_by_default_but_not_when_the_owner_defers_it() -> void:
	var reward: String = ChestOpenAnimScript.SFX_REWARD.resource_path
	_take_chimes(reward)
	var a: Control = ChestOpenAnimScript.new()
	a.setup(false, 2)
	add_child(a)
	_nodes.append(a)
	a._on_burst()
	assert(_take_chimes(reward) == 1, "varsayılan: ödül çınlaması kapak patlayınca çalar (enchant_screen.gd eski davranış)")
	var b: Control = ChestOpenAnimScript.new()
	b.setup(false, 2)
	b.chime_on_burst = false
	add_child(b)
	_nodes.append(b)
	b._on_burst()
	assert(_take_chimes(reward) == 0, "chime_on_burst=false: patlamada çınlama YOK (kart inince çalacak)")
	assert(b._burst_sent, "burst sinyali yine de gider")
	_take_chimes(ChestOpenAnimScript.SFX_COINS.resource_path) ## patlama para sesi de kökte kalmasın


func test_play_reward_chime_picks_the_elite_or_tier_sound() -> void:
	var reward: String = ChestOpenAnimScript.SFX_REWARD.resource_path
	var elite: String = ChestOpenAnimScript.SFX_ELITE.resource_path
	_take_chimes(reward)
	_take_chimes(elite)
	ChestOpenAnimScript.play_reward_chime(get_tree(), 3, false)
	assert(_take_chimes(reward) == 1 and _take_chimes(elite) == 0, "normal sandık: Reward çınlaması")
	ChestOpenAnimScript.play_reward_chime(get_tree(), 3, true)
	assert(_take_chimes(elite) == 1 and _take_chimes(reward) == 0, "elit sandık: mühür sesi")
	ChestOpenAnimScript.play_reward_chime(get_tree(), 9, false) ## nadirlik 4'e kısılır, hata vermez
	assert(_take_chimes(reward) == 1, "büyük nadirlik değeri de çalar")


func test_chest_menu_defers_the_chime_to_the_card_landing() -> void:
	## Davranışı gerçek menüyle sınayan ekran testi scratchpad'de (perf_chest.gd); burada kablolama: menü patlamadaki çınlamayı kapatır,
	## kart inişinde kendisi çalar.
	var src: String = FileAccess.get_file_as_string("res://scripts/chest_menu.gd")
	assert(src.contains("anim.chime_on_burst = false"), "menü patlamadaki çınlamayı kapatmalı")
	assert(src.contains("ChestOpenAnim.play_reward_chime(get_tree(), tier, _is_elite)"), "menü kart inince çınlamayı çalmalı")


# ------------------------------------------------------------------ altın ekleme kuralları

func test_give_shattered_adds_gold_but_show_shatter_does_not_double_add() -> void:
	_begin()
	GameManager.gold = 100
	FxScript.give_shattered(get_tree(), 40, Vector2(200, 200), _tex(), Vector2(96, 96))
	assert(GameManager.gold == 140, "give_shattered altını ekler: %d" % GameManager.gold)
	FxScript.show_shatter(get_tree(), 40, Vector2(200, 200), _tex(), Vector2(96, 96))
	assert(GameManager.gold == 140, "show_shatter altını ÇİFT eklemez (altın zaten eklenmişti): %d" % GameManager.gold)
	_end()


# ------------------------------------------------------------------ parçalanma animasyonu

func test_shatter_splits_the_icon_into_shards_and_turns_them_into_coins_that_pay_exactly() -> void:
	_begin()
	GameManager.gold = 500
	var fx: Node = _fx()
	fx._add_reward(30, Vector2(400, 300), false, &"shatter", false, {"texture": _tex(), "size": Vector2(96, 96)})
	assert(int(fx._pending) == 30, "yoldaki altın sayılır")
	fx._launch_reward(fx._rewards.pop_at(0))
	var grid: int = FxScript.SHATTER_GRID
	assert(fx._shards.size() == grid * grid, "ikon %d parçaya bölünür: %d" % [grid * grid, fx._shards.size()])
	var n: int = FxScript.shatter_coin_count(30)
	assert(fx._coins.size() == n, "her para bir parçadan doğar: %d" % fx._coins.size())
	var total_share: int = 0
	var conv_times: Array = []
	for c in fx._coins:
		total_share += int(c["share"])
		assert(float(c["t"]) < 0.0 and bool(c.get("pop", false)), "para, parçası dönüşene kadar gizli ve 'pop'lu")
		conv_times.append(snappedf(-float(c["t"]), 0.0001))
	assert(total_share == 30, "paraların payları TAM altın miktarı: %d" % total_share)
	var shard_convs: Array = []
	for s in fx._shards:
		if float(s["conv"]) >= 0.0:
			shard_convs.append(snappedf(float(s["conv"]), 0.0001))
	conv_times.sort()
	shard_convs.sort()
	assert(conv_times == shard_convs, "paranın doğuş anı parçanın dönüşüm anıyla aynı")
	assert(shard_convs.size() == n, "para olmayan parçalar sadece solar: %d para, %d dönüşen parça" % [n, shard_convs.size()])
	## Zamanı ilerlet: parçalar saçılıp solar, paralar panele varır, yoldaki altın 0'a iner.
	var guard: int = 0
	while (not fx._shards.is_empty() or not fx._coins.is_empty()) and guard < 600:
		fx._update_shards(0.016)
		fx._update_coins(0.016)
		guard += 1
	assert(fx._shards.is_empty() and fx._coins.is_empty(), "animasyon bitmeli (%d adım)" % guard)
	assert(int(fx._pending) == 0, "tüm paralar varınca yoldaki altın kalmaz: %d" % int(fx._pending))
	assert(is_equal_approx(float(fx._count_left), 30.0), "sayaç tam miktar kadar akacak: %s" % fx._count_left)
	_end()


func test_shards_scatter_outward_and_fall() -> void:
	_begin()
	var fx: Node = _fx()
	fx._add_reward(10, Vector2(500, 500), false, &"shatter", false, {"texture": _tex(), "size": Vector2(96, 96)})
	fx._launch_reward(fx._rewards.pop_at(0))
	var before: Array = []
	for s in fx._shards:
		before.append((s["node"] as Sprite2D).position)
	fx._update_shards(0.2)
	var moved: int = 0
	var spread_before: float = 0.0
	var spread_after: float = 0.0
	for i in fx._shards.size():
		var now_pos: Vector2 = (fx._shards[i]["node"] as Sprite2D).position
		spread_before += (before[i] as Vector2).distance_to(Vector2(500, 500))
		spread_after += now_pos.distance_to(Vector2(500, 500))
		if now_pos.distance_to(before[i]) > 5.0:
			moved += 1
	assert(moved == fx._shards.size(), "tüm parçalar hareket eder")
	assert(spread_after > spread_before * 1.1, "parçalar merkezden uzaklaşır (saçılma): %.0f -> %.0f" % [spread_before, spread_after])
	_end()


## Kullanıcı 2026-10-08: "parçalanma efekti ekranı çok kaplıyor ve göz yorucu, animasyonun ve altın dağılımının ufak olmasını istiyorum".
func test_shatter_stays_small_and_uses_few_small_coins() -> void:
	_begin()
	GameManager.gold = 5000
	var fx: Node = _fx()
	var origin := Vector2(600, 400)
	var icon: float = 128.0
	fx._add_reward(2000, origin, false, &"shatter", false, {"texture": _tex(), "size": Vector2(icon, icon)})
	fx._launch_reward(fx._rewards.pop_at(0))
	assert(FxScript.shatter_coin_count(2000) == FxScript.SHATTER_MAX_COINS and FxScript.SHATTER_MAX_COINS < FxScript.MAX_COINS, "satışta para sayısı normal ödülden az")
	assert(fx._coins.size() == FxScript.SHATTER_MAX_COINS, "büyük altında bile en çok %d para: %d" % [FxScript.SHATTER_MAX_COINS, fx._coins.size()])
	var total: int = 0
	for c in fx._coins:
		total += int(c["share"])
		assert(is_equal_approx(float(c["scale"]), FxScript.SHATTER_COIN_SCALE) and FxScript.SHATTER_COIN_SCALE < FxScript.COIN_SCALE, "satış parası daha küçük")
	assert(total == 2000, "az para yine de TAM altını taşır: %d" % total)
	var max_far: float = 0.0
	var steps: int = 0
	while not fx._shards.is_empty() and steps < 200:
		fx._update_shards(0.016)
		for s in fx._shards:
			if is_instance_valid(s["node"]):
				max_far = maxf(max_far, ((s["node"] as Sprite2D).position - origin).length())
		steps += 1
	assert(max_far <= icon * 1.3, "parçalar ikonun ~1,3 katından uzağa saçılmaz: en uzak %.0f px (ikon %.0f)" % [max_far, icon])
	while not fx._coins.is_empty() and steps < 900:
		fx._update_coins(0.016)
		steps += 1
	_end()


func test_tiny_refund_still_works() -> void:
	_begin()
	GameManager.gold = 50
	var fx: Node = _fx()
	fx._add_reward(1, Vector2(100, 100), false, &"shatter", false, {"texture": _tex(), "size": Vector2(64, 64)})
	fx._launch_reward(fx._rewards.pop_at(0))
	assert(fx._coins.size() == 1 and int((fx._coins[0] as Dictionary)["share"]) == 1, "1 altın -> 1 para")
	var guard: int = 0
	while (not fx._shards.is_empty() or not fx._coins.is_empty()) and guard < 600:
		fx._update_shards(0.016)
		fx._update_coins(0.016)
		guard += 1
	assert(int(fx._pending) == 0, "1 altın da panele varır")
	_end()


# ------------------------------------------------------------------ envanter satışı

func test_inventory_sale_removes_the_item_pays_once_and_starts_the_shatter() -> void:
	_begin()
	var keys: Array = Items.DEFS.keys()
	var key: String = ""
	for k in keys:
		if Items.sell_refund(str(k)) > 0 and Items.icon(str(k)) != null:
			key = str(k)
			break
	assert(key != "", "satılabilir ikonlu bir eşya bulunmalı")
	var saved_items: Array = GameManager.owned_items.duplicate(true)
	GameManager.owned_items = [{"key": key, "spent": 0}]
	GameManager.gold = 100
	var fx: Node = _fx()
	FxScript.set(&"_inst", fx) ## gerçek oyundaki tekil FX düğümünün yerine
	var player := FakePlayer.new()
	add_child(player)
	_nodes.append(player)
	var panel: Control = InventoryPanelScene.instantiate()
	panel.player = player
	add_child(panel)
	_nodes.append(panel)
	panel._refresh_items_grid()
	assert(panel._item_slot_icons.has(0), "eşya yuvasının ikonu kaydedilir")
	var refund: int = Items.sell_refund(key)
	panel._do_sell_item(0)
	assert(GameManager.owned_items.is_empty(), "eşya envanterden çıkar")
	assert(GameManager.gold == 100 + refund, "altın TEK kez eklenir: %d" % GameManager.gold)
	assert(not fx._rewards.is_empty() and str((fx._rewards[0] as Dictionary)["source"]) == "shatter", "parçalanma animasyonu sıraya girdi")
	assert(int(fx._pending) == refund, "HUD sayacı paralar varana kadar yoldaki altını bekler")
	GameManager.owned_items = saved_items
	_end()
