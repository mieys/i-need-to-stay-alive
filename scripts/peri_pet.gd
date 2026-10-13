extends Node2D

## EVCİL HAYVAN "PERİ" (kullanıcı isteği 2026-10-12): sahibinin canı %100'ün altındayken her PERI_HEAL_INTERVAL (6 sn) saniyede bir can
## basma büyüsü yapar: saldırı gücünün (damage_bonus) PERI_HEAL_RATIO'su (%10) kadar can. Sabitler pet_catalog.gd'de.
##  - Büyü HAZIR bekler: can doluyken sayaç 0'da durur, can eksilir eksilmez basar, sonra 6 sn bekler.
##  - Can player.gd heal() ile verilir (yeşil sayı + İyileştirme ve Kalkan Gücü çarpanı - oyuncunun KENDİ sağladığı can).
##  - Sahip yerdeyken/ölüyken basmaz (madde 104 kuralı; heal() de is_dead iken zaten işlemez).
##
## Görsel: kullanıcının seçtiği "J" prototipi (sarışın, mavi elbise, asa havada) - 4 yön: fly_<down|up|side> döngüsü, büyü anında
## cast_<yön> (asanın yeşil yıldızı patlar; kareler tools/gen_peri.py) + sahibin başında Melek pasifinin artı ışıltısı
## (fx_melek_heal_sparkle.gd - yeni efekt yok). Kelebek Ruhu ile aynı takip: sahibin baş hizasında, arka tarafında süzülür.
##
## Çok oyunculu (Kelebek Ruhu deseni): seçim ağdan gitmez; sahibin ekranı her büyüde + büyü yokken NET_HEARTBEAT'te bir
## NetworkManager.broadcast_peri yollar, diğer ekranlardaki kukla ilk olayda kurulur (remote_player.gd peri_event) ve büyüyü SADECE
## görsel oynatır. Canı yalnız sahibinin ekranı verir (can zaten normal durum senkronuyla gider).

const CharAnim := preload("res://scripts/char_anim.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const FxSparkleScript: GDScript = preload("res://scripts/fx_melek_heal_sparkle.gd")
const FRAMES: SpriteFrames = preload("res://assets/pets/peri/peri_frames.tres")

## Süzülme noktası karakterin 48x48 hücresinde (sanat pikseli): baş hizası, gövdenin 21 piksel yanında.
const HOVER_ART_Y := 7.0
const HOVER_ART_SIDE := 21.0
const PetFollowScript := preload("res://scripts/pet_follow.gd")
const SNAP_DIST := 240.0
const BOB_PERIOD := 1.4
const NET_HEARTBEAT := 8.0

var owner_body: Node2D = null
var char_anim: AnimatedSprite2D = null
var is_puppet: bool = false
var _vel: Vector2 = Vector2.ZERO
var _follow = PetFollowScript.new()

var _sprite: AnimatedSprite2D = null
var _side: float = 1.0 ## +1 = sahibin sağında, -1 = solunda
var _t: float = 0.0
var _dir: String = "down" ## sayfa yönü: down | up | side
var _casting: bool = false
var _cooldown: float = 0.0
var _net_idle: float = NET_HEARTBEAT - 1.0 ## ilk "buradayım" kurulumdan 1 sn sonra


func setup(body: Node2D, anim_src: AnimatedSprite2D, puppet: bool) -> void:
	owner_body = body
	char_anim = anim_src
	is_puppet = puppet
	name = "Peri"
	top_level = true
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"fly_down")
	global_scale = char_anim.global_scale
	global_position = _hover_global()


func _process(delta: float) -> void:
	if not is_instance_valid(owner_body) or not is_instance_valid(char_anim):
		return
	_t += delta
	var facing: String = CharAnim.dir_of(String(char_anim.animation))
	if facing == "left":
		_side = 1.0
	elif facing == "right":
		_side = -1.0
	_face(facing)
	global_scale = char_anim.global_scale
	var dest: Vector2 = _hover_global()
	if global_position.distance_to(dest) > SNAP_DIST:
		global_position = dest
		_vel = Vector2.ZERO
	else:
		## Yaylı takip (bkz. pet_follow.gd): sahip koşunca geride kalır, durunca hafif aşıp oturur; hedefe yavaş bir salınım biner.
		var st: Array = PetFollowScript.spring_step(global_position, _vel, dest + _follow.drift(_t), delta)
		global_position = st[0]
		_vel = st[1]
	_sprite.position.y = roundf(sin(_t * TAU / BOB_PERIOD))
	if not is_puppet:
		process_heal(delta)
		_net_idle += delta
		if _net_idle >= NET_HEARTBEAT:
			_broadcast(false)


func _hover_global() -> Vector2:
	var art := Vector2(24.0 + _side * HOVER_ART_SIDE, HOVER_ART_Y)
	return owner_body.to_global(char_anim.transform * (art - Vector2(24.0, 24.0) + char_anim.offset))


## Yön değişirken kare korunur (kanat / büyü baştan başlamaz).
func _face(facing: String) -> void:
	_dir = "up" if facing == "up" else ("side" if (facing == "left" or facing == "right") else "down")
	_sprite.flip_h = facing == "left"
	var want := StringName(("cast_" if _casting else "fly_") + _dir)
	if _sprite.animation != want:
		var f: int = _sprite.frame
		var p: float = _sprite.frame_progress
		_sprite.play(want)
		_sprite.set_frame_and_progress(f, p)


func _on_animation_finished() -> void:
	if _casting:
		_casting = false
		_sprite.play(StringName("fly_" + _dir))


## Büyü görseli (iki ekranda aynı): asanın yıldızı patlar + sahibin başında artı ışıltısı.
func _play_cast() -> void:
	_casting = true
	_sprite.play(StringName("cast_" + _dir))
	if is_instance_valid(owner_body):
		owner_body.add_child(FxSparkleScript.new())


## ---------------------------------------------------------------- sahibinin ekranı

## Her karede (testler doğrudan çağırır): bekleme dolduysa ve sahibin canı eksikse can basar.
func process_heal(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0 or is_puppet or not owner_needs_heal():
		return
	_cooldown = PetCatalog.PERI_HEAL_INTERVAL
	owner_body.heal(heal_amount())
	_play_cast()
	_broadcast(true)


func owner_needs_heal() -> bool:
	if not is_instance_valid(owner_body) or not owner_body.has_method("heal"):
		return false
	if owner_body.get("is_dead") == true or owner_body.get("is_downed") == true:
		return false
	return float(owner_body.get("health")) < float(owner_body.get("max_health"))


func heal_amount() -> float:
	return maxf(1.0, float(owner_body.get("damage_bonus"))) * PetCatalog.PERI_HEAL_RATIO


func _broadcast(cast: bool) -> void:
	_net_idle = 0.0
	if is_puppet or not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.broadcast_peri.rpc(multiplayer.get_unique_id(), cast)


## ---------------------------------------------------------------- kukla (diğer oyuncuların ekranı)

## remote_player.gd -> peri_event: sahibi büyü yaptı; can vermez, sadece görsel.
func play_cast_visual() -> void:
	_play_cast()
