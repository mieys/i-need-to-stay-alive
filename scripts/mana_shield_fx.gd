extends Node2D

## MANA KALKANI görseli "B - Mühür" (kullanıcı 2026-10-14, CLAUDE.md madde 148: prototip B seçildi; Kale mor, Enerji sarı;
## "kazmayla vurunca çatlama olmamalı"; "kalkan kırılınca her taraftan kırılmış gibi görünmeli"). Eski su baloncuğu
## (shield_visual.gd) artık SADECE Şovalye R kubbesi (is_shielded) için; mana kalkanının bütün görseli burada:
##   - darbe: hasarın geldiği yönde dönen büyü mührü (yan darbede dar oval, kuzeyden gelende karakterin ARDINDA)
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

const DISC_TEX: Texture2D = preload("res://assets/fx/mana_shield/disc.png")
const BREAK_BACK_TEX: Texture2D = preload("res://assets/fx/mana_shield/break_back.png")
const BREAK_FRONT_TEX: Texture2D = preload("res://assets/fx/mana_shield/break_front.png")
const GROUND_TEX: Texture2D = preload("res://assets/fx/mana_shield/ground.png")
const RISE_BACK_TEX: Texture2D = preload("res://assets/fx/mana_shield/rise_back.png")
const RISE_FRONT_TEX: Texture2D = preload("res://assets/fx/mana_shield/rise_front.png")
const DEBRIS_TEX: Texture2D = preload("res://assets/fx/mana_shield/debris.png")
const EnemyAbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const SHADER: Shader = preload("res://shaders/mana_shield.gdshader")

## --- tools/gen_mana_shield_fx.py ile AYNI tutulmalı ---
const DISC_COLS := 9 ## [beliriş 0,35, beliriş 0,7, krem flaş, dönüş 0..5]
const DISC_ROWS := 4 ## yatay basıklık sınıfları: 0,4 / 0,6 / 0,8 / 1,0 (f = 0,4 + 0,6 * |sin(açı)|)
const DISC_ROT_FRAMES := 6
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

const DISC_OFFSET := Vector2(15.0, 9.0) ## darbe mührü gövde merkezinden (cos, sin) x bu kadar uzakta
const DISC_LIFE := 0.6
const DISC_FADE_FROM := 0.3
const DISC_ROT_FPS := 19.0 ## 6 kare = 90 derece = ~0,31 sn
const MAX_DISCS := 3
const BACK_SIN := -0.3 ## sin(açı) bundan küçükse (kuzeyden gelen darbe) mühür karakterin ardında
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
const IMPACT_LIFE := 0.18
const SPARK_LIFE := 0.35
const GLINT_LIFE := 0.3
const SAVAS := "shield_savas"
const STANDART := "shield_standart"

const CREAM := Color8(255, 250, 228)
const WHITE := Color8(255, 255, 255)
const BOLT_HOT := Color8(255, 150, 60) ## cana geçen kısmın kıvılcımı (soğurma kısmi: %55-75)
const BOLT_DIM := Color8(200, 60, 24)
## [kontur, koyu, orta, açık, parlak] - gen_mana_shield_fx.py PALS ile aynı. Kale mor, Enerji sarı (kullanıcı 2026-10-14).
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
var _discs: Array = [] ## {"spr": Sprite2D, "age": float, "row": int}
var _impacts: Array = [] ## {"pos": Vector2 (ayağa göre, karakter pikseli), "angle": float, "age": float, "big": bool}
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
	set_shield_type(STANDART)
	if play_sounds:
		_break_sound = _copy_sound("ShieldVisual/BreakSound")
		_regen_sound = _copy_sound("ShieldVisual/RegenSound")


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
	_pal = PALETTES.get(key, PALETTES[STANDART])
	for m: ShaderMaterial in [_mat, _ground_mat]:
		if m == null:
			continue
		for i in 5:
			m.set_shader_parameter("c%d" % i, _pal[i])
		m.set_shader_parameter("c5", CREAM)
		m.set_shader_parameter("c6", WHITE)
	if key == SAVAS and _regen_on:
		_stop_regen()


## Kalkan hasar soğurdu. broke = bu darbe kalkanı 0'a indirdi -> her taraftan kırılma.
func hit(angle: float, broke: bool) -> void:
	if _is_suppressed():
		return
	if hit_only and broke:
		return ## kalkanı bitiren darbede mühür YOK (kırılmayı eski baloncuk gösterir)
	if broke:
		_play_break()
	else:
		_spawn_disc(angle)
	var dir := Vector2(cos(angle), sin(angle))
	_impacts.append({"pos": Vector2(0.0, -FEET_TO_BODY) + Vector2(dir.x * DISC_OFFSET.x, dir.y * DISC_OFFSET.y), "angle": angle, "age": 0.0, "big": broke})
	if _impacts.size() > 6:
		_impacts.pop_front()
	## Darbe yenilenme beklemesini sıfırlar: yer mührü söner.
	_regen_hold = 0.0
	if _regen_on:
		_stop_regen()
	queue_redraw()


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
	for d: Dictionary in _discs:
		if is_instance_valid(d["spr"]):
			(d["spr"] as Node).queue_free()
	_discs.clear()
	_impacts.clear()
	for s: Sprite2D in [_ground, _break_back, _break_front, _rise_back, _rise_front]:
		if s:
			s.visible = false
	_break_age = -1.0
	_rise_age = -1.0
	_regen_on = false
	_ground_fade = -1.0
	_glint = 0.0
	queue_redraw()
	if _back:
		_back.queue_redraw()


func is_anything_visible() -> bool:
	if not _discs.is_empty() or not _impacts.is_empty():
		return true
	for s: Sprite2D in [_ground, _break_back, _break_front, _rise_back, _rise_front]:
		if s and s.visible:
			return true
	return false


func is_regen_shown() -> bool:
	return _regen_on


func disc_count() -> int:
	return _discs.size()


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
	_update_discs(delta)
	_update_break(delta)
	_update_rise(delta)
	_update_ground_fade(delta)
	if not _impacts.is_empty():
		for i in range(_impacts.size() - 1, -1, -1):
			_impacts[i]["age"] = float(_impacts[i]["age"]) + delta
			if float(_impacts[i]["age"]) >= SPARK_LIFE:
				_impacts.remove_at(i)
		queue_redraw()
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


func _spawn_disc(angle: float) -> void:
	var f := 0.4 + 0.6 * absf(sin(angle))
	var row := clampi(int(round((f - 0.4) / 0.2)), 0, DISC_ROWS - 1)
	if _discs.size() >= MAX_DISCS:
		var old: Dictionary = _discs.pop_front()
		if is_instance_valid(old["spr"]):
			(old["spr"] as Node).queue_free()
	var behind := sin(angle) < BACK_SIN
	var spr := _sprite(_back if behind else self, DISC_TEX, DISC_COLS, _mat)
	spr.vframes = DISC_ROWS
	spr.centered = true
	spr.position = (Vector2(0.0, -FEET_TO_BODY) + Vector2(cos(angle) * DISC_OFFSET.x, sin(angle) * DISC_OFFSET.y)).round()
	spr.frame = row * DISC_COLS
	spr.visible = true
	_discs.append({"spr": spr, "age": 0.0, "row": row})


func _update_discs(delta: float) -> void:
	for i in range(_discs.size() - 1, -1, -1):
		var d: Dictionary = _discs[i]
		var age: float = float(d["age"]) + delta
		d["age"] = age
		var spr: Sprite2D = d["spr"]
		if age >= DISC_LIFE or not is_instance_valid(spr):
			if is_instance_valid(spr):
				spr.queue_free()
			_discs.remove_at(i)
			continue
		var col: int
		if age < 0.045:
			col = 0
		elif age < 0.09:
			col = 1
		elif age < 0.13:
			col = 2
		else:
			col = 3 + int(age * DISC_ROT_FPS) % DISC_ROT_FRAMES
		spr.frame = int(d["row"]) * DISC_COLS + col
		spr.modulate.a = 1.0 - maxf(0.0, (age - DISC_FADE_FROM) / (DISC_LIFE - DISC_FADE_FROM))


func _play_break() -> void:
	for d: Dictionary in _discs:
		if is_instance_valid(d["spr"]):
			(d["spr"] as Node).queue_free()
	_discs.clear()
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


## Ön katman: çarpma parlaması + kıvılcımlar (çoğu saldırgana geri seker = soğurulan kısım; 2 turuncu kıvılcım içeri geçer =
## cana geçen kısım). Karakter pikseli ızgarasında 1x1 dikdörtgenler; darbe başına ~20 çizim, 0,35 sn.
func _draw() -> void:
	for imp: Dictionary in _impacts:
		var age: float = imp["age"]
		var p: Vector2 = imp["pos"]
		var a: float = imp["angle"]
		var big: bool = imp["big"]
		if age < IMPACT_LIFE:
			var k := age / IMPACT_LIFE
			var r := (6.0 if big else 4.0) * (0.6 + 0.6 * k)
			_pixel_ellipse(p, r, r * 0.9, CREAM if k < 0.45 else _pal[4], k >= 0.45)
		var ks := age / SPARK_LIFE
		var n := 6 if big else 4
		var reach := 13.0 if big else 9.0
		for i in n:
			var da := (i - (n - 1) / 2.0) * 0.55
			var dist := reach * (1.0 - pow(1.0 - ks, 3.0)) * (0.7 + 0.1 * float(i % 3))
			var dir := Vector2(cos(a + da), sin(a + da) * 0.8)
			var tail := maxi(1, int(3.0 * (1.0 - ks)))
			for j in tail:
				_px(p + dir * (dist - j), CREAM if (j == 0 and ks < 0.5) else _pal[3])
		for i in 2:
			var b := a + PI + (i - 0.5) * 0.5
			_px(p + Vector2(cos(b), sin(b) * 0.8) * 6.0 * (1.0 - pow(1.0 - ks, 3.0)), BOLT_HOT if ks < 0.6 else BOLT_DIM)


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


func _px(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p.floor(), Vector2.ONE), col)


func _pixel_ellipse(c: Vector2, rx: float, ry: float, col: Color, ring: bool) -> void:
	var y0 := int(floor(c.y - ry))
	var y1 := int(ceil(c.y + ry))
	for y in range(y0, y1):
		var dy := (y + 0.5 - c.y) / ry
		if absf(dy) > 1.0:
			continue
		var hw := rx * sqrt(1.0 - dy * dy)
		var x0 := int(round(c.x - hw))
		var x1 := int(round(c.x + hw))
		if x1 <= x0:
			continue
		if ring and absf(dy) < 0.75:
			draw_rect(Rect2(x0, y, 1, 1), col)
			draw_rect(Rect2(x1 - 1, y, 1, 1), col)
		else:
			draw_rect(Rect2(x0, y, x1 - x0, 1), col)
