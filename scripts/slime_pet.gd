extends Node2D

## EVCİL HAYVAN "MİNİK CADI" (iyi slime; kullanıcı isteği 2026-11-09, madde 509): "%5 saldırı gücü kazandırır ve ultini kullandığında pembe
## kulakları parıldayarak sana büyü yapar; canın, hasarın, boyutun, menzilin 8 saniye boyunca %15 artar (karakterin menzili ince bir çizgi
## olarak görünür). 120 saniye bekleme."
##  - +%5 saldırı gücü: player.gd pet_ap_percent (_refresh_item_ap_percent havuzu) - kurulumda player.gd _setup_pet yazar.
##  - Ulti kancası: player.gd _pet_on_ult_used (R'nin dört yolu: standart _activate_skill3, Büyücü R çeşitlemesi, Vampir yarasa açılışı,
##    Cadı iksir atışı) -> on_owner_ult(). Bekleme dolmamışsa / güvenli alandaysa / sahip yerde-ölüyse hiçbir şey olmaz.
##  - Büyü: cast_<yön> klibi (kulaklar parlar, kare 4'te büyü çıkar = CAST_RELEASE) -> fx_slime_spell.gd (kulaklardan sahibe pembe taneler,
##    ayakta büyü çemberi, yükselen oklar) + sahibin ekranında player.gd apply_slime_buff (statlar + menzil çizgisi slime_range_ring.gd).
##  - Zemin hayvanı (Kirpi deseni, pet_follow.gd doğal takip): yürürken hop_<yön> (kullanıcının zıplama kareleri), dururken idle_<yön>.
##    Büyü sırasında durur. Sayfa: tools/gen_slime_pet.py (kullanıcının pikselleri + tek ton gölge; zemin satırı 25 -> sprite ofseti -9).
##
## Çok oyunculu (Peri deseni): seçim ağdan gitmez. Sahibin ekranı büyüde + NET_HEARTBEAT'te bir NetworkManager.broadcast_slime yollar;
## diğer ekranlardaki kukla ilk olayda kurulur (remote_player.gd slime_event) ve büyüyü SADECE görsel oynatır. Boy artışı ağdan durum
## anlık görüntüsüyle gider (main.gd extra "psz" -> remote_player.gd _apply_pet_size); menzil çizgisi yalnız sahibin ekranında.

const CharAnim := preload("res://scripts/char_anim.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const PetFollowScript := preload("res://scripts/pet_follow.gd")
const FxSpellScript: GDScript = preload("res://scripts/fx_slime_spell.gd")
const FRAMES: SpriteFrames = preload("res://assets/pets/slime/slime_frames.tres")

const CAST_RELEASE := 0.4 ## büyü klibinin 4. karesi (10 fps) - gen_slime_pet.py CAST_SPELL_FRAME
const NET_HEARTBEAT := 8.0
const SPRITE_OFFSET_Y := -9.0 ## hücre 32x32, zemin satırı 25: düğüm orijini ayak hizasında
const EAR_ART_Y := 15.0 ## kulakların ortası zeminden bu kadar sanat pikseli yukarıda (tanelerin çıkış noktası)
## Takip (kirpi_pet.gd ile aynı model).
const OWNER_MOVING_SPEED := 25.0
const HEADING_SMOOTH := 5.0
const ACCEL := 1100.0
const MIN_SPEED_CAP := 220.0
const WARP_DISTANCE := 480.0
const STUCK_SECONDS := 1.5
const MOVING_SPEED_MIN := 12.0
const BEHIND_HYSTERESIS := 3.0
const HEEL_BEHIND := 15.0
const HEEL_SIDE := 13.0

var owner_body: Node2D = null
var char_anim: AnimatedSprite2D = null
var is_puppet: bool = false

var _sprite: AnimatedSprite2D = null
var _dir: String = "down"
var _moving: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _heading: Vector2 = Vector2.DOWN
var _follow = PetFollowScript.new()
var _owner_prev: Vector2 = Vector2.ZERO
var _owner_vel: Vector2 = Vector2.ZERO
var _have_owner_prev: bool = false
var _stuck_t: float = 0.0
var _stuck_sample: float = 0.0
var _stuck_ref: Vector2 = Vector2.ZERO
var _is_behind: bool = false
var _casting: bool = false
var _release_t: float = -1.0 ## >= 0: büyünün çıkmasına kalan süre
var _cooldown: float = 0.0
var _net_idle: float = NET_HEARTBEAT - 1.0 ## ilk "buradayım" kurulumdan 1 sn sonra


func setup(body: Node2D, anim_src: AnimatedSprite2D, puppet: bool) -> void:
	owner_body = body
	char_anim = anim_src
	is_puppet = puppet
	name = "Slime"
	_follow.comfort_radius = 24.0
	_follow.start_radius = 46.0
	top_level = true
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.offset = Vector2(0.0, SPRITE_OFFSET_Y)
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	global_scale = Vector2.ONE * EntityScale.SIZE
	_sprite.play(&"idle_down")
	global_position = _heel_point()
	_owner_prev = body.global_position
	_stuck_ref = global_position


func _process(delta: float) -> void:
	if not is_instance_valid(owner_body) or not is_instance_valid(char_anim):
		return
	delta = minf(delta, 0.1)
	_update_owner_velocity(delta)
	if _casting:
		_velocity = Vector2.ZERO
	else:
		_process_movement(delta)
	_update_animation()
	_update_draw_order()
	if _release_t >= 0.0:
		_release_t -= delta
		if _release_t < 0.0:
			_release()
	if not is_puppet:
		process_cooldown(delta)
		_net_idle += delta
		if _net_idle >= NET_HEARTBEAT:
			_broadcast(false)


## ---------------------------------------------------------------- takip (kirpi_pet.gd ile aynı)

func _update_owner_velocity(delta: float) -> void:
	var o: Vector2 = owner_body.global_position
	if _have_owner_prev and delta > 0.0:
		var raw: Vector2 = (o - _owner_prev) / delta
		_owner_vel = _owner_vel.lerp(raw, minf(1.0, delta * 12.0)) if raw.length() < 1500.0 else Vector2.ZERO
	_owner_prev = o
	_have_owner_prev = true


func _heel_point() -> Vector2:
	var o: Vector2 = owner_body.global_position
	var p: Vector2 = o - _heading * HEEL_BEHIND + _heading.orthogonal() * HEEL_SIDE
	if GameManager.is_position_blocked_by_terrain(p):
		return o
	return p


func _warp_to_heel() -> void:
	global_position = _heel_point()
	_velocity = Vector2.ZERO
	_follow.active = false
	_stuck_t = 0.0
	_stuck_ref = global_position


func _process_movement(delta: float) -> void:
	var o: Vector2 = owner_body.global_position
	if global_position.distance_to(o) > WARP_DISTANCE:
		_warp_to_heel()
		return
	if _owner_vel.length() > OWNER_MOVING_SPEED:
		_heading = _heading.lerp(_owner_vel.normalized(), minf(1.0, delta * HEADING_SMOOTH))
		_heading = _heading.normalized() if _heading.length() > 0.05 else _owner_vel.normalized()
	var cap: float = maxf(MIN_SPEED_CAP, _owner_vel.length() * 1.3)
	var desired: Vector2 = _follow.ground_velocity(global_position, o, delta, cap)
	_velocity = _velocity.move_toward(desired, ACCEL * delta)
	if _velocity.length() > 1.0:
		_step(_velocity * delta)
	_check_stuck(delta, desired.length() > 60.0)


func _step(step: Vector2) -> void:
	var p: Vector2 = global_position
	if not GameManager.is_position_blocked_by_terrain(p + step):
		global_position = p + step
	elif not GameManager.is_position_blocked_by_terrain(p + Vector2(step.x, 0.0)):
		global_position = p + Vector2(step.x, 0.0)
	elif not GameManager.is_position_blocked_by_terrain(p + Vector2(0.0, step.y)):
		global_position = p + Vector2(0.0, step.y)
	else:
		_velocity = Vector2.ZERO


func _check_stuck(delta: float, wants_move: bool) -> void:
	_stuck_sample += delta
	if _stuck_sample < 0.5:
		return
	_stuck_sample = 0.0
	var moved: float = global_position.distance_to(_stuck_ref)
	_stuck_ref = global_position
	if wants_move and moved < 14.0:
		_stuck_t += 0.5
	else:
		_stuck_t = 0.0
		return
	if _stuck_t >= STUCK_SECONDS:
		_stuck_t = 0.0
		if global_position.distance_to(owner_body.global_position) > 90.0:
			_warp_to_heel()


## ---------------------------------------------------------------- görsel

func _update_animation() -> void:
	_moving = _velocity.length() > MOVING_SPEED_MIN
	if _moving:
		_dir = _dir_of(_velocity)
	elif _casting:
		_dir = _dir_toward_owner()
	_apply_clip()


static func _dir_of(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"


## Büyü yaparken sahibine döner (arkası dönükken büyü yapmasın).
func _dir_toward_owner() -> String:
	var to: Vector2 = owner_body.global_position - global_position
	return _dir if to.length() < 2.0 else _dir_of(to)


## Klip = (cast_ | hop_ | idle_) + yön; aynı türde yön değişirken kare korunur.
func _apply_clip() -> void:
	var kind: String = "cast_" if _casting else ("hop_" if _moving else "idle_")
	var want := StringName(kind + _dir)
	if _sprite.animation == want:
		return
	var same_kind: bool = String(_sprite.animation).begins_with(kind)
	var f: int = _sprite.frame
	var p: float = _sprite.frame_progress
	_sprite.play(want)
	if same_kind:
		_sprite.set_frame_and_progress(f, p)


func current_clip() -> StringName:
	return _sprite.animation


func is_casting() -> bool:
	return _casting


func _on_animation_finished() -> void:
	if _casting:
		_casting = false
		_apply_clip()


## Hayvan sahibinin arkasındaysa çocuk sırasının başında (sahibin sprite'ının altında), önündeyse sonunda çizilir (kirpi_pet.gd).
func _update_draw_order() -> void:
	var dy: float = global_position.y - owner_body.global_position.y
	var want_behind: bool = _is_behind
	if dy < -BEHIND_HYSTERESIS:
		want_behind = true
	elif dy > BEHIND_HYSTERESIS:
		want_behind = false
	if want_behind != _is_behind or get_parent() != owner_body:
		_is_behind = want_behind
		if get_parent() == owner_body:
			owner_body.move_child(self, 0 if want_behind else owner_body.get_child_count() - 1)


## Büyü başlar (iki ekranda aynı): kulak parlama klibi; CAST_RELEASE sonra _release efekti (sahibinde ayrıca buff) çıkarır.
func _start_cast() -> void:
	_casting = true
	_release_t = CAST_RELEASE
	_velocity = Vector2.ZERO
	_dir = _dir_toward_owner()
	_sprite.play(StringName("cast_" + _dir))


func _release() -> void:
	if not is_instance_valid(owner_body) or not is_instance_valid(char_anim):
		return
	var u: float = absf(char_anim.scale.x) ## sahibin sanat pikseli, kendi yerel uzayında (büyü efekti karakter pikseliyle aynı boyda)
	var size_mult: float = float(owner_body.get("_pet_size_mult")) if owner_body.get("_pet_size_mult") != null else 1.0
	u /= maxf(0.01, size_mult) ## buff tazelenirken büyümüş boydan değil taban boydan
	var fx: Node2D = FxSpellScript.new()
	fx.name = "SlimeSpellFx"
	fx.setup(owner_body.to_local(ear_global()), _owner_art_local(40.0, u), _owner_art_local(22.0, u), u)
	owner_body.add_child(fx, true)
	if not is_puppet and owner_body.has_method("apply_slime_buff"):
		owner_body.apply_slime_buff()


## Kulakların ortasının dünya konumu (tanelerin çıkış noktası).
func ear_global() -> Vector2:
	return global_position + Vector2(0.0, -EAR_ART_Y) * global_scale.y


## Sahibin sprite'ının 48x48 sanat hücresinde art_y satırının sahibin yerel uzayındaki yeri (peri_pet.gd _owner_art_local ile aynı kural).
func _owner_art_local(art_y: float, u: float) -> Vector2:
	return char_anim.position + (Vector2(0.0, art_y - 24.0) + char_anim.offset) * u


## ---------------------------------------------------------------- sahibinin ekranı

## Her karede (testler doğrudan çağırır): bekleme sayacı - güvenli alanda donar (madde 327).
func process_cooldown(delta: float) -> void:
	if owner_frozen():
		return
	_cooldown = maxf(0.0, _cooldown - delta)


## player.gd _pet_on_ult_used: sahip ultisini kullandı. Döner: büyü başladı mı.
func on_owner_ult() -> bool:
	if is_puppet or _cooldown > 0.0 or _casting or owner_frozen() or not owner_can_receive():
		return false
	_cooldown = PetCatalog.SLIME_COOLDOWN
	_start_cast()
	_broadcast(true)
	return true


func owner_frozen() -> bool:
	return is_instance_valid(owner_body) and owner_body.has_method("is_safe_zone_frozen") and owner_body.is_safe_zone_frozen()


func owner_can_receive() -> bool:
	return is_instance_valid(owner_body) and owner_body.get("is_dead") != true and owner_body.get("is_downed") != true


## HUD evcil yuvası (hud_pet_slot.gd): kalan bekleme oranı 0..1 (0 = hazır) ve saniyesi.
func cooldown_fraction() -> float:
	return clampf(_cooldown / PetCatalog.SLIME_COOLDOWN, 0.0, 1.0)


func cooldown_left() -> float:
	return _cooldown


func _broadcast(cast: bool) -> void:
	_net_idle = 0.0
	if is_puppet or not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.broadcast_slime.rpc(multiplayer.get_unique_id(), cast)


## ---------------------------------------------------------------- kukla (diğer oyuncuların ekranı)

## remote_player.gd -> slime_event: sahibi büyü yaptı; buff vermez, sadece görsel.
func play_cast_visual() -> void:
	if not _casting:
		_start_cast()
