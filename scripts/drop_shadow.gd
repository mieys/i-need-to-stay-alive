extends Node2D

## Yerdeki küçük objelerin gölgesi (sandık, altın, yemek, mıknatıs - exp orbunda YOK: kullanıcı 2026-10-02 "exp orblarının
## gölgesini kaldır sevmedim") - harita gölgeleriyle AYNI "B - Tepe gölgesi"
## dili (bkz. map_shadows.gd, kullanıcı seçimi 2026-10-02): objenin görünen alt kenarının hemen altında düz piksel bantlı ince
## hilal, aynı serin ton, çarpma karışımı. Sahne kökü zıplayan objelerde (altın/yemek/mıknatıs: position.y += bob) gölge
## yerde sabit kalır ve obje yükseldikçe hafifçe daralır - yükseklik okunur. Her istemcide aynı sahneden oluştuğu için ağ
## senkronu gerekmez.
##
## Kullanım (objenin _ready'sinde): DropShadow.attach(self, $Sprite)  - ölçü sprite'ın ilk karesinin dolu piksellerinden
## alınır (doku başına önbellek), sprite dokusu sonradan atanıyorsa ilk geçerli karede ölçülür.

const MapShadows := preload("res://scripts/map_shadows.gd")
const INNER := 0.30
const RIM := 0.21
## Kökü zıplayan objelerin bob genliği (gold_drop/food_drop/magnet_drop: sin(t*4)*3) - en alçak nokta = yer.
const ROOT_BOB_AMP := 3.0

static var _mat: CanvasItemMaterial = null
static var _used_cache: Dictionary = {} ## doku RID + bölge -> dolu dikdörtgen (piksel)

var _host: Node2D = null
var _sprite: Node2D = null
var _manual: Rect2 = Rect2()
var _root_bob: bool = false
var _depth: int = 2
var _width: int = 0
var _base_y: float = 0.0
var _measured: bool = false
var _immediate: bool = false


## immediate: sprite zaten dinlenme konumunda ve dokusu atanmış (sandık - sonra sadece sprite zıplıyor) -> hemen ölç.
static func attach(host: Node2D, sprite: Node2D, root_bob: bool = false, depth: int = 2, manual_rect: Rect2 = Rect2(),
		immediate: bool = false) -> Node2D:
	var s: Node2D = (load("res://scripts/drop_shadow.gd") as GDScript).new()
	s.name = "DropShadow"
	s.set("_host", host)
	s.set("_sprite", sprite)
	s.set("_root_bob", root_bob)
	s.set("_depth", depth)
	s.set("_manual", manual_rect)
	s.set("_immediate", immediate)
	host.add_child(s)
	host.move_child(s, 0) ## objenin altında çizilsin
	return s


func _ready() -> void:
	if _mat == null:
		_mat = CanvasItemMaterial.new()
		_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = _mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	show_behind_parent = true ## mıknatıs gibi kendini _draw ile çizen objelerin de altında kalsın
	## Ölçü ilk karede (_process): objenin kendi kurulumu (exp orbu kademe ölçeği, yemek dokusu) önce bitsin.
	if _immediate:
		_try_measure()


func _process(_delta: float) -> void:
	if not _measured:
		_try_measure()
		return
	if _root_bob and _host != null:
		## kök bob kadar yukarı/aşağı gidiyor: gölge yerde (en alçak noktada) kalsın
		var bob: float = float(_host.get("_last_bob_offset"))
		position.y = _base_y + ROOT_BOB_AMP - bob
		var lift: float = clampf((ROOT_BOB_AMP - bob) / (ROOT_BOB_AMP * 2.0), 0.0, 1.0)
		scale.x = 1.0 - 0.18 * lift
	else:
		set_process(false)


func _try_measure() -> void:
	var r: Rect2 = _manual
	if r.size == Vector2.ZERO:
		## exp orbu sprite'ı nabız gibi büyüyüp küçülüyor - ölçek olarak objenin taban ölçeği (_base_scale) alınır
		var base: Variant = _host.get("_base_scale") if _host != null else null
		r = _visible_rect(_sprite, Vector2.ONE * float(base) if base != null and float(base) > 0.0 else Vector2.ZERO)
	if r.size == Vector2.ZERO:
		return
	_measured = true
	## Güneş: gölge sola UZAR (taşınmaz, bkz. map_shadows.gd SUN_SHIFT_X) - sağ kenar objenin dibinde kalır.
	_width = maxi(3, int(round(r.size.x * 0.9))) + int(absf(MapShadows.SUN_SHIFT_X))
	_base_y = r.end.y
	position = Vector2(round(r.get_center().x + MapShadows.SUN_SHIFT_X * 0.5), _base_y)
	queue_redraw()


## Sprite'ın görünen (dolu) dikdörtgeni, ebeveyn (obje kökü) koordinatında. Bulunamazsa boş.
static func _visible_rect(spr: Node2D, scale_override: Vector2 = Vector2.ZERO) -> Rect2:
	if spr == null or not is_instance_valid(spr):
		return Rect2()
	var tex: Texture2D = null
	var region := Rect2i()
	var offset := Vector2.ZERO
	var centered := true
	if spr is AnimatedSprite2D:
		var a: AnimatedSprite2D = spr
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return Rect2()
		tex = a.sprite_frames.get_frame_texture(a.animation, 0)
		offset = a.offset
		centered = a.centered
	elif spr is Sprite2D:
		var s: Sprite2D = spr
		tex = s.texture
		offset = s.offset
		centered = s.centered
		if tex != null and (s.hframes > 1 or s.vframes > 1):
			var fw: int = tex.get_width() / maxi(1, s.hframes)
			var fh: int = tex.get_height() / maxi(1, s.vframes)
			region = Rect2i(0, 0, fw, fh)
		elif s.region_enabled:
			region = Rect2i(s.region_rect)
	if tex == null:
		return Rect2()
	if region.size == Vector2i.ZERO:
		region = Rect2i(0, 0, tex.get_width(), tex.get_height())
	var key: String = "%d:%s" % [tex.get_rid().get_id(), str(region)]
	var used: Rect2i
	if _used_cache.has(key):
		used = _used_cache[key]
	else:
		var img: Image = tex.get_image()
		if img == null:
			return Rect2()
		if img.is_compressed():
			img.decompress()
		used = img.get_region(region).get_used_rect()
		_used_cache[key] = used
	if used.size == Vector2i.ZERO:
		return Rect2()
	var origin: Vector2 = offset - (Vector2(region.size) * 0.5 if centered else Vector2.ZERO)
	var local := Rect2(origin + Vector2(used.position), Vector2(used.size))
	var sc: Vector2 = scale_override if scale_override != Vector2.ZERO else spr.scale
	return Rect2(spr.position + local.position * sc, local.size * sc)


static func _shade(a: float) -> Color:
	return Color(1.0, 1.0, 1.0).lerp(MapShadows.TINT, a)


## Hilal: d satır; son satır ve uç pikseller açık ton, iç koyu; son satır her yandan 1 piksel kısa (yuvarlak uç).
func _draw() -> void:
	if not _measured:
		return
	var half: float = float(_width) * 0.5
	for k in range(_depth):
		var last: bool = k == _depth - 1
		var x0: float = -half + (1.0 if last and _depth > 1 else 0.0)
		var x1: float = half - (1.0 if last and _depth > 1 else 0.0)
		if last:
			draw_rect(Rect2(x0, k, x1 - x0, 1.0), _shade(RIM))
		else:
			draw_rect(Rect2(x0, k, 1.0, 1.0), _shade(RIM))
			draw_rect(Rect2(x1 - 1.0, k, 1.0, 1.0), _shade(RIM))
			draw_rect(Rect2(x0 + 1.0, k, x1 - x0 - 2.0, 1.0), _shade(INNER))
