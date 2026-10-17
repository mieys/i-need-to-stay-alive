class_name ElaraFx
extends RefCounted
## Elara'nın Q/E/R efektleri (2026-10-16, madde 178; kullanıcı: "elaranın yeteneklerini silip skill setiyle uyumlu yeni yetenek efektleri
## üretmen istiyorum ... çevik bir nişancı karakteridir", "silahlarına da efekt verse iyi olabilir çünkü e ve R yeteneği silahlarıyla alakalı").
## MEKANİK DEĞİŞMEDİ - sadece görsel. Eski efektler (fx_elara_true/fx_elara_double sahneleri, Q'nun renkli patlaması + Matthew hız çizgisi)
## kaldırıldı. Sanat: tools/gen_elara_fx.py (onaylanan prototip tools/proto_20261016/gen_elara_nisanci.py çizimleri) -> assets/fx/elara/*.png.
##
## TEK KOD İKİ YER (CLAUDE.md "MP iki-yer hatası"): kasterde (player.gd) ve uzak kopyada (remote_player.gd) AYNI Driver düğümü çalışır,
## Elara'nın bayraklarını okur ve kenarlarda (açıldı/kapandı) efektleri kendisi başlatır/bitirir - yeni RPC yok:
##   Q Sıvışma      kaster _elara_evasion_timer > 0      uzak _elara_evasion  (main.gd extra "elara_evasion")
##   E Gerçek Hasar kaster elara_true_damage_active      uzak _elara_focus    (main.gd extra "elara_focus", 2026-10-16 yeni)
##   R Çift Tetik   kaster elara_double_fire_active      uzak _elara_double   (main.gd extra "elara_double")
## Mermi görünümü (E kehribar iz, R'nin ikinci tetiği turkuaz ikiz mermi) weapon.gd _fire_at'te look["elara"] ile kasterde uygulanır, uzak
## kopyaya NetworkManager.broadcast_projectile -> EnchantFx.apply_projectile_look ile aynı fonksiyondan (style_projectile) gider.
##
## Ölçek: 1 sayfa pikseli = 1 Elara sanat pikseli. Karaktere bağlı sayfalar Elara'nın AnimatedSprite2D ölçeğini (yerel) alır, dünyada sabit
## olanlar dünya ölçeğini (~0,903 dünya birimi/piksel). Karenin merkezi = AnimatedSprite2D'nin orijini (offset dahil).

const DIR := "res://assets/fx/elara/"
const FPS := 16.0
const SHEETS := {
	"q_cast": 9, "q_end": 5,
	"e_cast": 8, "e_ring_in": 3, "e_ring_loop": 10, "e_ring_out": 5, "e_chev": 10,
	"r_cast_top": 5, "r_cast_ring": 6,
	"r_wisp_back_in": 3, "r_wisp_back_loop": 15, "r_wisp_back_out": 6,
	"r_wisp_front_in": 3, "r_wisp_front_loop": 15, "r_wisp_front_out": 6,
}
## [kontur, koyu, orta, açık, parlak] - tools/proto_20261016/gen_elara_nisanci.py RUZ / AMB ile aynı.
const RUZ: Array[Color] = [Color8(22, 58, 70), Color8(36, 116, 128), Color8(78, 184, 182), Color8(164, 234, 218), Color8(236, 255, 246)]
const AMB: Array[Color] = [Color8(92, 36, 10), Color8(190, 86, 22), Color8(242, 146, 40), Color8(255, 206, 104), Color8(255, 246, 208)]
const CREAM := Color8(255, 250, 228)
## Bir Elara sanat pikselinin dünya boyutu (silah/mermi efektleri bunu kullanır; karaktere bağlı sayfalar sprite ölçeğini okur).
const PX := 0.903
## Çift Tetik ikizi: silah ikonuna göre DÜNYA kayması (prototip -5, +3 piksel = arka-sol-alt).
const ECHO_OFFSET := Vector2(-4.5, 2.7)
## Ardıl görüntü (Q): 2 karede bir doğar, 4 karede Bayer ile seyrelir.
const GHOST_INTERVAL := 2.0 / FPS
const GHOST_LEVELS: Array[float] = [0.62, 0.45, 0.28, 0.12]
const MOVE_SPEED_MIN := 20.0
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const PhysicsInterpScript := preload("res://scripts/physics_interp.gd")

## Tek shader, üç kip (hepsi piksel dilinde, alfa saydamlığı yerine 4x4 Bayer):
##  0 İKİZ  - dokunun turkuaz silüeti (açık yerler parlak) + EKRAN pikselinde dış kenar (dFdx; ölçek/dönmeden bağımsız, enchant_weapon_glow.gd
##            ile aynı yol) - R silah ikizi (level 0.85) ve ikinci tetik mermisi (level 1).
##  1 PARILTI - ikon silüetinin içinde, DÜNYA uzayında çapraz kayan kehribar bant (E). glint_c/glint_r ikonun dünya merkezi/yarı köşegeni.
##  2 ARDIL  - karakter karesinin turkuaz silüeti, 3 ton + 1 doku pikseli iç kenar, Bayer DOKU pikselinde (sanat pikseline oturur) - Q.
const SHADER_CODE := """
shader_type canvas_item;
uniform int mode = 0;
uniform float level = 1.0;
uniform float sweep = -1.0;
uniform vec2 glint_c = vec2(0.0);
uniform float glint_r = 16.0;
uniform float edge_px = 2.0;
const vec3 C1 = vec3(36.0, 116.0, 128.0) / 255.0;
const vec3 C2 = vec3(78.0, 184.0, 182.0) / 255.0;
const vec3 C3 = vec3(164.0, 234.0, 218.0) / 255.0;
const vec3 C4 = vec3(236.0, 255.0, 246.0) / 255.0;
const vec3 GLINT = vec3(255.0, 246.0, 208.0) / 255.0;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071),
		vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));
varying vec2 wpos;
varying vec4 vcol;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vcol = COLOR;
}

float bayer(vec2 p) {
	ivec2 i = ivec2(mod(floor(p), 4.0));
	return (BAYER[i.x + i.y * 4] + 0.5) / 16.0;
}

void fragment() {
	vec2 tsz = vec2(textureSize(TEXTURE, 0));
	if (mode == 2) {
		vec4 t = texture(TEXTURE, UV);
		if (t.a < 0.5 || bayer(floor(UV * tsz)) >= level) { discard; }
		vec2 tp = 1.0 / tsz;
		float n = min(min(texture(TEXTURE, UV + vec2(tp.x, 0.0)).a, texture(TEXTURE, UV - vec2(tp.x, 0.0)).a),
				min(texture(TEXTURE, UV + vec2(0.0, tp.y)).a, texture(TEXTURE, UV - vec2(0.0, tp.y)).a));
		float lum = dot(t.rgb, vec3(0.3333));
		vec3 c = n < 0.5 ? C1 : (lum > 0.588 ? C4 : (lum > 0.372 ? C3 : C2));
		COLOR = vec4(c, vcol.a);
	} else {
		vec2 ux = dFdx(UV);
		vec2 uy = dFdy(UV);
		float texels = max(length(ux * tsz), length(uy * tsz));
		float lod = max(0.0, log2(max(texels, 0.0001)) - 0.25);
		vec4 t = textureLod(TEXTURE, UV, lod);
		if (mode == 1) {
			if (t.a < 0.5 || sweep < 0.0) { discard; }
			float d = (wpos.x - glint_c.x) + (wpos.y - glint_c.y) * 0.7;
			float pos = -glint_r * 1.7 + glint_r * 3.4 * sweep;
			if (d < pos || d > pos + 2.7) { discard; }
			COLOR = vec4(mix(t.rgb / max(t.a, 0.001), GLINT, 0.75), vcol.a);
		} else {
			float b = bayer(floor(wpos));
			if (t.a > 0.5) {
				if (b >= level) { discard; }
				float lum = dot(t.rgb / max(t.a, 0.001), vec3(0.3333));
				COLOR = vec4(lum > 0.47 ? C4 : C3, vcol.a);
			} else {
				float m = 0.0;
				for (int i = 0; i < 8; i++) {
					vec2 o = DIRS[i] * edge_px;
					m = max(m, textureLod(TEXTURE, UV + ux * o.x + uy * o.y, lod).a);
				}
				if (m < 0.5 || b >= level * 0.8) { discard; }
				COLOR = vec4(C2, vcol.a);
			}
		}
	}
}
"""

static var _shader: Shader = null
static var _tex_cache: Dictionary = {}
static var _used_cache: Dictionary = {}
static var _pad_cache: Dictionary = {}


static func make_material(mode: int, level: float = 1.0) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("level", level)
	return m


static func tex(sheet: String) -> Texture2D:
	if not _tex_cache.has(sheet):
		_tex_cache[sheet] = load(DIR + sheet + ".png")
	return _tex_cache[sheet]


## Elara'nın Driver'ını (yoksa) takar - kaster: player.gd _skill_elara_*; uzak: remote_player.gd bayraklardan biri açıldığında.
static func ensure_driver(owner: Node2D) -> Node:
	if owner == null:
		return null
	var d: Node = owner.get_node_or_null("ElaraFxDriver")
	if d == null:
		d = Driver.new()
		d.name = "ElaraFxDriver"
		owner.add_child(d)
	return d


## [Q, E, R] açık mı - kaster ve uzak kopya alan adları farklı (bkz. dosya başı tablo). Ölüyken hepsi kapalı.
static func flags(p: Node) -> Array:
	if p == null or p.get("is_dead") == true:
		return [false, false, false]
	if "owned_weapon_nodes" in p:
		return [float(p.get("_elara_evasion_timer")) > 0.0, p.get("elara_true_damage_active") == true, p.get("elara_double_fire_active") == true]
	return [p.get("_elara_evasion") == true, p.get("_elara_focus") == true, p.get("_elara_double") == true]


## Silah ikonları (kaster: her silahın icon_sprite'ı - Yay'da AnimatedSprite2D; uzak: _weapon_icons Sprite2D'leri).
static func icons(p: Node) -> Array:
	var out: Array = []
	if "owned_weapon_nodes" in p:
		for w in p.get("owned_weapon_nodes"):
			if is_instance_valid(w) and w.get("icon_sprite") != null and is_instance_valid(w.get("icon_sprite")):
				out.append(w.get("icon_sprite"))
	elif "_weapon_icons" in p:
		for ic in p.get("_weapon_icons"):
			if is_instance_valid(ic):
				out.append(ic)
	return out


## İkonun ya da karakterin o an çizdiği doku (AnimatedSprite2D'de geçerli kare).
static func current_texture(n: Node) -> Texture2D:
	if n is Sprite2D:
		return (n as Sprite2D).texture
	if n is AnimatedSprite2D:
		var a := n as AnimatedSprite2D
		if a.sprite_frames and a.sprite_frames.has_animation(a.animation):
			return a.sprite_frames.get_frame_texture(a.animation, a.frame)
	return null


## Dokunun dolu bölgesi (silah ikonlarında 250 px tuvalin içindeki silah) - parantez kutusu ve parıltı yarıçapı için.
static func used_rect(t: Texture2D) -> Rect2:
	var key: RID = t.get_rid()
	if not _used_cache.has(key):
		var img: Image = t.get_image()
		if img == null:
			_used_cache[key] = Rect2(Vector2.ZERO, t.get_size())
		else:
			if img.is_compressed():
				img = img.duplicate()
				img.decompress()
			_used_cache[key] = Rect2(img.get_used_rect())
	return _used_cache[key]


## İkiz/parıltı için kenar paylı (dış kenar ikonun dışına taşar) mip zincirli kopya - enchant_weapon_glow.gd _build_coverage ile aynı fikir,
## ama renkler korunur (ikizin açık/koyu tonları ikonun parlaklığından gelir).
static func padded(t: Texture2D, px: int, py: int) -> Texture2D:
	var key: String = "%s|%d|%d" % [t.get_rid(), px, py]
	if not _pad_cache.has(key):
		var img: Image = t.get_image()
		if img == null:
			return null
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var out := Image.create(img.get_width() + px * 2, img.get_height() + py * 2, false, Image.FORMAT_RGBA8)
		out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(px, py))
		out.generate_mipmaps()
		_pad_cache[key] = ImageTexture.create_from_image(out)
	return _pad_cache[key]


## Mermi kipi: 2 = Çift Tetik'in ikinci tetiği (ikizden), 1 = E açık (kehribar), 0 = normal. weapon.gd _fire_at çağırır.
static func projectile_mode(weapon: Node, echo_shot: bool) -> int:
	if echo_shot:
		return 2
	var p: Node = weapon.get_parent() if weapon else null
	if p != null and p.get("elara_true_damage_active") == true:
		return 1
	return 0


## Mermiye Elara görünümü: namlu parıltısı + incelen iz (1 kehribar, 2 turkuaz); 2'de mermi sprite'ları turkuaz ikiz silüeti olur.
## Kaster (weapon.gd _fire_at) ve uzak kopya (EnchantFx.apply_projectile_look, look["elara"]) aynı fonksiyon.
static func style_projectile(proj: Node2D, mode: int) -> void:
	if proj == null or mode <= 0 or not proj.is_inside_tree():
		return
	var pal: Array[Color] = AMB if mode == 1 else RUZ
	var spark := Spark.new()
	spark.pal = pal
	proj.get_tree().current_scene.add_child(spark)
	spark.global_position = proj.global_position
	var tr := Trail.new()
	tr.pal = pal
	proj.add_child(tr)
	if mode == 2:
		var sprites: Array = proj.find_children("*", "Node2D", true, false)
		sprites.append(proj)
		for c in sprites:
			if c is Sprite2D or c is AnimatedSprite2D:
				(c as CanvasItem).material = make_material(0, 1.0)


## ============================================================== sayfa oynatıcı
## Yatay şerit sayfa (hframes) 16 fps; sıra: [[ad, döngü mü], ...]. Döngüsüz son sayfa bitince kendini siler. finish(): çıkış sayfasına
## geçer (on_wrap: döngü başa dönünce - R ikiz okları açı sıçramasın diye).
class SheetAnim extends Sprite2D:
	var _seq: Array = []
	var _loop := false
	var _frame := 0
	var _t := 0.0
	var _delay := 0.0
	var _out := ""

	func setup(seq: Array, delay_frames: int = 0) -> SheetAnim:
		_seq = seq.duplicate()
		_delay = float(delay_frames) / ElaraFx.FPS
		visible = delay_frames <= 0
		_next()
		return self

	func _next() -> bool:
		if _seq.is_empty():
			queue_free()
			return false
		var s: Array = _seq.pop_front()
		var n: String = str(s[0])
		_loop = bool(s[1])
		texture = ElaraFx.tex(n)
		hframes = int(ElaraFx.SHEETS[n])
		frame = 0
		_frame = 0
		return true

	func finish(out_sheet: String, on_wrap: bool = false) -> void:
		if _delay > 0.0 or out_sheet == "":
			queue_free()
			return
		if on_wrap and _loop:
			_out = out_sheet
			return
		_seq = [[out_sheet, false]]
		_next()

	func _process(delta: float) -> void:
		if _delay > 0.0:
			_delay -= delta
			if _delay > 0.0:
				return
			visible = true
			_t = 0.0
		_t += delta
		var step: float = 1.0 / ElaraFx.FPS
		while _t >= step:
			_t -= step
			_frame += 1
			if _frame >= hframes:
				if _loop and _out == "":
					_frame = 0
				else:
					if _loop:
						_seq = [[_out, false]]
						_out = ""
					if not _next():
						return
					continue
			frame = _frame


## Karaktere bağlı sayfa (Driver'ın çocuğu, karakterle birlikte gider).
static func char_anim(driver: Node2D, anim: Node2D, seq: Array, z: int, delay_frames: int = 0) -> SheetAnim:
	var a := SheetAnim.new()
	a.z_index = z
	a.centered = true
	a.position = anim.position
	a.scale = _base_scale(driver.get_parent(), anim)
	driver.add_child(a)
	return a.setup(seq, delay_frames)


## Dünyada sabit sayfa (top_level - karakter yürüse de kullanıldığı yerde kalır).
static func world_anim(driver: Node2D, anim: Node2D, seq: Array, z: int, flip: bool) -> SheetAnim:
	var a := SheetAnim.new()
	a.top_level = true
	a.z_index = z
	a.centered = true
	a.flip_h = flip
	driver.add_child(a)
	var s: Vector2 = _base_scale(driver.get_parent(), anim) * _owner_scale(driver.get_parent())
	a.global_transform = Transform2D(0.0, s.abs(), 0.0, anim.global_position + vis_delta(driver.get_parent()))
	return a.setup(seq, 0)


## Sprite'ın TABAN ölçeği (vuruş sıkışması gibi geçici ölçek oynamaları efekti titretmesin): kaster char_base_anim_scale, uzak _base_anim_scale.
static func _base_scale(p: Node, anim: Node2D) -> Vector2:
	if p != null:
		var v: Variant = p.get("char_base_anim_scale")
		if v is Vector2:
			return (v as Vector2).abs()
		v = p.get("_base_anim_scale")
		if v is Vector2:
			return (v as Vector2).abs()
	return anim.scale.abs()


## Oyuncu fizik interpolasyonlu çizilir (physics_interp.gd): dünyada serbest (top_level) Elara görselleri ham konuma değil EKRANDA çizilen
## konuma otursun diye eklenen fark (yoksa koşarken 60 Hz'de 1-2 px önde/geride titrer).
static func vis_delta(p: Node) -> Vector2:
	if not (p is Node2D):
		return Vector2.ZERO
	return PhysicsInterpScript.visual_position(p as Node2D) - (p as Node2D).global_position


static func _owner_scale(p: Node) -> Vector2:
	return (p as Node2D).global_transform.get_scale().abs() if p is Node2D else Vector2.ONE


## ============================================================== Driver (kaster + uzak kopya)
class Driver extends Node2D:
	var _q := false
	var _e := false
	var _r := false
	var _e_ground: SheetAnim = null
	var _e_top: SheetAnim = null
	var _r_back: SheetAnim = null
	var _r_front: SheetAnim = null
	var _last_pos := Vector2.INF
	var _vel := Vector2.ZERO
	var _dir := Vector2.RIGHT
	var _ghost_t := 0.0
	var _streak_t := 0.0
	var _shell_t := 0.0
	var _shell_on := false
	var _streaks: Streaks = null
	var _shell: Sprite2D = null
	var _wfx_any := false

	func _process(delta: float) -> void:
		var p := get_parent() as Node2D
		if p == null:
			return
		var anim := p.get("anim") as AnimatedSprite2D
		if anim == null:
			return
		var pos: Vector2 = p.global_position
		if _last_pos != Vector2.INF and delta > 0.0:
			_vel = _vel.lerp((pos - _last_pos) / delta, 0.5)
		_last_pos = pos
		if _vel.length() > ElaraFx.MOVE_SPEED_MIN:
			_dir = _vel.normalized()
		var f: Array = ElaraFx.flags(p)
		if f[0] != _q:
			_q = f[0]
			if _q:
				_q_start(anim)
			else:
				_q_end(anim)
		if f[1] != _e:
			_e = f[1]
			if _e:
				_e_ground = ElaraFx.char_anim(self, anim, [["e_ring_in", false], ["e_ring_loop", true]], -1, 6)
				_e_top = ElaraFx.char_anim(self, anim, [["e_cast", false], ["e_chev", true]], 2)
			else:
				if is_instance_valid(_e_ground):
					_e_ground.finish("e_ring_out")
				if is_instance_valid(_e_top):
					_e_top.queue_free()
		if f[2] != _r:
			_r = f[2]
			if _r:
				ElaraFx.char_anim(self, anim, [["r_cast_top", false]], 2)
				ElaraFx.char_anim(self, anim, [["r_cast_ring", false]], -1, 1)
				_r_back = ElaraFx.char_anim(self, anim, [["r_wisp_back_in", false], ["r_wisp_back_loop", true]], -1, 4)
				_r_front = ElaraFx.char_anim(self, anim, [["r_wisp_front_in", false], ["r_wisp_front_loop", true]], 2, 4)
			else:
				if is_instance_valid(_r_back):
					_r_back.finish("r_wisp_back_out", true)
				if is_instance_valid(_r_front):
					_r_front.finish("r_wisp_front_out", true)
		if _q:
			_q_tick(delta, anim)
		if _e or _r or _wfx_any:
			_update_weapons(p)

	## ---------------------------------------------------------- Q
	func _q_start(anim: AnimatedSprite2D) -> void:
		ElaraFx.world_anim(self, anim, [["q_cast", false]], -1, _facing_left(anim))
		_ghost_t = 0.0
		if _streaks == null:
			_streaks = Streaks.new()
			add_child(_streaks)
		if _shell == null:
			_shell = Sprite2D.new()
			_shell.top_level = true
			_shell.z_index = 1
			_shell.material = ElaraFx.make_material(2, 0.5)
			add_child(_shell)
		_shell.visible = false
		_shell_on = false

	func _q_end(anim: AnimatedSprite2D) -> void:
		ElaraFx.world_anim(self, anim, [["q_end", false]], -1, _facing_left(anim))
		if _streaks:
			_streaks.on = false
			_streaks.refresh()
		if _shell:
			_shell.visible = false

	func _facing_left(anim: AnimatedSprite2D) -> bool:
		if absf(_dir.x) > 0.3:
			return _dir.x < 0.0
		return str(anim.animation).contains("left")

	func _q_tick(delta: float, anim: AnimatedSprite2D) -> void:
		var moving: bool = _vel.length() > ElaraFx.MOVE_SPEED_MIN
		var wpx: float = ElaraFx._base_scale(get_parent(), anim).x * ElaraFx._owner_scale(get_parent()).x
		## Ardıl görüntüler (yalnız hareket ederken)
		_ghost_t -= delta
		if moving and _ghost_t <= 0.0:
			_ghost_t = ElaraFx.GHOST_INTERVAL
			var g := Ghost.new()
			add_child(g)
			g.copy_from(anim, ElaraFx.vis_delta(get_parent()))
		## Bacak/bel rüzgâr çizgileri
		_streak_t += delta
		if _streak_t >= 1.0 / ElaraFx.FPS:
			_streak_t = fmod(_streak_t, 1.0 / ElaraFx.FPS)
			_streaks.step += 1
		_streaks.on = moving
		_streaks.dir = _dir
		_streaks.center = anim.global_position + ElaraFx.vis_delta(get_parent())
		_streaks.px = wpx
		_streaks.refresh()
		## Yaratığın içinden geçerken siluete turkuaz rüzgâr kabuğu (0,1 sn'de bir aday sorgusu)
		_shell_t -= delta
		if _shell_t <= 0.0:
			_shell_t = 0.1
			_shell_on = _overlapping_creature(anim.global_position + Vector2(0.0, 12.0 * wpx))
		_shell.visible = _shell_on
		if _shell_on:
			_shell.texture = ElaraFx.current_texture(anim)
			var sx: Transform2D = anim.global_transform
			sx.origin += ElaraFx.vis_delta(get_parent())
			_shell.global_transform = sx
			_shell.offset = anim.offset
			_shell.centered = anim.centered
			_shell.flip_h = anim.flip_h

	func _overlapping_creature(feet: Vector2) -> bool:
		for e in ElaraFx.EnemyQueryScript.candidates(get_tree(), feet, 14.0):
			if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true:
				continue
			if (e as Node2D).global_position.distance_to(feet) < 12.0:
				return true
		return false

	## ---------------------------------------------------------- silahlar
	func _update_weapons(p: Node) -> void:
		var list: Array = ElaraFx.icons(p)
		var vd: Vector2 = ElaraFx.vis_delta(p)
		var any := false
		for i in range(list.size()):
			var icon: Node2D = list[i]
			var w: Node = icon.get_node_or_null("ElaraWeaponFx")
			if w == null:
				if not (_e or _r):
					continue
				w = WeaponFx.new()
				w.name = "ElaraWeaponFx"
				icon.add_child(w)
			if w.call("update_state", _e, _r, i, vd):
				any = true
		_wfx_any = any


## Q bacak/bel rüzgâr çizgileri: koşu yönünün tersine, eksene hizalı 1 piksellik çizgiler (kuyruk yarısı seyrek), 3 sıra, 16 fps titreşim.
## FPS (2026-10-16): eskiden her karede ~40 draw_rect. Artık eksen (yatay/dikey) x faz (step % 3) için 6 doku BİR KEZ pişirilir; tek Sprite2D
## (1 doku pikseli = 1 sanat pikseli, yön tersine dönünce flip). Eski dikey kayma 11,2/5,2/-5,8 en yakın piksele yuvarlandı (<0,2 piksel).
class Streaks extends Sprite2D:
	static var _baked: Array = [] ## [eksen 0 yatay / 1 dikey][faz 0..2] -> [Texture2D, offset]
	var on := false
	var dir := Vector2.RIGHT
	var center := Vector2.ZERO
	var px := ElaraFx.PX
	var step := 0

	func _init() -> void:
		top_level = true
		z_index = 1
		centered = false
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visible = false

	## Doku: geri yönü -x (yatay) / -y (dikey) kabul edilir; zıt yön flip ile.
	static func _bake(horiz: bool, step_phase: int) -> Array:
		var rows: Array = [[11.2, 16, 0], [5.2, 12, 3], [-5.8, 9, 5]] if horiz else [[-6.0, 12, 0], [0.0, 9, 3], [6.0, 12, 5]]
		var u0: float = 7.0 if horiz else 18.0
		var pts: Array = [] ## [Vector2i hücre, Color]
		for r in rows:
			var ph: int = (step_phase + int(r[2])) % 3
			if ph == 2:
				continue
			var n: int = int(r[1]) + 1 + ph * 2
			for i in range(n):
				var u: float = float(i) / float(n)
				if u < 0.45 and i % 2 == 1:
					continue
				var col: Color = ElaraFx.RUZ[4] if u > 0.8 else (ElaraFx.RUZ[3] if u > 0.4 else ElaraFx.RUZ[2])
				var d: int = int(round(u0 + float(n - 1 - i)))
				var perp: int = int(round(float(r[0])))
				pts.append([Vector2i(-d, perp) if horiz else Vector2i(perp, -d), col])
		var lo := Vector2i(1000, 1000)
		var hi := Vector2i(-1000, -1000)
		for pc in pts:
			var c: Vector2i = pc[0]
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var img := Image.create(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_RGBA8)
		for pc in pts:
			var c2: Vector2i = pc[0]
			img.set_pixel(c2.x - lo.x, c2.y - lo.y, pc[1])
		return [ImageTexture.create_from_image(img), Vector2(float(lo.x) - 0.5, float(lo.y) - 0.5)]

	static func _entry(horiz: bool, phase: int) -> Array:
		if _baked.is_empty():
			for ax in range(2):
				var per: Array = []
				for ph in range(3):
					per.append(_bake(ax == 0, ph))
				_baked.append(per)
		return _baked[0 if horiz else 1][phase]

	## Driver her kare çağırır (on/dir/center/px/step ayarlandıktan sonra).
	func refresh() -> void:
		visible = on
		if not on:
			return
		var horiz: bool = absf(dir.x) >= absf(dir.y)
		var e: Array = _entry(horiz, step % 3)
		var tex: Texture2D = e[0]
		var off: Vector2 = e[1]
		flip_h = horiz and dir.x < 0.0
		flip_v = (not horiz) and dir.y < 0.0 ## taban: geri = -y (aşağı koşarken); yukarı koşarken geri = +y
		texture = tex
		## merkezsiz Sprite2D'de flip dokuyu kendi kutusunda aynalar: kutuyu origin'in öbür yanına taşı
		var o := off
		if flip_h:
			o.x = -(off.x + float(tex.get_width()))
		if flip_v:
			o.y = -(off.y + float(tex.get_height()))
		offset = o
		global_position = center
		scale = Vector2(px, px)


## Q ardıl görüntüsü: karakterin o anki karesi, dünyada sabit, turkuaz silüet; 4 karede Bayer ile seyrelip söner.
class Ghost extends Sprite2D:
	var _t := 0.0
	var _mat: ShaderMaterial

	func _init() -> void:
		top_level = true
		z_index = -1

	func copy_from(anim: AnimatedSprite2D, delta: Vector2) -> void:
		texture = ElaraFx.current_texture(anim)
		var xf: Transform2D = anim.global_transform
		xf.origin += delta
		global_transform = xf
		offset = anim.offset
		centered = anim.centered
		flip_h = anim.flip_h
		_mat = ElaraFx.make_material(2, ElaraFx.GHOST_LEVELS[0])
		material = _mat

	func _process(delta: float) -> void:
		_t += delta
		var i: int = int(_t * ElaraFx.FPS)
		if i >= ElaraFx.GHOST_LEVELS.size():
			queue_free()
			return
		_mat.set_shader_parameter("level", ElaraFx.GHOST_LEVELS[i])


## ============================================================== silah ikonu (E parantez + parıltı, R turkuaz ikiz)
## İkonun çocuğu (enchant_weapon_glow.gd ile aynı yerleşim: ikonla döner/aynalanır/gizlenir). Parantezler dünya uzayında, eksene hizalı
## (prototipteki gibi) - bu düğüm top_level, ikiz ve parıltı ise ikonun çocuğu olan iki Sprite2D.
class WeaponFx extends Node2D:
	const ECHO_LEVELS_IN: Array[float] = [0.3, 0.6, 0.85]
	const ECHO_LEVELS_OUT: Array[float] = [0.6, 0.35, 0.15]
	const ECHO_DELAY := 4.0 / ElaraFx.FPS ## ikizler çapraz okların yörüngeye indiği an belirir (prototip SPLIT)
	var _icon: Node2D = null
	var _slot := 0
	var _focus := false
	var _focus_t := 0.0
	var _echo_on := false
	var _echo_t := 0.0
	var _echo_level := 0.0
	var _echo: Sprite2D = null
	var _glint: Sprite2D = null
	var _src: Texture2D = null
	var _rect := Rect2()

	func _ready() -> void:
		_icon = get_parent() as Node2D
		top_level = true
		z_index = 3
		global_transform = Transform2D.IDENTITY

	## Driver her kare çağırır; dönüş: hâlâ bir şey gösteriyor mu (göstermiyorsa kendini siler).
	func update_state(focus: bool, echo: bool, slot: int, vis_delta: Vector2 = Vector2.ZERO) -> bool:
		var dt: float = get_process_delta_time()
		_slot = slot
		if focus and not _focus:
			_focus_t = 0.0
		_focus = focus
		if _focus:
			_focus_t += dt
		if echo != _echo_on:
			_echo_on = echo
			_echo_t = 0.0
		_echo_t += dt
		_echo_level = _echo_level_now()
		var tex_now: Texture2D = ElaraFx.current_texture(_icon)
		if tex_now != _src:
			_rebuild(tex_now)
		_rect = _world_rect()
		_rect.position += vis_delta ## parantez/parıltı ikonun EKRANDA çizildiği yere
		## İkiz (R)
		if _echo:
			_echo.visible = _echo_level > 0.0 and _icon.visible
			if _echo.visible:
				(_echo.material as ShaderMaterial).set_shader_parameter("level", _echo_level)
				_echo.position = _icon.get_global_transform().affine_inverse().basis_xform(ElaraFx.ECHO_OFFSET)
				_echo.flip_h = bool(_icon.get("flip_h"))
				_echo.flip_v = bool(_icon.get("flip_v"))
		## Parıltı (E): kilitten sonra 8 karede bir, silahlar 2 kare arayla sırayla
		var sweep := -1.0
		if _focus and _focus_t > 8.0 / ElaraFx.FPS:
			var g: float = fmod(_focus_t * ElaraFx.FPS - 8.0 - float(_slot) * 2.0 + 80.0, 8.0)
			if g <= 4.0:
				sweep = g / 4.0
		if _glint:
			_glint.visible = sweep >= 0.0 and _icon.visible
			var m := _glint.material as ShaderMaterial
			m.set_shader_parameter("sweep", sweep)
			m.set_shader_parameter("glint_c", _rect.get_center())
			m.set_shader_parameter("glint_r", maxf(4.0, _rect.size.length() * 0.5))
			_glint.flip_h = bool(_icon.get("flip_h"))
			_glint.flip_v = bool(_icon.get("flip_v"))
		queue_redraw()
		var alive: bool = _focus or _echo_on or _echo_level > 0.0
		if not alive:
			_cleanup()
		return alive

	func _echo_level_now() -> float:
		if _echo_on:
			if _echo_t < ECHO_DELAY:
				return 0.0
			var k: int = int((_echo_t - ECHO_DELAY) * ElaraFx.FPS)
			return ECHO_LEVELS_IN[mini(k, ECHO_LEVELS_IN.size() - 1)]
		if _echo_level <= 0.0: ## hiç görünmedi ya da söndü
			return 0.0
		var i: int = int(_echo_t * ElaraFx.FPS)
		return ECHO_LEVELS_OUT[i] if i < ECHO_LEVELS_OUT.size() else 0.0

	func _rebuild(t: Texture2D) -> void:
		_src = t
		if t == null:
			return
		var gs: Vector2 = _icon.get_global_transform().get_scale().abs()
		var px: int = int(ceilf(3.0 / maxf(gs.x, 0.02))) + 1
		var py: int = int(ceilf(3.0 / maxf(gs.y, 0.02))) + 1
		var pt: Texture2D = ElaraFx.padded(t, px, py)
		if _echo == null:
			_echo = _make_sprite(0, true)
			_glint = _make_sprite(1, false)
		var centered: bool = bool(_icon.get("centered"))
		var icon_offset: Vector2 = _icon.get("offset") as Vector2
		for s: Sprite2D in [_echo, _glint]:
			s.texture = pt
			s.centered = centered
			s.offset = icon_offset if centered else icon_offset - Vector2(px, py)

	func _make_sprite(mode: int, behind: bool) -> Sprite2D:
		var s := Sprite2D.new()
		s.show_behind_parent = behind
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.material = ElaraFx.make_material(mode, 0.85)
		s.visible = false
		_icon.add_child(s)
		return s

	## İkonun dolu bölgesinin dünya uzayındaki eksene hizalı kutusu.
	func _world_rect() -> Rect2:
		if _src == null:
			return Rect2(_icon.global_position, Vector2.ZERO)
		var used: Rect2 = ElaraFx.used_rect(_src)
		var size: Vector2 = _src.get_size()
		var o: Vector2 = (_icon.get("offset") as Vector2) - (size * 0.5 if bool(_icon.get("centered")) else Vector2.ZERO)
		var xf: Transform2D = _icon.get_global_transform()
		var r := Rect2(xf * (o + used.position), Vector2.ZERO)
		for c in [o + used.position + Vector2(used.size.x, 0.0), o + used.position + Vector2(0.0, used.size.y), o + used.end]:
			r = r.expand(xf * c)
		return r

	## E başlangıcı: köşe parantezleri ikonun üstüne kapanır (6 kare), krem kilit, kehribar sönüş - prototip box_brackets.
	func _draw() -> void:
		if not _focus or not _icon.visible:
			return
		var i: int = int(_focus_t * ElaraFx.FPS)
		if i > 7:
			return
		var pad: float
		var col: Color = ElaraFx.AMB[3]
		if i < 6:
			var e: float = 1.0 - pow(1.0 - minf(1.0, float(i) / 5.0), 2.0)
			pad = 2.5 + 7.0 * (1.0 - e)
		elif i == 6:
			pad = 2.5
			col = ElaraFx.CREAM
		else:
			pad = 4.0
			col = ElaraFx.AMB[4]
		var c: Vector2 = _rect.get_center()
		var hw: float = _rect.size.x * 0.5 + pad * ElaraFx.PX
		var hh: float = _rect.size.y * 0.5 + pad * ElaraFx.PX
		var arm: float = 3.0 * ElaraFx.PX
		var th: float = 1.3 * ElaraFx.PX
		for pass_i in range(2):
			var grow: float = ElaraFx.PX if pass_i == 0 else 0.0
			var cc: Color = ElaraFx.AMB[0] if pass_i == 0 else col
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var p := Vector2(c.x + sx * hw, c.y + sy * hh)
					var hx: float = minf(p.x, p.x - sx * arm)
					var vy: float = minf(p.y, p.y - sy * arm)
					draw_rect(Rect2(hx - grow, p.y - th * 0.5 - grow, arm + th * 0.5 + grow * 2.0, th + grow * 2.0), cc)
					draw_rect(Rect2(p.x - th * 0.5 - grow, vy - grow, th + grow * 2.0, arm + th * 0.5 + grow * 2.0), cc)

	func _cleanup() -> void:
		for s in [_echo, _glint]:
			if is_instance_valid(s):
				s.queue_free()
		queue_free()


## ============================================================== mermi izi + namlu parıltısı
## İncelen iz: merminin arkasında (show_behind_parent), dünya uzayında, 13 birim; kat kat ton (kontur -> parlak çekirdek).
## FPS (2026-10-16): eskiden her mermi her karede 4 çokgen çiziyordu (40 mermi = +3,2 ms). Artık palete/boya göre BİR KEZ pişirilen tek doku
## (tam boy üçgen, baş sağ kenarda) + tek Sprite2D: kare başına sadece konum/açı/x-ölçeği (iz boyu kısalırken doku boyuna ölçeklenir).
class Trail extends Sprite2D:
	const TEXELS := 6.0 ## dünya birimi başına doku pikseli
	static var _baked: Dictionary = {}
	var pal: Array[Color] = []
	## Uzunluk / kalınlık (Elara sanat pikseli). Büyücü pasifinin güçlendirilmiş mermisi (BuyucuFx.style_surge_projectile) daha uzun/kalın kullanır.
	var len_px := 13.0
	var width_px := 2.2
	var _start := Vector2.INF
	var _head := Vector2.ZERO
	var _dir := Vector2.RIGHT
	var _len_world := 0.0
	var _tex_w := 1
	## Mermi fizik interpolasyonlu (projectile.gd opt_in) ve _physics_process'te ilerler: iz başı ham konumda kalırsa mermiden bir adım
	## önde görünür -> son iki fizik adımı tutulur, çizimde interpolasyon kesriyle ara konum alınır (physics_interp.gd visual_position fikri).
	var _prev := Vector2.INF
	var _cur := Vector2.INF

	## Tam boy iz dokusu (baş sağda, orta çizgi dokunun ortasında). İç içe 4 üçgen: en içteki kaplayan katman rengi kazanır.
	static func baked_texture(p_pal: Array[Color], p_len_px: float, p_width_px: float) -> Texture2D:
		var key := "%s|%s|%s%s%s%s" % [p_len_px, p_width_px, p_pal[1].to_html(), p_pal[2].to_html(), p_pal[3].to_html(), p_pal[4].to_html()]
		if _baked.has(key):
			return _baked[key]
		var w: float = p_width_px * ElaraFx.PX * 0.5
		var hws: Array[float] = [w + ElaraFx.PX * 0.6, w, w * 0.72, w * 0.36]
		var tw: int = maxi(2, int(ceil(p_len_px * ElaraFx.PX * TEXELS)))
		var half: int = int(ceil(hws[0] * TEXELS)) + 1
		var img := Image.create(tw, half * 2, false, Image.FORMAT_RGBA8)
		for x in range(tw):
			var t: float = (float(x) + 0.5) / float(tw) ## 0 kuyruk ucu ... 1 baş
			for y in range(half * 2):
				var dy: float = absf(float(y) + 0.5 - float(half)) / TEXELS
				var col := Color(0.0, 0.0, 0.0, 0.0)
				for i in range(4):
					if dy <= hws[i] * t:
						col = p_pal[i + 1]
				img.set_pixel(x, y, col)
		var tex := ImageTexture.create_from_image(img)
		_baked[key] = tex
		return tex

	func _ready() -> void:
		top_level = true
		show_behind_parent = true
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF ## konumu _process'te biz yazıyoruz
		centered = false
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		texture = baked_texture(pal, len_px, width_px)
		_tex_w = texture.get_width()
		offset = Vector2(-float(_tex_w), -float(texture.get_height()) * 0.5)
		_len_world = len_px * ElaraFx.PX
		_start = (get_parent() as Node2D).global_position
		_head = _start
		_prev = _start
		_cur = _start
		visible = false

	func _physics_process(_delta: float) -> void:
		_prev = _cur
		_cur = (get_parent() as Node2D).global_position

	func _process(_delta: float) -> void:
		var par := get_parent() as Node2D
		var h: Vector2 = par.global_position
		if par.is_physics_interpolated_and_enabled() and _prev.distance_squared_to(_cur) < 4096.0:
			h = _prev.lerp(_cur, Engine.get_physics_interpolation_fraction())
		if h.distance_squared_to(_head) > 0.01:
			_dir = (h - _head).normalized()
		_head = h
		var L: float = minf(_len_world, _head.distance_to(_start))
		if L < 1.0:
			visible = false
			return
		visible = true
		global_position = _head
		rotation = _dir.angle()
		scale = Vector2(L / float(_tex_w), 1.0 / TEXELS)


## Namlu parıltısı: 2 kare artı (beyaz çekirdek, renkli kollar), dünya pikselinde.
## FPS (2026-10-16): draw_rect yerine palet başına BİR KEZ pişirilen iki küçük doku (1 doku pikseli = 1 dünya sanat pikseli).
class Spark extends Sprite2D:
	static var _baked: Dictionary = {}
	var pal: Array[Color] = []
	var _t := 0.0
	var _frame := -1

	func _init() -> void:
		z_index = 5
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		scale = Vector2(ElaraFx.PX, ElaraFx.PX)

	## [büyük artı (2 kol), tek nokta]
	static func baked(p_pal: Array[Color]) -> Array:
		var key: String = p_pal[3].to_html()
		if _baked.has(key):
			return _baked[key]
		var big := Image.create(5, 5, false, Image.FORMAT_RGBA8)
		for i in range(1, 3):
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				big.set_pixel(2 + d.x * i, 2 + d.y * i, p_pal[3])
		big.set_pixel(2, 2, Color.WHITE)
		var dot := Image.create(5, 5, false, Image.FORMAT_RGBA8)
		dot.set_pixel(2, 2, Color.WHITE)
		var out: Array = [ImageTexture.create_from_image(big), ImageTexture.create_from_image(dot)]
		_baked[key] = out
		return out

	func _ready() -> void:
		texture = baked(pal)[0]
		_frame = 0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= 2.0 / ElaraFx.FPS:
			queue_free()
			return
		var f: int = 0 if _t < 1.0 / ElaraFx.FPS else 1
		if f != _frame:
			_frame = f
			texture = baked(pal)[f]
