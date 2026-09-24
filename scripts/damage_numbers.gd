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
## Görünüm floating_text.gd ile BİREBİR aynı olacak şekilde yazıldı (font, boyut,
## 4 yönlü piksel kontür, yükselme/belirme/sönme zamanlaması, saydamlığın metin+
## kontüre birlikte uygulanması, sis görünürlüğü, hedefi takip, hedef yok olunca
## son konumda kalma) - oradaki bir sabiti değiştirirsen buradakini de değiştir.

const VisionFogScript := preload("res://scripts/vision_fog.gd")
const PhysicsInterp := preload("res://scripts/physics_interp.gd")

const RISE := 6.0
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

static var _instance: Node2D = null

var _font: Font = null
var _next_id: int = 1
## id -> Entry
var _entries: Dictionary = {}
## Metin -> şekillendirilmiş TextLine. Bir alan hasarında 200 sayının hepsi genelde
## AYNI metin ("3" gibi) - şekillendirme (TextServer) her biri için tekrar yapılmasın.
var _line_cache: Dictionary = {}
const LINE_CACHE_MAX := 512


class Entry:
	var ci: RID
	## Takip edilen yaratık; öldüğünde/silindiğinde null'a çekilir ve sayı son
	## bilinen konumda (origin) sönmeye devam eder.
	var target = null
	var offset: Vector2
	var origin: Vector2
	var rise_t: float = 0.0
	var fade_t: float = 0.0
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
		for id in _entries:
			RenderingServer.free_rid((_entries[id] as Entry).ci)
		_entries.clear()


func spawn(target: Node2D, offset: Vector2, text: String, color: Color) -> int:
	var id: int = _next_id
	_next_id += 1
	var e := Entry.new()
	e.target = target
	e.offset = offset
	e.origin = target.global_position + offset if is_instance_valid(target) else Vector2.ZERO
	e.ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(e.ci, get_canvas_item())
	_paint(e.ci, text, color)
	_apply(e)
	_entries[id] = e
	return id


func is_alive(id: int) -> bool:
	return _entries.has(id)


## floating_text.gd update_text ile aynı: metin/renk güncellenir, sönme zamanlayıcısı
## MEVCUT saydamlıktan yeniden başlar, yükselme yeniden başlamaz.
func update_text(id: int, text: String, color: Color) -> void:
	var e: Entry = _entries.get(id)
	if e == null:
		return
	RenderingServer.canvas_item_clear(e.ci)
	_paint(e.ci, text, color)
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
	## Tween TRANS_SINE + EASE_OUT, 0 -> RISE.
	var rise: float = RISE * sin((e.rise_t / LIFETIME) * PI * 0.5)
	RenderingServer.canvas_item_set_transform(e.ci, Transform2D(0.0, e.origin - Vector2(0.0, rise)))
	var a: float = _alpha_of(e.fade_t, e.fade_from)
	if a != e.alpha:
		e.alpha = a
		RenderingServer.canvas_item_set_modulate(e.ci, Color(1, 1, 1, a))


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	var dead: Array[int] = []
	for id in _entries:
		var e: Entry = _entries[id]
		e.fade_t += delta
		if e.fade_t >= TOTAL_TIME:
			dead.append(id)
			continue
		e.rise_t = minf(e.rise_t + delta, LIFETIME)
		if e.target != null:
			if is_instance_valid(e.target):
				## Çizilen (interpolasyonlu) konuma yapış, ham fizik konumuna değil - bkz. PhysicsInterp.visual_position.
				e.origin = PhysicsInterp.visual_position(e.target) + e.offset
			else:
				e.target = null
		_apply(e)
	for id in dead:
		RenderingServer.free_rid((_entries[id] as Entry).ci)
		_entries.erase(id)
