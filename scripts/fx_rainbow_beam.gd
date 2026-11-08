extends Node2D

## GÖKKUŞAĞI ASASI ışını (madde 306; prototip madde 298 "C - Parıltılı Huzme", asa "A - Prizma").
## Gövde shader (shaders/gokkusagi_isin.gdshader): krem çekirdek + açık renk orta bant + yarı saydam renkli dış bant, renk dilimleri
## hedefe doğru akar; ışın boyunca parıltı tanecikleri (sparkle.png), her vuruş tikinde vurulan her hedefte 6 renkli patlama (impact.png).
## Göz Kamaştıran Işık özelliği: glow (0..1 = aynı hedefte tutma oranı) ışını kalınlaştırır, 0,8'den sonra titrer; >= 2 = hedef kamaştı
## (en kalın + parlak). Finalde (pierce) ışın hedefte durmaz, menzil sonuna kadar sivri uçla uzar.
## Kök namluda durur (top_level, dünya koordinatı): yerelde current_scene, uzakta RemotePlayer (ölçekli kök) altında AYNI boyda çizilir.
## Kullananlar AYNI sahne: kaster weapon.gd (setup / set_end / set_glow / play_tick), uzak remote_player.gd ("rbeam_*" ->
## setup_network / update_target / play_tick), görev kopyası mission_player_copy.gd (setup_network, kısa süre).

const SHADER := preload("res://shaders/gokkusagi_isin.gdshader")
const SPARKLE_TEX: Texture2D = preload("res://assets/fx/gokkusagi/sparkle.png")
const IMPACT_TEX: Texture2D = preload("res://assets/fx/gokkusagi/impact.png")
## Kamaşma anı sayfası (Göz Kamaştıran Işık -> EnchantFx "sprite" rainbow_dazzle): bu betik oyun açılışında silah sahnesiyle yüklendiği için
## sayfa da bellekte kalır - ilk kamaşmada (kasterde ve uzak oyuncuda) fx_enchant_sprite.gd load() diskten okumaz (ısınma listesi ilk ateşi
## yakalar, 3 sn'lik tutmayı değil).
const DAZZLE_FRAMES: SpriteFrames = preload("res://assets/fx/enchant/rainbow_dazzle_frames.tres")
const AudioBusesScript := preload("res://scripts/audio_buses.gd")
## Işın sesi (madde 451, masaüstü "gökkuşağı asası.mp3" -> tools/gen_gokkusagi_ses.py): ışın açılınca giriş + döngü gövdesi (tek dosya,
## loop_offset = SFX_LOOP_START: giriş bir kez, sonra gövde dikişsiz döner), ışın kapanınca kapanış patlaması.
const SFX_START_LOOP: AudioStreamOggVorbis = preload("res://assets/audio/gokkusagi/beam_start_loop.ogg")
const SFX_END: AudioStream = preload("res://assets/audio/gokkusagi/beam_end.ogg")
const SFX_LOOP_START := 1.0 ## giriş uzunluğu (sn); gen_gokkusagi_ses.py LOOP_A ile aynı
const SFX_DB := -6.0
const SFX_END_DB := -6.0
const SFX_FADE_OUT := 0.08 ## döngü gövdesinin kapanış patlamasına yer açarak sönme süresi
const SFX_MIN_LIFE := 0.3 ## bundan kısa yaşayan ışın (hedef hemen öldü) kapanış patlaması çalmaz, sadece söner
const BASE_W := 6.0 ## ışın YARI genişliği (dünya px); madde 331: 3,0 -> 6,0 ("çok ince vuruyor")
const FINAL_W := 8.0 ## finalde 3,8 -> 8,0; weapon.gd BEAM_PIERCE_RADIUS bununla birlikte değişir (yarı genişlik x1,15 + gövde)
const SPARK_RATE := 24.0
const SPARK_RATE_FINAL := 44.0
const MAX_SPARKS := 32
const IMPACT_FRAMES := 6
const IMPACT_FPS := 30.0
const FLICKER_FROM := 0.8 ## tutma oranı bunu geçince ışın kamaşmaya yakın titrer
## Vuruş sesi: şimdilik mevcut arcane atış sesi yüksek perdede ve kısık (özel ses için kullanıcıdan referans beklenir - hafıza "blind SFX";
## 2026-10-20 sentez sesler reddedildi, madde 344).
const TICK_SFX: AudioStream = preload("res://assets/audio/arcane_attack.mp3")
const TICK_DB := -13.0 ## 2026-11-07 (madde 441, "isabet sesi az"): -16 -> -13 (oyunda -28,6 -> -25,6; Yıldırım tikinin altında kalır)

var pierce: bool = false
var glow: float = 0.0
var _origin: Node2D = null
var _target: Node2D = null
var _use_net: bool = false
var _net_from: Vector2 = Vector2.ZERO
var _net_to: Vector2 = Vector2.ZERO
var _end_on: bool = false
var _end_pos: Vector2 = Vector2.ZERO
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _remote_db: float = 0.0
var _body: Sprite2D = null
var _mat: ShaderMaterial = null
var _tip: Sprite2D = null
var _sparks: Array = [] ## [Sprite2D, hız, yaş, ömür, satır]
var _spark_acc: float = 0.0
var _impacts: Array = [] ## [Sprite2D, yaş]
var _rng := RandomNumberGenerator.new()
var _hum: AudioStreamPlayer2D = null ## ışından bağımsız oyuncu (ışın silinince kapanış için söner); _process konumu namluya taşır
var _hum_gone: bool = false
static var _white: Texture2D = null


static func _white_tex() -> Texture2D:
	if _white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


func _ready() -> void:
	top_level = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	_body = Sprite2D.new()
	_body.texture = _white_tex()
	_body.centered = false
	_body.offset = Vector2(0.0, -0.5)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_body.material = _mat
	add_child(_body)
	_tip = _make_sheet_sprite(SPARKLE_TEX, 3, 6)
	_tip.z_index = 1
	add_child(_tip)
	_add_hum.call_deferred() ## kök sahnenin çocuğu olarak eklenir (kasterde kök sahne bu düğümü eklerken meşgul)


## Giriş + döngü sesi. Kaster: kendi ışını (1500 doğrusal); uzak oyuncu: network_manager "weapon_sound" ile aynı mesafe kuralı + kısık.
func _add_hum() -> void:
	if _hum_gone or not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	var st: AudioStreamOggVorbis = SFX_START_LOOP.duplicate()
	st.loop = true
	st.loop_offset = SFX_LOOP_START
	_hum = AudioStreamPlayer2D.new()
	_hum.stream = st
	parent.add_child(_hum)
	_hum.global_position = global_position
	_style_hum()
	_hum.play()


func _style_hum() -> void:
	_hum.volume_db = SFX_DB + _remote_db
	_hum.max_distance = 900.0 if _use_net else 1500.0
	_hum.attenuation = 1.6 if _use_net else 1.0


## Işın kapandı: gövde hızla söner, aynı anda kapanış patlaması çalar (ışın bittiği anda biter).
func _finish_hum() -> void:
	_hum_gone = true
	var tree: SceneTree = get_tree()
	if _hum == null or not is_instance_valid(_hum) or tree == null:
		return
	var hum: AudioStreamPlayer2D = _hum
	_hum = null
	var tw: Tween = hum.create_tween()
	tw.tween_property(hum, "volume_db", -60.0, SFX_FADE_OUT)
	tw.tween_callback(hum.queue_free)
	if _t < SFX_MIN_LIFE:
		return
	## Işın silinirken ebeveyni "meşgul": ekleme ertelenir (kapanış patlaması bir kare sonra başlar).
	_spawn_end.bind(hum.get_parent(), hum.global_position, SFX_END_DB + _remote_db, hum.max_distance, hum.attenuation).call_deferred()


static func _spawn_end(parent: Node, pos: Vector2, db: float, max_dist: float, atten: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var end := AudioStreamPlayer2D.new()
	end.stream = SFX_END
	end.volume_db = db
	end.max_distance = max_dist
	end.attenuation = atten
	parent.add_child(end)
	end.global_position = pos
	end.finished.connect(end.queue_free)
	end.play()


func _exit_tree() -> void:
	_finish_hum()


func _make_sheet_sprite(tex: Texture2D, hf: int, vf: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = hf
	s.vframes = vf
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func setup(origin: Node2D, target: Node2D) -> void:
	_origin = origin
	_target = target
	_use_net = false


## Uzak oyuncu / görev kopyası: konumlar ağdan. extra: from_pos, pi (final delme), h (tutma/kamaşma).
func setup_network(target_pos: Vector2, extra: Dictionary) -> void:
	_origin = null
	_target = null
	_use_net = true
	_remote_db = AudioBusesScript.remote_weapon_db()
	_net_to = target_pos
	var fallback: Vector2 = get_parent().global_position if get_parent() is Node2D else target_pos
	_net_from = Vector2(extra.get("from_pos", fallback))
	_apply_extra(extra)
	if _hum != null:
		_style_hum()


func update_target(target_pos: Vector2, origin_pos: Vector2 = Vector2.ZERO, extra: Dictionary = {}) -> void:
	_net_to = target_pos
	if origin_pos != Vector2.ZERO:
		_net_from = origin_pos
	_apply_extra(extra)


func _apply_extra(extra: Dictionary) -> void:
	if extra.has("pi"):
		pierce = bool(extra["pi"])
	if extra.has("h"):
		glow = float(extra["h"])


## Kaster: final delmesinde ışın menzil sonuna (on = false -> hedefe).
func set_end(pos: Vector2, on: bool) -> void:
	_end_on = on
	_end_pos = pos
	pierce = on


func set_glow(v: float) -> void:
	glow = v


func beam_width() -> float:
	var base: float = FINAL_W if pierce else BASE_W
	if glow >= 2.0:
		return base * 1.15
	return base * (0.82 + 0.33 * clampf(glow, 0.0, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _use_net:
		_from = _net_from
		_to = _net_to
	else:
		if _origin != null and is_instance_valid(_origin):
			_from = _origin.global_position
		if _end_on:
			_to = _end_pos
		elif _target != null and is_instance_valid(_target):
			_to = _target.global_position
	global_position = _from
	if _hum != null and is_instance_valid(_hum):
		_hum.global_position = _from
	var v: Vector2 = _to - _from
	var L: float = maxf(1.0, v.length())
	var w: float = beam_width()
	var quad_len: float = L + (0.0 if pierce else ceilf(w) + 1.0)
	var quad_h: float = 2.0 * (ceilf(w) + 2.0)
	_body.rotation = v.angle()
	_body.scale = Vector2(quad_len, quad_h)
	_mat.set_shader_parameter("beam_len", L)
	_mat.set_shader_parameter("quad_len", quad_len)
	_mat.set_shader_parameter("quad_h", quad_h)
	_mat.set_shader_parameter("width", w)
	_mat.set_shader_parameter("t", _t)
	_mat.set_shader_parameter("spear", pierce)
	_mat.set_shader_parameter("flicker", 1.0 if (glow >= FLICKER_FROM and glow < 2.0 and int(_t * 30.0) % 2 == 0) else 0.0)
	_mat.set_shader_parameter("bright", 1.0 if glow >= 2.0 else 0.0)
	## namlu parıltısı: titreyen küçük yıldız, renk döner
	_tip.frame = (int(_t * 6.0) % 6) * 3 + (0 if int(_t * 15.0) % 2 == 0 else 1)
	_update_sparks(delta, v / L, L)
	_update_impacts(delta)


func _update_sparks(delta: float, u: Vector2, L: float) -> void:
	_spark_acc += (SPARK_RATE_FINAL if pierce else SPARK_RATE) * delta
	while _spark_acc >= 1.0:
		_spark_acc -= 1.0
		if L < 10.0:
			continue
		var s: Sprite2D = null
		for rec in _sparks:
			if not (rec[0] as Sprite2D).visible:
				s = rec[0]
				_sparks.erase(rec)
				break
		if s == null:
			if _sparks.size() >= MAX_SPARKS:
				continue
			s = _make_sheet_sprite(SPARKLE_TEX, 3, 6)
			s.top_level = true
			s.z_index = 1
			add_child(s)
		var n := Vector2(-u.y, u.x)
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var along: float = _rng.randf_range(6.0, L - 2.0)
		var bw: float = beam_width()
		var off: float = side * _rng.randf_range(bw * 0.5, bw * 1.2)
		s.global_position = (_from + u * along + n * off).round()
		s.visible = true
		s.modulate.a = 1.0
		_sparks.append([s, u * 16.0 + n * side * 7.0, 0.0, _rng.randf_range(0.32, 0.5), _rng.randi() % 6])
	for rec in _sparks:
		var s: Sprite2D = rec[0]
		if not s.visible:
			continue
		rec[2] = float(rec[2]) + delta
		var f: float = float(rec[2]) / float(rec[3])
		if f >= 1.0:
			s.visible = false
			continue
		s.global_position += Vector2(rec[1]) * delta
		s.frame = int(rec[4]) * 3 + (0 if f < 0.3 else (1 if f < 0.75 else 2))
		s.modulate.a = 1.0 if f < 0.75 else 0.5


## Vuruş tiki: vurulan her hedefte 6 renkli patlama + (ilk konumda) vuruş sesi. Kaster weapon.gd, uzak "rbeam_hit".
func play_tick(positions: Array, with_sound: bool = true) -> void:
	for p in positions:
		var s: Sprite2D = null
		for rec in _impacts:
			if not (rec[0] as Sprite2D).visible:
				s = rec[0]
				_impacts.erase(rec)
				break
		if s == null:
			s = _make_sheet_sprite(IMPACT_TEX, IMPACT_FRAMES, 1)
			s.top_level = true
			s.z_index = 2
			add_child(s)
		s.global_position = Vector2(p).round()
		s.flip_h = _rng.randf() < 0.5
		s.frame = 0
		s.visible = true
		_impacts.append([s, 0.0])
	if with_sound and not positions.is_empty():
		var asp := AudioStreamPlayer2D.new()
		asp.stream = TICK_SFX
		asp.volume_db = TICK_DB + _remote_db
		asp.pitch_scale = _rng.randf_range(1.22, 1.34)
		asp.max_distance = 900.0 if _use_net else 1500.0
		asp.attenuation = 1.6 if _use_net else 1.0
		var tree := get_tree()
		var parent: Node = tree.current_scene if tree.current_scene else tree.root
		parent.add_child(asp)
		asp.global_position = Vector2(positions[0])
		asp.finished.connect(asp.queue_free)
		asp.play()


func _update_impacts(delta: float) -> void:
	for rec in _impacts:
		var s: Sprite2D = rec[0]
		if not s.visible:
			continue
		rec[1] = float(rec[1]) + delta
		var fi: int = int(float(rec[1]) * IMPACT_FPS)
		if fi >= IMPACT_FRAMES:
			s.visible = false
		else:
			s.frame = fi


## Gece ışığı (night_glow_catalog.gd): namludan ışının ucuna.
func get_glow_segment() -> Array:
	return [_from, _to]


## Gece ışığının rengi: beyaz ışık renkli ışının yanında seçilmiyordu (kullanıcı 2026-11-07, "parıltısız normal nesne gibi") ->
## ışık gökkuşağı renklerinde döner (doygunluk düşük tutulur: karanlıkta pastel, kirli değil).
func get_night_glow_color() -> Color:
	return Color.from_hsv(fposmod(_t * 0.45, 1.0), 0.6, 1.0)
