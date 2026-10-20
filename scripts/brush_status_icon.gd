extends Sprite2D

## SAKLANMA GÖSTERGESİ (madde 275, 2026-10-19; kullanıcı: "insanlar çalıya girdiğinde görünmediğini gösteren bir gösterge ekle can barının üstüne").
## Can barının (overhead_bar.gd) hemen üstünde küçük piksel göz: 1 = SAKLI (üstü çizili yeşil göz: hiçbir yaratık hedeflemiyor), 2 = GÖRÜLDÜ (kırmızı açık göz:
## çalıda ama giriş anında seni gören / yanına çarpan yaratık var, o yaratıklar kovalamaya devam eder; bkz. hide_brush_manager.gd). 0 = yok.
## Durum her peer'e zaten gidiyor (NetworkManager.sync_brush_state -> player.gd / remote_player.gd set_brush_state -> overhead_bar.set_brush_state),
## ek RPC yok: oyuncu kendi göstergesini de, arkadaşlarınınkini de görür.
## Sanat: 1 sanat pikseli = 1 dünya pikseli (harita + can barı çerçevesiyle aynı yoğunluk), siyah kontür + 1 px gölge (can barının dili); doku desenden kodda kurulur
## (load() yok -> ilk basışta takılma/ısınma listesi gerekmez).

const TEXEL := 1.0 ## 1 sanat pikseli = bu kadar dünya pikseli (ebeveyn ölçeğinden bağımsız)
const GAP := 3.0   ## can barının üstüyle simgenin altı arası (çubuğun yerel birimi)
const POP_TIME := 0.22
const HIDE_TIME := 0.12

## o kontür, w göz akı, i iris, k gözbebeği, h parıltı, s çizik (kontür rengi), b çiziğin açık kenarı
const EYE := [
	".............",
	"....ooooo....",
	"..oowwwwwoo..",
	".owwwhiiwwwo.",
	"owwwiikiiwwwo",
	".owwwiiiwwwo.",
	"..oowwwwwoo..",
	"....ooooo....",
	".............",
]
const PALETTES := {
	1: {"o": Color8(18, 22, 16), "w": Color8(250, 238, 214), "i": Color8(92, 168, 76), "k": Color8(24, 56, 30), "h": Color8(255, 255, 240),
		"s": Color8(18, 22, 16), "b": Color8(250, 238, 214)},
	2: {"o": Color8(18, 22, 16), "w": Color8(250, 238, 214), "i": Color8(226, 78, 46), "k": Color8(64, 14, 10), "h": Color8(255, 226, 200)},
}

static var _tex_cache: Dictionary = {}

var state: int = 0
var _bar_top: float = -68.0
var _base_scale: float = 1.0
var _tween: Tween = null


## Durumun dokusu (saf; testler çağırır). Saklı = göz + 45 derece çizik (2 px koyu + iki yanında 1 px açık kenar), sonra 1 px gölge.
static func build_image(st: int) -> Image:
	var pal: Dictionary = PALETTES[st]
	var h: int = EYE.size()
	var w: int = (EYE[0] as String).length()
	var grid: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append((EYE[y] as String)[x])
		grid.append(row)
	if st == 1:
		## 2026-10-19 v3: göz akı krem (yeşilimsi akla çizik "çizgili yaprak" gibi okunuyordu), çiziğin İKİ yanında da açık kenar (gözün dışında da)
		for y in range(h):
			for bx in [8 - y, 11 - y]:
				if bx >= 0 and bx < w:
					grid[y][bx] = "b"
			for x in [9 - y, 10 - y]:
				if x >= 0 and x < w:
					grid[y][x] = "s"
	var img := Image.create(w + 1, h + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			if grid[y][x] != "." and img.get_pixel(x + 1, y + 1).a == 0.0:
				img.set_pixel(x + 1, y + 1, Color(0, 0, 0, 0.35))
	for y in range(h):
		for x in range(w):
			var k: String = grid[y][x]
			if k != ".":
				img.set_pixel(x, y, pal[k])
	return img


static func texture_for(st: int) -> Texture2D:
	if not _tex_cache.has(st):
		_tex_cache[st] = ImageTexture.create_from_image(build_image(st))
	return _tex_cache[st]


func _ready() -> void:
	name = "BrushStatusIcon"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	visible = false
	## pivot alt-ortada (tam piksel): yaylanma alttan büyür, tek sayılı genişlik yarım piksele düşmez
	centered = false
	offset = Vector2(-floorf(float((EYE[0] as String).length() + 1) * 0.5), -float(EYE.size() + 1))


## overhead_bar.gd çağırır: st = HideBrush.STATE_*, bar_top = can barının üst kenarı (çubuğun yerel y'si).
func show_state(st: int, bar_top: float) -> void:
	_bar_top = bar_top
	_place()
	if st == state:
		return
	var was: int = state
	state = st
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if st == 0:
		if not visible:
			return
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(self, "scale", Vector2.ONE * _base_scale * 0.4, HIDE_TIME)
		_tween.tween_property(self, "modulate:a", 0.0, HIDE_TIME)
		_tween.chain().tween_callback(func() -> void: visible = false)
		return
	texture = texture_for(st)
	_place()
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE * _base_scale * (0.7 if was != 0 else 0.35)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * _base_scale, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_bar_top(bar_top: float) -> void:
	_bar_top = bar_top
	_place()


## Ölçek: 1 sanat pikseli = TEXEL dünya pikseli (karakter kökü 0,5 ölçekli; kuklanın ölçeği farklı olabilir). Konum: dokunun altı (gölge satırı) can barının GAP üstünde, ortada.
func _place() -> void:
	var ps: float = absf(get_parent().global_scale.y) if get_parent() is Node2D else 1.0
	_base_scale = TEXEL / (ps if ps > 0.01 else 1.0)
	position = Vector2(0.0, _bar_top - GAP)
	if _tween == null or not _tween.is_valid():
		scale = Vector2.ONE * _base_scale
