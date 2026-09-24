extends Node2D

## Mermi arkasında bırakılan PARÇACIK izi (kullanıcı istekleri 2026-09-24: "füze ateşlendiğinde arkasında partiküller
## bıraksın füze olduğu hissedilsin" + "ateş asası, buz asası ateşlendiğinde attığı atışın arkasında kendine uygun
## partiküller olsun" - "pixel tarzda yapıp spritesheete dönüştür performans düşüşü olmaması için").
##
## Görseller tools/gen_projectile_trail_fx.py'nin pişirdiği sayfalar (her stil: 8 karelik parçacık ömrü x 2 varyant,
## kare 12x12 sanat pikseli). PERF: parçacık başına Node YOK - tek bu Node tüm canlı parçacıkları _draw'da sayfadan
## draw_texture_rect_region ile çizer. Mermiyle birlikte silinmesin diye sahnenin köküne (current_scene) eklenir: mermi
## yaşarken onun konumuna parçacık bırakır, mermi yok olunca (ya da çarpıp patlama animasyonuna geçince) yeni parçacık
## bırakmayı keser, kalanlar sönünce kendini siler.
##
## Kullanım: `ParticleTrail.attach(mermi, "missile" | "fire" | "ice")` - projectile.gd (PARTICLE_TRAILS, sahne adına göre)
## ve firework_projectile.gd çağırır. Diğer oyunculardaki kozmetik mermiler AYNI sahne/script olduğu için (bkz.
## network_manager.gd broadcast_projectile) iz orada da aynen görünür.

const TEXEL := 1.212 ## PixelDraw.TEXEL - 1 sanat pikseli
const CELL := 12
const FRAMES := 8
const VARIANTS := 2

## stil -> ayarlar. interval: bırakma aralığı (sn), life: parçacık ömrü (sn), drift: dünya birimi/sn kayma (yukarı eksi),
## jitter: bırakılış konumuna rastgele sapma (birim), back: merminin gerisine (uçuş yönünün tersine) kaydırma (birim).
const STYLES := {
	"missile": {"sheet": preload("res://assets/fx/projectile_trails/missile_sheet.png"), "interval": 0.035, "life": 0.5, "drift": Vector2(0.0, -16.0), "jitter": 2.0, "back": 6.0},
	"fire": {"sheet": preload("res://assets/fx/projectile_trails/fire_sheet.png"), "interval": 0.03, "life": 0.36, "drift": Vector2(0.0, -26.0), "jitter": 3.0, "back": 4.0},
	"ice": {"sheet": preload("res://assets/fx/projectile_trails/ice_sheet.png"), "interval": 0.04, "life": 0.45, "drift": Vector2(0.0, 10.0), "jitter": 4.0, "back": 4.0},
}

var source: Node2D = null
var style: String = "missile"
var _cfg: Dictionary = {}
var _puffs: Array = [] ## [pos, age, variant]
var _acc: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _has_last: bool = false
var _variant_toggle: int = 0


## Mermiye iz bağlar. İz, merminin HEMEN ARKASINDA (ağaç sırasında önünde -> altında) çizilir.
static func attach(projectile: Node2D, trail_style: String) -> Node2D:
	if projectile == null or not STYLES.has(trail_style):
		return null
	var tree: SceneTree = projectile.get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var trail := Node2D.new()
	trail.set_script(load("res://scripts/fx_particle_trail.gd"))
	trail.set("source", projectile)
	trail.set("style", trail_style)
	tree.current_scene.add_child.call_deferred(trail)
	return trail


func _ready() -> void:
	_cfg = STYLES.get(style, STYLES["missile"])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = Vector2.ZERO
	## Mermiden önce çizilsin (ağaç sırası) - parçacıklar mermi sprite'ının altında kalır.
	if source and is_instance_valid(source) and source.get_parent() == get_parent():
		get_parent().move_child(self, source.get_index())


func _source_emitting() -> bool:
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		return false
	if source.get("_impacted") == true or source.get("_done") == true:
		return false
	return true


func _process(delta: float) -> void:
	var life: float = float(_cfg["life"])
	for p in _puffs:
		p[1] += delta
		p[0] += (_cfg["drift"] as Vector2) * delta
	_puffs = _puffs.filter(func(p): return float(p[1]) < life)
	if _source_emitting():
		var pos: Vector2 = source.global_position
		var back: Vector2 = Vector2.ZERO
		if _has_last and pos.distance_to(_last_pos) > 0.1:
			back = (_last_pos - pos).normalized() * float(_cfg["back"])
		_acc += delta
		var interval: float = float(_cfg["interval"])
		## Aralıktaki her bırakma, son konumla şimdiki arasında eşit dağılır (hızlı mermide boşluklu olmasın).
		var n: int = int(_acc / interval)
		if n > 0:
			_acc -= float(n) * interval
			for i in range(n):
				var f: float = float(i + 1) / float(n)
				var at: Vector2 = (_last_pos.lerp(pos, f) if _has_last else pos) + back
				var j: float = float(_cfg["jitter"])
				at += Vector2(randf_range(-j, j), randf_range(-j, j))
				_variant_toggle = (_variant_toggle + 1) % VARIANTS
				_puffs.append([at, float(n - 1 - i) * interval, _variant_toggle])
		_last_pos = pos
		_has_last = true
	elif _puffs.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var sheet: Texture2D = _cfg["sheet"]
	var life: float = float(_cfg["life"])
	var size := Vector2(CELL, CELL) * TEXEL
	for p in _puffs:
		var frame: int = mini(FRAMES - 1, int(float(p[1]) / life * float(FRAMES)))
		var src := Rect2(frame * CELL, int(p[2]) * CELL, CELL, CELL)
		## Sanat pikseli ızgarasına oturt (pixel_draw.gd snap ile aynı) - parçacıklar kayarken titremesin.
		var c: Vector2 = ((p[0] as Vector2) / TEXEL).round() * TEXEL
		draw_texture_rect_region(sheet, Rect2(c - size * 0.5, size), src)
