extends RefCounted
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## Yaratık öldürme altını (kullanıcı isteği 2026-10-15): "yaratıklar ölünce yere altın düşürmeyecek. onun yerine üstünde
## +'altın miktarı' yazacak ve altın sesi çıkacak. yaratıklar kademelerine göre altın verecek."
## Altın artık yere düşmez: öldüren oyuncunun kişisel altınına HEMEN eklenir, ölen yaratığın olduğu yerde "+N" yazısı
## yükselir ve altın sesi çalar. Miktar: yaratığın kademesine göre sahne değerleri (gold_min/gold_max x gold_chance, bkz.
## amount_for) - her ölüm en az 1 altın verir. Host/tek oyunculu hesaplar. (2026-10-24'ten beri altın yine yere düşer, aşağıya bak.)

const FloatingText := preload("res://scenes/floating_text.tscn")
const VisionFogScript := preload("res://scripts/vision_fog.gd")
const BalanceLog := preload("res://scripts/balance_log.gd")
const SOUND: AudioStream = preload("res://assets/audio/gold_pickup.mp3")
const SOUND_DB := -4.0 ## yerden toplama sesi (gold_drop.tscn) -10 dB; yaratık altını kullanıcı isteğiyle +6 dB yükseltildi (2026-10-15)
const TEXT_COLOR := Color(1.0, 0.85, 0.25)
const TEAM_KIND := 4 ## balans kaydı türü: takım payı (balance_log.gd on_kill_gold "team"; NetworkManager._receive_team_gold)
const TEXT_OFFSET := Vector2(0.0, -26.0)
## 2026-10-24 (kullanıcı: "yaratıklar ölünce altını karaktere otomatik göndermesin; eskisi gibi rastgele yere düşsün, toplama mesafesine bağlı
## XP gibi toplansın, toplanınca karakterin üstünde +altın + ses"): altın yerde GoldDrop (gold_drop.gd) olarak kalır, toplayan oyuncu credit() ile
## alır (çok oyunculuda takım payı NetworkManager.host_split_creature_gold). Eski doğrudan teslim (dönen para + asist bölüşümü, assist.gd,
## GROUND_DROPS = false) 2026-11-15'te silindi (kullanıcı kararı; Savaş Şevki artık yalnız öldürmeyle yığılır).
## 2026-11-06 (kullanıcı: "karakter altın toplayınca üstünde + altın görünmesin"): toplanan/teslim edilen altında karakterin üstünde "+N" yazısı ve
## simgesi ÇIKMAZ; altın sesi ve balans kaydı aynen sürer. false = yazı yok.
const SHOW_PICKUP_TEXT := false
const COIN_FRAMES := preload("res://assets/pickups/gold/gold_coin_frames.tres")
const ICON_SCALE := 0.8 ## 16 px para -> ~13 px (yazı 16 pt piksel fontu)
const ICON_GAP := 3.0
## Kalabalık ölümlerinde sesler üst üste yığılıp patlamasın: iki ses arası en az bu kadar ms (yazılar yine her ölümde çıkar).
const MIN_SOUND_GAP_MSEC := 55

static var _last_sound_msec: int = -100000

## 2026-11-13 (kullanıcı: "yaratıklardan %15 daha fazla altın düşsün; tek tek 1-1 düşürmek yerine daha çok sayıda altın versin, yoksa yerde
## çok altın oluyor ve değersiz hissettiriyorlar"): (1) her yaratığın altını INCOME_MULT ile çarpılır (kesirli kısım şansla yuvarlanır, beklenen
## değer tam %15); (2) normal yaratıkların küçük payları havuzda birikir, havuz MIN_COIN'e varınca TEK büyük altın düşer (boss altını havuza
## girmez). Gelir aynı kalır (+%15), yerdeki altın sayısı ~MIN_COIN/ortalama pay kat azalır. Host/tek oyunculu hesaplar.
const INCOME_MULT := 1.15
const MIN_COIN := 15 ## bir altın düşmesi en az bu kadar değer taşır (boss hariç)
static var _pool: int = 0


## TAKIM PAYLAŞIMI (2026-11-15, kullanıcı: "öldüremeyenler fazla altın kasamıyor, item bitiremiyor; öldürebilenler çok rahat item alabiliyor" +
## "toplayana azcık daha fazla versin"): çok oyunculuda yerden toplanan SIRADAN yaratık altını toplayana kalmaz, canlı katılımcılara bölünür.
## Toplayanın payı diğerlerinin PICKER_SHARE_WEIGHT katı (5 oyuncu: %27 / %18'er, 4: %33 / %22, 2: %60 / %40). Boss altını eskisi gibi
## tam eşit (NetworkManager.host_share_boss_gold). Cüzdanlar kişisel kalır. Host hesaplar: NetworkManager.host_split_creature_gold.
const PICKER_SHARE_WEIGHT := 1.5
## peer id -> henüz ödenmemiş kesir (0..1). 15 altınlık para 5 kişide 4,09 + 4 x 2,73 eder; aşağı yuvarlayıp artanı toplayana vermek onun
## payını %27'den %47'ye çıkarırdı - kesirler birikir, uzun vadede oran tam tutar.
static var _share_carry: Dictionary = {}


static func reset_pool() -> void:
	_pool = 0
	_share_carry.clear()


## Bir altının paylarını döndürür: peer id -> şimdi ödenecek tam altın (0 olabilir; kesir _share_carry'de bekler). Toplayan listede yoksa
## herkes eşit ağırlıkta. Tek katılımcı tamamını alır.
static func split_shares(amount: int, peer_ids: Array, picker_id: int) -> Dictionary:
	var out: Dictionary = {}
	if amount <= 0 or peer_ids.is_empty():
		return out
	if peer_ids.size() == 1:
		out[int(peer_ids[0])] = amount
		return out
	var total_w: float = 0.0
	for pid in peer_ids:
		total_w += PICKER_SHARE_WEIGHT if int(pid) == picker_id else 1.0
	for pid in peer_ids:
		var id: int = int(pid)
		var exact: float = float(amount) * (PICKER_SHARE_WEIGHT if id == picker_id else 1.0) / total_w + float(_share_carry.get(id, 0.0))
		var pay: int = int(floor(exact + 0.000001))
		_share_carry[id] = maxf(0.0, exact - float(pay))
		out[id] = pay
	return out


## Kesirli çarpan: 3 x 1,15 = 3,45 -> %45 ihtimalle 4, aksi 3 (beklenen değer tam).
static func scale_amount(amount: int) -> int:
	if amount <= 0:
		return 0
	var v: float = float(amount) * INCOME_MULT
	var whole: int = int(floor(v))
	return whole + (1 if randf() < v - float(whole) else 0)


## Normal yaratık payını havuza ekler; havuz MIN_COIN'e vardıysa boşaltıp tek düşmenin miktarını döndürür, aksi halde 0 (bu ölüm altın düşürmez).
static func pool_take(amount: int) -> int:
	_pool += maxi(amount, 0)
	if _pool < MIN_COIN:
		return 0
	var out: int = _pool
	_pool = 0
	return out


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
static func show_at(tree: SceneTree, amount: int, world_pos: Vector2) -> void:
	if amount <= 0:
		return
	BalanceLog.on_kill_gold(amount, 0) ## balans kaydı: öldürme altını (bkz. balance_log.gd)
	if tree == null or tree.current_scene == null:
		return
	world_pos = resolve_pos(tree, world_pos)
	if not SHOW_PICKUP_TEXT:
		_play_sound(tree, world_pos)
		return
	var ft: Node = FloatingText.instantiate()
	tree.current_scene.add_child(ft)
	ft.global_position = world_pos + TEXT_OFFSET
	var text: String = "+%d" % amount
	if ft.has_method("setup"):
		ft.setup(text, TEXT_COLOR)
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


## Altını gerçekten ekler + ses (yazı SHOW_PICKUP_TEXT ile). Yerden toplama (gold_drop.gd) ve host'un uzak oyuncuya verdiği pay (grant_personal_gold).
static func credit(tree: SceneTree, amount: int, world_pos: Vector2) -> void:
	if amount <= 0:
		return
	GameManager.gold += amount
	show_at(tree, amount, world_pos)
