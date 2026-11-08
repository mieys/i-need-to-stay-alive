extends Node2D
## RUH HÂLİ görünüş PROTOTİPLERİ (madde 438 devamı, 2026-11-07; kullanıcı: "istediğim gibi görünmüyor, 4 prototip hazırla").
## OYUNA BAĞLI DEĞİL - ruh_proto_capture.gd gerçek Main'de oyuncunun üstüne koyar. Asıl AnimatedSprite2D gizlenir, karesi her karede
## kopyalanır (okuma klibi oynar). Hepsi doku pikseline oturur, dither/bulanıklık yok.
##   0 A HAYALET      : karakterin kendi çizimi soluk camgöbeğine döner, yarı saydam, bacaklar aşağı doğru basamakla silinir (kuyruk),
##                      1-2 sanat px süzülür, kenarında soluk hale.
##   1 B IŞIK RUHU    : gövde içten parlar (koyu çizgiler mavi, açıklar beyaza), iki halkalı ışık kenarı nabız atar, etrafta yıldız pırıltıları.
##   2 C BEDENDEN ÇIKIŞ: beden yerde gri/soluk kalır (okur), ruhu saydam mavi kopya olarak birkaç piksel yukarıda süzülür.
##   3 D MAVİ ALEV    : karakter serin maviye döner (detay aynı), silüetin üstünden piksel piksel mavi ruh alevi yükselir.

var style: int = 0
var src: AnimatedSprite2D = null

var _copies: Array[Sprite2D] = []
var _mats: Array[ShaderMaterial] = []
var _t: float = 0.0
var _sparks: Array = [] ## [x, y, yaş, ömür] sanat pikseli, gövde merkezine göre
var _bbox_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()

const COMMON := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0); // karenin atlastaki UV dikdörtgeni
uniform vec2 body_y = vec2(0.0, 1.0);           // opak gövdenin üst/alt UV y'si
uniform float phase = 0.0;
bool inr(vec2 uv) {
	return uv.x >= region.x && uv.y >= region.y && uv.x < region.x + region.z && uv.y < region.y + region.w;
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
"""

## A HAYALET
const SH_A := """
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	float v = clamp((UV.y - body_y.x) / max(body_y.y - body_y.x, 0.0001), 0.0, 1.0);
	float fade = v < 0.62 ? 1.0 : (v < 0.76 ? 0.7 : (v < 0.88 ? 0.4 : 0.15));
	if (c.a > 0.5) {
		vec3 g = mix(vec3(0.30, 0.58, 0.98), vec3(0.90, 0.99, 1.0), clamp(lum(c.rgb) * 1.5, 0.0, 1.0));
		COLOR = vec4(mix(c.rgb, g, 0.88), 0.74 * fade);
	} else {
		float n = 0.0;
		vec2 o[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
		for (int i = 0; i < 4; i++) {
			if (inr(UV + o[i])) { n += texture(TEXTURE, UV + o[i]).a; }
		}
		COLOR = n > 0.5 ? vec4(0.70, 0.93, 1.0, 0.6 * fade) : vec4(0.0);
	}
}
"""

## B IŞIK RUHU
const SH_B := """
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	float pulse = sin(TIME * 3.0 + phase) > 0.0 ? 1.0 : 0.0;
	if (c.a > 0.5) {
		float l = clamp(lum(c.rgb) * 1.25, 0.0, 1.0);
		vec3 col = mix(vec3(0.28, 0.55, 0.98), vec3(1.0, 1.0, 1.0), pow(l, 0.75));
		COLOR = vec4(col, 0.95);
	} else {
		float d1 = 0.0;
		float d2 = 0.0;
		for (int dx = -2; dx <= 2; dx++) {
			for (int dy = -2; dy <= 2; dy++) {
				int m = abs(dx) + abs(dy);
				if (m == 0 || m > 2) { continue; }
				vec2 uv = UV + vec2(float(dx) * px.x, float(dy) * px.y);
				if (!inr(uv) || texture(TEXTURE, uv).a < 0.5) { continue; }
				if (m == 1) { d1 = 1.0; } else { d2 = 1.0; }
			}
		}
		if (d1 > 0.0) {
			COLOR = vec4(0.80, 0.96, 1.0, mix(0.6, 0.85, pulse));
		} else if (d2 > 0.0) {
			COLOR = vec4(0.45, 0.76, 1.0, mix(0.22, 0.38, pulse));
		} else {
			COLOR = vec4(0.0);
		}
	}
}
"""

## C BEDEN (gri, soluk) - ruh kopyası A'nın gövdesine benzer ama tam boy, kuyruksuz
const SH_C_BODY := """
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = lum(c.rgb);
	vec3 grey = vec3(l) * vec3(0.80, 0.84, 0.94);
	COLOR = vec4(mix(c.rgb, grey, 0.65) * 0.9, c.a);
}
"""
const SH_C_SOUL := """
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.5) {
		vec3 g = mix(vec3(0.30, 0.58, 0.98), vec3(0.90, 0.99, 1.0), clamp(lum(c.rgb) * 1.5, 0.0, 1.0));
		COLOR = vec4(mix(c.rgb, g, 0.88), 0.62);
	} else {
		float n = 0.0;
		vec2 o[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
		for (int i = 0; i < 4; i++) {
			if (inr(UV + o[i])) { n += texture(TEXTURE, UV + o[i]).a; }
		}
		COLOR = n > 0.5 ? vec4(0.80, 0.96, 1.0, 0.6) : vec4(0.0);
	}
}
"""

## D MAVİ ALEV
const SH_D := """
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.5) {
		vec3 b = mix(vec3(0.12, 0.25, 0.60), vec3(0.80, 0.95, 1.0), clamp(lum(c.rgb) * 1.2, 0.0, 1.0));
		COLOR = vec4(mix(c.rgb, b, 0.5), 1.0);
	} else {
		vec2 t = floor(UV / px);
		float tick = floor(TIME * 9.0 + phase);
		float h = 1.0 + floor(hash(vec2(t.x, tick)) * 3.99); // sütun başına 1-4 texel dil
		float d = 0.0;
		for (int i = 1; i <= 4; i++) {
			vec2 uv = UV + vec2(0.0, float(i) * px.y);
			if (float(i) <= h && inr(uv) && texture(TEXTURE, uv).a > 0.5) { d = float(i); break; }
		}
		if (d == 0.0) {
			bool side = (inr(UV + vec2(px.x, 0.0)) && texture(TEXTURE, UV + vec2(px.x, 0.0)).a > 0.5)
					|| (inr(UV - vec2(px.x, 0.0)) && texture(TEXTURE, UV - vec2(px.x, 0.0)).a > 0.5);
			if (side && hash(vec2(t.y, tick + 7.0)) > 0.45) { d = 1.0; }
		}
		if (d == 1.0) { COLOR = vec4(0.72, 0.94, 1.0, 0.9); }
		else if (d == 2.0) { COLOR = vec4(0.36, 0.70, 1.0, 0.75); }
		else if (d >= 3.0) { COLOR = vec4(0.16, 0.38, 0.88, 0.55); }
		else { COLOR = vec4(0.0); }
	}
}
"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 4381 + style
	if not is_instance_valid(src):
		return
	z_index = src.z_index
	var codes: Array = []
	match style:
		0: codes = [SH_A]
		1: codes = [SH_B]
		2: codes = [SH_C_BODY, SH_C_SOUL]
		3: codes = [SH_D]
	for code in codes:
		var sh := Shader.new()
		sh.code = COMMON + code
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("phase", _rng.randf() * TAU)
		var s := Sprite2D.new()
		s.material = m
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		_copies.append(s)
		_mats.append(m)
	src.visible = false
	for i in 5:
		_sparks.append(_new_spark(_rng.randf()))
	_sync()


func _exit_tree() -> void:
	if is_instance_valid(src):
		src.visible = true


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(src):
		return
	src.visible = false
	_sync()
	if style == 1:
		for s in _sparks:
			s[2] += delta
			if s[2] >= s[3]:
				var f: Array = _new_spark(0.0)
				for k in 4:
					s[k] = f[k]
	queue_redraw()


func _new_spark(age_frac: float) -> Array:
	var life: float = _rng.randf_range(0.5, 0.9)
	return [float(_rng.randi_range(-11, 11)), float(_rng.randi_range(-16, 8)), age_frac * life, life]


func _sync() -> void:
	if src.sprite_frames == null or not src.sprite_frames.has_animation(src.animation):
		return
	var tex: Texture2D = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	var region := Vector4(0, 0, 1, 1)
	var body := Vector2(0, 1)
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var asz: Vector2 = at.atlas.get_size()
		region = Vector4(at.region.position.x / asz.x, at.region.position.y / asz.y, at.region.size.x / asz.x, at.region.size.y / asz.y)
		var bb: Vector2i = _body_rows(at)
		body = Vector2((at.region.position.y + bb.x) / asz.y, (at.region.position.y + bb.y + 1) / asz.y)
	var px: float = absf(src.scale.y)
	for i in _copies.size():
		var s: Sprite2D = _copies[i]
		s.texture = tex
		s.scale = src.scale
		s.offset = src.offset
		s.centered = src.centered
		s.flip_h = src.flip_h
		s.position = src.position
		_mats[i].set_shader_parameter("region", region)
		_mats[i].set_shader_parameter("body_y", body)
	## süzülme: sanat pikseline oturan yavaş inip kalkma
	var bob: float = roundf(sin(_t * 2.4) * 1.0)
	if style == 0:
		_copies[0].position.y -= (2.0 + bob) * px
	elif style == 2:
		_copies[1].position.y -= (14.0 + bob) * px


## Karenin opak satır aralığı (üst, alt) - A'nın kuyruk silinmesi gövdenin kendi boyuna göre olsun diye. Önbellekli.
func _body_rows(at: AtlasTexture) -> Vector2i:
	var key: String = "%d:%s" % [at.atlas.get_instance_id(), str(at.region)]
	if _bbox_cache.has(key):
		return _bbox_cache[key]
	var img: Image = at.atlas.get_image()
	if img == null:
		return Vector2i(0, int(at.region.size.y) - 1)
	if img.is_compressed():
		img.decompress()
	var top: int = -1
	var bot: int = -1
	var r: Rect2i = Rect2i(at.region)
	for y in r.size.y:
		for x in r.size.x:
			if img.get_pixel(r.position.x + x, r.position.y + y).a > 0.5:
				if top < 0:
					top = y
				bot = y
				break
	var out := Vector2i(maxi(top, 0), maxi(bot, 0))
	_bbox_cache[key] = out
	return out


func _draw() -> void:
	if style != 1 or not is_instance_valid(src):
		return
	var px: float = absf(src.scale.x)
	var c0: Vector2 = src.position + src.offset * src.scale
	for s in _sparks:
		var k: float = float(s[2]) / float(s[3])
		var big: bool = k > 0.3 and k < 0.7
		var col := Color(0.86, 0.97, 1.0, 0.95 if big else 0.6)
		var p: Vector2 = (Vector2(s[0], s[1] - roundf(k * 3.0)) * px + c0).floor()
		draw_rect(Rect2(p, Vector2(px, px)), col)
		if big:
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_rect(Rect2(p + d * px, Vector2(px, px)), Color(0.55, 0.82, 1.0, 0.7))
