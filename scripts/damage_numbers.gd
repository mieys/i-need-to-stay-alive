extends Node2D

## Yaratık hasar sayılarının TEK düğümden toplu çizimi.
##
## Neden (kullanıcı bildirimi: "alan hasarı alınca FPS 60'tan 40'a düşüyor", gerçek
## oyunda 200 yaratıkla ölçüldü): her hasar sayısı eskiden ayrı bir floating_text
## sahnesiydi (Node2D + 5 Label + 2 Tween). 200 yaratığa vuran bir alan hasarı = 200
## sahne oluşturmak + ekranda 1000 Label; alan hasarından sonra ~35-40 kare 40-55ms
## sürüyordu, hasar sayıları kapatılınca bu neredeyse sıfıra iniyordu.
##
## Burada her sayı node DEĞİL, bu düğümün altında ham bir RenderingServer canvas
## item'ı: metin + 4 kontür kopyası doğduğunda (ve toplam güncellenince) BİR KEZ
## çiziliyor, sonraki karelerde sadece konumu/saydamlığı değişiyor (sayı başına 2
## hafif çağrı). İlk sürüm her karede hepsini yeniden çiziyordu - 200 sayıda kare
## başına ~1.5ms ölçüldü, bu yüzden bu yapıya geçildi.
##
## Yazı floating_text.gd ile aynı (font, boyut, 4 yönlü piksel kontür, belirme/sönme zamanlaması, sis görünürlüğü).
## 2026-10-01'den beri hareket farklı ve sadece burada: pop + uzun süzülme + push_up yığılması, yaratıklar
## spawn_fixed kullanır - bkz. RISE üstündeki not. 2026-11-06'dan beri (madde 416) sayı hedefi TAKİP eder (follow_targets).
##
## FPS (2026-10-18, ölçüm: 600 sayıda _process 1,95 ms = sayı başına 3,2 us; bir hasar sayısının doğuşu ~31 us, yarısından fazlası 5 TextLine.draw):
##  - görünüm/zamanlama AYNI. _process her sayı için _apply + _alpha_of + fog_visibility_of çağrılarını satır içine aldı, sayılar `_list` dizisinde
##    (sözlük araması yok); ömrü biten sayı swap-remove ile çıkar.
##  - Süresi biten (ya da erken silinen) sayının ÇİZİLMİŞ canvas item'ı atılmaz, (metin + renk) anahtarıyla havuzlanır; aynı sayı tekrar çıkınca
##    yeniden çizilmeden kullanılır (hasar değerleri tamsayı ve sınırlı: isabet oranı yüksek). Yeniden kullanılan item canvas_item_set_parent ile
##    kardeşlerin SONUNA taşınır -> "yeni sayı eskilerin üstünde" sırası eskisi gibi.
##  - spawn_fixed_capped: yaratık başına sayı sınırı (ölen kimlikleri at, sınıra gelince en eskiyi sil) tek çağrıda.

const VisionFogScript := preload("res://scripts/vision_fog.gd")
const PhysicsInterp := preload("res://scripts/physics_interp.gd")
const VIS_META := VisionFogScript.VIS_META
const MIN_VISIBILITY := VisionFogScript.SIDE_ELEMENT_MIN_VISIBILITY

## Kullanıcı isteği (2026-10-01): "yukarı çıkmadan direk spawn oluyor... daha güzel bir yukarı çıkış animasyonu" - eski
## 6 px yükselme görünmüyordu. Artık: küçük bir pop (POP_SCALE'den 1'e, POP_TIME'da) + ömür boyunca RISE kadar
## yumuşak süzülme. Yaratıklar sayıyı çevresinde rastgele bir noktada doğurur (madde 429: spawn_hit HIT_SCATTER); push_up() (eskileri
## yumuşakça yukarı kaydırma) şu an kullanılmıyor, sütun dizilimi istenirse hazır. Maliyet aynı: sayı başına karede yine
## 1 transform (+ değişirse 1 modulate) çağrısı.
## Madde 429 (kullanıcı 2026-11-06: "hasar sayıları çok göz yoruyor, karmaşık gösteriyor... kapatmadan"): yükselme 22 -> 20 ve "fırla, fren yap,
## sön" eğrisi (RISE_TIME'da kübik ease-out ile tam yükselir, sonra durup söner; eskisi ömür boyu sinüs süzülme), ömür 0,9 -> 0,7 sn,
## kontür saf siyah yerine paletin OUTLINE kahvesi. Tür başına ömür/yükselme/pop/saydamlık spawn_hit'te (KIND_*).
const RISE := 20.0
const RISE_TIME := 0.6 ## LIFETIME'ın bu oranında tam yükselir
const POP_SCALE := 1.3
const POP_TIME := 0.14
const LIFT_SMOOTH := 16.0
const LIFETIME := 0.7
const FADE_IN_DURATION := 0.08
const HOLD := LIFETIME * 0.4
const FADE_OUT := LIFETIME * 0.6
const TOTAL_TIME := FADE_IN_DURATION + HOLD + FADE_OUT
const HudTheme := preload("res://scripts/hud_theme.gd")
const OUTLINE_COLOR := HudTheme.OUTLINE

## ---- VURUŞ SAYISI (madde 429): yaratık / kopya hasar sayılarının TEK girişi spawn_hit ----
const KIND_HIT := 0
const KIND_CRIT := 1
const KIND_DOT := 2 ## süreli hasar tiki (zehir/yanma/kanama/arı zehri)
## Bir hedefin üstünde en fazla bu aralıkta (gerçek sn) bir YENİ sayı açılır; arada gelen AYNI türden hasar son sayıya eklenir
## (Terraria'nın dokunulmazlık karesinin görsel karşılığı - hasar hesabı değişmez, yalnız gösterim seyrelir). Kritik birleşmez, hep kendi sayısı.
const MERGE_WINDOW := 0.15
## Doğuş noktası çevresinde rastgele saçılma (yarı genişlik / yarı yükseklik). Eski enemy.gd DMG_SCATTER 22x14 - sayılar dağınıktı.
const HIT_SCATTER := Vector2(8.0, 3.0)
## AYRI SAYI (Pompalı saçması, madde 448; kullanıcı: "8 saçma bir düşmana vurunca her saçmanın hasarı ayrı bir hasar gibi görünmeli"):
## isabet eden kod take_damage çağrısının ETRAFINDA true yapar (projectile.gd separate_damage_numbers; istemci vuruşu host'a
## request_enemy_damage'in sep argümanıyla, host'un sayısı "damage_number" "sep" alanıyla gider). true iken: birleştirme YOK,
## hedef başına canlı sayı sınırı SEPARATE_MAX_LIVE, saçılma SEPARATE_SCATTER (salvo patlama gibi dağılır), yer bulamasa da açılır.
static var separate_hits: bool = false
const SEPARATE_SCATTER := Vector2(15.0, 8.0)
const SEPARATE_MAX_LIVE := 14
## Tür başına (KIND_HIT, KIND_CRIT, KIND_DOT): ömür (sn), yükselme çarpanı, pop. Kritik Terraria'daki gibi daha uzun kalır, daha çok yükselir.
const KIND_LIFE: Array[float] = [0.7, 1.0, 0.55]
const KIND_RISE: Array[float] = [1.0, 1.3, 0.6]
const KIND_POP: Array[bool] = [false, true, false]
## Önem: hedefin azami canının bu oranından küçük normal vuruş SMALL_ALPHA saydamlıkta (göz büyük vuruşlara gitsin); süreli hasar hep DOT_ALPHA.
const SMALL_HIT_FRACTION := 0.04
const SMALL_ALPHA := 0.65
const DOT_ALPHA := 0.7
## Ekranda aynı anda en çok bu kadar sayı. Dolunca: soluk (küçük/süreli) yeni sayı hiç açılmaz; büyük vuruş / kritik, kritik olmayanlardan
## en eski + ekran ortasına en uzak olanı siler (eski görünüşte 60 yaratıklık savaşta ortalama 45, en çok 169 sayı vardı). İlk çekimde 30
## alan vuruşunda tek öbek oluyordu -> 24.
const SCREEN_BUDGET := 24
## Üst üste binme (ilk oyun çekimi: sıkışık kalabalıkta komşu yaratıkların "19" ve "36"sı "1936" gibi okunuyordu): yeni sayı, ekrandaki bir sayının
## OVERLAP_W x OVERLAP_H kutusuna düşüyorsa OVERLAP_H kadar yukarı kayar, en çok OVERLAP_TRIES kez (dünya px; m5x7 16 rakam ~6 px, satır ~9 px).
## Yer bulamayan SOLUK sayı (küçük vuruş / süreli hasar) hiç açılmaz - zaten başka sayıların arkasında kalırdı; tam sayılar en üst denemede açılır.
const OVERLAP_W := 16.0
const OVERLAP_H := 9.0
const OVERLAP_TRIES := 3
const BUDGET_DIST_NORM := 600.0 ## kurban seçiminde uzaklık terimi (dünya px; 600 px uzaklık = ömrünün tamamı kadar eski sayılır)
const OUTLINE_OFFSETS: Array[Vector2] = [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
## floating_text.tscn'deki Label kutusu: (-80,-22)..(80,22), yatay ortalı, üstten hizalı.
const BOX_POS := Vector2(-80.0, -22.0)
const BOX_WIDTH := 160.0
const FONT_SIZE := 16
## Havuzdaki (boşta, çizilmiş) canvas item üst sınırı; aşan atılır.
const FREE_MAX := 256

## HEDEFİ TAKİP (kullanıcı isteği 2026-11-06, madde 416): "hasar sayıları aktifleşince hangi hedeften çıkıyorsa o hedefin üstünde kalmaya
## devam etsin, normal haliyle". true: spawn_fixed / spawn_fixed_capped da sayıyı hedefe bağlar - doğduğu noktanın hedefe göre ofseti
## (rastgele saçılma dahil) saklanır, her karede hedefin ÇİZİLEN konumu + ofset; pop + süzülme + sönme AYNI, hedefe göre işler. Hedef
## silinince sayı son konumunda söner (Entry.target). false = 2026-10-01 davranışı (doğduğu dünya noktasında sabit; o gün "itilen yaratıkla
## sağa sola sallanıyor" diye kapatılmıştı). Testler/ölçüm çalışma anında değiştirebilir: `set_follow_targets`.
static var follow_targets: bool = true


static func set_follow_targets(value: bool) -> void:
	follow_targets = value

static var _instance: Node2D = null

var _font: Font = null
var _next_id: int = 1
## id -> Entry (is_alive / remove / update_text / push_up için)
var _entries: Dictionary = {}
## Aynı kayıtlar, her karede gezilen dizi (Entry.slot = buradaki indeks).
var _list: Array[Entry] = []
## Metin -> şekillendirilmiş TextLine. Bir alan hasarında 200 sayının hepsi genelde
## AYNI metin ("3" gibi) - şekillendirme (TextServer) her biri için tekrar yapılmasın.
var _line_cache: Dictionary = {}
const LINE_CACHE_MAX := 512
## anahtar (metin + renk) -> Array[RID]: çizilmiş, gizli, boşta canvas item'lar.
var _free: Dictionary = {}
var _free_count: int = 0
## call_later kuyruğu: [kalan_sn, Callable] çiftleri (en çok birkaç düzine; süreli hasar sayılarının geciken parçaları).
var _delayed: Array = []


class Entry:
	var ci: RID
	var id: int = 0
	var slot: int = 0
	var key: String = ""
	## Takip edilen yaratık; öldüğünde/silindiğinde null'a çekilir ve sayı son
	## bilinen konumda (origin) sönmeye devam eder.
	var target = null
	var offset: Vector2
	var origin: Vector2
	## false: doğduğu dünya noktasında sabit kalır, dümdüz yukarı çıkar (target sadece sis görünürlüğü için tutulur).
	var follow: bool = true
	var rise_t: float = 0.0
	var fade_t: float = 0.0
	## push_up birikimi (hedef) ve şu anki yumuşatılmış değeri.
	var lift: float = 0.0
	var lift_target: float = 0.0
	var fade_from: float = 0.0
	## Son uygulanan değerler - değişmeyen RenderingServer çağrıları atlanır. alpha = zaman çizelgesindeki değer (_alpha_of), modulate = alpha x alpha_mul.
	var shown: bool = true
	var alpha: float = -1.0
	## Madde 429 (spawn_hit): tür, gösterilen tamsayı değer (birleştirmede büyür), zaman ölçeği (LIFETIME / tür ömrü - fade_t ve rise_t
	## LIFETIME birimiyle işler, TOTAL_TIME/_alpha_of hepsinde aynı), yükselme çarpanı, pop, saydamlık çarpanı, gerçek yaş (birleştirme
	## penceresi), metin değişti bayrağı (birleştirme karede bir kez yeniden çizilir), azami can (önem saydamlığı), süreli hasar türü.
	var kind: int = -1
	var value: int = 0
	var tscale: float = 1.0
	var rise_mul: float = 1.0
	var pop: bool = true
	var alpha_mul: float = 1.0
	var age: float = 0.0
	var dirty: bool = false
	var max_hp: float = 0.0
	var dot_src: String = ""


## Tek örneği döndürür, yoksa oluşturur (sahneye ekleme ertelenir - fizik sorgu
## taşması sırasında da güvenle çağrılabilsin diye; eklenene kadar kayıtlar
## birikir, eklenince görünür).
static func get_instance(tree: SceneTree) -> Node2D:
	if _instance != null and is_instance_valid(_instance) and not _instance.is_queued_for_deletion():
		return _instance
	if tree == null or tree.current_scene == null:
		return null
	var n := Node2D.new()
	n.set_script(load("res://scripts/damage_numbers.gd"))
	n.name = "DamageNumbers"
	tree.current_scene.add_child.call_deferred(n)
	_instance = n
	return n


func _init() -> void:
	## Eski floating_text düğümleri z=0'da ama sahneye EN SON eklendikleri için
	## yaratıkların (z=0) üstünde çiziliyordu. Bu düğüm bir kez, erken ekleniyor -
	## sonradan eklenen yaratıklar üstüne binmesin diye 1 (oyuncuyla aynı katman).
	z_index = 1
	var th: Theme = ThemeDB.get_project_theme()
	if th != null and th.has_font("font", "Label"):
		_font = th.get_font("font", "Label")
	if _font == null:
		_font = ThemeDB.fallback_font


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for e in _list:
			RenderingServer.free_rid(e.ci)
		_list.clear()
		_entries.clear()
		for key in _free:
			for ci: RID in _free[key]:
				RenderingServer.free_rid(ci)
		_free.clear()
		_free_count = 0


func spawn(target: Node2D, offset: Vector2, text: String, color: Color) -> int:
	return _spawn_entry(target, offset, target.global_position + offset if is_instance_valid(target) else Vector2.ZERO, true, text, color)


## world_pos'ta doğan sayı. follow_targets true (varsayılan, madde 416) ve hedef geçerliyse hedefe bağlanır (ofset = world_pos - hedefin
## çizilen konumu), değilse doğduğu noktada sabit kalıp dümdüz yukarı çıkar (2026-10-01 kipi; target yalnızca sis görünürlüğü için).
func spawn_fixed(target: Node2D, world_pos: Vector2, text: String, color: Color) -> int:
	return _spawn_at(target, world_pos, text, color)


func _spawn_at(target: Node2D, world_pos: Vector2, text: String, color: Color) -> int:
	if follow_targets and target != null and is_instance_valid(target):
		return _spawn_entry(target, world_pos - PhysicsInterp.visual_position(target), world_pos, true, text, color)
	return _spawn_entry(target, Vector2.ZERO, world_pos, false, text, color)


## Yaratık başına sayı sınırı ile doğurma (enemy.gd _spawn_floating_text): ids = yaratığın canlı sayı kimlikleri (eskiden yeniye), YERİNDE güncellenir.
## Ölmüş (süresi dolmuş/silinmiş) kimlikler atılır, max_live'a ulaşılmışsa en eskiler silinir, yeni sayı eklenir.
func spawn_fixed_capped(target: Node2D, world_pos: Vector2, text: String, color: Color, ids: Array[int], max_live: int) -> void:
	var w: int = 0
	for i in range(ids.size()):
		var id: int = ids[i]
		if _entries.has(id):
			ids[w] = id
			w += 1
	if w != ids.size():
		ids.resize(w)
	while not ids.is_empty() and ids.size() >= max_live:
		remove(ids.pop_front())
	ids.append(_spawn_at(target, world_pos, text, color))


## Süreli hasar kaynağı ("dot:zehir" / "zehir" ...) -> sayı rengi. Bilinmeyen = DMG_DOT.
static func color_for(kind: int, dot_src: String = "") -> Color:
	if kind == KIND_CRIT:
		return HudTheme.DMG_CRIT
	if kind == KIND_DOT:
		var s: String = dot_src.trim_prefix("dot:")
		if s == "zehir" or s == "ari_zehri":
			return HudTheme.DMG_DOT_POISON
		if s == "yanma":
			return HudTheme.DMG_DOT_BURN
		if s == "kanama":
			return HudTheme.DMG_DOT_BLEED
		return HudTheme.DMG_DOT
	return HudTheme.DMG_HIT


## Saydamlık çarpanı: süreli hasar DOT_ALPHA, hedefin azami canının SMALL_HIT_FRACTION'ından küçük normal vuruş SMALL_ALPHA, gerisi tam.
static func alpha_mul_for(kind: int, value: int, max_hp: float) -> float:
	if kind == KIND_DOT:
		return DOT_ALPHA
	if kind == KIND_HIT and max_hp > 0.0 and float(value) < max_hp * SMALL_HIT_FRACTION:
		return SMALL_ALPHA
	return 1.0


## VURUŞ SAYISI (madde 429) - enemy.gd _spawn_floating_text + mission_player_copy.gd'nin tek girişi (host'taki vuruş da, istemcinin ağdan aldığı
## "damage_number" da buradan geçer -> iki yerde aynı görünür). anchor = hedefin tepesi (saçılma burada eklenir), ids = hedefin canlı sayı
## kimlikleri (eskiden yeniye, YERİNDE güncellenir), max_live = hedef başı sınır, max_hp = önem saydamlığı için (0 = hep tam).
## Sıra: ölü kimlikleri at -> son sayı aynı türden, kritik değil ve MERGE_WINDOW'dan gençse ona ekle -> ekran bütçesi -> hedef başı sınır -> yeni sayı.
func spawn_hit(target: Node2D, anchor: Vector2, amount: int, kind: int, ids: Array[int], max_live: int, max_hp: float = 0.0, dot_src: String = "") -> void:
	amount = maxi(1, amount)
	var w: int = 0
	for i in range(ids.size()):
		var id: int = ids[i]
		if _entries.has(id):
			ids[w] = id
			w += 1
	if w != ids.size():
		ids.resize(w)
	var sep: bool = separate_hits
	if sep:
		max_live = maxi(max_live, SEPARATE_MAX_LIVE)
	if kind != KIND_CRIT and not sep and not ids.is_empty():
		var last: Entry = _entries.get(ids[ids.size() - 1])
		if last != null and last.kind == kind and last.age < MERGE_WINDOW and last.dot_src == dot_src:
			last.value += amount
			last.alpha_mul = alpha_mul_for(kind, last.value, last.max_hp)
			last.alpha = -1.0 ## modulate yeniden uygulansın (alpha_mul değişmiş olabilir)
			last.dirty = true
			return
	var new_mul: float = alpha_mul_for(kind, amount, max_hp)
	var sc: Vector2 = SEPARATE_SCATTER if sep else HIT_SCATTER
	var jitter := Vector2(randf_range(-sc.x, sc.x), randf_range(-sc.y, sc.y))
	var spot: Vector2 = _free_spot(anchor + jitter)
	if _spot_blocked and new_mul < 1.0 and kind != KIND_CRIT and not sep:
		return
	if _list.size() >= SCREEN_BUDGET and not _make_room(kind, new_mul):
		return
	while not ids.is_empty() and ids.size() >= max_live:
		remove(ids.pop_front())
	var k: int = clampi(kind, 0, KIND_LIFE.size() - 1)
	var id: int = _spawn_at(target, spot, str(amount), color_for(kind, dot_src))
	var e: Entry = _entries[id]
	e.kind = kind
	e.value = amount
	e.tscale = LIFETIME / KIND_LIFE[k]
	e.rise_mul = KIND_RISE[k]
	e.pop = KIND_POP[k]
	e.max_hp = max_hp
	e.dot_src = dot_src
	e.alpha_mul = new_mul
	e.alpha = -1.0
	_apply(e) ## tür değerleriyle ilk kare
	ids.append(id)


## Üst üste binmeyen doğuş noktası: ekrandaki (görünen) bir sayının çizildiği yere çok yakınsa OVERLAP_H yukarı, en çok OVERLAP_TRIES kez.
## Hiçbiri boş değilse en üst deneme döner ve _spot_blocked true olur. Ekranda en çok SCREEN_BUDGET sayı olduğu için tarama ucuz (24 x 4).
var _spot_blocked: bool = false


func _free_spot(pos: Vector2) -> Vector2:
	_spot_blocked = false
	for t in range(OVERLAP_TRIES + 1):
		var hit: bool = false
		for e in _list:
			if not e.shown or e.fade_t > TOTAL_TIME * 0.85: ## sönmek üzere olan engel sayılmaz (yeni doğanın alfası 0 olsa da sayılır)
				continue
			var p: Vector2 = e.origin - Vector2(0.0, _rise_of(e.rise_t, e.rise_mul) + e.lift)
			if absf(p.x - pos.x) < OVERLAP_W and absf(p.y - pos.y) < OVERLAP_H:
				hit = true
				break
		if not hit:
			return pos
		if t < OVERLAP_TRIES:
			pos.y -= OVERLAP_H
	_spot_blocked = true
	return pos


## Ekran bütçesi dolu (SCREEN_BUDGET): yer açılabildiyse true. Soluk (küçük/süreli) yeni sayı yer açmaz. Kurban: kritik olmayanlardan
## (ömür oranı + ekran ortasına uzaklık / BUDGET_DIST_NORM) en büyüğü; hepsi kritikse ve yeni sayı kritikse en eski kritik.
func _make_room(kind: int, new_mul: float) -> bool:
	if new_mul < 1.0 and kind != KIND_CRIT:
		return false
	var center := Vector2.INF
	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_2d()
		if cam != null:
			center = cam.get_screen_center_position()
	var victim: Entry = null
	var best: float = -1.0
	var oldest_crit: Entry = null
	for e in _list:
		var score: float = e.fade_t / TOTAL_TIME
		if e.kind == KIND_CRIT:
			if oldest_crit == null or e.fade_t > oldest_crit.fade_t:
				oldest_crit = e
			continue
		if center != Vector2.INF:
			score += e.origin.distance_to(center) / BUDGET_DIST_NORM
		if e.alpha_mul < 1.0:
			score += 1.0 ## önce soluklar gider
		if score > best:
			best = score
			victim = e
	if victim == null and kind == KIND_CRIT:
		victim = oldest_crit
	if victim == null:
		return false
	_release(victim)
	return true


func _spawn_entry(target: Node2D, offset: Vector2, origin: Vector2, follow: bool, text: String, color: Color) -> int:
	var id: int = _next_id
	_next_id += 1
	var e := Entry.new()
	e.id = id
	e.target = target
	e.offset = offset
	e.origin = origin
	e.follow = follow
	e.key = text if color == Color.WHITE else "%s|%d" % [text, color.to_rgba32()]
	var pooled: Variant = _free.get(e.key)
	if pooled != null and not (pooled as Array).is_empty():
		e.ci = (pooled as Array).pop_back()
		_free_count -= 1
		RenderingServer.canvas_item_set_parent(e.ci, get_canvas_item()) ## kardeşlerin sonuna: yeni sayı eskilerin üstünde
		RenderingServer.canvas_item_set_visible(e.ci, true)
	else:
		e.ci = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(e.ci, get_canvas_item())
		_paint(e.ci, text, color)
	_apply(e)
	_entries[id] = e
	e.slot = _list.size()
	_list.append(e)
	return id


func is_alive(id: int) -> bool:
	return _entries.has(id)


## `delay` sn sonra `c`'yi çağırır (süreli hasar tikinin sayısı bölününce geciken parçaları: enemy.gd _show_hit_number). Çağrılacak nesne bu arada
## silindiyse parça sessizce atılır. Duraklatmada _process durduğu için kuyruk da durur. Yeni bir node/Tween/zamanlayıcı açmaz.
func call_later(delay: float, c: Callable) -> void:
	_delayed.append([maxf(delay, 0.0), c])


func _run_delayed(delta: float) -> void:
	var i: int = 0
	while i < _delayed.size():
		var item: Array = _delayed[i]
		var left: float = float(item[0]) - delta
		if left > 0.0:
			item[0] = left
			i += 1
			continue
		_delayed.remove_at(i) ## i'yi ilerletme: sıradaki öğe şimdi bu indekste (çağrı sırasında kuyruğa eklenenler sona gider, bu karede işlenir)
		var c: Callable = item[1]
		if c.is_valid():
			c.call()


## Sayıyı yumuşakça amount kadar daha yukarı kaydırır (aynı yaratığa yeni sayı geldiğinde ona yer açmak için).
func push_up(id: int, amount: float) -> void:
	var e: Entry = _entries.get(id)
	if e != null:
		e.lift_target += amount


## Kaydı süresi dolmadan siler (yaratık başı sayı sınırı dolunca en eskisi gider).
func remove(id: int) -> void:
	var e: Entry = _entries.get(id)
	if e == null:
		return
	_release(e)


## Kaydı listeden/sözlükten çıkarır ve canvas item'ı havuza (doluysa serbest) bırakır.
func _release(e: Entry) -> void:
	var last: Entry = _list.pop_back()
	if last != e:
		_list[e.slot] = last
		last.slot = e.slot
	_entries.erase(e.id)
	if _free_count < FREE_MAX:
		RenderingServer.canvas_item_set_visible(e.ci, false)
		var arr: Variant = _free.get(e.key)
		if arr == null:
			arr = []
			_free[e.key] = arr
		(arr as Array).append(e.ci)
		_free_count += 1
	else:
		RenderingServer.free_rid(e.ci)


## floating_text.gd update_text ile aynı: metin/renk güncellenir, sönme zamanlayıcısı
## MEVCUT saydamlıktan yeniden başlar, yükselme yeniden başlamaz.
func update_text(id: int, text: String, color: Color) -> void:
	var e: Entry = _entries.get(id)
	if e == null:
		return
	RenderingServer.canvas_item_clear(e.ci)
	_paint(e.ci, text, color)
	e.key = text if color == Color.WHITE else "%s|%d" % [text, color.to_rgba32()]
	e.fade_from = _alpha_of(e.fade_t, e.fade_from)
	e.fade_t = 0.0


func _paint(ci: RID, text: String, color: Color) -> void:
	var tl: TextLine = _line_cache.get(text)
	if tl == null:
		if _line_cache.size() >= LINE_CACHE_MAX:
			_line_cache.clear()
		tl = TextLine.new()
		tl.add_string(text, _font, FONT_SIZE)
		tl.width = BOX_WIDTH
		tl.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_line_cache[text] = tl
	for off in OUTLINE_OFFSETS:
		tl.draw(ci, BOX_POS + off, OUTLINE_COLOR)
	tl.draw(ci, BOX_POS, color)


static func _alpha_of(t: float, a0: float) -> float:
	if t < FADE_IN_DURATION:
		return a0 + (1.0 - a0) * (t / FADE_IN_DURATION)
	t -= FADE_IN_DURATION
	if t < HOLD:
		return 1.0
	t -= HOLD
	if t < FADE_OUT:
		## Tween TRANS_SINE + EASE_IN, 1 -> 0.
		return cos((t / FADE_OUT) * PI * 0.5)
	return 0.0


## "Fırla, fren yap, sön" (madde 429): LIFETIME x RISE_TIME'da kübik ease-out ile RISE x mul'a çıkar, sonra durur (sönme yerinde).
static func _rise_of(rise_t: float, mul: float) -> float:
	var u: float = minf(1.0, rise_t / (LIFETIME * RISE_TIME))
	var v: float = 1.0 - u
	return RISE * mul * (1.0 - v * v * v)


static func _key_of(text: String, color: Color) -> String:
	return text if color == Color.WHITE else "%s|%d" % [text, color.to_rgba32()]


## Birleştirilen sayının yeni değerini çizer (spawn_hit dirty bırakır, karede BİR kez burada; havuz anahtarı da güncellenir).
func _repaint(e: Entry) -> void:
	e.dirty = false
	var text: String = str(e.value)
	var color: Color = color_for(e.kind, e.dot_src)
	RenderingServer.canvas_item_clear(e.ci)
	_paint(e.ci, text, color)
	e.key = _key_of(text, color)


func _apply(e: Entry) -> void:
	## Sis görünürlüğü (floating_text.gd ile aynı kural - sadece sisin yönettiği değer).
	var visible_now: bool = e.target == null or VisionFogScript.fog_visibility_of(e.target) >= VisionFogScript.SIDE_ELEMENT_MIN_VISIBILITY
	if visible_now != e.shown:
		e.shown = visible_now
		RenderingServer.canvas_item_set_visible(e.ci, visible_now)
	if visible_now:
		_place(e)


## Konum/ölçek + saydamlık (doğuşta _apply'dan, her karede _process'ten). Pop: e.pop ise ilk POP_TIME'da POP_SCALE -> 1 (karesel ease-out).
## modulate = zaman çizelgesi (alpha) x önem çarpanı (alpha_mul); e.alpha = -1 yeniden uygulatır.
func _place(e: Entry) -> void:
	var rise_t: float = e.rise_t
	var sc: float = 1.0
	if e.pop and rise_t < POP_TIME:
		var k: float = 1.0 - rise_t / POP_TIME
		sc = 1.0 + (POP_SCALE - 1.0) * k * k
	RenderingServer.canvas_item_set_transform(e.ci, Transform2D(0.0, Vector2(sc, sc), 0.0, e.origin - Vector2(0.0, _rise_of(rise_t, e.rise_mul) + e.lift)))
	var a: float = _alpha_of(e.fade_t, e.fade_from)
	if a != e.alpha:
		e.alpha = a
		RenderingServer.canvas_item_set_modulate(e.ci, Color(1, 1, 1, a * e.alpha_mul))


## Madde 429'dan beri ekranda en çok SCREEN_BUDGET (30) sayı olduğu için _process artık satır içi değil (_place ortak): eskiden 600 sayıda 3,2 us/sayı
## için satır içine alınmıştı. Süreler e.tscale ile LIFETIME birimine çevrilir (tür ömrü); e.age gerçek saniye (birleştirme penceresi).
func _process(delta: float) -> void:
	if not _delayed.is_empty():
		_run_delayed(delta)
	var n: int = _list.size()
	if n == 0:
		return
	var i: int = 0
	while i < n:
		var e: Entry = _list[i]
		var d: float = delta * e.tscale
		var fade_t: float = e.fade_t + d
		e.fade_t = fade_t
		if fade_t >= TOTAL_TIME:
			_release(e) ## swap-remove: yerine listenin SONU geldi, i'yi ilerletme (o da bu karede işlenmeli)
			n -= 1
			continue
		e.age += delta
		e.rise_t = minf(e.rise_t + d, LIFETIME)
		if e.dirty:
			_repaint(e)
		if e.lift != e.lift_target:
			e.lift = move_toward(e.lift, e.lift_target, maxf(0.5, absf(e.lift_target - e.lift) * LIFT_SMOOTH * delta))
		var tgt = e.target
		if tgt != null:
			if not is_instance_valid(tgt):
				e.target = null
				tgt = null
			elif e.follow:
				## Çizilen (interpolasyonlu) konuma yapış, ham fizik konumuna değil - bkz. PhysicsInterp.visual_position.
				e.origin = PhysicsInterp.visual_position(tgt) + e.offset
		var visible_now: bool = tgt == null or float(tgt.get_meta(VIS_META, 1.0)) >= MIN_VISIBILITY
		if visible_now != e.shown:
			e.shown = visible_now
			RenderingServer.canvas_item_set_visible(e.ci, visible_now)
		if visible_now:
			_place(e)
		i += 1
