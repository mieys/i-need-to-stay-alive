extends Node

## Tabanca / Tüfek / Pompalı / Makineli ŞARJÖR DOLDURMA görseli + sesi. İlk hâli 2026-10-19 (madde 296: sadece poz + gri şarjör + üretilmiş
## sesler); 2026-11-13 yeniden, madde 645 (kullanıcı: "şarjör doldururken mermi veya şarjör çıkarılıp eklenmiyor", sesler masaüstündeki 3
## dosyadan; prototip tools/proto_20261113/sarjor/index.html onaylandı). Zaman çizelgesi + parçalar + ses anları SAF:
## gun_reload_math.gd. Kaster (weapon.gd) VE uzak kukla (remote_player.gd, "weapon_reload" yayını) AYNI sürücüyü kurar.
##  - Tabanca (Luger): boş şarjör kabzadan eğik kayıp düşer, yenisi aşağıdan kayıp oturur (kıvılcım), üstteki kol kalkıp çakılır.
##  - Tüfek: kutu şarjör düşer, yenisi alttan oturur, sürgü açılınca yatakta pirinç mermi görünür, ileri itilir.
##  - Pompalı: eksik fişek kadar kırmızı fişek alttaki yuvaya tek tek sürülür, sonra kundak geri-ileri (pompa).
##  - Makineli (madde 652): uzun düz şarjör aşağı kayıp düşer, yenisi alttan oturur (kıvılcım), kurma kolu geri-ileri (iki tepme).
## Parçalar ikonun iki çocuk katmanında çizilir (arka: show_behind_parent - gövdenin içinde kalan kısım görünmez; ön), ikonun
## dönüş/ölçek/aynalamasını izler. Gövdeden ayrılan parça varken ikon dokusu geçici olarak parçasız sürüme döner (_restore geri alır).
## Sesler: her olayın kendi parçası (assets/audio/gun/reload/), anahtar anı olaya oturacak şekilde önceden başlar; doldurma
## kısalınca en çok MAX_RATE hızlanır. Silahın üstünde mermi sayısı / doldurma göstergesi YOK (kullanıcı 2026-10-19).
## Kasterde ilerleme weapon.gd'den itilir (set_progress), kuklada yayındaki süreyle kendi saatinde ilerler. İkon meta "gun_reload"
## = bu sürücü (kukla nişan döngüsü o ikonu atlar).
## İkinci kip: pompalı ATIŞ SONRASI pompa (on_shot): kundak geri-ileri + boş fişek geri vuruşta fırlar (META yok, nişanı durdurmaz).

const GunMagMath := preload("res://scripts/gun_mag_math.gd")
const GunReloadMath := preload("res://scripts/gun_reload_math.gd")
const ShellCasingFx := preload("res://scripts/shell_casing_fx.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const MakineliHeatFx := preload("res://scripts/makineli_heat_fx.gd")

const PIECES := {
	&"tabanca_mag": preload("res://assets/fx/gun/reload/tabanca_mag.png"),
	&"tabanca_toggle": preload("res://assets/fx/gun/reload/tabanca_toggle.png"),
	&"tabanca_toggle_open": preload("res://assets/fx/gun/reload/tabanca_toggle_open.png"),
	&"tufek_mag": preload("res://assets/fx/gun/reload/tufek_mag.png"),
	&"tufek_nomag": preload("res://assets/fx/gun/reload/tufek_nomag.png"),
	&"tufek_round": preload("res://assets/fx/gun/reload/tufek_round.png"),
	&"tufek_bolt_open": preload("res://assets/fx/gun/reload/tufek_bolt_open.png"),
	&"pompali_shell": preload("res://assets/fx/gun/reload/pompali_shell.png"),
	&"pompali_fore": preload("res://assets/fx/gun/reload/pompali_fore.png"),
	&"pompali_nofore": preload("res://assets/fx/gun/reload/pompali_nofore.png"),
	&"makineli_mag": preload("res://assets/fx/gun/reload/makineli_mag.png"), ## madde 652
	&"makineli_nomag": preload("res://assets/fx/gun/reload/makineli_nomag.png"),
}
## Gövde yerine geçen (parçası çıkarılmış) dokular - yalnız bunlar geri alınır, başka bir sistemin koyduğu doku ezilmez.
const BODY_VARIANTS := [&"tabanca_toggle_open", &"tufek_nomag", &"tufek_bolt_open", &"pompali_nofore", &"makineli_nomag"]
const SOUNDS := {
	&"tabanca_out": preload("res://assets/audio/gun/reload/tabanca_out.wav"),
	&"tabanca_in": preload("res://assets/audio/gun/reload/tabanca_in.wav"),
	&"tabanca_rack": preload("res://assets/audio/gun/reload/tabanca_rack.wav"),
	&"tufek_out": preload("res://assets/audio/gun/reload/tufek_out.wav"),
	&"tufek_in": preload("res://assets/audio/gun/reload/tufek_in.wav"),
	&"tufek_bolt": preload("res://assets/audio/gun/reload/tufek_bolt.wav"),
	&"pompali_shell": preload("res://assets/audio/gun/reload/pompali_shell.wav"),
	&"pompali_pump": preload("res://assets/audio/gun/reload/pompali_pump.wav"),
	## Makineli (madde 652): kullanıcının "ses efekti.mp3" dosyasından (tools/gen_makineli_ses.py)
	&"makineli_out": preload("res://assets/audio/gun/reload/makineli_out.wav"),
	&"makineli_in": preload("res://assets/audio/gun/reload/makineli_in.wav"),
	&"makineli_back": preload("res://assets/audio/gun/reload/makineli_back.wav"),
	&"makineli_fwd": preload("res://assets/audio/gun/reload/makineli_fwd.wav"),
}

const META := &"gun_reload"
const PUMP_META := &"gun_pump_shot"
const SND_DB := -7.0 ## parçalar -1 dBFS tepeye normalize (gen_gun_reload_fx.py); atış sesinin (-6,5 / -8) biraz altında
const TAKEOVER_AT := 0.16 ## bu ilerlemeden önce konum/ölçek son atışın geri tepme tween'ine bırakılır (poz o ana kadar sadece döner)

var icon: Node2D = null
var key: String = ""
var duration: float = 1.0
var t: float = 0.0
var external: bool = false
var owner_body: Node2D = null
var base_pos: Vector2 = Vector2.ZERO
var base_scale: Vector2 = Vector2.ONE
var start_rot: float = 0.0
var up_sign: float = -1.0
var barrel_world: Vector2 = Vector2.RIGHT
var forward_deg: float = 0.0
var kill_tweens: Callable = Callable()
var shells: int = -1 ## pompalı: sürülecek fişek (eksik mermi); diğerleri kullanmaz
var pump_mode: bool = false
var aim_dir: Vector2 = Vector2.RIGHT

var _len: float = 1.0
var _sounds: Array = []
var _si: int = 0
var _dropped: bool = false
var _took_over: bool = false
var _done: bool = false
var _parts_ok: bool = false
var _base_tex: Texture2D = null
var _state: Dictionary = {}
var _back: Node2D = null
var _front: Node2D = null
var _ejected: bool = false


## host: sürücünün ebeveyni (kaster: silah düğümü, kukla: remote_player). opts: base_pos, base_scale, forward_deg, external,
## kill_tweens (Callable - konum devralınırken son atışın tween'ini keser), shells (pompalı: sürülecek fişek sayısı).
static func begin(host: Node, p_icon: Node2D, p_key: String, p_duration: float, p_owner: Node2D, opts: Dictionary = {}) -> Node:
	if host == null or p_icon == null or not is_instance_valid(p_icon) or not GunMagMath.has_mag(p_key):
		return null
	var old: Variant = p_icon.get_meta(META) if p_icon.has_meta(META) else null
	if old is Node and is_instance_valid(old):
		(old as Node).call("abort")
	if p_key == "makineli":
		MakineliHeatFx.cool(p_icon) ## namlu kızarması doldurmada söner (madde 652)
	var d: Node = (load("res://scripts/gun_reload_fx.gd") as GDScript).new()
	d.name = "GunReloadFx"
	d.set("icon", p_icon)
	d.set("key", p_key)
	d.set("duration", maxf(0.05, p_duration))
	d.set("owner_body", p_owner)
	d.set("base_pos", opts.get("base_pos", p_icon.position))
	d.set("base_scale", opts.get("base_scale", p_icon.scale))
	d.set("forward_deg", float(opts.get("forward_deg", 0.0)))
	d.set("external", bool(opts.get("external", false)))
	d.set("shells", int(opts.get("shells", -1)))
	if opts.get("kill_tweens") is Callable:
		d.set("kill_tweens", opts["kill_tweens"])
	host.add_child(d)
	d.call("_start")
	return d


## Atış anında (kaster weapon.gd _fire_at, kukla remote_player.gd "weapon_fire"): boş kovan. Pompalı: kovan hemen değil, atıştan
## sonraki pompanın geri vuruşunda (pump_shot_sound.gd ile aynı 0,2 sn) çıkar + kundak geri-ileri kayar.
## Makineli (madde 652): namlu ısınır (makineli_heat_fx.gd) ve kovan 2 atışta 1 çıkar (saniyede 12+ atışta kovan yağmuru + tavan 48
## en eski kovanları anında silerdi). Sayaç ikonun meta'sında - kaster ve kukla kendi ikonunda aynı kuralı işler.
const CASING_EVERY := {"makineli": 2}


static func on_shot(p_icon: Node2D, p_key: String, p_aim: Vector2, p_owner: Node2D) -> void:
	if p_key == "makineli":
		MakineliHeatFx.shot(p_icon)
	if CASING_EVERY.has(p_key) and p_icon != null and is_instance_valid(p_icon):
		var c: int = int(p_icon.get_meta(&"casing_n", 0)) + 1
		p_icon.set_meta(&"casing_n", c)
		if c % int(CASING_EVERY[p_key]) != 0:
			return
	if p_key != "pompali":
		ShellCasingFx.eject(p_icon, p_key, p_aim, p_owner)
		return
	if p_icon == null or not is_instance_valid(p_icon) or not p_icon.is_inside_tree():
		return
	var old: Variant = p_icon.get_meta(PUMP_META) if p_icon.has_meta(PUMP_META) else null
	if old is Node and is_instance_valid(old):
		(old as Node).call("_pump_finish") ## önceki atışın pompası yarıdaysa kovanını hemen bırakır, yenisi baştan
	var d: Node = (load("res://scripts/gun_reload_fx.gd") as GDScript).new()
	d.name = "GunPumpShotFx"
	d.set("icon", p_icon)
	d.set("key", p_key)
	d.set("owner_body", p_owner)
	d.set("aim_dir", p_aim)
	d.set("pump_mode", true)
	p_icon.add_child(d)
	d.call("_pump_start")


func _start() -> void:
	start_rot = icon.rotation
	barrel_world = _barrel_world_dir()
	up_sign = -1.0 if barrel_world.x >= 0.0 else 1.0
	icon.set_meta(META, self)
	_len = GunReloadMath.length(key, shells)
	_sounds = GunReloadMath.sounds(key, shells)
	_setup_parts()


## Parça katmanları yalnız ikon bu silahın OYUN çizimini gösterirken (koordinatlar o çizime göre); yoksa poz + ses yine çalışır.
func _setup_parts() -> void:
	if not (icon is Sprite2D) or not GunReloadMath.has_reload(key):
		return
	var s: Sprite2D = icon as Sprite2D
	_base_tex = WeaponTierArt.texture(key)
	if _base_tex == null or not (s.texture == _base_tex or _is_variant(s.texture)):
		return
	_parts_ok = true
	_back = _make_layer(true)
	_front = _make_layer(false)


func _make_layer(behind: bool) -> Node2D:
	var n := Node2D.new()
	n.name = "ReloadBack" if behind else "ReloadFront"
	n.show_behind_parent = behind
	n.draw.connect(_draw_layer.bind(n, behind))
	icon.add_child(n)
	return n


func _is_variant(tex: Texture2D) -> bool:
	if tex == null:
		return false
	for v in BODY_VARIANTS:
		if PIECES[v] == tex:
			return true
	return false


## Namlunun dünyadaki yönü (sanatın ileri açısı + aynalama + ikonun küresel dönüşü).
func _barrel_world_dir() -> Vector2:
	var local := Vector2.RIGHT.rotated(deg_to_rad(forward_deg))
	if icon is Sprite2D and (icon as Sprite2D).flip_h:
		local.x = -local.x
	var w: Vector2 = icon.global_transform.basis_xform(local)
	return w.normalized() if w.length() > 0.0001 else Vector2.RIGHT


func set_progress(p: float) -> void:
	t = clampf(p, 0.0, 1.0)


func is_done() -> bool:
	return _done


func _process(delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(icon):
		_done = true
		queue_free()
		return
	if pump_mode:
		_pump_process(delta)
		return
	if not external:
		t = minf(1.0, t + delta / duration)
	_apply()
	if not external and t >= 1.0:
		finish()


func _apply() -> void:
	var u: float = t * _len
	var p: Dictionary = GunReloadMath.pose(key, u, shells)
	icon.rotation = start_rot + up_sign * float(p["tilt"])
	if not _took_over and t >= TAKEOVER_AT:
		_took_over = true
		if kill_tweens.is_valid():
			kill_tweens.call()
	if _took_over:
		var world_off := Vector2(0.0, -float(p["lift"])) - barrel_world * float(p["kick"])
		var par: Node2D = icon.get_parent() as Node2D
		var local_off: Vector2 = par.global_transform.affine_inverse().basis_xform(world_off) if par != null else world_off
		icon.position = base_pos + local_off
		icon.scale = base_scale * Vector2(float(p["sx"]), float(p["sy"]))
	if _parts_ok:
		_state = GunReloadMath.parts(key, u, shells)
		_set_body(StringName(_state["tex"]))
		_redraw()
	var du: float = GunReloadMath.drop_u(key)
	if du >= 0.0 and u >= du and not _dropped:
		_dropped = true
		ShellCasingFx.drop_mag(icon, key, owner_body, GunReloadMath.drop_piece(key))
	## sesler: parça, anahtar anı olaya denk gelecek kadar önce başlar (speed = temel sn / gerçek sn)
	var speed: float = _len / duration
	while _si < _sounds.size():
		var s: Array = _sounds[_si]
		if u + 0.0001 < GunReloadMath.sound_start_u(float(s[1]), float(s[2]), speed):
			break
		_si += 1
		_sound(StringName(s[0]), clampf(speed, 1.0, GunReloadMath.MAX_RATE))


func _set_body(want: StringName) -> void:
	if not is_instance_valid(icon) or not (icon is Sprite2D) or _base_tex == null:
		return
	var s: Sprite2D = icon as Sprite2D
	var tex: Texture2D = PIECES[want] if want != &"" and PIECES.has(want) else _base_tex
	if s.texture != tex and (s.texture == _base_tex or _is_variant(s.texture)):
		s.texture = tex


func _redraw() -> void:
	if is_instance_valid(_back):
		_back.queue_redraw()
	if is_instance_valid(_front):
		_front.queue_redraw()


## Katman çizimi ikonun yerel uzayında: doku pikseli (sol-üst köşeye göre) -> ikon merkezine göre; aynalama ölçekle.
func _draw_layer(n: Node2D, behind: bool) -> void:
	if _state.is_empty() or not is_instance_valid(icon) or not (icon is Sprite2D) or _base_tex == null:
		return
	var s: Sprite2D = icon as Sprite2D
	n.draw_set_transform(s.offset, 0.0, Vector2(-1.0 if s.flip_h else 1.0, -1.0 if s.flip_v else 1.0))
	var half: Vector2 = _base_tex.get_size() * 0.5 if s.centered else Vector2.ZERO
	for p in _state["back" if behind else "front"]:
		var tex: Texture2D = PIECES.get(p[0])
		if tex != null:
			n.draw_texture(tex, (p[1] as Vector2) - half, Color(1.0, 1.0, 1.0, float(p[2])))
	if not behind:
		for sp in _state["sparks"]:
			n.draw_rect(Rect2((sp[0] as Vector2) - half, Vector2.ONE), Color(sp[1] as Color, float(sp[2])))


## Doldurma tamam: ikon nişan pozuna döner, uç parıltısı.
func finish() -> void:
	if _done:
		return
	_done = true
	t = 1.0
	if is_instance_valid(icon):
		if not _dropped and GunReloadMath.drop_u(key) >= 0.0:
			## çok kısa doldurmada kare atlandıysa görsel yine olsun (ses yığılmasın)
			ShellCasingFx.drop_mag(icon, key, owner_body, GunReloadMath.drop_piece(key))
		_restore_icon()
		if icon.is_visible_in_tree():
			WeaponFollowFx.spawn_glint(icon.get_parent(), icon, forward_deg)
	queue_free()


## İptal (sahip öldü / silah kaldırıldı): poz geri, ses/parıltı yok.
func abort() -> void:
	if pump_mode:
		_pump_finish()
		return
	if is_instance_valid(icon):
		_restore_icon()
	_done = true
	queue_free()


func _restore_icon() -> void:
	icon.rotation = start_rot
	if _took_over:
		icon.position = base_pos
		icon.scale = base_scale
	_state = {}
	_set_body(&"")
	for n in [_back, _front]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_back = null
	_front = null
	if icon.has_meta(META) and icon.get_meta(META) == self:
		icon.remove_meta(META)


func _sound(clip: StringName, rate: float) -> void:
	if not is_instance_valid(icon) or not icon.is_inside_tree() or not SOUNDS.has(clip):
		return
	var scene: Node = icon.get_tree().current_scene
	if scene == null:
		return
	var asp := AudioStreamPlayer2D.new()
	asp.stream = SOUNDS[clip]
	asp.volume_db = SND_DB
	asp.pitch_scale = rate * randf_range(0.98, 1.02)
	asp.max_distance = 900.0
	asp.attenuation = 1.6
	scene.add_child(asp)
	asp.global_position = icon.global_position
	asp.finished.connect(asp.queue_free)
	asp.play()


## ---------------------------------------------------------------- atış sonrası pompa (yalnız pompalı)
func _pump_start() -> void:
	icon.set_meta(PUMP_META, self)
	_base_tex = WeaponTierArt.texture(key)
	var s: Sprite2D = icon as Sprite2D if icon is Sprite2D else null
	_parts_ok = s != null and _base_tex != null and (s.texture == _base_tex or _is_variant(s.texture))
	if _parts_ok:
		_front = _make_layer(false)


func _pump_process(delta: float) -> void:
	t += delta
	## doldurma sürücüsü ikonu devraldıysa kundağa o dokunur; burada yalnız kovan kalır
	var reload_owns: bool = icon.has_meta(META)
	if _parts_ok and not reload_owns:
		_state = GunReloadMath.pump_shot_parts(t)
		_set_body(StringName(_state["tex"]))
		_redraw()
	elif _parts_ok:
		_state = {}
		_redraw()
	if not _ejected and t >= float(GunReloadMath.PUMP_SHOT["eject"]):
		_ejected = true
		ShellCasingFx.eject(icon, key, aim_dir, owner_body)
	if t >= float(GunReloadMath.PUMP_SHOT["f1"]):
		_pump_finish()


func _pump_finish() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(icon):
		if not _ejected:
			_ejected = true
			ShellCasingFx.eject(icon, key, aim_dir, owner_body)
		_state = {}
		if not icon.has_meta(META):
			_set_body(&"")
		if is_instance_valid(_front):
			_front.queue_free()
		if icon.has_meta(PUMP_META) and icon.get_meta(PUMP_META) == self:
			icon.remove_meta(PUMP_META)
	queue_free()
