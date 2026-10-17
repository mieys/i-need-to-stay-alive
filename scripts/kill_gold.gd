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
const TEXT_OFFSET := Vector2(0.0, -26.0)
## 2026-10-15 (kullanıcı: önce "1 sn sonra", sonra "0,2 saniye olsun"): altın, yazı ve ses ölümden bu kadar sonra gelir; konum ÖLÜM
## anında alınır (yaratık silinse de yazı olduğu yerde çıkar).
const SHOW_DELAY := 0.2
const COIN_FRAMES := preload("res://assets/pickups/gold/gold_coin_frames.tres")
const ICON_SCALE := 0.8 ## 16 px para -> ~13 px (yazı 16 pt piksel fontu)
const ICON_GAP := 3.0
## Kalabalık ölümlerinde sesler üst üste yığılıp patlamasın: iki ses arası en az bu kadar ms (yazılar yine her ölümde çıkar).
const MIN_SOUND_GAP_MSEC := 55

static var _last_sound_msec: int = -100000


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
	var text: String = ("ASİST +%d" if assist > 0 else "+%d") % amount
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


## Host/tek oyunculu: altını öldürene ver (+ yazı/ses onun ekranında). killer = enemy._killer_node() sonucu.
static func award(tree: SceneTree, amount: int, world_pos: Vector2, killer: Node, assist: int = 0) -> void:
	if amount <= 0:
		return
	if tree == null or SHOW_DELAY <= 0.0:
		award_now(tree, amount, world_pos, killer, assist)
		return
	## Alıcı (RemotePlayer kuklası) o arada silinebilir - peer id yakalanır, düğüm değil.
	var peer: int = int(killer.get("peer_id")) if killer != null and is_instance_valid(killer) and "peer_id" in killer and not killer.is_in_group("player") else 0
	tree.create_timer(SHOW_DELAY, false).timeout.connect(func() -> void:
		var target: Node = killer
		if peer > 0 and (target == null or not is_instance_valid(target)):
			target = _remote_by_peer(tree, peer)
		if target != null and not is_instance_valid(target):
			target = null
		award_now(tree, amount, world_pos, target, assist))


static func _remote_by_peer(tree: SceneTree, peer: int) -> Node:
	for rp in tree.get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and "peer_id" in rp and int(rp.peer_id) == peer:
			return rp
	return null


## Gecikmesiz hali (testler, zaten gecikmiş çağrılar).
static func award_now(tree: SceneTree, amount: int, world_pos: Vector2, killer: Node, assist: int = 0) -> void:
	if amount <= 0:
		return
	if killer != null and is_instance_valid(killer) and not killer.is_in_group("player") \
			and killer.is_in_group("remote_players") and "peer_id" in killer and int(killer.peer_id) > 0 \
			and NetworkManager.is_multiplayer_active:
		NetworkManager.grant_kill_gold.rpc_id(int(killer.peer_id), amount, world_pos, assist)
		return
	GameManager.gold += amount
	show_at(tree, amount, world_pos, assist)
