extends Node2D

## EVCİL HAYVAN "HAYALET" (kullanıcı isteği 2026-11-09, madde 509): "%5 sıvışma verir. Canın %25'in altına düştüğünde kendi bedeniyle senin
## üstünü kaplayarak seni 5 saniye boyunca görünmez ve dokunulmaz yapar (90 saniye bekleme). Hayalet yarı opak olmalı."
##  - +%5 sıvışma: player.gd _setup_pet dodge_chance'a ekler (stat: kart/eşya sıvışmasıyla aynı sınır).
##  - Tetik (sahibin ekranı): can < azami x HAYALET_HP_THRESHOLD ve bekleme dolmuşsa -> player.gd start_ghost_cover (görünmez: yaratıklar hedef
##    almaz [is_invisible_now + ağda extra "is_invisible"], dokunulmaz: take_damage girmez, yaratıkların içinden geçer). Hem her karede
##    (process_guard) hem take_damage'in can düştüğü anda (player.gd _item_after_health_damage -> check_low_health) bakılır: aynı karedeki
##    ikinci vuruş da engellenir.
##  - Görsel (iki ekranda aynı, kullanıcının çizimi tools/gen_hayalet_pet.py): süzülme idle / yana gidiş move_right (sol = ayna) / sahip yerde
##    ya da ölüyken cry. Kaplama: sahibe uçar -> büyük hayalet (Scale2x, aynı piksel boyu) küçük bir noktadan açılıp üstünü örter (cover_in) ->
##    cover döngüsü; sahip yürürken doğal hâlindeki gibi gidiş yönüne eğilir (cover_move_right, sola ayna; madde 513) -> süre bitince kıvrılıp
##    küçülerek kaybolur (cover_out) -> küçük hayalet yanında aynı şekilde açılıp belirir (appear). Yok olma = kaynak 35-41 (kullanıcı seçimi;
##    toz olup dağılma 21-29 kullanılmıyor). Yarı opak: GHOST_ALPHA / COVER_ALPHA.
##
## Çok oyunculu (Peri deseni): seçim ağdan gitmez. Sahibin ekranı kaplama başlayınca/bitince + NET_HEARTBEAT'te bir NetworkManager.broadcast_hayalet
## yollar; diğer ekranlardaki kukla ilk olayda kurulur (remote_player.gd hayalet_event) ve kaplamayı SADECE görsel oynatır. Görünmezlik/
## dokunulmazlığın kendisi durum anlık görüntüsüyle gider (main.gd extra "is_invisible").

const CharAnim := preload("res://scripts/char_anim.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const PetFollowScript := preload("res://scripts/pet_follow.gd")
const PhysicsInterp := preload("res://scripts/physics_interp.gd")
const FRAMES: SpriteFrames = preload("res://assets/pets/hayalet/hayalet_frames.tres")

const GHOST_ALPHA := 0.62 ## yarı opak (kullanıcı isteği)
const COVER_ALPHA := 0.72 ## kaplarken biraz daha yoğun: altındaki karakter seçilir ama "örtülü" okunur
## Süzülme noktası sahibin 48x48 sanat hücresinde (peri_pet.gd ile aynı kural): baş hizasının biraz üstü, yanında.
const HOVER_ART_Y := 4.0
const HOVER_ART_SIDE := 22.0
const SNAP_DIST := 240.0
const BOB_PERIOD := 1.8
const MOVE_ANIM_SPEED := 40.0 ## yay hızı bunu aşınca yana gidiş klibi
const NET_HEARTBEAT := 8.0
## Kaplama: büyük hayaletin gövdesinin altı (hücre 64, gövde satır 8-58) sahibin ayağının biraz altına gelir.
const COVER_FEET_ART_Y := 45.0
const COVER_BODY_BOTTOM := 26.0 ## büyük hücrenin merkezinden gövdenin altına (piksel)
const FLY_IN_TIME := 0.15
const COVER_REMOTE_FALLBACK := 2.0 ## kuklada "bitti" olayı gelmezse süre + bu kadar sonra kendiliğinden biter
## Örtüde eğilme (madde 513): sahibin yatay hızı (yumuşatılmış) bunu aşınca eğilme klibi, OFF'un altına inince öne döner (eşik aralığı:
## yürüme hızı sınırda gidip gelirken klip/ayna titremesin). Doğal hâlde aynı karar MOVE_ANIM_SPEED ile hayaletin kendi yay hızından.
## Örtü boyunca karakterin kendisi de soluklaşır (madde 515): sahibin sprite saydamlığı bu orana iner (çalı saydamlığıyla çarpılır,
## player.gd / remote_player.gd set_pet_cover_fade); örtü açılırken/kapanırken CHAR_FADE_TIME'da yumuşak geçiş.
const CHAR_FADE := 0.45
const CHAR_FADE_TIME := 0.25
const COVER_MOVE_ON := 40.0
const COVER_MOVE_OFF := 22.0
const OWNER_VEL_SMOOTH := 10.0

enum { HOVER, FLY_IN, COVER_IN, COVER, COVER_OUT, APPEAR }

var owner_body: Node2D = null
var char_anim: AnimatedSprite2D = null
var is_puppet: bool = false

var _sprite: AnimatedSprite2D = null
var _vel: Vector2 = Vector2.ZERO
var _base: Vector2 = Vector2.ZERO
var _follow = PetFollowScript.new()
var _side: float = 1.0
var _t: float = 0.0
var _state: int = HOVER
var _state_t: float = 0.0
var _fly_from: Vector2 = Vector2.ZERO
var _cooldown: float = 0.0
var _covering_owner: bool = false ## sahibin ekranı: sahibin kaplaması bu hayaletten mi açıldı
var _net_idle: float = NET_HEARTBEAT - 1.0
var _owner_prev: Vector2 = Vector2.ZERO
var _owner_vel: Vector2 = Vector2.ZERO
var _have_owner_prev: bool = false
var _cover_moving: bool = false
var _char_fade: float = 1.0


func setup(body: Node2D, anim_src: AnimatedSprite2D, puppet: bool) -> void:
	owner_body = body
	char_anim = anim_src
	is_puppet = puppet
	name = "Hayalet"
	top_level = true
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.modulate.a = GHOST_ALPHA
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"idle")
	global_scale = char_anim.global_scale.abs()
	_base = _hover_global()
	global_position = _base


func _process(delta: float) -> void:
	if not is_instance_valid(owner_body) or not is_instance_valid(char_anim):
		return
	_t += delta
	_state_t += delta
	var facing: String = CharAnim.dir_of(String(char_anim.animation))
	if facing == "left":
		_side = 1.0
	elif facing == "right":
		_side = -1.0
	global_scale = char_anim.global_scale.abs()
	_update_owner_velocity(delta)
	match _state:
		HOVER, APPEAR:
			_process_hover(delta)
		FLY_IN:
			var q: float = clampf(_state_t / FLY_IN_TIME, 0.0, 1.0)
			global_position = _fly_from.lerp(cover_global(), q * q)
			_base = global_position
			if q >= 1.0:
				_set_state(COVER_IN)
		COVER_IN, COVER, COVER_OUT:
			global_position = cover_global()
			_base = global_position
			_sprite.position.y = roundf(sin(_t * TAU / BOB_PERIOD)) if _state == COVER else 0.0
			if _state == COVER:
				_apply_cover_clip()
			if is_puppet and _state != COVER_OUT and _state_t > PetCatalog.HAYALET_COVER_TIME + COVER_REMOTE_FALLBACK:
				end_cover_visual()
	_update_char_fade(delta)
	if not is_puppet:
		process_guard(delta)
		_net_idle += delta
		if _net_idle >= NET_HEARTBEAT:
			_broadcast(_state != HOVER and _state != APPEAR and _state != COVER_OUT)


func _process_hover(delta: float) -> void:
	var dest: Vector2 = _hover_global()
	if _base.distance_to(dest) > SNAP_DIST:
		_base = dest
		_vel = Vector2.ZERO
	else:
		var st: Array = PetFollowScript.spring_step(_base, _vel, dest + _follow.drift(_t), delta)
		_base = st[0]
		_vel = st[1]
	global_position = _base
	_sprite.position.y = roundf(sin(_t * TAU / BOB_PERIOD))
	if _state == HOVER:
		_apply_hover_clip()


## Sahibin sprite solukluğu: örtü görseli sürerken (uçuş + açılma + örtü) CHAR_FADE'e iner, kıvrılıp kaybolurken geri gelir. İki ekranda
## aynı (kuklada sahip = uzak oyuncu); ağ alanı yok - örtü olayı zaten broadcast_hayalet ile geliyor.
func _update_char_fade(delta: float) -> void:
	var want: float = CHAR_FADE if (_state == FLY_IN or _state == COVER_IN or _state == COVER) else 1.0
	if is_equal_approx(_char_fade, want):
		return
	_char_fade = move_toward(_char_fade, want, delta * (1.0 - CHAR_FADE) / CHAR_FADE_TIME)
	if owner_body.has_method("set_pet_cover_fade"):
		owner_body.set_pet_cover_fade(_char_fade)


func char_fade() -> float:
	return _char_fade


func _exit_tree() -> void:
	if _char_fade < 1.0 and is_instance_valid(owner_body) and owner_body.has_method("set_pet_cover_fade"):
		owner_body.set_pet_cover_fade(1.0) ## hayalet silinirse karakter soluk kalmasın


## Sahibin hızı konum farkından (yerelde de kuklada da aynı çalışır; ışınlanma sayılmaz).
func _update_owner_velocity(delta: float) -> void:
	var o: Vector2 = PhysicsInterp.visual_position(owner_body)
	if _have_owner_prev and delta > 0.0:
		var raw: Vector2 = (o - _owner_prev) / delta
		_owner_vel = _owner_vel.lerp(raw, minf(1.0, delta * OWNER_VEL_SMOOTH)) if (o - _owner_prev).length() < 64.0 else Vector2.ZERO
	_owner_prev = o
	_have_owner_prev = true


## Örtüde doğal hâlin kuralı: yana giderken gidiş yönüne eğilir (sola ayna), durunca / dikey giderken öne döner. Klip değişirken kare ve
## ilerleme korunur (ikisi de 8 kare) - süzülme baştan başlamaz.
func _apply_cover_clip() -> void:
	var vx: float = _owner_vel.x
	if _cover_moving:
		if absf(vx) < COVER_MOVE_OFF:
			_cover_moving = false
	elif absf(vx) > COVER_MOVE_ON:
		_cover_moving = true
	if _cover_moving:
		if absf(vx) >= COVER_MOVE_OFF:
			_sprite.flip_h = vx < 0.0
	else:
		_sprite.flip_h = false
	var want: StringName = &"cover_move_right" if _cover_moving else &"cover"
	if _sprite.animation != want:
		var f: int = _sprite.frame
		var p: float = _sprite.frame_progress
		_sprite.play(want)
		_sprite.set_frame_and_progress(f, p)


func cover_leaning() -> bool:
	return _cover_moving


func _hover_global() -> Vector2:
	var art := Vector2(24.0 + _side * HOVER_ART_SIDE, HOVER_ART_Y)
	return owner_body.to_global(char_anim.transform * (art - Vector2(24.0, 24.0) + char_anim.offset))


## Kaplama noktası: büyük hayaletin merkezi; gövdesinin altı sahibin ayağının biraz altında. Sahibin EKRANDA çizildiği (fizik ara-değerli)
## konuma göre (madde 513): ham global_position'a yapışınca yürürken bir fizik adımı önde kalıp titriyordu (sağa yürürken karakterin sağına
## kayıyordu) - bkz. PhysicsInterp.visual_position.
func cover_global() -> Vector2:
	var feet: Vector2 = owner_body.to_global(char_anim.transform * (Vector2(0.0, COVER_FEET_ART_Y - 24.0) + char_anim.offset))
	return feet - Vector2(0.0, COVER_BODY_BOTTOM) * global_scale.y + _owner_visual_offset()


## Sahibin çizilen konumu ile ham fizik konumu arasındaki fark (ara-değerleme kapalıysa / ışınlamada 0).
func _owner_visual_offset() -> Vector2:
	return PhysicsInterp.visual_position(owner_body) - owner_body.global_position


func _owner_down() -> bool:
	return owner_body.get("is_downed") == true or owner_body.get("is_dead") == true


func _apply_hover_clip() -> void:
	var want: StringName = &"idle"
	if _owner_down():
		want = &"cry"
		_sprite.flip_h = false
	elif absf(_vel.x) > MOVE_ANIM_SPEED:
		want = &"move_right"
		_sprite.flip_h = _vel.x < 0.0
	else:
		_sprite.flip_h = false
	if _sprite.animation != want:
		_sprite.play(want)


func _set_state(s: int) -> void:
	_state = s
	_state_t = 0.0
	match s:
		FLY_IN:
			_fly_from = global_position
			_sprite.flip_h = (cover_global().x - global_position.x) < 0.0
			_sprite.play(&"move_right")
			z_index = 1
		COVER_IN:
			_sprite.flip_h = false
			_sprite.modulate.a = COVER_ALPHA
			_sprite.play(&"cover_in")
			z_index = 1
		COVER:
			_cover_moving = false
			_sprite.play(&"cover")
			_apply_cover_clip()
		COVER_OUT:
			_sprite.play(&"cover_out")
		APPEAR:
			_sprite.modulate.a = GHOST_ALPHA
			_sprite.flip_h = false
			_sprite.position.y = 0.0
			_vel = Vector2.ZERO
			_base = _hover_global()
			global_position = _base
			_sprite.play(&"appear")
			z_index = 0
		HOVER:
			_sprite.modulate.a = GHOST_ALPHA
			z_index = 0
			_apply_hover_clip()


func _on_animation_finished() -> void:
	match _state:
		COVER_IN:
			_set_state(COVER)
		COVER_OUT:
			_set_state(APPEAR)
		APPEAR:
			_set_state(HOVER)


func is_covering() -> bool:
	return _state == FLY_IN or _state == COVER_IN or _state == COVER


func state() -> int:
	return _state


func current_clip() -> StringName:
	return _sprite.animation


func sprite_alpha() -> float:
	return _sprite.modulate.a


## Kaplama görseli başlar (iki ekranda aynı).
func start_cover_visual() -> void:
	if is_covering():
		return
	_set_state(FLY_IN)


## Kaplama görseli biter: büyük hayalet kıvrılıp küçülerek kaybolur, küçük hayalet yanında açılıp belirir.
func end_cover_visual() -> void:
	if not is_covering():
		return
	if _state == FLY_IN:
		_set_state(APPEAR)
		return
	_set_state(COVER_OUT)


## ---------------------------------------------------------------- sahibinin ekranı

## Her karede (testler doğrudan çağırır): bekleme sayacı (güvenli alanda donar, madde 327) + düşük can tetiği + kaplama bitişi.
func process_guard(delta: float) -> void:
	if is_puppet:
		return
	if _covering_owner and not owner_cover_active():
		_covering_owner = false
		end_cover_visual()
		_broadcast(false)
	if owner_frozen():
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	check_low_health()


## player.gd _item_after_health_damage da çağırır (vuruşun düştüğü anda). Döner: kaplama başladı mı.
func check_low_health() -> bool:
	if is_puppet or _cooldown > 0.0 or _covering_owner or owner_frozen() or not owner_low():
		return false
	if not owner_body.has_method("start_ghost_cover"):
		return false
	_cooldown = PetCatalog.HAYALET_COOLDOWN
	_covering_owner = true
	owner_body.start_ghost_cover(PetCatalog.HAYALET_COVER_TIME)
	start_cover_visual()
	_broadcast(true)
	return true


func owner_low() -> bool:
	if not is_instance_valid(owner_body) or _owner_down():
		return false
	var mx: float = float(owner_body.get("max_health"))
	var hp: float = float(owner_body.get("health"))
	return mx > 0.0 and hp > 0.0 and hp < mx * PetCatalog.HAYALET_HP_THRESHOLD


func owner_cover_active() -> bool:
	return is_instance_valid(owner_body) and owner_body.has_method("ghost_cover_active") and owner_body.ghost_cover_active()


func owner_frozen() -> bool:
	return is_instance_valid(owner_body) and owner_body.has_method("is_safe_zone_frozen") and owner_body.is_safe_zone_frozen()


## HUD evcil yuvası (hud_pet_slot.gd): kalan bekleme oranı 0..1 (0 = hazır) ve saniyesi.
func cooldown_fraction() -> float:
	return clampf(_cooldown / PetCatalog.HAYALET_COOLDOWN, 0.0, 1.0)


func cooldown_left() -> float:
	return _cooldown


func _broadcast(cover: bool) -> void:
	_net_idle = 0.0
	if is_puppet or not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.broadcast_hayalet.rpc(multiplayer.get_unique_id(), cover)


## ---------------------------------------------------------------- kukla (diğer oyuncuların ekranı)

## remote_player.gd -> hayalet_event: sahibinin kaplama durumu (görünmezlik ağdan ayrıca gelir; burada sadece görsel).
func apply_remote_state(cover: bool) -> void:
	if cover:
		start_cover_visual()
	else:
		end_cover_visual()
