extends Sprite2D
## Efsunlu silahın kademe göstergesi: silüetin etrafında KONTÜR (kullanıcı isteği 2026-10-04: "efsunlanan silahların arkaplanı hafif
## parıltılı olacak ... 1. kademe yeşil, 2 mavi, 3 mor, 4 sarı, 5 (final) kırmızı"; 2026-10-08: "efsun leveline göre verdiğimiz parıltı
## efektinin daha sade olmasını istiyorum" -> 4 prototipten "A Kontür" seçildi, "final hali hafif yanıp sönerken diğer versiyonlar
## yanıp sönmüyor onun gibi" -> hafif nefes alma TÜM kademelerde). Eski halka parıltısı (bantlı hale + parıltı şeridi + kıvılcımlar) kaldırıldı.
## 2026-10-08 (kullanıcı): "1. level aynı kalsın, 2. level yeşil, 3. level mavi, 4. level mor, 5. level kırmızı; renkler silahlarla uyuşmazlık
## yaşamasın diye doğru seçilsin": Temel (kademe 1) = kontür YOK (her silah efsunlu doğuyor - silah olduğu gibi görünür); kademe 2-5 sönük,
## doygunluğu kısılmış tonlar (neon değil: silah ikonlarının renkleriyle çakışmasın) - TIER_COLORS tek yerden ayarlanır.
## 2026-10-08 (kullanıcı, oyun içi ekran görüntüsüyle: "kontürler oyunda hiç belli olmuyor"): sönük tonlar + 1,7 px çizgi çimen/toprak üstünde kayboluyordu
## (yeşil kademe çimle aynı renkti) -> çizgi 2,4 ekran pikseli, tonlar daha canlı. Koyu dış çizgi (rim) denendi, zemin üstünde kirli göründü, atıldı.
## Kademe = tier_for(efsun kaydı). Yerel: weapon.gd set_enchant takar. Uzak kopyalar: main.gd extra["ench_tiers"] (weapon_keys
## ile aynı sıra) -> remote_player.gd _apply_enchant_glows - ikisi de AYNI attach() yolundan geçer.
##
## Silah ikonunun (Sprite2D ya da AnimatedSprite2D - Yay) ÇOCUĞU olarak, ikonun ARKASINDA çizilir (show_behind_parent) -> ikonla birlikte döner,
## aynalanır, gizlenir.
## KONTÜR EKRAN UZAYINDA, SHADER'DA (2026-10-08, kullanıcı: "çizgi ince ve kesik kesik"): önceki sürüm kontürü DÜNYA pikseli çözünürlüğünde
## bir dokuya yazıyordu; oyun 1920x1080 tuvalini pencereye ölçekleyince (ve ikonlar ~x0,2-0,5 küçültülünce) o 1 dünya pikseli ekranda bir yerde
## 1 bir yerde 2 piksel çıkıyor, silüetin pürüzü de çizgiyi kesik gösteriyordu (yumuşatma da kenarları şişirip pençe/diken aralarını doldurdu).
## Şimdi doku sadece ikonun ALFA kapsamı (kaynak çözünürlükte, kenarlarda boşluk payıyla, mip zincirli); shader her ekran pikselinde
## ekran türevleriyle (dFdx/dFdy) "ekranda OUTLINE_PX piksel çevrede dolu alan var mı" diye bakar -> kalınlık ölçekten/dönmeden BAĞIMSIZ sabit,
## çizgi kesintisiz; mip düzeyi ekran pikselinin kapsadığı doku sayısından seçilir (küçültülmüş ikonun gürültülü kenarı süzülür). Final
## (kademe 5): dışında ikinci, koyu bir halka daha. Canlılık: yavaş nefes alan parlaklık (shader), tüm kademelerde aynı.

## Kontürü olan ilk kademe: Temel (1) göstergesiz; geliştirme aldıkça 2 yeşil, 3 mavi, 4 mor, 5 (final) kırmızı.
const MIN_TIER := 2
const TIER_COLORS: Array[Color] = [
	Color8(120, 232, 90), ## 2 - yeşil (çimen üstünde de okunsun diye açık/canlı limon yeşili)
	Color8(80, 160, 255), ## 3 - mavi
	Color8(186, 124, 255), ## 4 - mor
	Color8(255, 84, 72), ## 5 - kırmızı (final)
]
## Kontür kalınlığı EKRAN pikseli (iç halka); final'in dış halkası aynı kalınlıkta bir halka daha.
const OUTLINE_PX := 2.4
## Genel yoğunluk (kontür opaklığı).
const GLOW_INTENSITY := 1.0
## Doku kenar payı (dünya pikseli): en dış halka (2 x OUTLINE_PX) küçük pencerede bile (ölçek ~0,6) sığsın.
const PAD_WORLD_PX := 9.0

const GLOW_SHADER := """
shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float phase = 0.0;
uniform float double_ring = 0.0;
uniform float thick = 2.4;
const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071),
		vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

float cov(sampler2D tex, vec2 uv, float lod) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return inside.x * inside.y * textureLod(tex, uv, lod).a;
}

// Ekranda r piksel çevrede (8 yön) silüet var mı: 0..1
float ring(sampler2D tex, vec2 uv, vec2 ux, vec2 uy, float lod, float r) {
	float m = 0.0;
	for (int i = 0; i < 8; i++) {
		vec2 o = DIRS[i] * r;
		m = max(m, smoothstep(0.3, 0.7, cov(tex, uv + ux * o.x + uy * o.y, lod)));
	}
	return m;
}

void fragment() {
	// ux/uy: ekranda +1 piksel sağa/aşağı giderken doku koordinatındaki değişim (döndürme/aynalama dahil)
	vec2 ux = dFdx(UV);
	vec2 uy = dFdy(UV);
	vec2 tsz = vec2(textureSize(TEXTURE, 0));
	float texels = max(length(ux * tsz), length(uy * tsz));
	float lod = max(0.0, log2(max(texels, 0.0001)) - 0.25);
	float raw = cov(TEXTURE, UV, lod);
	if (raw >= 0.97) { discard; } // tam içeri: ikonla kaplı, 17+ komşu örneklemesine gerek yok
	float own = smoothstep(0.3, 0.7, raw);
	// iç halka: silüetin kendisi (kenar pikselleri ikonun altında boşluk bırakmasın) + OUTLINE_PX çevresi; tam içerisi ikonla kaplı
	float a1 = max(own, max(ring(TEXTURE, UV, ux, uy, lod, thick * 0.5), ring(TEXTURE, UV, ux, uy, lod, thick)));
	a1 *= 1.0 - smoothstep(0.75, 0.97, raw);
	float a2 = 0.0;
	if (double_ring > 0.5) {
		a2 = max(ring(TEXTURE, UV, ux, uy, lod, thick * 1.5), ring(TEXTURE, UV, ux, uy, lod, thick * 2.0));
		a2 *= (1.0 - a1) * (1.0 - smoothstep(0.75, 0.97, raw));
	}
	float alpha = a1 + a2;
	if (alpha <= 0.002) { discard; }
	float pulse = 0.82 + 0.18 * sin((TIME + phase) * 2.3);
	vec3 col = glow_color.rgb * (a1 + 0.55 * a2) / alpha;
	COLOR = vec4(col, clamp(alpha * pulse * strength, 0.0, 1.0));
}
"""

static var _shader: Shader = null
## (kaynak doku, kenar payı) -> alfa kapsam dokusu
static var _cache: Dictionary = {}

var tier: int = MIN_TIER
var _icon: Node2D = null
var _src_tex: Texture2D = null


## Bir silah ikonuna kademe kontürü takar (varsa günceller). Kademe MIN_TIER'ın altındaysa (0 = efsun yok, 1 = Temel) kaldırır.
static func attach(icon: Node2D, new_tier: int) -> Node:
	if icon == null:
		return null
	var existing: Node = icon.get_node_or_null("EnchantGlow")
	if new_tier < MIN_TIER:
		if existing:
			existing.queue_free()
		return null
	if existing:
		existing.set("tier", clampi(new_tier, MIN_TIER, 5))
		existing.call("_apply_tier")
		return existing
	var g: Sprite2D = (load("res://scripts/enchant_weapon_glow.gd") as GDScript).new()
	g.name = "EnchantGlow"
	g.tier = clampi(new_tier, MIN_TIER, 5)
	icon.add_child(g)
	return g


func _ready() -> void:
	_icon = get_parent() as Node2D
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS ## shader mip düzeyinden alfa kapsamı okur
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("phase", randf() * 10.0)
	material = mat
	_apply_tier()
	_rebuild()


func _apply_tier() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("glow_color", TIER_COLORS[clampi(tier, MIN_TIER, 5) - MIN_TIER])
	mat.set_shader_parameter("strength", GLOW_INTENSITY)
	mat.set_shader_parameter("thick", OUTLINE_PX)
	mat.set_shader_parameter("double_ring", 1.0 if tier >= 5 else 0.0)


func _rebuild() -> void:
	var tex: Texture2D = _icon_texture()
	if tex == null:
		texture = null
		_src_tex = null
		return
	_src_tex = tex
	## Doku = ikonun alfası + kenarlarda boşluk payı (kontür ikonun dışına taşar), kaynak çözünürlükte; boyut/konum ikonla birebir
	## (ölçek 1: glow ikonun çocuğu, ölçeğini devralır).
	var gs: Vector2 = _icon.get_global_transform().get_scale().abs()
	var px: int = int(ceilf(PAD_WORLD_PX / maxf(gs.x, 0.02))) + 1
	var py: int = int(ceilf(PAD_WORLD_PX / maxf(gs.y, 0.02))) + 1
	var key: String = "%s|%d|%d" % [_src_tex.get_rid(), px, py]
	if not _cache.has(key):
		_cache[key] = _build_coverage(_src_tex, px, py)
	texture = _cache[key]
	scale = Vector2.ONE
	centered = bool(_icon.get("centered"))
	var icon_offset: Vector2 = _icon.get("offset") as Vector2
	offset = icon_offset if centered else icon_offset - Vector2(px, py)


## Alfa kapsam dokusu: kaynak ikon, her kenarına (px, py) şeffaf boşlukla büyütülmüş, mip zincirli. Shader bunu ekran piksel ölçeğinde süzer.
static func _build_coverage(src: Texture2D, px: int, py: int) -> ImageTexture:
	var img: Image = src.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create(img.get_width() + px * 2, img.get_height() + py * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(px, py))
	out.generate_mipmaps()
	return ImageTexture.create_from_image(out)


func _process(_delta: float) -> void:
	if _icon == null:
		return
	if _icon_texture() != _src_tex:
		_rebuild()
	flip_h = bool(_icon.get("flip_h"))
	flip_v = bool(_icon.get("flip_v"))


## İkonun o an çizdiği doku (AnimatedSprite2D'de geçerli kare).
func _icon_texture() -> Texture2D:
	if _icon is Sprite2D:
		return (_icon as Sprite2D).texture
	if _icon is AnimatedSprite2D:
		var a := _icon as AnimatedSprite2D
		if a.sprite_frames and a.sprite_frames.has_animation(a.animation):
			return a.sprite_frames.get_frame_texture(a.animation, a.frame)
	return null


## Efsun kaydından kademe (player.gd apply_enchant_choice: {"id", "ups": [..], "final"}): Temel = 1, her geliştirme +1
## (en fazla 4), Final = 5. "Seviye" efsunlarında (3 geliştirme) birebir Seviye 1-5. Efsun yok = 0.
static func tier_for(ench: Dictionary) -> int:
	if ench.is_empty() or str(ench.get("id", "")).is_empty():
		return 0
	if bool(ench.get("final", false)):
		return 5
	return mini(4, 1 + (ench.get("ups", []) as Array).size())
