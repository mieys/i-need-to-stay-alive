extends Node2D

## MANA KALKANI görseli "B - Mühür" (kullanıcı 2026-10-14, CLAUDE.md madde 148: prototip B seçildi; Kale mor, Enerji sarı;
## "kazmayla vurunca çatlama olmamalı"; "kalkan kırılınca her taraftan kırılmış gibi görünmeli"). Eski su baloncuğu
## (shield_visual.gd) artık SADECE Şovalye R kubbesi (is_shielded) için; mana kalkanının bütün görseli burada:
##   - darbe (madde 572, eski dönen mühür kalktı - "3D izometrik gibi"): darbe baloncuğa DIŞARIDAN vurur - vurulan noktada
##     baloncuğun kendi sanatı yuvarlak yama hâlinde belirip söner, kenar parlar (A "Işıyan Yüzey", shaders/kalkan_darbe);
##     menzilli atışta (ranged_hit, shield_bubble_hit.gd: mermi baloncuğun kenarında söner) ek olarak kıvılcımlar DIŞARI seker
##   - kırılma (darbe kalkanı 0'a indirdi): karakteri saran küre mühür her yanından çatlar, parçalar dört bir yana saçılır
##   - yenilenme: ayak altında mühür; dolan kısım (kalkan/azami) parlak, kalanı soluk; her tikte ilerler
##   - doldu: yer mührü parlayıp söner, ayaktan başa bir halka tarar
##   - yetenek bedeli / kazma / kalkan azalması: HİÇBİR görsel yok
## Savaş Mana Kalkanı sürekli yenilendiği için yer mührü/doldu göstermez (eski kural: "sadece hasar alınca görünsün").
## Yenilenme/doldu sahibin item_shield_hp/item_shield_max değerlerinden OKUNUR -> yerel oyuncu ile uzak kukla aynı kodu
## çalıştırır (kukla değerleri anlık görüntüden alır). Darbe/kırılma olayla gelir: yerelde player.gd take_damage,
## uzakta network_manager.gd "shield_hit_flash" (with_ring + broke) - MP iki-yer kuralı.
## Katmanlar: bu düğüm ÖN katman (sahibin son çocuklarından, karakter sprite'ından sonra çizilir); arka katman sahibin
## show_behind_parent çocuğu "ManaShieldBack". İkisi de her kare ayak noktasına + karakter piksel ölçeğine (anim.scale)
## oturur: 1 sanat px = 1 karakter pikseli (prototiple birebir). Sayfalar tools/gen_mana_shield_fx.py'den (ton numaralı),
## renk shaders/mana_shield.gdshader + PALETTES.

const BREAK_BACK_TEX: Texture2D = preload("res://assets/fx/mana_shield/break_back.png")
const BREAK_FRONT_TEX: Texture2D = preload("res://assets/fx/mana_shield/break_front.png")
const GROUND_TEX: Texture2D = preload("res://assets/fx/mana_shield/ground.png")
const RISE_BACK_TEX: Texture2D = preload("res://assets/fx/mana_shield/rise_back.png")
const RISE_FRONT_TEX: Texture2D = preload("res://assets/fx/mana_shield/rise_front.png")
const DEBRIS_TEX: Texture2D = preload("res://assets/fx/mana_shield/debris.png")
const EnemyAbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const SHADER: Shader = preload("res://shaders/mana_shield.gdshader")
const HIT_SHADER: Shader = preload("res://shaders/kalkan_darbe.gdshader")

## --- tools/gen_mana_shield_fx.py ile AYNI tutulmalı ---
const BREAK_FRAMES := 14
const BREAK_BODY := Vector2(44.0, 42.0) ## kırılma hücresinde gövde merkezi
const GROUND_C := Vector2(23.0, 11.0) ## yer mührü hücresinde elips merkezi
const GROUND_R := Vector2(17.0, 6.0)
const RISE_FRAMES := 11
const RISE_FEET := Vector2(20.0, 48.0)
const FEET_TO_BODY := 15.0
const DEBRIS_FRAMES := 2 ## 0 = yeni düşmüş (parıltılı), 1 = sönmüş
const DEBRIS_FEET := Vector2(44.0, 24.0)
const FPS := 20.0
## ---

## --- Darbe (madde 572): baloncuğun texel ızgarasında; düğüm ölçeği = ShieldVisual/BubbleSprite ölçeği ---
const HIT_CANVAS := 48 ## shader tuvali (texel); baloncuk karesi 24x24, kıvılcımlar dışarı taşar
const BUBBLE_R := 11.0 ## baloncuğun görünen yarıçapı (texel) - shield_bubble_hit.gd BUBBLE_R ile aynı
const HIT_LIFE := 0.55 ## yama 0,5 sn'de söner
const MAX_HITS := 4 ## shader dizisi
const SPARK_TIME := 0.32 ## menzilli: seken kıvılcımların uçuşu
const SPARK_OFFS := [-1.05, -0.45, 0.45, 1.05] ## dış normale göre (rad), her darbede +-0,15 sarsılır
const BUBBLE_LOOP_FPS := 10.0 ## baloncuk "loop" klibinin hızı (bubble_frames.tres)
const REGEN_HOLD := 1.3 ## son artıştan sonra yer mührü bu kadar açık kalır (tik saniyede 1, SHIELD_REGEN_TICK_INTERVAL)
const REGEN_FADE := 0.2
const RISE_DURATION := RISE_FRAMES / FPS
const BREAK_DURATION := BREAK_FRAMES / FPS
## Yere düşen kırıklar (kullanıcı 2026-10-14: "kalkan patladığında çatlaklar yere düşüp yavaşça kaybolsun"): kırılmanın
## son karesiyle birebir başlar, DÜNYAYA sabit (oyuncu yürüse de yerinde kalır), zemin katmanında.
## Kalkan görsellerinin ortak saydamlığı (kullanıcı 2026-10-14: "kalkanın bir miktar saydam olmasını istiyorum"):
## mühür, küre, yer mührü, tarama, kıvılcım ve yerdeki kırıkların hepsi bununla çarpılır. 1 = tam opak.
const SHIELD_ALPHA := 0.7
const DEBRIS_DIM_AT := 0.6 ## parıltı söner
const DEBRIS_FADE_FROM := 1.0
const DEBRIS_FADE := 1.6
const GLINT_LIFE := 0.3
const SAVAS := "shield_savas"
const STANDART := "shield_standart"

const CREAM := Color8(255, 250, 228)
const WHITE := Color8(255, 255, 255)
## [kontur, koyu, orta, açık, parlak] - gen_mana_shield_fx.py PALS ile aynı. Anahtar = GÖRSEL anahtarı: oyunda hangi türün hangi paleti
## gösterdiği ShieldEnchantDefs.EFFECT_OF'ta (2026-11-09: Standart sarı, Enerji mor, Kale mavi); paletin kendisi Kale mor, Enerji sarı (2026-10-14).
const PALETTES := {
	"shield_standart": [Color8(14, 22, 70), Color8(36, 70, 164), Color8(74, 136, 232), Color8(150, 204, 255), Color8(228, 244, 255)],
	"shield_savas": [Color8(64, 8, 20), Color8(146, 28, 40), Color8(222, 68, 64), Color8(255, 146, 124), Color8(255, 230, 222)],
	"shield_enerji": [Color8(70, 44, 4), Color8(164, 112, 14), Color8(236, 186, 36), Color8(255, 226, 108), Color8(255, 249, 212)],
	"shield_kale": [Color8(34, 12, 64), Color8(86, 38, 148), Color8(146, 84, 214), Color8(204, 156, 250), Color8(244, 228, 255)],
}

var host: Node2D = null
var play_sounds: bool = false
## true: SADECE darbe mührü (hasar alma efekti) çalışır; kırılma/yenilenme/doldu görselleri kapalı (eski kalkan baloncuğu
## onları gösterir). 2026-10-14: kullanıcı "herşey eski kalkandaki gibi, sadece hasar alma efekti yeni".
var hit_only: bool = false
var _back: Node2D = null
var _mat: ShaderMaterial = null
var _ground_mat: ShaderMaterial = null
var _ground: Sprite2D = null
var _break_back: Sprite2D = null
var _break_front: Sprite2D = null
var _rise_back: Sprite2D = null
var _rise_front: Sprite2D = null
var _hits: Array = [] ## {"angle": float, "age": float, "ranged": bool, "spark": Array, "reach": float}
var _surf: Node2D = null ## darbe katmanı: sahibin son çocuğu, BubbleSprite'ın konum + ölçeğinde
var _surf_spr: Sprite2D = null
var _surf_px: Node2D = null
var _surf_mat: ShaderMaterial = null
var _surf_light: Color = Color(0.8, 1.0, 0.7)
var _surf_light_key: String = ""
var _clock: float = 0.0
var _last_ranged_msec: int = -100000
var _type: String = "-"
var _pal: Array = []
var _break_age: float = -1.0
var _break_anchor: Vector2 = Vector2.ZERO ## kırılma anındaki gövde merkezi (dünya): parçalar orada uçar, oraya düşer
var _break_px: Vector2 = Vector2.ONE
var _rise_age: float = -1.0
var _regen_on: bool = false
var _regen_hold: float = 0.0
var _ground_fade: float = -1.0 ## >= 0: yer mührü sönüyor
var _ground_fade_dur: float = REGEN_FADE
var _shown_progress: float = 0.0
var _last_hp: float = -1.0
var _last_max: float = -1.0
var _glint: float = 0.0
var _suppressed: bool = false
var _suppress_until_msec: int = 0
var _break_sound: AudioStreamPlayer2D = null
var _regen_sound: AudioStreamPlayer2D = null


## Sahibe ön + arka katmanı ekler. with_sounds: kırılma/yenilenme sesleri (eskiden baloncukta; sadece yerel oyuncuda).
static func attach(owner_node: Node2D, with_sounds: bool) -> Node2D:
	var back := Node2D.new()
	back.name = "ManaShieldBack"
	back.show_behind_parent = true ## karakter sprite'ından (kardeş düğüm) ÖNCE çizilir
	owner_node.add_child(back)
	var fx: Node2D = (load("res://scripts/mana_shield_fx.gd") as GDScript).new()
	fx.name = "ManaShieldFx"
	fx.host = owner_node
	fx.play_sounds = with_sounds
	fx.set("_back", back)
	owner_node.add_child(fx)
	return fx


func _ready() -> void:
	if host == null:
		host = get_parent() as Node2D
	if _back == null:
		_back = Node2D.new()
		_back.name = "ManaShieldBack"
		_back.show_behind_parent = true
		host.add_child.call_deferred(_back)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = _make_mat(false)
	_ground_mat = _make_mat(true)
	_ground = _sprite(_back, GROUND_TEX, 1, _ground_mat)
	_ground.position = Vector2(0.0, 1.0) - GROUND_C
	_break_back = _sprite(_back, BREAK_BACK_TEX, BREAK_FRAMES, _mat)
	_break_back.position = Vector2(0.0, -FEET_TO_BODY) - BREAK_BODY
	_break_front = _sprite(self, BREAK_FRONT_TEX, BREAK_FRAMES, _mat)
	_break_front.position = _break_back.position
	_rise_back = _sprite(_back, RISE_BACK_TEX, RISE_FRAMES, _mat)
	_rise_back.position = -RISE_FEET
	_rise_front = _sprite(self, RISE_FRONT_TEX, RISE_FRAMES, _mat)
	_rise_front.position = -RISE_FEET
	_back.draw.connect(_draw_back)
	_build_hit_layer()
	set_shield_type(STANDART)
	if play_sounds:
		_break_sound = _copy_sound("ShieldVisual/BreakSound")
		_regen_sound = _copy_sound("ShieldVisual/RegenSound")


## Darbe katmanı (madde 572): sahibin SON çocuğu (karakter sprite'ından + baloncuktan sonra çizilir), her karede
## ShieldVisual/BubbleSprite'ın konum + ölçeğine oturur -> 1 birim = 1 baloncuk texel'i. Shader yüzeyi + piksel çocuğu.
func _build_hit_layer() -> void:
	_surf = Node2D.new()
	_surf.name = "ManaShieldHit"
	_surf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_surf.visible = false
	_surf_spr = Sprite2D.new()
	_surf_spr.texture = _blank_canvas()
	_surf_spr.centered = true
	_surf_mat = ShaderMaterial.new()
	_surf_mat.shader = HIT_SHADER
	_surf_mat.set_shader_parameter("canvas_px", float(HIT_CANVAS))
	_surf_spr.material = _surf_mat
	_surf.add_child(_surf_spr)
	_surf_px = Node2D.new()
	_surf.add_child(_surf_px)
	_surf_px.draw.connect(_draw_hit_pixels)
	host.add_child.call_deferred(_surf)


static var _blank_tex: ImageTexture = null


static func _blank_canvas() -> ImageTexture:
	if _blank_tex == null:
		_blank_tex = ImageTexture.create_from_image(Image.create(HIT_CANVAS, HIT_CANVAS, false, Image.FORMAT_RGBA8))
	return _blank_tex


func _make_mat(progress: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("use_progress", progress)
	m.set_shader_parameter("ell_center", GROUND_C)
	m.set_shader_parameter("ell_radii", GROUND_R)
	return m


func _sprite(parent: Node2D, tex: Texture2D, hframes: int, mat: ShaderMaterial) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = hframes
	s.centered = false
	s.material = mat
	s.visible = false
	parent.add_child(s)
	return s


func _copy_sound(path: String) -> AudioStreamPlayer2D:
	var src: AudioStreamPlayer2D = host.get_node_or_null(path) as AudioStreamPlayer2D
	if src == null or src.stream == null:
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = src.stream
	p.volume_db = src.volume_db
	p.bus = src.bus
	add_child(p)
	return p


## Kalkan türü -> palet (yerelde player.gd _update_shield_bubble, uzakta anlık görüntü "shield_type").
func set_shield_type(key: String) -> void:
	if key == _type:
		return
	_type = key
	_pal = PALETTES.get(ShieldEnchantDefs.effect_key(key), PALETTES[STANDART]) ## efekt eşlemesi: shield_enchant_defs.gd EFFECT_OF
	for m: ShaderMaterial in [_mat, _ground_mat]:
		if m == null:
			continue
		for i in 5:
			m.set_shader_parameter("c%d" % i, _pal[i])
		m.set_shader_parameter("c5", CREAM)
		m.set_shader_parameter("c6", WHITE)
	if key == SAVAS and _regen_on:
		_stop_regen()


## Kalkan hasar soğurdu (yakın dövüş / temas). broke = bu darbe kalkanı 0'a indirdi -> her taraftan kırılma.
## Yerelde player.gd take_damage, uzakta network_manager.gd "shield_hit_flash".
func hit(angle: float, broke: bool) -> void:
	if _is_suppressed():
		return
	if hit_only and broke:
		return ## kalkanı bitiren darbede efekt YOK (kırılmayı eski baloncuk gösterir)
	if broke:
		_play_break()
	else:
		_add_hit(angle, false)
	_after_hit()


## MENZİLLİ atış baloncuğun dış kenarında söndü (shield_bubble_hit.gd impact - her makine kendi mermi kopyasıyla çağırır,
## ağ olayı yok): A yaması + dışarı seken kıvılcımlar. Hasar (ve kalkanın düşmesi) ayrıca hedefin kendi makinesinde gelir.
func ranged_hit(angle: float) -> void:
	if _is_suppressed():
		return
	_last_ranged_msec = Time.get_ticks_msec()
	_add_hit(angle, true)
	_after_hit()


## Menzilli hasar geldi ama bu makinede o merminin kopyası baloncuğa değmedi (kalkan durumu ağda bir an farklıydı ya da
## ateş topu patlaması gibi alan hasarı): son 0,25 sn'de menzilli darbe gösterilmediyse kaynağın yönünde gösterir.
func ranged_hit_if_missing(angle: float) -> void:
	if Time.get_ticks_msec() - _last_ranged_msec > 250:
		ranged_hit(angle)


func _add_hit(angle: float, ranged: bool) -> void:
	var sparks: Array = []
	if ranged:
		for off: float in SPARK_OFFS:
			sparks.append(off + randf_range(-0.15, 0.15))
	_hits.append({"angle": angle, "age": 0.0, "ranged": ranged, "spark": sparks, "reach": randf_range(7.5, 9.5)})
	if _hits.size() > MAX_HITS:
		_hits.pop_front()


func _after_hit() -> void:
	## Darbe yenilenme beklemesini sıfırlar: yer mührü söner.
	_regen_hold = 0.0
	if _regen_on:
		_stop_regen()


## Ölü/düşmüş yerel oyuncu: her kare çağrılır (player.gd _hide_combat_visuals_while_dead).
func suppress() -> void:
	_suppress_until_msec = Time.get_ticks_msec() + 150
	if is_anything_visible():
		hide_all()


## Uzak kukla: kalıcı ölü iken hiçbir şey gösterme.
func set_suppressed(value: bool) -> void:
	_suppressed = value
	if value and is_anything_visible():
		hide_all()


func hide_all() -> void:
	_hits.clear()
	if _surf:
		_surf.visible = false
	for s: Sprite2D in [_ground, _break_back, _break_front, _rise_back, _rise_front]:
		if s:
			s.visible = false
	_break_age = -1.0
	_rise_age = -1.0
	_regen_on = false
	_ground_fade = -1.0
	_glint = 0.0
	if _back:
		_back.queue_redraw()


func is_anything_visible() -> bool:
	if not _hits.is_empty():
		return true
	for s: Sprite2D in [_ground, _break_back, _break_front, _rise_back, _rise_front]:
		if s and s.visible:
			return true
	return false


func is_regen_shown() -> bool:
	return _regen_on


## Görünen darbe sayısı (yakın + menzilli); ranged_only: yalnız menzilliler.
func hit_count(ranged_only: bool = false) -> int:
	if not ranged_only:
		return _hits.size()
	var n := 0
	for h: Dictionary in _hits:
		if bool(h["ranged"]):
			n += 1
	return n


func _is_suppressed() -> bool:
	return _suppressed or Time.get_ticks_msec() < _suppress_until_msec


func _host_value(prop: String) -> float:
	if host == null or not (prop in host):
		return 0.0
	return float(host.get(prop))


func _process(delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	_follow_host()
	if _is_suppressed():
		_last_hp = _host_value("item_shield_hp")
		return
	if not hit_only:
		_update_regen(delta)
	_update_hits(delta)
	_update_break(delta)
	_update_rise(delta)
	_update_ground_fade(delta)
	if _glint > 0.0:
		_glint = maxf(0.0, _glint - delta)
		_back.queue_redraw()


## Katmanları ayak noktasına ve karakter piksel ölçeğine oturtur; çalıdaki/görünmez karakterin saydamlığını izler.
func _follow_host() -> void:
	var anim: AnimatedSprite2D = host.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var s := Vector2.ONE
	var feet := Vector2.ZERO
	var alpha := 1.0
	if anim:
		s = anim.scale.abs()
		var half_h := 24.0
		if anim.sprite_frames and anim.sprite_frames.has_animation(anim.animation):
			var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex:
				half_h = tex.get_height() * 0.5
		## 48x48 hücrede ayak 40. satırda: merkez + 16 = yarı yükseklik x 2/3.
		feet = anim.position + (Vector2(0.0, half_h * 2.0 / 3.0) + anim.offset) * s
		if anim.visible:
			alpha = anim.modulate.a * anim.self_modulate.a
	position = feet
	scale = s
	modulate.a = alpha * SHIELD_ALPHA
	if _back:
		_back.position = feet
		_back.scale = s
		_back.modulate.a = alpha * SHIELD_ALPHA


func _update_regen(delta: float) -> void:
	var hp := _host_value("item_shield_hp")
	var mx := _host_value("item_shield_max")
	if mx <= 0.0:
		_last_hp = hp
		_last_max = mx
		if _regen_on:
			_stop_regen()
		return
	var frac := clampf(hp / mx, 0.0, 1.0)
	## Yalnız ARTIŞ yer mührünü açar; azalma (darbe olay ile gelir, yetenek bedeli/kazma) görsel üretmez. Azami kalkan bu
	## kare değiştiyse (kart/eşya, kuklanın ilk anlık görüntüsü) artış yenilenme sayılmaz - sahte "doldu" oynamasın.
	var same_max := absf(mx - _last_max) < 0.01
	_last_max = mx
	if same_max and _last_hp >= 0.0 and hp > _last_hp + 0.01 and _type != SAVAS and _break_age < 0.0:
		_regen_hold = REGEN_HOLD
		if not _regen_on and _last_hp < mx - 0.01:
			_start_regen(clampf(_last_hp / mx, 0.0, 1.0))
		_glint = GLINT_LIFE
		if _regen_on and frac >= 0.999:
			_play_full()
	_last_hp = hp
	if not _regen_on:
		return
	_shown_progress = lerpf(_shown_progress, frac, minf(1.0, delta * 12.0))
	_ground_mat.set_shader_parameter("progress", _shown_progress)
	_regen_hold -= delta
	if _regen_hold <= 0.0:
		_stop_regen()


func _start_regen(from_frac: float) -> void:
	_regen_on = true
	_shown_progress = from_frac
	_ground_fade = -1.0
	_ground.visible = true
	_ground.modulate.a = 1.0
	_ground_mat.set_shader_parameter("progress", from_frac)
	_ground_mat.set_shader_parameter("flash", 0.0)
	if _regen_sound:
		_regen_sound.pitch_scale = randf_range(0.92, 1.08)
		_regen_sound.play()


func _stop_regen() -> void:
	_regen_on = false
	_fade_ground(REGEN_FADE)


func _fade_ground(dur: float) -> void:
	if _ground and _ground.visible:
		_ground_fade = 0.0
		_ground_fade_dur = dur


func _update_ground_fade(delta: float) -> void:
	if _ground_fade < 0.0:
		return
	_ground_fade += delta
	_ground.modulate.a = 1.0 - clampf(_ground_fade / _ground_fade_dur, 0.0, 1.0)
	if _ground_fade >= _ground_fade_dur:
		_ground.visible = false
		_ground_fade = -1.0


func _play_full() -> void:
	_regen_on = false
	_shown_progress = 1.0
	_ground_mat.set_shader_parameter("progress", 1.0)
	_rise_age = 0.0
	_rise_back.visible = true
	_rise_front.visible = true
	_rise_back.frame = 0
	_rise_front.frame = 0
	_fade_ground(RISE_DURATION)


func _update_rise(delta: float) -> void:
	if _rise_age < 0.0:
		return
	_rise_age += delta
	_ground_mat.set_shader_parameter("flash", maxf(0.0, 1.0 - _rise_age * 4.0))
	if _rise_age >= RISE_DURATION:
		_rise_back.visible = false
		_rise_front.visible = false
		_rise_age = -1.0
		_ground_mat.set_shader_parameter("flash", 0.0)
		return
	var fr := mini(RISE_FRAMES - 1, int(_rise_age * FPS))
	_rise_back.frame = fr
	_rise_front.frame = fr


## Darbeleri yaşlandırır; varsa katmanı baloncuğun o anki konum/ölçeğine + "loop" karesine oturtup shader'a yazar.
func _update_hits(delta: float) -> void:
	if _hits.is_empty():
		if _surf and _surf.visible:
			_surf.visible = false
		return
	_clock += delta
	for i in range(_hits.size() - 1, -1, -1):
		_hits[i]["age"] = float(_hits[i]["age"]) + delta
		if float(_hits[i]["age"]) >= HIT_LIFE:
			_hits.remove_at(i)
	if _surf == null or not _surf.is_inside_tree():
		return
	if _hits.is_empty() or not _bind_bubble():
		_surf.visible = false
		return
	_surf.visible = true
	_surf.modulate.a = modulate.a / SHIELD_ALPHA ## karakterin saydamlığı (çalı / görünmezlik), _follow_host
	var ang := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var ages := PackedFloat32Array([-1.0, -1.0, -1.0, -1.0])
	for i in _hits.size():
		ang[i] = float(_hits[i]["angle"])
		ages[i] = float(_hits[i]["age"])
	_surf_mat.set_shader_parameter("hit_angle", ang)
	_surf_mat.set_shader_parameter("hit_age", ages)
	_surf_px.queue_redraw()


## Katmanı ShieldVisual/BubbleSprite'a oturtur + o anki "loop" karesini shader'a verir (tür değişince kare de değişir).
func _bind_bubble() -> bool:
	var bub: AnimatedSprite2D = host.get_node_or_null("ShieldVisual/BubbleSprite") as AnimatedSprite2D
	if bub == null or bub.sprite_frames == null or not bub.sprite_frames.has_animation("loop"):
		return false
	_surf.position = host.to_local(bub.global_position)
	_surf.scale = bub.global_scale / host.global_scale
	var n: int = maxi(1, bub.sprite_frames.get_frame_count("loop"))
	var tex := bub.sprite_frames.get_frame_texture("loop", int(_clock * BUBBLE_LOOP_FPS) % n) as AtlasTexture
	if tex == null or tex.atlas == null:
		return false
	_surf_mat.set_shader_parameter("sheet", tex.atlas)
	_surf_mat.set_shader_parameter("sheet_size", tex.atlas.get_size())
	_surf_mat.set_shader_parameter("frame_rect", Vector4(tex.region.position.x, tex.region.position.y, tex.region.size.x, tex.region.size.y))
	var key := str(tex.atlas.resource_path)
	if key != _surf_light_key:
		_surf_light_key = key
		_surf_light = _light_of(tex)
	return true


static var _light_cache: Dictionary = {} ## sayfa yolu -> kıvılcım/flaş açık tonu


## Baloncuk sanatının belirgin piksellerinin ortalaması, beyaza %45 açılmış (kıvılcım + elmas flaş türün renginde).
static func _light_of(tex: AtlasTexture) -> Color:
	var key := str(tex.atlas.resource_path)
	if _light_cache.has(key):
		return _light_cache[key]
	var col := Color(0.8, 1.0, 0.7)
	var im: Image = tex.atlas.get_image()
	if im != null:
		if im.is_compressed():
			im.decompress()
		var acc := Vector3.ZERO
		var cnt := 0
		for y in range(int(tex.region.position.y), int(tex.region.end.y)):
			for x in range(int(tex.region.position.x), int(tex.region.end.x)):
				var c := im.get_pixel(x, y)
				if c.a > 0.55:
					acc += Vector3(c.r, c.g, c.b)
					cnt += 1
		if cnt > 0:
			acc /= float(cnt)
			col = Color(acc.x, acc.y, acc.z).lerp(Color.WHITE, 0.45)
	_light_cache[key] = col
	return col


func _dot(p: Vector2, col: Color) -> void:
	_surf_px.draw_rect(Rect2(p.floor(), Vector2.ONE), col)


## Darbe pikselleri baloncuğun texel ızgarasında (1 birim = 1 texel, tam sayı konum - kesirli blok yok, madde 564 ek 4):
## değme noktasında artı -> elmas flaş; menzilli darbede 4 kıvılcım dış normale yakın açılarla DIŞARI seker.
func _draw_hit_pixels() -> void:
	var light := _surf_light
	var dim := Color(light.r, light.g, light.b, 0.55)
	for h: Dictionary in _hits:
		var a: float = h["angle"]
		var t: float = h["age"]
		var n := Vector2(cos(a), sin(a))
		var c := n * (BUBBLE_R - 0.5)
		if t < 0.06:
			_dot(c, WHITE)
			for o: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				_dot(c + o, WHITE)
		elif t < 0.14:
			for x in range(-2, 3):
				var y := 2 - absi(x)
				_dot(c + Vector2(x, y), light)
				if y != 0:
					_dot(c + Vector2(x, -y), light)
		if not bool(h["ranged"]):
			continue
		var u := clampf(t / SPARK_TIME, 0.0, 1.0)
		if u >= 1.0:
			continue
		var reach: float = h["reach"]
		var hit_p := n * (BUBBLE_R + 0.5)
		for off: float in h["spark"]:
			var dir := Vector2(cos(a + off), sin(a + off))
			var p := hit_p + dir * (0.5 + reach * (1.0 - pow(1.0 - u, 2.0)))
			_dot(p, WHITE if u < 0.35 else light)
			if u < 0.7:
				_dot(p - dir, light if u < 0.35 else dim)
			if u < 0.35:
				_dot(p - dir * 2.0, dim)


func _play_break() -> void:
	_hits.clear()
	_regen_on = false
	_ground.visible = false
	_ground_fade = -1.0
	_rise_back.visible = false
	_rise_front.visible = false
	_rise_age = -1.0
	_break_age = 0.0
	_break_anchor = to_global(Vector2(0.0, -FEET_TO_BODY))
	_break_px = global_scale.abs()
	_break_back.frame = 0
	_break_front.frame = 0
	_break_back.visible = true
	_break_front.visible = true
	_pin_break()
	if _break_sound:
		_break_sound.pitch_scale = randf_range(0.92, 1.08)
		_break_sound.play()


func _update_break(delta: float) -> void:
	if _break_age < 0.0:
		return
	_break_age += delta
	if _break_age >= BREAK_DURATION:
		_break_back.visible = false
		_break_front.visible = false
		_break_age = -1.0
		_spawn_debris()
		return
	var fr := mini(BREAK_FRAMES - 1, int(_break_age * FPS))
	_break_back.frame = fr
	_break_front.frame = fr
	_pin_break()


## Kırılma parçaları dünyada sabit uçar (oyuncu yürürken onunla kaymasın); ön/arka katman ayrımı korunur.
func _pin_break() -> void:
	_break_front.position = to_local(_break_anchor) - BREAK_BODY
	_break_back.position = _back.to_local(_break_anchor) - BREAK_BODY


## Kırılmanın son karesi = yerdeki kırıklar: sahnenin zemin katmanına (yaratık/oyuncuların altına) bırakılır, önce parıltısı
## söner, sonra saydamlaşarak kaybolur. Olay iki tarafta da çalıştığı için (yerel + kukla) ek RPC yok.
func _spawn_debris() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null or modulate.a < 0.3 * SHIELD_ALPHA:
		return
	var holder := Node2D.new()
	holder.name = "ManaShieldDebris"
	tree.current_scene.add_child(holder)
	EnemyAbilitiesScript.place_on_ground(tree, holder)
	holder.global_position = _break_anchor + Vector2(0.0, FEET_TO_BODY * _break_px.y)
	holder.global_scale = _break_px
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.modulate.a = SHIELD_ALPHA
	var spr := Sprite2D.new()
	spr.texture = DEBRIS_TEX
	spr.hframes = DEBRIS_FRAMES
	spr.centered = false
	spr.position = -DEBRIS_FEET
	spr.material = _mat.duplicate() ## palet kopyası: oyuncu sonradan tür değiştirse de kırıklar kendi renginde kalır
	holder.add_child(spr)
	var tw := holder.create_tween()
	tw.tween_interval(DEBRIS_DIM_AT)
	tw.tween_callback(func(): spr.frame = 1)
	tw.tween_interval(DEBRIS_FADE_FROM - DEBRIS_DIM_AT)
	tw.tween_property(holder, "modulate:a", 0.0, DEBRIS_FADE)
	tw.tween_callback(holder.queue_free)


## Arka katman: yenilenme tikinde yer mührünün ilerleyen ucunda yıldız parıltısı.
func _draw_back() -> void:
	if _glint <= 0.0 or not _regen_on or _pal.is_empty():
		return
	var ha := PI * 0.5 + TAU * _shown_progress
	var c := Vector2(0.0, 1.0) + Vector2(cos(ha) * GROUND_R.x, sin(ha) * GROUND_R.y)
	var arm := 2 if _glint > GLINT_LIFE * 0.5 else 1
	for k in range(1, arm + 1):
		var col: Color = WHITE if k < arm else _pal[4]
		for o: Vector2 in [Vector2(k, 0), Vector2(-k, 0), Vector2(0, k), Vector2(0, -k)]:
			_back.draw_rect(Rect2((c + o).floor(), Vector2.ONE), col)
	_back.draw_rect(Rect2(c.floor(), Vector2.ONE), WHITE)
