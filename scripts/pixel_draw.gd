extends RefCounted

## Pixel-art efektlerinin ORTAK çizim yardımcıları (Vampir FX, Melek dalgası, Talon, Korsan, Matthew hepsi bunu kullanır).
##
## Kural (bkz. hafıza: "Pixel-style FX"): efektler karakter dokusunun piksel boyutunda (1 sanat pikseli = TEXEL
## dünya birimi) KARELERDEN oluşur; konumlar bu ızgaraya oturtulur, bulanık/yumuşak çizgi-daire-parçacık yok.
## Tüm fonksiyonlar bir CanvasItem alır ve o öğenin _draw() (ya da draw sinyali) sırasında çağrılmalıdır;
## konumlar o CanvasItem'in YEREL uzayındadır.

## DEFAULT_ANIM_SCALE (1.27575) x EntityScale.SIZE (0.95) - karakter kareleri 64x64 sanat pikseli.
const TEXEL := 1.212


static func snap(v: Vector2) -> Vector2:
	return (v / TEXEL).round() * TEXEL


## n x n sanat pikselinlik bir kare (merkezi pos).
static func px(ci: CanvasItem, pos: Vector2, n: int, col: Color) -> void:
	var s: float = float(n) * TEXEL
	ci.draw_rect(Rect2(snap(pos) - Vector2(s, s) * 0.5, Vector2(s, s)), col)


## w x h sanat pikselinlik dikdörtgen (merkezi pos).
static func rect(ci: CanvasItem, pos: Vector2, w: int, h: int, col: Color) -> void:
	var size := Vector2(float(w), float(h)) * TEXEL
	ci.draw_rect(Rect2(snap(pos) - size * 0.5, size), col)


## Pikselden oluşan düz çizgi (n = kalınlık, sanat pikseli).
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, n: int = 1) -> void:
	var step: float = TEXEL * float(maxi(n, 1))
	var steps: int = maxi(1, int(a.distance_to(b) / step))
	for i in range(steps + 1):
		px(ci, a.lerp(b, float(i) / float(steps)), n, col)


## Pikselden halka. dash_on/dash_off > 0 ise kesik çizgi (phase ile kayar - "yürüyen karıncalar" efekti).
static func ring(ci: CanvasItem, center: Vector2, radius: float, col: Color, n: int = 1, dash_on: int = 0, dash_off: int = 0, phase: float = 0.0, from_angle: float = 0.0, sweep: float = TAU) -> void:
	var step: float = TEXEL * float(maxi(n, 1))
	var count: int = maxi(8, int(absf(sweep) * radius / step))
	var period: int = dash_on + dash_off
	for i in range(count):
		if period > 0 and (int(float(i) + phase) % period) >= dash_on:
			continue
		var a: float = from_angle + sweep * float(i) / float(count)
		px(ci, center + Vector2(cos(a), sin(a)) * radius, n, col)


## Dolu daire (satır satır). Kenarı pixel-art gibi basamaklı.
static func disc(ci: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	var c: Vector2 = snap(center)
	var rt: int = int(radius / TEXEL)
	for iy in range(-rt, rt + 1):
		var hw: float = sqrt(maxf(0.0, float(rt * rt) - float(iy * iy)))
		if hw < 0.5:
			continue
		ci.draw_rect(Rect2(c.x - hw * TEXEL, c.y + float(iy) * TEXEL - TEXEL * 0.5, hw * 2.0 * TEXEL, TEXEL), col)


## Dolu daire, ama dama (checker) desenli - "yarı saydam ışık" hissini gerçek alfa yerine dither ile verir.
## cell: dama karesinin kenarı (sanat pikseli) - büyük alanlarda 2 kullanmak çizim sayısını 4'e böler.
static func disc_dither(ci: CanvasItem, center: Vector2, radius: float, col: Color, parity: int = 0, cell: int = 1) -> void:
	var c: Vector2 = snap(center)
	var cs: float = TEXEL * float(maxi(cell, 1))
	var rc: int = int(radius / cs)
	for iy in range(-rc, rc + 1):
		var hw: int = int(sqrt(maxf(0.0, float(rc * rc) - float(iy * iy))))
		for ix in range(-hw, hw + 1):
			if ((ix + iy + parity) & 1) == 0:
				continue
			ci.draw_rect(Rect2(c.x + float(ix) * cs - cs * 0.5, c.y + float(iy) * cs - cs * 0.5, cs, cs), col)


## ASCII pixel-art: rows'un her karakteri palette'teki bir renk ('.' ya da palette'te olmayan = boş). center =
## sprite'ın ortası. scale = sanat pikselinin katı (1.0 = TEXEL).
static func art(ci: CanvasItem, center: Vector2, rows: Array, palette: Dictionary, scale: float = 1.0, flip_x: bool = false, flip_y: bool = false) -> void:
	var h: int = rows.size()
	if h == 0:
		return
	var w: int = str(rows[0]).length()
	var cell: float = TEXEL * scale
	var origin: Vector2 = snap(center) - Vector2(float(w), float(h)) * cell * 0.5
	for y in range(h):
		var row: String = str(rows[y])
		for x in range(w):
			var ch: String = row.substr(x, 1)
			if not palette.has(ch):
				continue
			var xx: int = (w - 1 - x) if flip_x else x
			var yy: int = (h - 1 - y) if flip_y else y
			ci.draw_rect(Rect2(origin + Vector2(float(xx), float(yy)) * cell, Vector2(cell, cell)), palette[ch])


## Ateş renk rampası: t 0 (en sıcak, sarı-beyaz) -> 1 (soğuk, koyu kırmızı).
static func fire_color(t: float) -> Color:
	var stops: Array[Color] = [
		Color(1.0, 0.96, 0.7),
		Color(1.0, 0.78, 0.22),
		Color(1.0, 0.5, 0.1),
		Color(0.9, 0.2, 0.06),
		Color(0.45, 0.08, 0.06),
	]
	var f: float = clampf(t, 0.0, 1.0) * float(stops.size() - 1)
	var i: int = mini(int(f), stops.size() - 2)
	return stops[i].lerp(stops[i + 1], f - float(i))


## Deterministik (id ile) 0..1 sahte rastgele - yeniden çizimde titremesin diye.
static func hash01(seed_value: int) -> float:
	var x: int = seed_value * 374761393 + 668265263
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(x & 0xFFFF) / 65535.0


## Dünya konumunda kısa ömürlü pixel parçacık patlaması doğurur (vampir_fx.gd'nin "puff"ının genel hali).
## palette: "fire" | "smoke" | "spark" | "dust". Ağ senkronu için network_manager.gd "pixel_burst" dalı da bunu çağırır.
static func spawn_burst(host: Node, world_pos: Vector2, palette: String = "fire", count: int = 18, speed: float = 160.0, life: float = 0.5) -> Node2D:
	if host == null or not is_instance_valid(host):
		return null
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/fx_pixel_burst.gd"))
	fx.set("palette", palette)
	fx.set("count", count)
	fx.set("speed", speed)
	fx.set("life", life)
	host.add_child(fx)
	fx.global_position = world_pos
	return fx
