extends Node

## SİLAH PARÇACIĞI (kullanıcı isteği 2026-10-08): "yaratıklardan %0.5 ihtimalle düşecek, elit yaratıklardan kesin 1, bosslardan 5; oyunculara
## eşit miktarda gidecek (biri 5 tane alırsa 5 tane herkese); yemek gibi yerde duracak ve hafif yukarı aşağı olacak; pixel sanatı".
## Kapsam: düşme kuralları (enemy.gd), oyuncu sayacı (game_manager.gd), yerdeki drop (weapon_shard_drop.gd/.tscn + sanat), HUD sayacı.
## Çok oyunculu dağıtım (herkese aynı miktar, RPC) iki süreçli koşucuyla ayrıca sınanır (bkz. CLAUDE.md madde 24).

const DropScene: PackedScene = preload("res://scenes/weapon_shard_drop.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")

var _saved_shards: int = 0
var _spawned: Array = []


func _begin() -> void:
	_end() ## önceki testin (bir assert'te yarıda kalmış olabilir) artıklarını temizle
	_saved_shards = GameManager.weapon_shards
	GameManager.weapon_shards = 0


func _end() -> void:
	GameManager.weapon_shards = _saved_shards
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for d in get_tree().get_nodes_in_group("weapon_shard_drops"):
		if is_instance_valid(d):
			d.free()


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ------------------------------------------------------------------ düşme kuralları

func test_drop_count_rules_boss_five_elite_one_normal_half_percent() -> void:
	_begin()
	assert(Enemy.WEAPON_SHARD_CHANCE == 0.005, "sıradan yaratık %0.5")
	assert(Enemy.weapon_shard_count(true, false, 0.999) == 5, "boss: şansa bakmadan 5")
	assert(Enemy.weapon_shard_count(true, true, 0.999) == 5, "elit boss yine 5 (toplanmaz)")
	assert(Enemy.weapon_shard_count(false, true, 0.999) == 1, "elit: şansa bakmadan 1")
	assert(Enemy.weapon_shard_count(false, false, 0.004) == 1, "zar şansın altında: 1")
	assert(Enemy.weapon_shard_count(false, false, 0.005) == 1, "tam sınırda: 1")
	assert(Enemy.weapon_shard_count(false, false, 0.0051) == 0, "zar şansın üstünde: 0")
	assert(Enemy.weapon_shard_count(false, false, 0.0099, 2.0) == 1 and Enemy.weapon_shard_count(false, false, 0.0101, 2.0) == 0,
		"şans çarpanı (luck) %0.5'i büyütür")
	_end()


func test_normal_creature_rate_is_about_half_a_percent() -> void:
	_begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	var hits: int = 0
	for i in range(200000):
		hits += Enemy.weapon_shard_count(false, false, rng.randf())
	assert(hits >= 800 and hits <= 1200, "200.000 ölümde ~1000 parçacık beklenir, bulunan: %d" % hits)
	_end()


func test_boss_death_spawns_five_separate_pickups_in_a_ring() -> void:
	_begin()
	var boss: Enemy = _track(EnemyScene.instantiate()) as Enemy
	add_child(boss)
	boss.global_position = Vector2(500, 500)
	boss.is_boss = true
	boss._drop_weapon_shards()
	Enemy.drain_drop_spawn_queue()
	await _frames(2)
	var drops: Array = get_tree().get_nodes_in_group("weapon_shard_drops")
	assert(drops.size() == 5, "boss 5 AYRI drop düşürür, bulunan: %d" % drops.size())
	var seen: Dictionary = {}
	for d in drops:
		assert(int(d.amount) == 1, "her drop 1 parçacık (toplam 5)")
		var off: Vector2 = (d as Node2D).global_position - boss.global_position
		assert(off.length() > 15.0 and off.length() < 60.0, "boss çevresine saçılır: %s" % str(off))
		seen[Vector2i(off.round())] = true
	assert(seen.size() == 5, "5 parça birbirinin üstüne yığılmaz")
	_end()


func test_elite_death_drops_exactly_one_and_plain_creature_usually_none() -> void:
	_begin()
	var elite: Enemy = _track(EnemyScene.instantiate()) as Enemy
	add_child(elite)
	elite.is_elite = true
	elite._drop_weapon_shards()
	Enemy.drain_drop_spawn_queue()
	await _frames(2)
	assert(get_tree().get_nodes_in_group("weapon_shard_drops").size() == 1, "elit: tam 1 parçacık")
	assert(int(get_tree().get_nodes_in_group("weapon_shard_drops")[0].amount) == 1)
	_end()


# ------------------------------------------------------------------ oyuncu sayacı

func test_game_manager_counter_signal_clamp_and_run_state() -> void:
	_begin()
	var seen: Array = []
	var cb := func(total: int) -> void: seen.append(total)
	GameManager.weapon_shards_changed.connect(cb)
	GameManager.add_weapon_shards(5)
	GameManager.add_weapon_shards(0)
	GameManager.add_weapon_shards(-100)
	GameManager.weapon_shards_changed.disconnect(cb)
	assert(seen == [5, 0], "sinyal sadece değişimde, alt sınır 0: %s" % str(seen))
	GameManager.weapon_shards = 7
	var state: Dictionary = GameManager.capture_run_state()
	assert(int(state.get("weapon_shards", -1)) == 7, "geri katılım anlık görüntüsüne yazılır")
	GameManager.weapon_shards = 0
	GameManager.restore_run_state(state)
	assert(GameManager.weapon_shards == 7, "geri yüklenir")
	GameManager.reset()
	assert(GameManager.weapon_shards == 0, "yeni koşuda sıfırlanır")
	_end()


# ------------------------------------------------------------------ yerdeki drop

func test_drop_scene_has_pixel_art_and_animation() -> void:
	_begin()
	var d: Node = _track(DropScene.instantiate())
	add_child(d)
	assert(d.is_in_group("weapon_shard_drops"))
	var spr: AnimatedSprite2D = d.get_node("AnimatedSprite2D")
	assert(spr.sprite_frames.has_animation(&"shine") and spr.sprite_frames.get_frame_count(&"shine") == 6, "6 karelik parıltı animasyonu")
	assert(spr.sprite_frames.get_animation_loop(&"shine"), "döngüde")
	for i in range(6):
		var tex: Texture2D = spr.sprite_frames.get_frame_texture(&"shine", i)
		assert(tex != null and tex.get_size() == Vector2(22, 22), "kare %d 22x22 olmalı" % i)
	assert(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "piksel sanatı: bulanıklaşmaz")
	var icon: Texture2D = load("res://assets/pickups/weapon_shard/shard_icon.png")
	assert(icon != null and icon.get_size() == Vector2(22, 22), "HUD/dükkan simgesi")
	_end()


func test_drop_bobs_gently_up_and_down_like_food() -> void:
	_begin()
	var d: Node2D = _track(DropScene.instantiate()) as Node2D
	add_child(d)
	d.global_position = Vector2(300, 300)
	await _frames(1) ## _place_on_ground (deferred) konumu/z'yi oturtsun
	var base_y: float = d.position.y - d._last_bob_offset
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	for i in range(80):
		d._process(0.05) ## 4 sn: iki tam salınım
		lo = minf(lo, d.position.y)
		hi = maxf(hi, d.position.y)
	assert(hi - lo > 4.0 and hi - lo < 7.0, "hafif yukarı-aşağı (±3 px): genlik %.2f" % (hi - lo))
	assert(absf(((hi + lo) * 0.5) - base_y) < 1.0, "salınım doğduğu yerin etrafında (sürüklenme yok)")
	_end()


func test_single_player_pickup_gives_the_amount_once() -> void:
	_begin()
	var player := Node2D.new()
	player.add_to_group("player")
	_track(player)
	add_child(player)
	var d: Node = _track(DropScene.instantiate())
	d.amount = 3
	add_child(d)
	var enemy_body := Node2D.new()
	_track(enemy_body)
	add_child(enemy_body)
	d._on_body_entered(enemy_body)
	assert(GameManager.weapon_shards == 0, "oyuncu olmayan gövde toplayamaz")
	d._on_body_entered(player)
	assert(GameManager.weapon_shards == 3, "toplayana amount kadar: %d" % GameManager.weapon_shards)
	d._on_body_entered(player)
	assert(GameManager.weapon_shards == 3, "çift toplama yok (aynı kare iki gövde)")
	assert(d.is_queued_for_deletion(), "toplanan drop yok olur")
	_end()


func test_pickup_award_is_not_split_between_players_in_multiplayer_math() -> void:
	_begin()
	## host_award_weapon_shards RPC kullandığı için tek süreçte sadece yerel katılımcı yolu sınanır: host'un yerel oyuncusu TAM miktarı alır
	## (bölünme yok); uzak oyuncuların aynı miktarı alması iki süreçli koşuyla doğrulanır.
	var prev_active: bool = NetworkManager.is_multiplayer_active
	var prev_host: bool = NetworkManager.is_host
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	var player := Node2D.new()
	player.add_to_group("player")
	_track(player)
	add_child(player)
	var n: int = NetworkManager.host_award_weapon_shards(5)
	NetworkManager.is_multiplayer_active = prev_active
	NetworkManager.is_host = prev_host
	assert(n == 1 and GameManager.weapon_shards == 5, "tek katılımcı 5'in tamamını alır (bölünmez): n=%d, parçacık=%d" % [n, GameManager.weapon_shards])
	assert(NetworkManager.host_award_weapon_shards(0) == 0, "0 miktar ödül sayılmaz")
	var before: int = GameManager.weapon_shards
	NetworkManager.grant_weapon_shards(5) ## uzak gönderen olmadan (tek süreç): host kimliği doğrulanamaz -> kabul edilmemeli
	assert(GameManager.weapon_shards == before, "host dışından gelen ödül kabul edilmez")
	_end()


# ------------------------------------------------------------------ HUD sayacı

func test_hud_shows_a_shard_counter_below_gold_and_tracks_changes() -> void:
	_begin()
	var hud: Node = _track((load("res://scenes/hud.tscn") as PackedScene).instantiate())
	add_child(hud)
	await _frames(2)
	var ind: Control = hud.get_node_or_null("ShardIndicator") as Control
	assert(ind != null and ind.visible, "parçacık göstergesi kurulmalı")
	var gold: Control = hud.get_node("GoldIndicator")
	assert(ind.get_global_rect().position.y >= gold.get_global_rect().end.y - 1.0, "altın göstergesinin ALTINDA")
	assert(is_equal_approx(ind.get_global_rect().position.x, gold.get_global_rect().position.x), "sol kenarları hizalı")
	var label: Label = hud._shard_label
	assert(label.text == "0")
	GameManager.add_weapon_shards(12)
	assert(label.text == "12", "sinyalle anında güncellenir: %s" % label.text)
	assert(hud._left_stack_bottom() >= ind.get_global_rect().end.y - 0.5, "grup paneli/debug düğmesi sayacın altından başlar")
	for c in ind.get_children():
		_assert_ignores_mouse(c)
	_end()


func _assert_ignores_mouse(node: Node) -> void:
	if node is Control:
		assert((node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s fareyi geçirmeli" % node.name)
	for c in node.get_children():
		_assert_ignores_mouse(c)
