extends Sprite2D

## SAKLANMA ÇALILIĞI arama göstergesi (madde 283, 2026-10-19; kullanıcı: "kovalayan yaratıkların kafası karışacak, üstlerinde soru işareti çıkacak ve etrafı arayıp onu
## bulmaya çalışacaklar; halkayı geçerse onu görüp herkesin saldırmasını sağlayabilir").
##  - KIND_SEARCH "?": arayan yaratığın başında, aranırken sürer (enemy.gd _spawn_brush_search_fx / _remove_brush_search_fx); hafif zıplama + "etrafa bakınma" eğilmesi.
##  - KIND_ALERT "!": halkada gören (ve alarmla saldırıya geçen) yaratığın başında kısa yaylanma, ~1 sn sonra söner.
## Karar host'ta (hide_brush_manager.gd), istemcilere NetworkManager.broadcast_enemy_vfx "brush_search_start/stop" / "brush_alert".
## Sanat: 1 sanat pikseli = TEXEL dünya pikseli (ebeveyn ölçeğinden bağımsız), koyu kontür + 1 px gölge (can barı/göz simgesiyle aynı dil, madde 275); doku desenden kodda
## kurulur (load() yok -> ısınma listesi gerekmez).

const TEXEL := 1.0
const HEAD_RATIO := 0.4 ## enemy.get_overhead_bar_offset() oranı (başın hemen üstü; 0,62 kafanın ~45 px yukarısında kalıyordu)
const KIND_SEARCH := 0
const KIND_ALERT := 1
const ALERT_LIFE := 1.0

## o kontür, Y dolgu, H parıltı
const GLYPHS := {
	KIND_SEARCH: [
		"..oooooo..",
		".oHHYYYYo.",
		"oHYooooYYo",
		"oYYo..oYYo",
		".oo..oYYYo",
		"....oYYYo.",
		"...oYYYo..",
		"...oYYo...",
		"...oooo...",
		"...oHYo...",
		"...oYYo...",
		"...oooo...",
	],
	KIND_ALERT: [
		"oooo",
		"oHYo",
		"oYYo",
		"oYYo",
		"oYYo",
		"oYYo",
		"oooo",
		"....",
		"oooo",
		"oHYo",
		"oooo",
	],
}
const PALETTES := {
	KIND_SEARCH: {"o": Color8(40, 26, 16), "Y": Color8(255, 222, 112), "H": Color8(255, 248, 206)},
	KIND_ALERT: {"o": Color8(40, 16, 12), "Y": Color8(240, 84, 52), "H": Color8(255, 176, 136)},
}

static var _tex_cache: Dictionary = {}

var kind: int = KIND_SEARCH
var _t: float = 0.0
var _base_scale: float = 1.0
var _parent_body: Node2D = null


static func build_image(k: int) -> Image:
	var rows: Array = GLYPHS[k]
	var pal: Dictionary = PALETTES[k]
	var h: int = rows.size()
	var w: int = (rows[0] as String).length()
	var img := Image.create(w + 1, h + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			if (rows[y] as String)[x] != ".":
				img.set_pixel(x + 1, y + 1, Color(0, 0, 0, 0.35))
	for y in range(h):
		for x in range(w):
			var c: String = (rows[y] as String)[x]
			if c != ".":
				img.set_pixel(x, y, pal[c])
	return img


static func texture_for(k: int) -> Texture2D:
	if not _tex_cache.has(k):
		_tex_cache[k] = ImageTexture.create_from_image(build_image(k))
	return _tex_cache[k]


func setup(k: int) -> void:
	kind = k
	texture = texture_for(k)
	var rows: Array = GLYPHS[k]
	offset = Vector2(-floorf(float((rows[0] as String).length() + 1) * 0.5), -float(rows.size() + 1))
	_t = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	z_index = 60
	z_as_relative = false
	_parent_body = get_parent() as Node2D
	if texture == null:
		setup(kind)
	var ps: float = absf(_parent_body.global_scale.y) if _parent_body != null else 1.0
	_base_scale = TEXEL / (ps if ps > 0.01 else 1.0)
	scale = Vector2.ONE * _base_scale * 0.3
	_update_position()


func _process(delta: float) -> void:
	_t += delta
	if _parent_body != null and (not is_instance_valid(_parent_body) or _parent_body.get("is_dead") == true):
		queue_free()
		return
	_update_position()
	## açılış yaylanması (0,18 sn), sonra tür davranışı
	var pop: float = clampf(_t / 0.18, 0.0, 1.0)
	var s: float = _base_scale * (0.3 + 0.7 * pop + (0.25 * sin(pop * PI) if kind == KIND_ALERT else 0.12 * sin(pop * PI)))
	scale = Vector2.ONE * s
	if kind == KIND_SEARCH:
		position.y += roundf(sin(_t * 4.0) * 1.0) * _base_scale
		rotation = sin(_t * 2.2) * 0.2
	else:
		modulate.a = 1.0 - clampf((_t - (ALERT_LIFE - 0.25)) / 0.25, 0.0, 1.0)
		if _t >= ALERT_LIFE:
			queue_free()


func _update_position() -> void:
	if is_instance_valid(_parent_body) and _parent_body.has_method("get_overhead_bar_offset"):
		position = Vector2(0, roundf(_parent_body.get_overhead_bar_offset() * HEAD_RATIO))
