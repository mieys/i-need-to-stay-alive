extends Control

## Arayüz (ekran uzayı) piksel kıvılcımları - kart seçim ödülü parıltısı için (bkz. level_up_screen.gd / chest_menu.gd
## _celebrate_pick). Her parçacık kartın 3 px'lik sanat pikseli ızgarasına oturan karelerden çizilir (TEXEL): nokta ya da
## 4 kollu yıldız (+), bulanık/yumuşak parçacık yok (bkz. hafıza: pixel-style FX, 48x48 piksel yoğunluğu).
## Kendi başına yaşar: burst() sonrası parçacıklar bitince kendini gizler. Ağaç duraklatılmışken de çalışır (level atlama
## ekranı process_mode ALWAYS, bu düğüm ondan miras alır).

const TEXEL := 3.0

## [pos, vel, age, life, delay, star, color]
var _parts: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## rect: parıltının çıktığı alan (bu Control'ün yerel uzayında). colors: rastgele seçilen renkler.
## count dışa saçılan kıvılcım, twinkles süre boyunca rect üstünde yanıp sönen yıldız sayısı.
func burst(rect: Rect2, colors: Array, count: int = 26, twinkles: int = 12, duration: float = 1.0) -> void:
	var center: Vector2 = rect.get_center()
	for i in range(count):
		var p: Vector2 = _perimeter_point(rect)
		var dir: Vector2 = (p - center).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		dir = dir.rotated(randf_range(-0.35, 0.35))
		_parts.append([p, dir * randf_range(90.0, 280.0), 0.0, randf_range(0.45, 0.85), randf() * 0.12,
			randf() < 0.4, colors[randi() % colors.size()]])
	for i in range(twinkles):
		var q := Vector2(randf_range(rect.position.x - 12.0, rect.end.x + 12.0), randf_range(rect.position.y - 12.0, rect.end.y + 12.0))
		_parts.append([q, Vector2(0, -randf_range(0.0, 18.0)), 0.0, randf_range(0.3, 0.45), randf_range(0.05, maxf(0.1, duration - 0.4)),
			true, colors[randi() % colors.size()]])
	visible = true
	set_process(true)


func _perimeter_point(r: Rect2) -> Vector2:
	var per: float = 2.0 * (r.size.x + r.size.y)
	var t: float = randf() * per
	if t < r.size.x:
		return Vector2(r.position.x + t, r.position.y)
	t -= r.size.x
	if t < r.size.y:
		return Vector2(r.end.x, r.position.y + t)
	t -= r.size.y
	if t < r.size.x:
		return Vector2(r.end.x - t, r.end.y)
	t -= r.size.x
	return Vector2(r.position.x, r.end.y - t)


func _process(delta: float) -> void:
	var alive: Array = []
	for p in _parts:
		p[2] = float(p[2]) + delta
		var t: float = float(p[2]) - float(p[4])
		if t < 0.0:
			alive.append(p)
			continue
		if t > float(p[3]):
			continue
		p[0] = p[0] + p[1] * delta
		p[1] = p[1] * (1.0 - clampf(3.5 * delta, 0.0, 1.0))
		alive.append(p)
	_parts = alive
	queue_redraw()
	if _parts.is_empty():
		set_process(false)


func _cell(pos: Vector2) -> Vector2:
	return (pos / TEXEL).floor() * TEXEL


func _draw() -> void:
	var s := Vector2(TEXEL, TEXEL)
	for p in _parts:
		var t: float = float(p[2]) - float(p[4])
		if t < 0.0:
			continue
		var k: float = t / float(p[3])
		var col: Color = p[6]
		if k > 0.65:
			col.a *= clampf((1.0 - k) / 0.35, 0.0, 1.0)
		var c: Vector2 = _cell(p[0])
		if bool(p[5]):
			## yıldız: ömrün ortasında kollar 2 texel, başta/sonda 1
			var arm: int = 2 if (k > 0.2 and k < 0.7) else 1
			draw_rect(Rect2(c, s), Color(1, 1, 1, col.a))
			for i in range(1, arm + 1):
				var o: float = TEXEL * i
				draw_rect(Rect2(c + Vector2(o, 0), s), col)
				draw_rect(Rect2(c - Vector2(o, 0), s), col)
				draw_rect(Rect2(c + Vector2(0, o), s), col)
				draw_rect(Rect2(c - Vector2(0, o), s), col)
		else:
			draw_rect(Rect2(c, s * (2.0 if k < 0.35 else 1.0)), col)
