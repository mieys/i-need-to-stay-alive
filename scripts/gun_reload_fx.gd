extends Node

## Tabanca + Tüfek ŞARJÖR DOLDURMA görseli + sesi (2026-10-19, madde 296). Kaster (weapon.gd) VE uzak kukla (remote_player.gd)
## AYNI sürücüyü kurar (CLAUDE.md "iki yer" kuralı; kukla "weapon_reload" yayınıyla):
##  - ikon pozu GunMagMath.pose: namlu kalkar, şarjör düşerken silkinir, yeni şarjör çakılınca iner, horoz çekilirken geri kayar,
##    sonunda nişan açısına döner;
##  - MAG_OUT anında boş şarjör düşer (ShellCasingFx.drop_mag) + "çıkar" sesi, MAG_IN "tak" sesi, COCK "horoz" sesi;
##  - bitişte uç parıltısı (WeaponFollowFx.spawn_glint - hücum takibinin parıltısıyla aynı).
## Silahın üstünde mermi sayısı / doldurma göstergesi YOK (kullanıcı 2026-10-19: "üstlerinde mermi miktarı görünmesin").
## Kasterde ilerleme weapon.gd'den itilir (set_progress; doldurma sırasında saldırı hızı değişirse anında yansır), kuklada yayındaki
## süreyle kendi saatinde ilerler. İkon meta "gun_reload" = bu sürücü (kukla nişan döngüsü o ikonu atlar).

const GunMagMath := preload("res://scripts/gun_mag_math.gd")
const ShellCasingFx := preload("res://scripts/shell_casing_fx.gd")
const WeaponFollowFx := preload("res://scripts/weapon_follow_fx.gd")
const SND_OUT := preload("res://assets/audio/gun/gun_mag_out.wav")
const SND_IN := preload("res://assets/audio/gun/gun_mag_in.wav")
const SND_COCK := preload("res://assets/audio/gun/gun_cock.wav")

const META := &"gun_reload"
const SND_DB := {"out": -11.0, "in": -9.0, "cock": -9.0}
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

var _events: int = 0 ## 1 şarjör düştü, 2 takıldı, 4 horoz
var _took_over: bool = false
var _done: bool = false


## host: sürücünün ebeveyni (kaster: silah düğümü, kukla: remote_player). opts: base_pos, base_scale, forward_deg, external,
## kill_tweens (Callable - konum devralınırken son atışın tween'ini keser).
static func begin(host: Node, p_icon: Node2D, p_key: String, p_duration: float, p_owner: Node2D, opts: Dictionary = {}) -> Node:
	if host == null or p_icon == null or not is_instance_valid(p_icon) or not GunMagMath.has_mag(p_key):
		return null
	var old: Variant = p_icon.get_meta(META) if p_icon.has_meta(META) else null
	if old is Node and is_instance_valid(old):
		(old as Node).call("abort")
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
	if opts.get("kill_tweens") is Callable:
		d.set("kill_tweens", opts["kill_tweens"])
	host.add_child(d)
	d.call("_start")
	return d


func _start() -> void:
	start_rot = icon.rotation
	barrel_world = _barrel_world_dir()
	up_sign = -1.0 if barrel_world.x >= 0.0 else 1.0
	icon.set_meta(META, self)


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
	if not external:
		t = minf(1.0, t + delta / duration)
	_apply()
	if not external and t >= 1.0:
		finish()


func _apply() -> void:
	var p: Dictionary = GunMagMath.pose(t)
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
	if t >= GunMagMath.MAG_OUT_AT and (_events & 1) == 0:
		_events |= 1
		ShellCasingFx.drop_mag(icon, key, owner_body)
		_sound(SND_OUT, "out")
	if t >= GunMagMath.MAG_IN_AT and (_events & 2) == 0:
		_events |= 2
		_sound(SND_IN, "in")
	if t >= GunMagMath.COCK_AT and (_events & 4) == 0:
		_events |= 4
		_sound(SND_COCK, "cock")


## Doldurma tamam: ikon nişan pozuna döner, uç parıltısı.
func finish() -> void:
	if _done:
		return
	_done = true
	t = 1.0
	if is_instance_valid(icon):
		if (_events & 1) == 0:
			ShellCasingFx.drop_mag(icon, key, owner_body) ## çok kısa doldurmada kare atlandıysa görsel yine olsun (ses yığılmasın)
		_restore_icon()
		if icon.is_visible_in_tree():
			WeaponFollowFx.spawn_glint(icon.get_parent(), icon, forward_deg)
	queue_free()


## İptal (sahip öldü / silah kaldırıldı): poz geri, ses/parıltı yok.
func abort() -> void:
	if is_instance_valid(icon):
		_restore_icon()
	_done = true
	queue_free()


func _restore_icon() -> void:
	icon.rotation = start_rot
	if _took_over:
		icon.position = base_pos
		icon.scale = base_scale
	if icon.has_meta(META) and icon.get_meta(META) == self:
		icon.remove_meta(META)


func _sound(stream: AudioStream, kind: String) -> void:
	if not is_instance_valid(icon) or not icon.is_inside_tree():
		return
	var scene: Node = icon.get_tree().current_scene
	if scene == null:
		return
	var asp := AudioStreamPlayer2D.new()
	asp.stream = stream
	asp.volume_db = float(SND_DB.get(kind, -10.0))
	asp.pitch_scale = float(GunMagMath.cfg(key).get("pitch", 1.0)) * randf_range(0.97, 1.03)
	asp.max_distance = 900.0
	asp.attenuation = 1.6
	scene.add_child(asp)
	asp.global_position = icon.global_position
	asp.finished.connect(asp.queue_free)
	asp.play()
