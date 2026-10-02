extends Sprite2D

## Ölü/yere düşmüş karakterin altında yavaşça büyüyen kan + üstünde "hırpalanmış" görünüm (kullanıcı isteği 2026-10-02:
## "bir karakter ölünce altında yavaşça kan birikmesini istiyorum ölüp de kanamış gibi yavaşça çoğalan bir kan. ayrıca
## karakter ölü vaziyetteyken biraz hırpalanmış görüneceği türden bir shader olsun üstünde" - 4 prototipten P2 seçildi:
## "Sıçramalı birikinti + Kan lekeleri").
##
## - Kan: beden yere değince (IMPACT_DELAY) çevreye 7 küçük damla sıçrar, sonra dişli kenarlı havuz ~12 sn'de büyüyüp
##   yakındaki damlaları yutar; 25 sn içinde pıhtılaşmış gibi koyulaşır. Havuz DÜNYADA durur (haritanın hemen arkası,
##   enemy_abilities.place_on_ground - yaratıklar ve oyuncular üstünde yürür) ve her karede bedenin yatış karesinin
##   opak sınır kutusuna oturur; dokusu karakterin 48x48 piksel ızgarasıyla aynı ölçekte.
## - Hırpalanma: beden sprite'ına (Suriyeli Hadime hayaletken: yerdeki ceset) piksel ölçekli kan lekeleri + %30 solma.
## - Diriltilirken (kullanıcı isteği 2026-10-02: "kan efektinin yavaşça geriye sarmasını ve diriltilme süresine göre ters
##   bir şekilde anime edilmesini istiyorum iyileşiyormuş gibi") kan ve lekeler diriltme oranıyla TERSİNE oynar: oran 1'e
##   varınca havuz bedenin altına çekilmiş, lekeler silinmiş olur. Diriltme yarıda kalırsa ("eski haline dönsün yavaşça")
##   kan REGROW_RATE hızıyla yeniden yayılır. Diriltme tamamlanınca shader kalkar, kalan kan FADE_OUT_TIME'da söner.
##   Kalıcı ölümde ceset kanıyla yerde kalır.
##
## Çok oyunculu: ölüm/yere düşme durumu zaten senkron; player.gd ve remote_player.gd AYNI sync() çağrısını yapar, her
## istemci kendi kopyasını üretir (ek RPC yok). Kan gece parlamaz (night_glow_catalog'da yok - sahnesiz düğüm).

const POOL_SIZE := Vector2i(100, 48) ## doku pikseli = karakter sanat pikseli
const IMPACT_DELAY := 0.45 ## ölüm klibi 3 kare / 5 fps - beden bu civarda yere değer
const BATTER_FADE_IN := 1.5
const FADE_OUT_TIME := 2.5
const POOL_RADIUS_Y := 9.0
const REGROW_RATE := 0.25 ## diriltme kesilince geri sarılmış kanın yeniden yayılma hızı (oran/sn - tamamı ~4 sn)
const META := &"death_blood"

const POOL_SHADER := """
shader_type canvas_item;
uniform vec2 size = vec2(100.0, 48.0);
uniform vec2 radius = vec2(22.0, 9.0);
uniform float t = 0.0;
uniform float seed = 0.0;
uniform float fade = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = hash(i); float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)); float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.65 + vnoise(p * 2.1 + 13.7) * 0.35; }

// Havuz kenarına normalize uzaklık (<1 içeride), kenar gürültüsü dişli/organik görünüm verir.
float edist(vec2 p, float g) {
	vec2 r = radius * g;
	float e = length(p / max(r, vec2(0.6)));
	return e + (fbm(p * 0.16 + vec2(seed * 3.1, seed * 1.7)) - 0.5) * 0.64;
}

void fragment() {
	vec2 p = floor(UV * size) - size * 0.5 + 0.5; // texel merkezi, havuz merkezine göre
	float g = mix(0.12, 1.0, 1.0 - exp(-t / 4.0));
	float e = edist(p, g);
	float age = clamp(t / 25.0, 0.0, 1.0); // pıhtılaşma: zamanla koyulaşır
	vec3 body = mix(vec3(0.60, 0.08, 0.13), vec3(0.44, 0.05, 0.09), age);
	vec3 rim = vec3(0.26, 0.03, 0.06);
	vec3 lip = mix(vec3(0.74, 0.15, 0.19), vec3(0.58, 0.10, 0.14), age);
	vec4 col = vec4(0.0);
	if (e < 1.0) {
		bool edge = edist(p + vec2(1.0, 0.0), g) >= 1.0 || edist(p - vec2(1.0, 0.0), g) >= 1.0
			|| edist(p + vec2(0.0, 1.0), g) >= 1.0 || edist(p - vec2(0.0, 1.0), g) >= 1.0;
		col = vec4(body, 1.0);
		if (edge) {
			col.rgb = rim;
		} else if (p.y > 0.0 && edist(p + vec2(0.0, 1.0), g) < 1.0 && edist(p + vec2(0.0, 2.0), g) >= 1.0) {
			col.rgb = lip; // alt kenarın bir texel içinde ıslak parlama bandı
		} else if (e < 0.85 && hash(p + 4.2) > 0.975) {
			col.rgb = vec3(0.95, 0.55, 0.52); // seyrek ıslak parıltı
		}
	} else if (t > 0.0) {
		// Yere değiş anı sıçrayan damlalar (1x1 / 2x1 / 2x2) - havuz büyüdükçe yakındakileri yutar.
		for (int k = 0; k < 7; k++) {
			float fk = float(k);
			float ang = hash(vec2(fk, 3.1)) * 6.2831;
			float dist = mix(0.9, 1.45, hash(vec2(fk, 7.7)));
			vec2 c = floor(vec2(cos(ang), sin(ang)) * radius * dist);
			float hs = hash(vec2(fk, 9.9));
			vec2 sz = hs > 0.66 ? vec2(2.0, 2.0) : (hs > 0.33 ? vec2(2.0, 1.0) : vec2(1.0, 1.0));
			vec2 d = p - 0.5 - c;
			if (d.x >= 0.0 && d.y >= 0.0 && d.x < sz.x && d.y < sz.y) {
				col = vec4(sz.y > 1.0 ? body * 0.85 : rim * 1.4, 1.0);
			}
		}
	}
	col.a *= fade;
	COLOR = col * COLOR;
}
"""

const BATTER_SHADER := """
shader_type canvas_item;
uniform float amount = 1.0;
uniform float seed = 0.0;
varying vec2 lp;

void vertex() { lp = VERTEX; } // sprite'ın yerel pikseli - lekeler sanat pikseline oturur

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = hash(i); float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)); float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 c = COLOR;
	vec2 px = floor(lp);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(c.rgb, vec3(l), 0.3 * amount) * mix(1.0, 0.9, amount);
	float s = vnoise(px * 0.3 + vec2(seed * 2.3, 1.0)) + hash(px) * 0.12;
	if (s > 0.70 && c.a > 0.5) {
		vec3 blood = s > 0.80 ? vec3(0.33, 0.04, 0.07) : vec3(0.52, 0.06, 0.10);
		rgb = mix(rgb, blood * (0.75 + l * 0.6), 0.85 * amount);
	}
	COLOR = vec4(rgb, c.a);
}
"""

static var _pool_shader: Shader = null
static var _batter_shader: Shader = null
static var _pool_tex: Texture2D = null
static var _bbox_cache: Dictionary = {} ## "frames yolu|klip" -> Rect2i (son karenin opak kutusu)

var _host: Node2D = null
var _elapsed: float = 0.0
var _fading: bool = false
var _fade_t: float = 0.0
var _pool_mat: ShaderMaterial
var _batter_mat: ShaderMaterial
var _body: CanvasItem = null
var _placed_key: String = ""
var _center: Vector2 = Vector2.ZERO ## sprite yerel pikseli (ofset hariç)
var _revive_shown: float = 0.0 ## ekranda uygulanan diriltme oranı (yumuşatılmış)


## Her iki taraf da (player.gd _update_death_status_fx, remote_player.gd _update_death_status_fx) ölüm durumu her
## değiştiğinde/güncellendiğinde çağırır. dead: yere düşmüş VEYA kalıcı ölü.
static func sync(host: Node2D, dead: bool) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	## Tipsiz: silinmiş bir düğüm tipli değişkene atanırken hata verirdi.
	var cur = host.get_meta(META) if host.has_meta(META) else null
	if cur != null and not is_instance_valid(cur):
		cur = null
	if dead:
		if cur == null:
			var tree: SceneTree = host.get_tree()
			if tree.current_scene == null:
				return
			var node: Sprite2D = (load("res://scripts/death_blood.gd") as GDScript).new()
			node.set("_host", host)
			tree.current_scene.add_child(node)
			preload("res://scripts/enemy_abilities.gd").place_on_ground(tree, node)
			host.set_meta(META, node)
	elif cur != null:
		cur.call("fade_out")
		host.remove_meta(META)


func _ready() -> void:
	name = "DeathBlood"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = _shared_texture()
	if _pool_shader == null:
		_pool_shader = Shader.new()
		_pool_shader.code = POOL_SHADER
		_batter_shader = Shader.new()
		_batter_shader.code = BATTER_SHADER
	var seed_v: float = randf() * 50.0
	_pool_mat = ShaderMaterial.new()
	_pool_mat.shader = _pool_shader
	_pool_mat.set_shader_parameter("size", Vector2(POOL_SIZE))
	_pool_mat.set_shader_parameter("seed", seed_v)
	material = _pool_mat
	_batter_mat = ShaderMaterial.new()
	_batter_mat.shader = _batter_shader
	_batter_mat.set_shader_parameter("seed", seed_v)
	_batter_mat.set_shader_parameter("amount", 0.0)
	visible = false


static func _shared_texture() -> Texture2D:
	if _pool_tex == null:
		var img := Image.create(POOL_SIZE.x, POOL_SIZE.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_pool_tex = ImageTexture.create_from_image(img)
	return _pool_tex


func fade_out() -> void:
	if _fading:
		return
	_fading = true
	_set_body(null) ## shader dirilince hemen kalkar


func _exit_tree() -> void:
	_set_body(null)


## Hırpalanma materyalini gösterilen bedene taşır (Hadime hayalete dönünce: oyuncu sprite'ından yerdeki cesede).
## Başka bir sistemin materyalinin (Hadime form/hayalet) üstüne yazmaz, sadece kendi koyduğunu geri alır.
func _set_body(b: CanvasItem) -> void:
	if is_instance_valid(_body) and _body.material == _batter_mat:
		_body.material = null
	_body = b
	if _body != null and _body.material == null:
		_body.material = _batter_mat


func _resolve_body() -> AnimatedSprite2D:
	var corpse: Node = _host.get_node_or_null(preload("res://scripts/hadime_math.gd").CORPSE_NODE)
	if corpse != null and not corpse.is_queued_for_deletion():
		var b: Node = corpse.get_node_or_null("Body")
		if b is AnimatedSprite2D:
			return b
	var a = _host.get("anim")
	if a == null or not is_instance_valid(a) or not (a is AnimatedSprite2D):
		return null
	return a


func _process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		queue_free()
		return
	_elapsed += delta
	var body: AnimatedSprite2D = _resolve_body()
	if not _fading:
		if body != _body:
			_set_body(body)
		elif is_instance_valid(_body) and _body.material == null:
			_body.material = _batter_mat ## bir şey sıfırladıysa geri koy (başka materyal varsa dokunma)
	if body == null or body.sprite_frames == null:
		visible = false
		return
	_place(body)
	_update_revive(delta)
	var bleed: float = maxf(0.0, _elapsed - IMPACT_DELAY)
	var t: float = bleed * (1.0 - _revive_shown)
	_pool_mat.set_shader_parameter("t", t)
	if not _fading:
		## Lekeler diriltme ilerledikçe doğrusal silinir (yalnız kanın zamanına bağlansaydı son ana kadar dururdu).
		_batter_mat.set_shader_parameter("amount", clampf(bleed / BATTER_FADE_IN, 0.0, 1.0) * (1.0 - _revive_shown))
	else:
		_fade_t += delta
		var f: float = 1.0 - _fade_t / FADE_OUT_TIME
		_pool_mat.set_shader_parameter("fade", clampf(f, 0.0, 1.0))
		if f <= 0.0:
			queue_free()
			return
	visible = true


## Diriltme oranı: yerel oyuncuda get_revive_progress_ratio, kuklada downed iken health/max_health (main.gd bu alanlarda
## diriltme oranını yollar - bkz. remote_player.gd _update_revive_rewind_fx). Ağdan seyrek geldiği için yumuşatılır;
## azalırken (diriltme kesildi) REGROW_RATE ile yavaşça.
func _update_revive(delta: float) -> void:
	var target: float = 0.0
	if _host.has_method("get_revive_progress_ratio"):
		target = float(_host.call("get_revive_progress_ratio"))
	elif bool(_host.get("is_downed")):
		var mh: float = float(_host.get("max_health"))
		target = clampf(float(_host.get("health")) / mh, 0.0, 1.0) if mh > 0.0 else 0.0
	if target >= _revive_shown:
		_revive_shown = lerpf(_revive_shown, target, 1.0 - exp(-12.0 * delta))
	else:
		_revive_shown = move_toward(_revive_shown, target, REGROW_RATE * delta)


## Havuz merkezi = gösterilen klibin SON karesindeki (yatış pozu) opak kutunun yatay ortası, alt kenarın 3 piksel üstü.
## Doku pikselleri sprite'ın pikselleriyle aynı ölçek/ızgarada (sprite ofseti dahil).
func _place(body: AnimatedSprite2D) -> void:
	var clip: StringName = body.animation
	var key: String = body.sprite_frames.resource_path + "|" + String(clip)
	if key != _placed_key:
		_placed_key = key
		var n: int = body.sprite_frames.get_frame_count(clip)
		var tex: Texture2D = body.sprite_frames.get_frame_texture(clip, n - 1) if n > 0 else null
		var fw: float = float(tex.get_width()) if tex else 48.0
		var fh: float = float(tex.get_height()) if tex else 48.0
		var bb: Rect2i = _frame_bbox(key, tex)
		if bb.size == Vector2i.ZERO:
			bb = Rect2i(int(fw * 0.25), int(fh * 0.6), int(fw * 0.5), int(fh * 0.25))
		var cx: float = round(bb.position.x + bb.size.x * 0.5)
		var cy: float = float(bb.position.y + bb.size.y) - 3.0
		_center = Vector2(cx - fw * 0.5, cy - fh * 0.5)
		_pool_mat.set_shader_parameter("radius", Vector2(maxf(18.0, bb.size.x * 0.5 + 6.0), POOL_RADIUS_Y))
	var local: Vector2 = _center
	if body.flip_h:
		local.x = -local.x
	global_position = body.global_transform * (local + body.offset)
	var s: Vector2 = body.global_scale.abs()
	global_scale = s
	global_rotation = 0.0


static func _frame_bbox(key: String, tex: Texture2D) -> Rect2i:
	if _bbox_cache.has(key):
		return _bbox_cache[key]
	var r := Rect2i()
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			r = img.get_used_rect()
	_bbox_cache[key] = r
	return r
