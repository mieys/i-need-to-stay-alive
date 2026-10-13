extends Node2D

## EVCİL HAYVAN "KELEBEK RUHU" (kullanıcı isteği 2026-10-12): pembe ışık küresi + 4 lila kanat. Sahibine +%10 saldırı hızı verir
## (player.gd pet_attack_speed) ve sahibin İLK silahının isabet ettiği düşmana minik pembe bir lazer atışı yapar: saldırı gücünün
## (damage_bonus) %20'si kadar hasar. Sabitler pet_catalog.gd'de; isabet kancası player.gd _kelebek_on_weapon_hit.
##
## Görsel: sahibin omuz hizasında, ARKA tarafında süzülür (yumuşak takip + 1 piksellik salınım), sahibi nereye bakıyorsa oraya bakar -
## 4 yön: fly_down / fly_up / fly_side (sol = flip_h); kareler tools/gen_kelebek_ruhu.py. Karakterin pikseliyle aynı doku yoğunluğu
## (global_scale = karakter sprite'ı, papağanın uçuş hali gibi). Sahibin çocuğu ama top_level: görünürlük/solma sahibinden gelir.
##
## Çok oyunculu (papağandaki desen): hayvan seçimi ağdan gitmez; sahibin ekranı her atışta (en çok NET_SHOT_INTERVAL'de bir) ve atış
## yokken NET_HEARTBEAT'te bir NetworkManager.broadcast_kelebek_ruhu yollar, diğer ekranlardaki kukla ilk olayda kurulur
## (remote_player.gd kelebek_ruhu_event) ve atışı SADECE görsel olarak oynatır. Hasarı yalnız sahibinin ekranı verir.

const CharAnim := preload("res://scripts/char_anim.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const BoltScript: GDScript = preload("res://scripts/fx_kelebek_bolt.gd")
const FRAMES: SpriteFrames = preload("res://assets/pets/kelebek_ruhu/kelebek_frames.tres")

## Süzülme noktası karakterin 48x48 hücresinde (sanat pikseli): baş hizası, gövdenin 20 piksel yanında (prototipteki yer).
const HOVER_ART_Y := 8.0
const HOVER_ART_SIDE := 20.0
const PetFollowScript := preload("res://scripts/pet_follow.gd")
const SNAP_DIST := 240.0 ## ışınlanma / diriliş: bu kadar geride kaldıysa süzülerek gelmez, yanında belirir
const BOB_PERIOD := 1.0
## Aynı anda uçan atış görseli sınırı: aşılırsa hasar yine verilir, görsel atlanır (hızlı silah + kalabalıkta FPS).
const MAX_BOLTS := 24
const NET_SHOT_INTERVAL := 0.12
const NET_HEARTBEAT := 8.0

var owner_body: Node2D = null
var char_anim: AnimatedSprite2D = null
var is_puppet: bool = false
var _vel: Vector2 = Vector2.ZERO
var _follow = PetFollowScript.new()

var _sprite: AnimatedSprite2D = null
var _side: float = 1.0 ## +1 = sahibin sağında, -1 = solunda
var _t: float = 0.0
var _bolts: int = 0
var _net_shot_cd: float = 0.0
var _net_idle: float = NET_HEARTBEAT - 1.0 ## ilk "buradayım" kurulumdan 1 sn sonra


func setup(body: Node2D, anim_src: AnimatedSprite2D, puppet: bool) -> void:
	owner_body = body
	char_anim = anim_src
	is_puppet = puppet
	name = "KelebekRuhu"
	top_level = true
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
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
		_net_shot_cd = maxf(0.0, _net_shot_cd - delta)
		_net_idle += delta
		if _net_idle >= NET_HEARTBEAT:
			_broadcast(Vector2.ZERO, false)


func _hover_global() -> Vector2:
	var art := Vector2(24.0 + _side * HOVER_ART_SIDE, HOVER_ART_Y)
	return owner_body.to_global(char_anim.transform * (art - Vector2(24.0, 24.0) + char_anim.offset))


## Yön değişirken çırpma karesi korunur (kanat baştan başlamaz).
func _face(facing: String) -> void:
	var want: StringName = &"fly_down"
	if facing == "up":
		want = &"fly_up"
	elif facing == "left" or facing == "right":
		want = &"fly_side"
	_sprite.flip_h = facing == "left"
	if _sprite.animation != want:
		var f: int = _sprite.frame
		var p: float = _sprite.frame_progress
		_sprite.play(want)
		_sprite.set_frame_and_progress(f, p)


## Atışın çıktığı nokta: küre (düğüm orijini + salınım).
func muzzle() -> Vector2:
	return global_position + Vector2(0.0, _sprite.position.y * global_scale.y)


## ---------------------------------------------------------------- sahibinin ekranı

## player.gd _kelebek_on_weapon_hit: ilk silah bu yaratığa isabet etti.
func fire_at(target: Node2D) -> void:
	if is_puppet or not is_instance_valid(target):
		return
	if _bolts >= MAX_BOLTS:
		_deal(target)
		return
	_spawn_bolt(target, target.global_position, _deal)
	if _net_shot_cd <= 0.0:
		_net_shot_cd = NET_SHOT_INTERVAL
		_broadcast(target.global_position, true)


## Atış hedefe vardı (ya da görsel sınırı doluydu): yaratık hâlâ canlıysa saldırı gücünün %20'si.
func _deal(target: Node2D) -> void:
	if is_puppet or not is_instance_valid(target) or target.get("is_dead") == true or not target.has_method("take_damage"):
		return
	if not is_instance_valid(owner_body) or owner_body.get("is_dead") == true:
		return
	var ap: float = maxf(1.0, float(owner_body.get("damage_bonus"))) if "damage_bonus" in owner_body else 1.0
	BalanceLogScript.tag(&"s:kelebek_ruhu")
	target.take_damage(ap * PetCatalog.KELEBEK_DAMAGE_RATIO, false)


func _broadcast(dest: Vector2, shot: bool) -> void:
	_net_idle = 0.0
	if is_puppet or not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.broadcast_kelebek_ruhu.rpc(multiplayer.get_unique_id(), dest, shot)


## ---------------------------------------------------------------- kukla (diğer oyuncuların ekranı)

## remote_player.gd -> kelebek_ruhu_event: sahibi atış yaptı; hasarsız, sadece görsel.
func fire_visual(dest: Vector2) -> void:
	if _bolts < MAX_BOLTS:
		_spawn_bolt(null, dest, Callable())


func _spawn_bolt(target: Node2D, dest: Vector2, on_hit: Callable) -> void:
	var b: Node2D = BoltScript.new()
	add_child(b)
	_bolts += 1
	b.tree_exiting.connect(_on_bolt_gone)
	b.launch(muzzle(), target, dest, absf(global_scale.x), on_hit)


func _on_bolt_gone() -> void:
	_bolts = maxi(0, _bolts - 1)
