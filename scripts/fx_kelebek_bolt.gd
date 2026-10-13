extends Node2D

## Kelebek Ruhu'nun atışı (kullanıcı seçimi 2026-10-12: anlık ışın değil, hedefe uçan kısa mermi). 2026-10-13 YENİDEN ÇİZİLDİ
## (kullanıcı: "neredeyse hiç görünmüyor, parlak değil"): eskisi 1 piksel kalınlığında 9 piksellik çizgiydi (ekranda ~1 px).
## Şimdi "ruh kıvılcımı": 7 piksellik elmas baş (beyaz çekirdek - açık pembe - koyu pembe kenar), 2 karede göz kırpan yıldız uçları,
## incelerek sönen 14 piksellik kuyruk + savrulan 2 toz pikseli, altında EKLEMELİ (additive) basamaklı pembe hale; varınca 3 karelik
## yıldız patlaması. Düğüm DÖNMEZ: baş piksel ızgarasına oturur, kuyruk yön boyunca yuvarlanmış piksellerle dizilir.
## Hedef canlıysa onu izler; öldüyse son bilinen noktaya gider. Hasar BURADA DEĞİL: varınca on_hit çağrılır (kelebek_ruhu.gd _deal;
## kukla ekranında boş).

const SPEED := 520.0 ## dünya birimi/sn
const TWINKLE := 0.06 ## uçarken yıldız uçlarının yanıp sönme karesi
const SPARK_FRAME := 0.07 ## patlamanın her karesi
const SPARK_FRAMES := 3
const LENGTH := 14
const C_CORE := Color8(255, 250, 253)
const C_LIGHT := Color8(255, 176, 220)
const C_PINK := Color8(255, 96, 176)
const C_RIM := Color8(224, 48, 142)
const C_DARK := Color8(150, 36, 110)
const C_GLOW := Color(1.0, 0.3, 0.65)
const AXES: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
const DIAGS: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]

static var _add_mat: CanvasItemMaterial = null

var _target: Node2D = null
var _dest: Vector2 = Vector2.ZERO
var _on_hit: Callable = Callable()
var _spark_t: float = -1.0
var _travelled: float = 0.0
var _len: int = 1 ## çizilen kuyruk boyu: namludan çıkarken uzar (kuyruk kelebeğin arkasına taşmasın)
var _dir: Vector2 = Vector2.RIGHT
var _anim_t: float = 0.0
var _frame: int = 0
var _glow: Node2D = null


func _ready() -> void:
	top_level = true
	z_index = 60 ## fx_matthew_bolt.gd ile aynı katman (yaratıkların üstünde)
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Node2D.new()
	_glow.material = _add_mat
	_glow.show_behind_parent = true
	add_child(_glow)
	_glow.draw.connect(_draw_glow)


## px = 1 sanat pikselinin dünya boyu (sahibin karakter pikseli).
func launch(from: Vector2, target: Node2D, dest: Vector2, px: float, on_hit: Callable) -> void:
	_target = target
	_dest = dest
	_on_hit = on_hit
	global_position = from
	scale = Vector2(px, px)
	if not dest.is_equal_approx(from):
		_dir = (dest - from).normalized()


func _process(delta: float) -> void:
	if _spark_t >= 0.0:
		_spark_t += delta
		var f: int = int(_spark_t / SPARK_FRAME)
		if f >= SPARK_FRAMES:
			queue_free()
		elif f != _frame:
			_frame = f
			_redraw()
		return
	if is_instance_valid(_target):
		_dest = _target.global_position
	var to: Vector2 = _dest - global_position
	var step: float = SPEED * delta
	if to.length() <= step:
		global_position = _dest
		_spark_t = 0.0
		_frame = 0
		_redraw()
		if _on_hit.is_valid():
			_on_hit.call(_target if is_instance_valid(_target) else null)
		return
	_dir = to / to.length()
	global_position += _dir * step
	_travelled += step
	_anim_t += delta
	var want: int = clampi(int(_travelled / maxf(0.001, scale.x)), 1, LENGTH)
	var f2: int = int(_anim_t / TWINKLE) % 2
	if want != _len or f2 != _frame:
		_len = want
		_frame = f2
		_redraw()


func _redraw() -> void:
	queue_redraw()
	_glow.queue_redraw()


func _px(ci: CanvasItem, p: Vector2, col: Color, w: float = 1.0) -> void:
	var h: float = floorf(w * 0.5) + 0.5
	ci.draw_rect(Rect2(p.x - h, p.y - h, w, w), col)


func _diamond(ci: CanvasItem, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		var half: float = float(r - absi(y))
		ci.draw_rect(Rect2(-half - 0.5, float(y) - 0.5, half * 2.0 + 1.0, 1.0), col)


func _draw_glow() -> void:
	if _spark_t < 0.0:
		_diamond(_glow, 6, Color(C_GLOW, 0.2))
		_diamond(_glow, 4, Color(C_GLOW, 0.28))
	elif _frame == 0:
		_diamond(_glow, 8, Color(C_GLOW, 0.24))
		_diamond(_glow, 6, Color(C_GLOW, 0.34))
	elif _frame == 1:
		_diamond(_glow, 7, Color(C_GLOW, 0.2))


func _draw() -> void:
	if _spark_t >= 0.0:
		_draw_spark()
		return
	var perp := Vector2(-_dir.y, _dir.x)
	for i in range(_len, 0, -1):
		var col: Color = C_LIGHT if i <= 4 else (C_PINK if i <= 8 else (C_RIM if i <= 11 else Color(C_DARK, 0.75)))
		_px(self, (-_dir * float(i)).round(), col, 3.0 if i <= 5 else (2.0 if i <= 10 else 1.0))
	var side: float = 2.0 if _frame == 0 else -2.0
	if _len >= 7:
		_px(self, (-_dir * 7.0 + perp * side).round(), C_CORE)
	if _len >= 12:
		_px(self, (-_dir * 12.0 - perp * side).round(), C_PINK)
	_diamond(self, 3, C_RIM)
	_diamond(self, 2, C_LIGHT)
	_diamond(self, 1, C_CORE)
	if _frame == 1:
		for d: Vector2 in AXES:
			_px(self, d * 4.0, C_LIGHT)


func _draw_spark() -> void:
	match _frame:
		0:
			_diamond(self, 4, C_RIM)
			_diamond(self, 3, C_LIGHT)
			_diamond(self, 2, C_CORE)
			for d: Vector2 in AXES:
				_px(self, d * 5.0, C_CORE)
				_px(self, d * 6.0, C_LIGHT)
		1:
			for d: Vector2 in AXES:
				_px(self, d * 4.0, C_CORE)
				_px(self, d * 5.0, C_LIGHT)
				_px(self, d * 6.0, C_PINK)
				_px(self, d * 7.0, C_RIM)
			for d: Vector2 in DIAGS:
				_px(self, d * 3.0, C_LIGHT)
				_px(self, d * 4.0, C_RIM)
			_diamond(self, 1, C_CORE)
		_:
			for d: Vector2 in AXES:
				_px(self, d * 7.0, C_PINK)
				_px(self, d * 8.0, Color(C_DARK, 0.75))
			for d: Vector2 in DIAGS:
				_px(self, d * 5.0, Color(C_RIM, 0.8))
			_px(self, Vector2.ZERO, C_LIGHT)
