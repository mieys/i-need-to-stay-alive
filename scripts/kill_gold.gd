extends RefCounted

## Yaratık öldürme altını (kullanıcı isteği 2026-10-15): "yaratıklar ölünce yere altın düşürmeyecek. onun yerine üstünde
## +'altın miktarı' yazacak ve altın sesi çıkacak. yaratıklar kademelerine göre altın verecek."
## Altın artık yere düşmez: öldüren oyuncunun kişisel altınına HEMEN eklenir, ölen yaratığın olduğu yerde "+N" yazısı
## yükselir ve altın sesi çalar. Miktar: yaratığın kademesine göre sahne değerleri (gold_min/gold_max x gold_chance, bkz.
## amount_for) - her ölüm en az 1 altın verir. Host/tek oyunculu hesaplar; uzak öldürene NetworkManager.grant_kill_gold gider.

const FloatingText := preload("res://scenes/floating_text.tscn")
const VisionFogScript := preload("res://scripts/vision_fog.gd")
const BalanceLog := preload("res://scripts/balance_log.gd")
const SOUND: AudioStream = preload("res://assets/audio/gold_pickup.mp3")
const SOUND_DB := -4.0 ## yerden toplama sesi (gold_drop.tscn) -10 dB; yaratık altını kullanıcı isteğiyle +6 dB yükseltildi (2026-10-15)
const TEXT_COLOR := Color(1.0, 0.85, 0.25)
const ASSIST_COLOR := Color(0.65, 0.9, 1.0) ## asist payı daha soluk/mavimsi (bkz. assist.gd)
const TEAM_KIND := 4 ## assist.gd KIND_TEAM: yakındaki canlı takım arkadaşı payı ("TAKIM +N"; assist.gd'yi önyüklememek için kopya)
const TEXT_OFFSET := Vector2(0.0, -26.0)
## 2026-10-21: altın yerde dönen para olarak düşer, HOVER_TIME (kill_gold_coin.gd) sonra alıcıya uçup varınca verilir. Aynı anda en çok
## MAX_ACTIVE_COINS para uçar/bekler; fazlası eski gibi anında verilir (kalabalık ölümlerinde düğüm sayısı patlamasın).
const COIN_SCRIPT := preload("res://scripts/kill_gold_coin.gd")
const MAX_ACTIVE_COINS := 60
## 2026-10-24 (kullanıcı: "yaratıklar ölünce altını karaktere otomatik göndermesin; eskisi gibi rastgele yere düşsün, toplama mesafesine bağlı
## XP gibi toplansın, toplanınca karakterin üstünde +altın + ses"): true = altın yerde GoldDrop (gold_drop.gd) olarak kalır, toplayan oyuncu
## credit() ile alır (miktar hesabı amount_for aynı, gelir değişmez). false = eski doğrudan teslim (dönen para + asist/takım payı bölüşümü,
## enemy.gd _award_gold_directly): yerden toplamada altın toplayana gittiği için asist/takım payı yalnız bu modda çalışır.
const GROUND_DROPS := true
const COIN_FRAMES := preload("res://assets/pickups/gold/gold_coin_frames.tres")
const ICON_SCALE := 0.8 ## 16 px para -> ~13 px (yazı 16 pt piksel fontu)
const ICON_GAP := 3.0
## Kalabalık ölümlerinde sesler üst üste yığılıp patlamasın: iki ses arası en az bu kadar ms (yazılar yine her ölümde çıkar).
const MIN_SOUND_GAP_MSEC := 55

static var _last_sound_msec: int = -100000
static var active_coins: int = 0


## Bir yaratığın vereceği altın. gold_chance 1 (boss) ise [min,max] arası rastgele; aksi halde beklenen değer
## (şans x ortalama) yuvarlanır, en az 1 - eskiden şansa bağlı düşüyordu, artık her yaratık kademesine göre garanti verir.
## chance_roll = true (çağıranın "minyon" gibi garanti vermemesi gereken yaratıklar için): eski gibi şansı zar atar, tutmazsa 0.
static func amount_for(gold_min: int, gold_max: int, chance: float, chance_roll: bool = false) -> int:
	var lo: int = maxi(gold_min, 1)
	var hi: int = maxi(gold_max, lo)
	if chance_roll:
		return randi_range(lo, hi) if randf() <= chance else 0
	if chance >= 1.0:
		return randi_range(lo, hi)
	return maxi(1, int(round(chance * 0.5 * float(lo + hi))))


## Kaynak noktası yerel oyuncunun KENDİ görüş alanı dışındaysa (sis elipsi + duvar/ağaç ışını) yazı ve ses oradan değil KARAKTERİN
## üstünden gelir (kullanıcı 2026-10-15: "görüş alanı dışından gelen altın artışları karakterin üstünde +altın olarak görünecek").
static func resolve_pos(tree: SceneTree, world_pos: Vector2) -> Vector2:
	var p: Node = tree.get_first_node_in_group("player") if tree else null
	if p == null or not is_instance_valid(p) or not (p is Node2D):
		return world_pos
	var me: Vector2 = (p as Node2D).global_position
	if VisionFogScript.own_vision_contains(tree, me, world_pos):
		return world_pos
	return me + Vector2(0.0, -8.0)


## Yazı + ses (altın ZATEN eklendi). Her makinede yalnızca altını kazanan oyuncunun ekranında çağrılır.
static func show_at(tree: SceneTree, amount: int, world_pos: Vector2, assist: int = 0) -> void:
	if amount <= 0:
		return
	BalanceLog.on_kill_gold(amount, assist) ## balans kaydı: öldürme/asist altını (bkz. balance_log.gd)
	if tree == null or tree.current_scene == null:
		return
	world_pos = resolve_pos(tree, world_pos)
	var ft: Node = FloatingText.instantiate()
	tree.current_scene.add_child(ft)
	ft.global_position = world_pos + TEXT_OFFSET
	var text: String = ("TAKIM +%d" if assist == TEAM_KIND else ("ASİST +%d" if assist > 0 else "+%d")) % amount
	if ft.has_method("setup"):
		ft.setup(text, ASSIST_COLOR if assist > 0 else TEXT_COLOR)
	_add_coin_icon(ft, text)
	_play_sound(tree, world_pos)


## Yazının hemen soluna SABİT (animasyonsuz) altın simgesi - yazının çocuğu: birlikte yükselir ve söner. Yazı Label'ın üst-ortasına
## yerleşir (dikey hizalama üst), bu yüzden simge ölçülen metin kutusunun ortasına konur.
static func _add_coin_icon(ft: Node, _text: String) -> void:
	var lbl: Label = ft.get("label") as Label
	if lbl == null:
		return
	var size: Vector2 = lbl.get_minimum_size()
	var icon := Sprite2D.new()
	icon.texture = COIN_FRAMES.get_frame_texture("spin", 0)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.scale = Vector2.ONE * ICON_SCALE
	icon.position = Vector2(lbl.position.x + lbl.size.x * 0.5 - size.x * 0.5 - ICON_GAP - 8.0 * ICON_SCALE, lbl.position.y + size.y * 0.5)
	ft.add_child(icon)


static func play_sound_at(tree: SceneTree, world_pos: Vector2) -> void:
	if tree != null and tree.current_scene != null:
		_play_sound(tree, world_pos)


static func _play_sound(tree: SceneTree, world_pos: Vector2) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_sound_msec < MIN_SOUND_GAP_MSEC:
		return
	_last_sound_msec = now
	var s := AudioStreamPlayer2D.new()
	s.stream = SOUND
	s.volume_db = SOUND_DB
	s.max_distance = 1500.0
	s.pitch_scale = randf_range(0.97, 1.05)
	tree.current_scene.add_child(s)
	s.global_position = world_pos
	s.finished.connect(s.queue_free)
	s.play()


## Host/tek oyunculu: altını öldürene ver. killer = enemy._killer_node() sonucu.
## 2026-10-21 (kullanıcı: "altını yere düşürüp 0.5 saniye sonra vermesi gereken kişiye doğru uçarak versin"): yerel alıcı için ölüm
## noktasında dönen para belirir (drop_coin), 0,5 sn sonra ona uçar ve varınca altın eklenir. Uzak alıcıya host HEMEN RPC atar; para o
## makinede aynı şekilde düşer (NetworkManager.grant_kill_gold -> drop_coin).
static func award(tree: SceneTree, amount: int, world_pos: Vector2, killer: Node, assist: int = 0) -> void:
	if amount <= 0:
		return
	if _send_to_remote(amount, world_pos, killer, assist):
		return
	drop_coin(tree, amount, world_pos, assist)


## Yerel alıcı için yerde dönen para. Para görünmeyecekse (sahne/oyuncu yok, doğuş noktası görüş dışı, çok para var) eski gibi anında verilir.
static func drop_coin(tree: SceneTree, amount: int, world_pos: Vector2, assist: int = 0) -> void:
	if amount <= 0:
		return
	var p: Node = tree.get_first_node_in_group("player") if tree else null
	if tree == null or tree.current_scene == null or p == null or not is_instance_valid(p) or not (p is Node2D) 			or active_coins >= MAX_ACTIVE_COINS or not VisionFogScript.own_vision_contains(tree, (p as Node2D).global_position, world_pos):
		credit(tree, amount, world_pos, assist)
		return
	var coin: Node2D = COIN_SCRIPT.new()
	coin.call("setup", amount, assist, p as Node2D, func(a: int, pos: Vector2, kind: int) -> void: credit(tree, a, pos, kind))
	coin.position = world_pos + Vector2(randf_range(-7.0, 7.0), randf_range(-4.0, 4.0)) ## aynı noktada birikenler üst üste yığılmasın
	active_coins += 1
	coin.tree_exited.connect(func() -> void: active_coins = maxi(0, active_coins - 1))
	tree.current_scene.add_child.call_deferred(coin) ## fizik sorgusu akışından (öldürme) çağrılabilir


static func _send_to_remote(amount: int, world_pos: Vector2, killer: Node, assist: int) -> bool:
	if killer != null and is_instance_valid(killer) and not killer.is_in_group("player") 			and killer.is_in_group("remote_players") and "peer_id" in killer and int(killer.peer_id) > 0 			and NetworkManager.is_multiplayer_active:
		NetworkManager.grant_kill_gold.rpc_id(int(killer.peer_id), amount, world_pos, assist)
		return true
	return false


## Altını gerçekten ekler + "+N" yazısı/ses (para varınca, ya da para gösterilemiyorsa hemen).
static func credit(tree: SceneTree, amount: int, world_pos: Vector2, assist: int = 0) -> void:
	if amount <= 0:
		return
	GameManager.gold += amount
	show_at(tree, amount, world_pos, assist)


## Gecikmesiz hali (testler, para animasyonu istenmeyen çağrılar).
static func award_now(tree: SceneTree, amount: int, world_pos: Vector2, killer: Node, assist: int = 0) -> void:
	if amount <= 0:
		return
	if _send_to_remote(amount, world_pos, killer, assist):
		return
	credit(tree, amount, world_pos, assist)
