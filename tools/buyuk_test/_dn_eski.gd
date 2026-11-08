extends Node2D

## YALNIZ ÖLÇÜM / KARŞILAŞTIRMA (madde 429): madde 429 ÖNCESİ hasar sayısı görünüşü - buyuk_test.gd "dmgnum" kipi BT_DN_OLD=1 ile çalışan
## DamageNumbers düğümünün betiğini bununla değiştirir (enemy.gd spawn_hit çağırır -> burada eski enemy.gd yolu: düz beyaz / kritik doygun kırmızı,
## saf siyah kontür, 22x14 saçılma, her vuruş kendi sayısı, ekran sınırı yok, herkese pop, 0,9 sn sinüs süzülme). Oyun bunu YÜKLEMEZ.

const PhysicsInterp := preload("res://scripts/physics_interp.gd")
const RISE := 22.0
const POP_SCALE := 1.3
const POP_TIME := 0.14
const LIFETIME := 0.9
const FADE_IN_DURATION := 0.08
const HOLD := LIFETIME * 0.4
const FADE_OUT := LIFETIME * 0.6
const TOTAL_TIME := FADE_IN_DURATION + HOLD + FADE_OUT
const OUTLINE_OFFSETS: Array[Vector2] = [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
const BOX_POS := Vector2(-80.0, -22.0)
const BOX_WIDTH := 160.0
const FONT_SIZE := 16
const OLD_SCATTER := Vector2(22, 14)
const OLD_CRIT := Color(1.0, 0.25, 0.2)

var _font: Font = null
var _next_id: int = 1
var _entries: Dictionary = {}
var _list: Array = []
var _delayed: Array = []


class Entry:
	var ci: RID
	var id: int = 0
	var target = null
	var offset: Vector2
	var origin: Vector2
	var t: float = 0.0


func _init() -> void:
	z_index = 1
	var th: Theme = ThemeDB.get_project_theme()
	if th != null and th.has_font("font", "Label"):
		_font = th.get_font("font", "Label")
	if _font == null:
		_font = ThemeDB.fallback_font


func spawn_hit(target: Node2D, anchor: Vector2, amount: int, kind: int, ids: Array[int], max_live: int, _max_hp: float = 0.0, _dot_src: String = "") -> void:
	var w: int = 0
	for i in range(ids.size()):
		if _entries.has(ids[i]):
			ids[w] = ids[i]
			w += 1
	ids.resize(w)
	while not ids.is_empty() and ids.size() >= max_live:
		_free_entry(_entries[ids.pop_front()])
	var jitter := Vector2(randf_range(-OLD_SCATTER.x, OLD_SCATTER.x), randf_range(-OLD_SCATTER.y, OLD_SCATTER.y))
	var color: Color = OLD_CRIT if kind == 1 else Color.WHITE
	var e := Entry.new()
	e.id = _next_id
	_next_id += 1
	e.target = target
	var pos: Vector2 = anchor + jitter
	e.origin = pos
	e.offset = pos - PhysicsInterp.visual_position(target) if is_instance_valid(target) else Vector2.ZERO
	e.ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(e.ci, get_canvas_item())
	var tl := TextLine.new()
	tl.add_string(str(maxi(1, amount)), _font, FONT_SIZE)
	tl.width = BOX_WIDTH
	tl.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for off in OUTLINE_OFFSETS:
		tl.draw(e.ci, BOX_POS + off, Color(0, 0, 0, 1))
	tl.draw(e.ci, BOX_POS, color)
	_entries[e.id] = e
	_list.append(e)
	_place(e)
	ids.append(e.id)


func is_alive(id: int) -> bool:
	return _entries.has(id)


func remove(id: int) -> void:
	if _entries.has(id):
		_free_entry(_entries[id])


func call_later(delay: float, c: Callable) -> void:
	_delayed.append([maxf(delay, 0.0), c])


func _free_entry(e: Entry) -> void:
	_entries.erase(e.id)
	_list.erase(e)
	RenderingServer.free_rid(e.ci)


func _place(e: Entry) -> void:
	var rise: float = RISE * sin((minf(e.t, LIFETIME) / LIFETIME) * PI * 0.5)
	var sc: float = 1.0
	if e.t < POP_TIME:
		var k: float = 1.0 - e.t / POP_TIME
		sc = 1.0 + (POP_SCALE - 1.0) * k * k
	RenderingServer.canvas_item_set_transform(e.ci, Transform2D(0.0, Vector2(sc, sc), 0.0, e.origin - Vector2(0.0, rise)))
	var t: float = e.t
	var a: float
	if t < FADE_IN_DURATION:
		a = t / FADE_IN_DURATION
	else:
		t -= FADE_IN_DURATION
		a = 1.0 if t < HOLD else (cos(((t - HOLD) / FADE_OUT) * PI * 0.5) if t - HOLD < FADE_OUT else 0.0)
	RenderingServer.canvas_item_set_modulate(e.ci, Color(1, 1, 1, a))


func _process(delta: float) -> void:
	var i: int = 0
	while i < _delayed.size():
		var item: Array = _delayed[i]
		item[0] = float(item[0]) - delta
		if float(item[0]) > 0.0:
			i += 1
			continue
		_delayed.remove_at(i)
		var c: Callable = item[1]
		if c.is_valid():
			c.call()
	for e in _list.duplicate():
		e.t += delta
		if e.t >= TOTAL_TIME:
			_free_entry(e)
			continue
		if e.target != null and is_instance_valid(e.target):
			e.origin = PhysicsInterp.visual_position(e.target) + e.offset
		else:
			e.target = null
		_place(e)
