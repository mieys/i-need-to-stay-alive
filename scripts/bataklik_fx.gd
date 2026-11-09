extends Node2D

## KARA BATAKLIK atmosfer efektleri (yeni harita, 2026-11-09; main.gd kurar, MapProfiles "bataklik_fx" bayrağı). Tamamen kozmetik + yerel:
## ağ gerekmez (gün saati zaten eşitli, konumlar haritanın sabit verisi scripts/bataklik_meta.gd).
##  - GECE IŞIKLARI: meşale alevleri, cadı kulübesi feneri, kazanlar -> bataklik_isik.gd noktaları (night_glow_catalog.gd ışığı takar).
##  - ATEŞ BÖCEKLERİ: göl kıyısı ve gölcüklerin üstünde sürüler. Her böcek 1 dünya pikseli (kamera 2x'te 2x2 ekran pikseli), parlarken artı
##    biçiminde 3 px'lik soluk hale; yolu zamana bağlı kapalı eğri (durum tutulmaz -> hiç bellek/ağ yok), yanıp sönme böcek başına ayrı
##    evrede. Yalnız karanlıkta görünür (Atmosphere.get_darkness), yalnız görüntüdeki sürüler çizilir; sürü başına kısık titrek ışık
##    (bataklik_bocek_isik.gd) geceleyin pikselleri karanlıktan çıkarır.

const MetaScript := preload("res://scripts/bataklik_meta.gd")
const LightScript := preload("res://scripts/bataklik_isik.gd")
const BugLightScript := preload("res://scripts/bataklik_bocek_isik.gd")

const LIGHT_PROFILES := {
	"mesale": {"c": Color(0.45, 1.0, 0.82), "r": 46.0},
	"kucuk_mesale": {"c": Color(0.45, 1.0, 0.82), "r": 30.0},
	"cadi_kulubesi": {"c": Color(0.42, 0.95, 0.9), "r": 58.0},
	"kazan_1": {"c": Color(0.55, 1.0, 0.45), "r": 34.0},
	"kazan_2": {"c": Color(0.55, 1.0, 0.45), "r": 40.0},
}
const BUGS_PER_SWARM := 7
const BUG_CORE := Color(0.93, 1.0, 0.55)
const BUG_HALO := Color(0.72, 0.95, 0.35, 0.55)
const DARK_MIN := 0.08 ## bu karanlığın altında (gündüz) hiç çizilmez
const REDRAW_INTERVAL := 1.0 / 30.0 ## böcekler 30 kare/sn yeter (her kare yeniden çizmek gereksiz)

var _swarms: Array = [] ## [Vector2 merkez, float yarıçap, int tohum]
var _atmosphere: Node = null
var _alpha: float = 0.0
var _t_accum: float = 0.0
var _visible_swarms: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	z_index = 4 ## ağaçların ve ön kopyaların (z 2-3) üstünde: havada uçuşurlar
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for l: Array in MetaScript.LIGHTS:
		var kind: String = l[0]
		var prof: Dictionary = LIGHT_PROFILES.get(kind, LIGHT_PROFILES["mesale"])
		var n: Node2D = LightScript.new()
		n.name = "Isik_" + kind
		n.glow_color = prof["c"]
		n.glow_radius = prof["r"]
		n.position = l[1]
		add_child(n)
	var i := 0
	for z: Array in MetaScript.FIREFLY_ZONES:
		var center: Vector2 = z[0]
		var r: float = z[1]
		_swarms.append([center, r, i * 7919 + 13])
		var g: Node2D = BugLightScript.new()
		g.name = "BocekIsigi_%d" % i
		g.glow_radius = clampf(r * 0.55, 26.0, 46.0)
		g.position = center
		add_child(g)
		i += 1


func _process(delta: float) -> void:
	if _atmosphere == null or not is_instance_valid(_atmosphere):
		var scene: Node = get_tree().current_scene
		_atmosphere = scene.get_node_or_null("Atmosphere") if scene != null else null
	var dark: float = float(_atmosphere.call("get_darkness")) if _atmosphere != null else 0.0
	var target: float = clampf((dark - DARK_MIN) / 0.35, 0.0, 1.0)
	_alpha = move_toward(_alpha, target, delta * 0.5)
	_t_accum += delta
	if _t_accum < REDRAW_INTERVAL:
		return
	_t_accum = 0.0
	var vis := PackedInt32Array()
	if _alpha > 0.01:
		var view: Rect2 = _view_rect().grow(48.0)
		for k in range(_swarms.size()):
			var s: Array = _swarms[k]
			var c: Vector2 = s[0]
			var r: float = s[1]
			if view.intersects(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)):
				vis.append(k)
	if vis.is_empty() and _visible_swarms.is_empty():
		return
	_visible_swarms = vis
	queue_redraw()


func _view_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2()
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var size: Vector2 = vp.get_visible_rect().size
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * size)


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var t: float = float(Time.get_ticks_msec()) * 0.001
	for k in _visible_swarms:
		var s: Array = _swarms[k]
		var c: Vector2 = s[0]
		var r: float = s[1]
		var seed: int = s[2]
		for b in range(BUGS_PER_SWARM):
			var h1: float = _h(seed + b * 3)
			var h2: float = _h(seed + b * 3 + 1)
			var h3: float = _h(seed + b * 3 + 2)
			## kapalı eğri: iki farklı frekanslı salınım + yavaş dönen merkez kayması (böcekler aynı yolda gidip gelmesin)
			var a1: float = t * (0.21 + h1 * 0.23) + h2 * TAU
			var a2: float = t * (0.17 + h3 * 0.19) + h1 * TAU
			var p := c + Vector2(cos(a1) * r * (0.35 + 0.6 * h2) + sin(a2 * 2.3) * 9.0,
				sin(a2) * r * (0.25 + 0.45 * h3) + cos(a1 * 1.7) * 6.0 - 10.0)
			p = p.floor()
			## yanıp sönme: döngünün ~%45'inde yanık, tepe anında hale
			var ph: float = fposmod(t * (0.35 + h3 * 0.3) + h1 * 5.0, 1.0)
			var on: float = clampf(sin(ph * TAU) * 1.6 - 0.25, 0.0, 1.0)
			if on <= 0.0:
				continue
			var a: float = on * _alpha
			if on > 0.75:
				var hc := Color(BUG_HALO, BUG_HALO.a * a)
				draw_rect(Rect2(p + Vector2(-1, 0), Vector2.ONE), hc)
				draw_rect(Rect2(p + Vector2(1, 0), Vector2.ONE), hc)
				draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), hc)
				draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), hc)
			draw_rect(Rect2(p, Vector2.ONE), Color(BUG_CORE, a))


static func _h(n: int) -> float:
	var x: int = (n * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10007) / 10007.0
