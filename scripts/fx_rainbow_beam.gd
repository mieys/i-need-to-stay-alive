extends Node2D

## GÖKKUŞAĞI ASASI ışını (madde 306; prototip madde 298 "C - Parıltılı Huzme", asa "A - Prizma").
## Gövde shader (shaders/gokkusagi_isin.gdshader): krem çekirdek + açık renk orta bant + yarı saydam renkli dış bant, renk dilimleri
## hedefe doğru akar; ışın boyunca parıltı tanecikleri (sparkle.png), her vuruş tikinde vurulan her hedefte 6 renkli patlama (impact.png).
## Göz Kamaştıran Işık özelliği: glow (0..1 = aynı hedefte tutma oranı) ışını kalınlaştırır, 0,8'den sonra titrer; >= 2 = hedef kamaştı
## (en kalın + parlak). Finalde (pierce) ışın hedefte durmaz: "Lux Huzmesi" (madde 551) görüş elipsinin kenarına kadar kalın, düz uzanır,
## açılırken uca koşar, kapanırken incelerek söner, her vuruşta asadan uca rengarenk halkalar koşar. Her iki kipte vurulan düşmanın üstünde
## IŞIK SAÇILMASI (Scatter: rastgele yönlere uzayıp kısalan tayf konileri + dönen yıldız; hasarı weapon.gd _apply_beam_splash).
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
## Işın sesi (madde 451, masaüstü "Laser beam Heat Vision" mp3'ü -> tools/gen_gokkusagi_ses.py): ışın açılınca giriş + döngü gövdesi (tek dosya,
## loop_offset = SFX_LOOP_START: giriş bir kez, sonra gövde dikişsiz döner), ışın kapanınca kapanış patlaması.
const SFX_START_LOOP: AudioStreamOggVorbis = preload("res://assets/audio/gokkusagi/beam_start_loop.ogg")
const SFX_LOOP_START := 1.16 ## giriş uzunluğu (sn); gen_gokkusagi_ses.py LOOP_A - START_A ile aynı
const SFX_DB := -3.0 ## yeni kaynakta gövde sessiz (tepe 0,17), vuruş/kapanış yüksek: gövde 0 dB'ye yakın, kapanış kısık
const SFX_FADE_OUT := 0.15 ## ışın kapanınca döngü gövdesinin sönme süresi (kapanış patlaması yok)
const BASE_W := 6.0 ## ışın YARI genişliği (dünya px); madde 331: 3,0 -> 6,0 ("çok ince vuruyor")
## Final "Lux Huzmesi" (madde 551): yarı genişlik 8 -> 11, görüş elipsinin kenarına kadar; weapon.gd BEAM_PIERCE_RADIUS bununla birlikte
## değişir (yarı genişlik x1,15 + gövde).
const FINAL_W := 11.0
const SPARK_RATE := 24.0
const SPARK_RATE_FINAL := 90.0 ## ışın ~2 kat uzun (görüş kenarı)
const MAX_SPARKS := 48
## Işık saçılması (madde 551, "C + yıldız"): vurulan düşmanın çevresinde rastgele yönlere uzayıp kısalan tayf konileri + dönen yıldız.
## Görüntü tamamen shader'da (shaders/gokkusagi_sacilma.gdshader); hasar weapon.gd _apply_beam_splash (60 px, en çok 4, %50).
const SCATTER_SHADER := preload("res://shaders/gokkusagi_sacilma.gdshader")
const SCATTER_SIZE := 144.0 ## koni boyu en çok 64 + yıldız; kare dörtgen, merkez = vurulan
const SCATTER_FADE := 0.15
## Final gönderiliş / bırakış (prototip Final "A2"): ışın 0,12 sn'de uca koşar (uç parlak), kapanınca 0,25 sn'de incelerek söner.
const LAUNCH_TIME := 0.12
const RELEASE_TIME := 0.25
## Finalde her vuruşta (ve gönderilişte) asadan uca koşan 3 rengarenk halka (D "Halkalı Işın"ın halkaları; renkler rastgele ve farklı).
const RING_SPEED := 480.0 ## px/sn; kullanıcı 2026-11-10: "halkalar biraz daha yavaş gitsin" (prototip 720)
const RING_GAP := 15.0
const RING_COUNT := 3
const MAX_RING_SETS := 3 ## shader dizisi 9 halka
const RING_ALPHA := 0.75 ## ön yarı saydamlığı (arka yarı x0,3 = 0,25); kullanıcı 2026-11-10 "halkaları biraz daha saydam" (eski 1,0 / 0,5)
const RING_RB: Array[Color] = [Color("f06a5a"), Color("f7a24a"), Color("f4d85a"), Color("86d26e"), Color("62b2ec"), Color("a87ae6")]
const IMPACT_FRAMES := 6
const IMPACT_FPS := 30.0
const FLICKER_FROM := 0.8 ## tutma oranı bunu geçince ışın kamaşmaya yakın titrer
const HIT_FADE := 0.08 ## namlu parıltısı / saçılma: değiyor <-> değmiyor geçiş süresi (sn)
## Vuruş sesi: şimdilik mevcut arcane atış sesi yüksek perdede ve kısık (özel ses için kullanıcıdan referans beklenir - hafıza "blind SFX";
## 2026-10-20 sentez sesler reddedildi, madde 344).
const TICK_SFX: AudioStream = preload("res://assets/audio/arcane_attack.mp3")
const TICK_DB := -13.0 ## 2026-11-07 (madde 441, "isabet sesi az"): -16 -> -13 (oyunda -28,6 -> -25,6; Yıldırım tikinin altında kalır)

var pierce: bool = false
var glow: float = 0.0
var _origin: Node2D = null
var _target: Node2D = null
const BeamNetSmooth := preload("res://scripts/beam_net_smooth.gd")
var _net_smooth = BeamNetSmooth.new() ## uzak ışın: ağ konumlarını yumuşatır (Talon E'de ışın dönerken sıçramasın)
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
var _net_splash: Vector2 = Vector2.ZERO ## uzak kukla: finalde vurulan birincil hedef ("sp"); temelde ışının ucu zaten hedef
var _net_splash_on: bool = false
## Işın şu an bir yaratığa değiyor mu (namlu parıltısı + uçtaki saçılma yalnız o zaman görünür; boşa giden / savrulan ışında yok).
## Bilgi hiç gelmezse (eski istemci, görev kopyası) "değiyor" sayılır - eski görünüm. _hit_k: yumuşak geçiş (hızlı hedef değişiminde yanıp sönmesin).
var _hit_on: bool = true
var _hit_k: float = 1.0
var _hit_known: bool = false
var _hit_pos: Vector2 = Vector2.ZERO
var _hit_pos_set: bool = false
var _scatter: Sprite2D = null
var _scatter_mat: ShaderMaterial = null
var _launch_t: float = LAUNCH_TIME ## LAUNCH_TIME = gönderiliş yok (hedef değişiminde ışın baştan koşmaz)
var _launch_ring_pending: bool = false
var _releasing: bool = false
var _rel_t: float = 0.0
var _ring_sets: Array = [] ## [başlangıç zamanı (_t), [Color x3]]
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
	_scatter = Sprite2D.new()
	_scatter.texture = _white_tex()
	_scatter.top_level = true
	_scatter.z_index = 1
	_scatter.scale = Vector2(SCATTER_SIZE, SCATTER_SIZE)
	_scatter_mat = ShaderMaterial.new()
	_scatter_mat.shader = SCATTER_SHADER
	_scatter_mat.set_shader_parameter("size", SCATTER_SIZE)
	_scatter_mat.set_shader_parameter("seed", _rng.randf_range(0.0, 100.0)) ## iki ışın aynı deseni çizmesin
	_scatter.material = _scatter_mat
	_scatter.visible = false
	add_child(_scatter)
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


## Işın kapandı: döngü gövdesi kısa sürede söner (kapanış patlaması 2026-11-09'da kaldırıldı: "kulak yoruyor").
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
	_to = target_pos ## beam_to() ilk _process'ten önce de geçerli olsun (kukla asası ilk karede dünya orijinine dönmesin)
	var fallback: Vector2 = get_parent().global_position if get_parent() is Node2D else target_pos
	_net_from = Vector2(extra.get("from_pos", fallback))
	_net_smooth.push(_net_from, _net_to)
	_apply_extra(extra)
	if _hum != null:
		_style_hum()


## Uzak oyuncu: ışın kasterin ağdan gelen namlu konumundan DEĞİL, kuklanın kendi asa ucundan (ikonun çocuğu bir işaret düğümü) çıkar -
## kasterde ışın Icon/Muzzle'dan çıkar; ağ konumu ~50 ms + ağ gecikmesi geriden gelir ve kuklanın ikonu (kendi yumuşatması / hücum yayı)
## ağdaki namluyla örtüşmezdi (ışın asadan kopuk / yan çıkıyordu). Uç (hedef) yine ağdan.
var _net_origin_node: Node2D = null


func set_net_origin(node: Node2D) -> void:
	_net_origin_node = node


## Işının (yumuşatılmış) bitiş noktası - kukla asasını ışının yönüne çevirmek için (remote_player.gd _update_local_weapon_aim).
func beam_to() -> Vector2:
	return _to


func update_target(target_pos: Vector2, origin_pos: Vector2 = Vector2.ZERO, extra: Dictionary = {}) -> void:
	_net_to = target_pos
	if origin_pos != Vector2.ZERO:
		_net_from = origin_pos
	_net_smooth.push(_net_from, _net_to)
	_apply_extra(extra)


func _apply_extra(extra: Dictionary) -> void:
	if extra.has("pi"):
		pierce = bool(extra["pi"])
	if extra.has("h"):
		glow = float(extra["h"])
	if extra.has("ht"):
		set_hit(bool(extra["ht"]))
	if extra.has("sp"):
		_net_splash = Vector2(extra["sp"])
		_net_splash_on = true
	if extra.has("ln"):
		set_launch(bool(extra["ln"]))


## Final gönderilişi: ışın sıfırdan açılıyorsa (hedef değişimi değil) uca koşar ve ilk halka takımı fırlar. Kaster weapon.gd, uzak "ln".
func set_launch(on: bool) -> void:
	_launch_t = 0.0 if on else LAUNCH_TIME
	_launch_ring_pending = on


## Hedef değişimi: ışın (ve başlangıç/döngü sesi) kapanmadan yeni hedefe geçer - giriş sesi yalnız hedefsizken ilk kilitte çalar.
func retarget(target: Node2D) -> void:
	_target = target


## Işın kapanıyor: finalde 0,25 sn'de incelerek söner (sonra kendini siler), temelde hemen silinir. Kaster weapon.gd _end_beam(true),
## uzak "rbeam_stop".
func release() -> void:
	if _releasing:
		return
	if not pierce:
		queue_free()
		return
	_releasing = true
	_rel_t = 0.0
	_finish_hum()


## 3 halka: rastgele, birbirinden farklı ve spektrumda ardışık olmayan renkler (ardışık üçlü = tek ton ailesi; madde 551 prototip ring_colors).
func _ring_colors() -> Array:
	var idx: Array = [0, 1, 2, 3, 4, 5]
	while true:
		for i in range(5, 0, -1):
			var j: int = _rng.randi_range(0, i)
			var tmp: int = idx[i]
			idx[i] = idx[j]
			idx[j] = tmp
		var pick: Array = idx.slice(0, RING_COUNT)
		var consecutive: bool = false
		for a in range(6):
			if pick.has(a) and pick.has((a + 1) % 6) and pick.has((a + 2) % 6):
				consecutive = true
				break
		if not consecutive:
			var cols: Array = []
			for k in pick:
				cols.append(RING_RB[int(k)])
			return cols
	return []


func _spawn_rings() -> void:
	_ring_sets.append([_t, _ring_colors()])
	while _ring_sets.size() > MAX_RING_SETS:
		_ring_sets.pop_front()


## Kaster: final delmesinde ışın menzil sonuna (on = false -> hedefe).
func set_end(pos: Vector2, on: bool) -> void:
	_end_on = on
	_end_pos = pos
	pierce = on


func set_glow(v: float) -> void:
	glow = v


## Işın şu an bir yaratığa değiyor mu (kaster weapon.gd her karede; uzak "ht"). İlk çağrı geçişsiz oturur (ışın boşa açılırsa parıltı doğmaz).
## pos: kasterde değen yaratığın konumu - saçılma onun üstünde açılır (final delen ışında _target ışının uzak ucudur, yaratık değil).
func set_hit(on: bool, pos: Variant = null) -> void:
	_hit_on = on
	if pos is Vector2:
		_hit_pos = pos
		_hit_pos_set = true
	if not _hit_known:
		_hit_known = true
		_hit_k = 1.0 if on else 0.0


func beam_width() -> float:
	var base: float = FINAL_W if pierce else BASE_W
	if glow >= 2.0:
		return base * 1.15
	return base * (0.82 + 0.33 * clampf(glow, 0.0, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _use_net:
		_net_smooth.step(delta)
		_from = _net_smooth.from_pos()
		_to = _net_smooth.to_pos()
		if _net_origin_node != null and is_instance_valid(_net_origin_node) and _net_origin_node.is_inside_tree():
			_from = _net_origin_node.global_position
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
	## Bırakış (yalnız finalde): genişlik + halkalar + saçılma 0,25 sn'de söner, sonra düğüm kendini siler.
	var rel_k: float = 1.0
	if _releasing:
		_rel_t += delta
		if _rel_t >= RELEASE_TIME:
			queue_free()
			return
		var rf: float = _rel_t / RELEASE_TIME
		rel_k = 1.0 - (1.0 - (1.0 - rf) * (1.0 - rf))
	var w: float = beam_width() * rel_k
	var vis_len: float = L
	var launching: bool = false
	if pierce:
		if _launch_ring_pending:
			_launch_ring_pending = false
			_spawn_rings()
		if _launch_t < LAUNCH_TIME:
			_launch_t += delta
			var lf: float = clampf(_launch_t / LAUNCH_TIME, 0.0, 1.0)
			vis_len = maxf(1.0, L * (1.0 - (1.0 - lf) * (1.0 - lf)))
			launching = _launch_t < LAUNCH_TIME
	else:
		_launch_ring_pending = false
		_ring_sets.clear()
	var ring_h: float = beam_width() + 6.0
	var quad_len: float = L + (0.0 if pierce else ceilf(w) + 1.0)
	var quad_h: float = 2.0 * (ceilf(maxf(w, ring_h * 1.35) if pierce else w) + 2.0)
	_body.rotation = v.angle()
	_body.scale = Vector2(quad_len, quad_h)
	_mat.set_shader_parameter("beam_len", vis_len)
	_mat.set_shader_parameter("quad_len", quad_len)
	_mat.set_shader_parameter("quad_h", quad_h)
	_mat.set_shader_parameter("width", w)
	_mat.set_shader_parameter("t", _t)
	_mat.set_shader_parameter("spear", pierce)
	_mat.set_shader_parameter("lux", pierce)
	_mat.set_shader_parameter("full_len", L)
	_mat.set_shader_parameter("launching", launching)
	_mat.set_shader_parameter("flicker", 1.0 if (glow >= FLICKER_FROM and glow < 2.0 and int(_t * 30.0) % 2 == 0) else 0.0)
	_mat.set_shader_parameter("bright", 1.0 if glow >= 2.0 else 0.0)
	if pierce:
		_update_rings(L, ring_h, rel_k)
	_hit_k = move_toward(_hit_k, 1.0 if _hit_on else 0.0, delta / HIT_FADE)
	## namlu parıltısı: titreyen küçük yıldız, renk döner - yalnız ışın bir yaratığa değerken
	_tip.frame = (int(_t * 6.0) % 6) * 3 + (0 if int(_t * 15.0) % 2 == 0 else 1)
	_tip.modulate.a = rel_k * _hit_k
	_tip.visible = _hit_k > 0.01
	_update_sparks(delta, v / L, L)
	_update_impacts(delta)
	_update_scatter(rel_k)


## Halka takımları: her biri başladığı andan beri RING_SPEED ile uca koşar; takımın son halkası ucu geçince silinir.
func _update_rings(L: float, ring_h: float, rel_k: float) -> void:
	var arr := PackedVector4Array()
	var keep: Array = []
	for rs in _ring_sets:
		var age: float = _t - float(rs[0])
		var cols: Array = rs[1]
		if age * RING_SPEED - float(RING_COUNT - 1) * RING_GAP > L:
			continue
		keep.append(rs)
		for j in range(RING_COUNT):
			var pos: float = age * RING_SPEED - float(j) * RING_GAP
			var c: Color = cols[j]
			arr.append(Vector4(pos, c.r, c.g, c.b))
	_ring_sets = keep
	var n: int = mini(arr.size(), MAX_RING_SETS * RING_COUNT)
	arr.resize(MAX_RING_SETS * RING_COUNT) ## shader dizisi sabit 9: eksik kalanlar sıfır (ring_n dışında okunmaz)
	_mat.set_shader_parameter("rings", arr)
	_mat.set_shader_parameter("ring_n", n)
	_mat.set_shader_parameter("ring_h", ring_h)
	_mat.set_shader_parameter("ring_fade", rel_k)
	_mat.set_shader_parameter("ring_alpha", RING_ALPHA)


## Işık saçılması: vurulan düşmanın üstünde (kaster: hedef düğüm; uzak: temelde ışın ucu, finalde "sp"). Işın açılınca yumuşak belirir.
func _update_scatter(rel_k: float) -> void:
	var center: Vector2 = Vector2.ZERO
	var on: bool = false
	if _use_net:
		if pierce:
			on = _net_splash_on
			center = _net_splash
		else:
			on = true
			center = _to
	elif _target != null and is_instance_valid(_target):
		on = true
		center = _hit_pos if _hit_pos_set else _target.global_position
	on = on and _hit_k > 0.01 ## ışın hiçbir yaratığa değmiyorsa (boşa gidiyor / hedef değişirken savruluyor) saçılma yok
	_scatter.visible = on
	if not on:
		return
	_scatter.global_position = center.round()
	_scatter_mat.set_shader_parameter("t", _t)
	_scatter_mat.set_shader_parameter("back_ang", (_from - center).angle())
	_scatter_mat.set_shader_parameter("alpha", clampf(_t / SCATTER_FADE, 0.0, 1.0) * rel_k * _hit_k)


func _update_sparks(delta: float, u: Vector2, L: float) -> void:
	_spark_acc += 0.0 if _releasing else (SPARK_RATE_FINAL if pierce else SPARK_RATE) * delta
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


## Vuruş tiki: vurulan her hedefte 6 renkli patlama + (ilk konumda) vuruş sesi; finalde asadan 3 halka fırlar. Kaster weapon.gd, uzak "rbeam_hit".
func play_tick(positions: Array, with_sound: bool = true) -> void:
	if pierce and not _releasing and not positions.is_empty():
		_spawn_rings()
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
