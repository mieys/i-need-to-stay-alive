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
## spawn_fixed kullanır (takip yok) - bkz. RISE üstündeki not.
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
## yumuşak süzülme. Yaratıklar sayıyı çevresinde rastgele bir noktada doğurur (enemy.gd DMG_SCATTER); push_up() (eskileri
## yumuşakça yukarı kaydırma) şu an kullanılmıyor, sütun dizilimi istenirse hazır. Maliyet aynı: sayı başına karede yine
## 1 transform (+ değişirse 1 modulate) çağrısı.
const RISE := 22.0
const POP_SCALE := 1.3
const POP_TIME := 0.14
const LIFT_SMOOTH := 16.0
const LIFETIME := 0.9
const FADE_IN_DURATION := 0.08
const HOLD := LIFETIME * 0.4
const FADE_OUT := LIFETIME * 0.6
const TOTAL_TIME := FADE_IN_DURATION + HOLD + FADE_OUT
const OUTLINE_COLOR := Color(0, 0, 0, 1)
const OUTLINE_OFFSETS: Array[Vector2] = [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
## floating_text.tscn'deki Label kutusu: (-80,-22)..(80,22), yatay ortalı, üstten hizalı.
const BOX_POS := Vector2(-80.0, -22.0)
const BOX_WIDTH := 160.0
const FONT_SIZE := 16
## Havuzdaki (boşta, çizilmiş) canvas item üst sınırı; aşan atılır.
const FREE_MAX := 256

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
	## Son uygulanan değerler - değişmeyen RenderingServer çağrıları atlanır.
	var shown: bool = true
	var alpha: float = -1.0


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


## Hedefi TAKİP ETMEYEN sayı: world_pos'ta doğar, oradan dümdüz yukarı çıkar. Kullanıcı bildirimi (2026-10-01): takip
## eden sayılar her vuruşta geri itilip ilerleyen yaratıkla birlikte sağa sola sallanıyordu ("sağ sol sağ sol").
## target yalnızca sis görünürlüğü için.
func spawn_fixed(target: Node2D, world_pos: Vector2, text: String, color: Color) -> int:
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
	ids.append(_spawn_entry(target, Vector2.ZERO, world_pos, false, text, color))


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


func _apply(e: Entry) -> void:
	## Sis görünürlüğü (floating_text.gd ile aynı kural - sadece sisin yönettiği değer).
	var visible_now: bool = e.target == null or VisionFogScript.fog_visibility_of(e.target) >= VisionFogScript.SIDE_ELEMENT_MIN_VISIBILITY
	if visible_now != e.shown:
		e.shown = visible_now
		RenderingServer.canvas_item_set_visible(e.ci, visible_now)
	if not visible_now:
		return
	## Yükselme: sinüs ease-out, 0 -> RISE. Pop: ilk POP_TIME'da POP_SCALE -> 1 (karesel ease-out).
	var rise: float = RISE * sin((e.rise_t / LIFETIME) * PI * 0.5)
	var sc: float = 1.0
	if e.rise_t < POP_TIME:
		var k: float = 1.0 - e.rise_t / POP_TIME
		sc = 1.0 + (POP_SCALE - 1.0) * k * k
	RenderingServer.canvas_item_set_transform(e.ci, Transform2D(0.0, Vector2(sc, sc), 0.0, e.origin - Vector2(0.0, rise + e.lift)))
	var a: float = _alpha_of(e.fade_t, e.fade_from)
	if a != e.alpha:
		e.alpha = a
		RenderingServer.canvas_item_set_modulate(e.ci, Color(1, 1, 1, a))


func _process(delta: float) -> void:
	var n: int = _list.size()
	if n == 0:
		return
	var i: int = 0
	while i < n:
		var e: Entry = _list[i]
		var fade_t: float = e.fade_t + delta
		e.fade_t = fade_t
		if fade_t >= TOTAL_TIME:
			_release(e) ## swap-remove: yerine listenin SONU geldi, i'yi ilerletme (o da bu karede işlenmeli)
			n -= 1
			continue
		var rise_t: float = minf(e.rise_t + delta, LIFETIME)
		e.rise_t = rise_t
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
		## ---- _apply(e) satır içi (sonuç birebir aynı): sis görünürlüğü, konum/ölçek, saydamlık
		var visible_now: bool = tgt == null or float(tgt.get_meta(VIS_META, 1.0)) >= MIN_VISIBILITY
		if visible_now != e.shown:
			e.shown = visible_now
			RenderingServer.canvas_item_set_visible(e.ci, visible_now)
		if visible_now:
			var rise: float = RISE * sin((rise_t / LIFETIME) * PI * 0.5)
			var sc: float = 1.0
			if rise_t < POP_TIME:
				var k: float = 1.0 - rise_t / POP_TIME
				sc = 1.0 + (POP_SCALE - 1.0) * k * k
			RenderingServer.canvas_item_set_transform(e.ci, Transform2D(0.0, Vector2(sc, sc), 0.0, e.origin - Vector2(0.0, rise + e.lift)))
			var t: float = fade_t
			var a: float
			if t < FADE_IN_DURATION:
				a = e.fade_from + (1.0 - e.fade_from) * (t / FADE_IN_DURATION)
			else:
				t -= FADE_IN_DURATION
				if t < HOLD:
					a = 1.0
				else:
					t -= HOLD
					a = cos((t / FADE_OUT) * PI * 0.5) if t < FADE_OUT else 0.0
			if a != e.alpha:
				e.alpha = a
				RenderingServer.canvas_item_set_modulate(e.ci, Color(1, 1, 1, a))
		i += 1
