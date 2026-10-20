extends Node2D

## Görev ağacının kristali atış yaparken PARLAR (2026-10-19, kullanıcı: "ağacın kristalinin parlaması gerek o atışı yaptığında"; madde 317).
## İki katman, ikisi de toplamsal (ADD) karışım:
##  - TAŞIN KENDİSİ: ağaç sayfasındaki kristal pikselleri (mavi, CRYSTAL_REGION içinde) kare kare beyaz maskeye çevrilir (bir kez, statik önbellek) ve
##    ağacın AnimatedSprite2D'sine çocuk Sprite2D olarak aynı karede çizilir -> taş tam kendi biçimiyle aydınlanır.
##  - HALE + YILDIZ: bu düğüm (kristalin ortasında, dünya pikseli) basamaklı elips hale + dikey/yatay ışın çizer.
## pulse(): kristal mermisi (kısa), charge(): sihirli atış şarjı (yükselen parıltı, sonunda güçlü pulse). Her istemcide yerel (atışlar zaten yerel doğar).

const CRYSTAL_REGION := Rect2i(55, 0, 50, 90) ## kare içinde kristali arama bölgesi (sanat px) - taş x 72-94, y 13-71
const IDLE := 0.08 ## atış yokken taşın hafif nefesi
const MASK_TINT := Color(0.55, 0.9, 1.0)
const HALO := Color(0.45, 0.85, 1.0)
const RAY := Color(0.85, 0.98, 1.0)
const WARM_SHEET := preload("res://assets/fx/mission_tree/tree_active.png") ## mission_tree.gd ACTIVE_SHEET ile aynı
const WARM_FRAMES := 6
const WARM_FRAME_SIZE := 160

static var _mask_cache: Dictionary = {} ## sayfa yolu -> Array[Texture2D]
static var _partial: Array = [] ## ısınmada yarım kalan sayfanın kareleri
static var _partial_key: String = ""

var _anim: AnimatedSprite2D = null
var _mask: Sprite2D = null
var _masks: Array = []
var _pulse: float = 0.0
var _pulse_decay: float = 4.0
var _charge_t: float = -1.0
var _charge_len: float = 0.0
var _time: float = 0.0
var intensity: float = 0.0 ## son karedeki toplam parıltı (testler okur)


func setup(anim: AnimatedSprite2D, sheet: Texture2D, frames: int, frame_size: int) -> void:
	_anim = anim
	_masks = mask_frames(sheet, frames, frame_size)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_mask = Sprite2D.new()
	_mask.centered = anim.centered
	_mask.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mask.material = add
	_mask.visible = false
	anim.add_child(_mask)


## Kristal piksellerinin beyaz maskesi, kare başına bir doku. Mavi + kırmızısı düşük + bölge içinde = taş (yapraklar nane yeşili, r yüksek).
## Tamamı ~7 ms (GDScript piksel döngüsü) -> fx_warmup.gd arka plan ısınması warm_step() ile kare başına BİR kare çıkarır; görev başında önbellekten gelir.
static func mask_frames(sheet: Texture2D, frames: int, frame_size: int) -> Array:
	var key: String = sheet.resource_path
	while not _mask_cache.has(key):
		_mask_next(sheet, frames, frame_size)
	return _mask_cache[key]


## Isınma adımı (fx_warmup.gd _step): görev ağacı sayfasının bir sonraki maske karesi. Hepsi hazırsa true.
static func warm_step() -> bool:
	if _mask_cache.has(WARM_SHEET.resource_path):
		return true
	_mask_next(WARM_SHEET, WARM_FRAMES, WARM_FRAME_SIZE)
	return _mask_cache.has(WARM_SHEET.resource_path)


static func _mask_next(sheet: Texture2D, frames: int, frame_size: int) -> void:
	var key: String = sheet.resource_path
	if _partial_key != key:
		_partial_key = key
		_partial = []
	var img: Image = sheet.get_image()
	if img == null:
		_mask_cache[key] = []
		return
	if img.is_compressed():
		img.decompress()
	var f: int = _partial.size()
	var m := Image.create(frame_size, frame_size, false, Image.FORMAT_RGBA8)
	for y in range(CRYSTAL_REGION.position.y, CRYSTAL_REGION.end.y):
		for x in range(CRYSTAL_REGION.position.x, CRYSTAL_REGION.end.x):
			var c: Color = img.get_pixel(f * frame_size + x, y)
			if c.a > 0.78 and c.b8 > 120 and c.r8 < 110 and c.b8 > c.r8 + 50:
				m.set_pixel(x, y, Color(1, 1, 1, 1))
	_partial.append(ImageTexture.create_from_image(m))
	if _partial.size() >= frames:
		_mask_cache[key] = _partial
		_partial = []
		_partial_key = ""


func pulse(strength: float, decay_time: float) -> void:
	if strength >= _pulse:
		_pulse_decay = strength / maxf(decay_time, 0.01)
	_pulse = maxf(_pulse, strength)


## Sihirli atış şarjı: length sn boyunca yükselir, bitince güçlü pulse.
func charge(length: float) -> void:
	_charge_t = 0.0
	_charge_len = maxf(length, 0.01)


func _process(delta: float) -> void:
	_time += delta
	_pulse = maxf(0.0, _pulse - _pulse_decay * delta)
	var ch: float = 0.0
	if _charge_t >= 0.0:
		_charge_t += delta
		ch = clampf(_charge_t / _charge_len, 0.0, 1.0)
		ch = ch * ch * 0.85
		if _charge_t >= _charge_len:
			_charge_t = -1.0
			pulse(1.0, 0.45)
	var idle: float = IDLE * (0.6 + 0.4 * sin(_time * 2.6))
	intensity = maxf(maxf(_pulse, ch), idle)
	if _mask != null:
		var active: bool = _anim != null and _anim.animation == &"active" and not _masks.is_empty()
		_mask.visible = active
		if active:
			_mask.texture = _masks[_anim.frame % _masks.size()]
			_mask.modulate = Color(MASK_TINT.r, MASK_TINT.g, MASK_TINT.b, clampf(0.25 + 0.75 * intensity, 0.0, 1.0) * minf(1.0, intensity * 4.0))
	queue_redraw()


func _ell(rx: float, ry: float, col: Color) -> void:
	var ri: int = int(ceil(ry))
	for y in range(-ri, ri + 1):
		var w: int = int(roundf(rx * sqrt(maxf(1.0 - float(y * y) / (ry * ry), 0.0))))
		if w <= 0:
			continue
		draw_rect(Rect2(-w, y, w * 2 + 1, 1), col)


func _draw() -> void:
	var i: float = intensity
	if i < 0.12:
		return
	_ell(9.0 + 9.0 * i, 24.0 + 12.0 * i, Color(HALO.r, HALO.g, HALO.b, 0.10 * i))
	_ell(7.0 + 5.0 * i, 20.0 + 6.0 * i, Color(HALO.r, HALO.g, HALO.b, 0.14 * i))
	if i < 0.3:
		return
	## yıldız ışınları: dikey uzun, yatay kısa; uçlara doğru incelir
	var v: int = int(10.0 + 22.0 * i)
	var h: int = int(6.0 + 12.0 * i)
	var a: float = clampf(i, 0.0, 1.0)
	draw_rect(Rect2(-1, -v, 2, v * 2), Color(RAY.r, RAY.g, RAY.b, 0.35 * a))
	draw_rect(Rect2(0, -v - 3, 1, 3), Color(RAY.r, RAY.g, RAY.b, 0.2 * a))
	draw_rect(Rect2(0, v, 1, 3), Color(RAY.r, RAY.g, RAY.b, 0.2 * a))
	draw_rect(Rect2(-h, -1, h * 2, 2), Color(RAY.r, RAY.g, RAY.b, 0.3 * a))
	draw_rect(Rect2(-3, -3, 6, 6), Color(RAY.r, RAY.g, RAY.b, 0.45 * a))
	## şarjda taşın çevresinde dönen 4 kıvılcım
	if _charge_t >= 0.0:
		for k in range(4):
			var ang: float = _time * 5.0 + TAU * float(k) / 4.0
			var p: Vector2 = Vector2(cos(ang) * 12.0, sin(ang) * 26.0).round()
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(RAY.r, RAY.g, RAY.b, 0.8))
