extends CharacterBody2D

## ==============================================================================
## CORVINA (Necromancer) BİRLİĞİ - Q savaşçı / E okçu / R ordu askeri + komutan (2026-11-16, kullanıcı onayı)
## ==============================================================================
## Eski skeleton_pet.gd'nin denenmiş hareket/rota/ayrışma/görüş tasması mantığı + yeni paket (Vol2 The Necromancer's Order)
## 5 yönlü kareleri. Tür (kind) sahneden gelir: scenes/necro_warrior|archer|soldier|commander.tscn - kozmetik kopya da türünü
## sahneden bilir. Görünüm (unit_key, NecroUnits.UNITS anahtarı) rütbeyle değişir: sahibi (player.gd necro_unit_key) her 0,5 sn
## sorulur; kozmetik kopyaya durum paketinin sprite_row'unda gider (bkz. _net_code).
## Statlar NecroArmyMath'ten (Corvina'nın saldırı gücü + saldırı hızı), çağırma anında hesaplanır.
##
## Multiplayer (skeleton_pet.gd ile AYNI desen): yapay zeka/hasar YALNIZ kasterde. Diğer istemcide remote_player.gd
## _spawn_pet_visual aynı sahneyi kurup mark_as_network_visual() der; kopya broadcast_pet_state ile gelen konuma kayar, yön/anim/
## görünüm sprite_row kodundan okunur. Ok / ateş sütunu / yeniden doğuş "necro_fx" player-vfx ile gider (bkz. necro_fx.gd).
## Ölüm: broadcast_pet_despawn -> kopyada begin_out() (ölüm animi, sonra silinir).

const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const ProjectileRangeScript := preload("res://scripts/projectile_range.gd")
const PetRouterScript := preload("res://scripts/pet_router.gd")
const NecroUnits := preload("res://scripts/necro_units.gd")
const NecroMath := preload("res://scripts/necro_army_math.gd")
const NecroFx := preload("res://scripts/necro_fx.gd")

signal died

## warrior | archer | soldier | commander - sahne başına sabit.
@export var kind: String = "warrior"

const SEEK_RADIUS := 420.0
const MELEE_STOP_RANGE := 42.0
const MELEE_RESUME_CHASE_RANGE := 70.0
const MELEE_HIT_SLACK := 16.0
const FOLLOW_DISTANCE := 90.0
const CATCH_UP_DISTANCE := 320.0
const CATCH_UP_ROUTE_SPEED_MULT := 2.5
const TARGET_SCAN_INTERVAL := 0.2
const RANK_POLL_INTERVAL := 0.5
const INCOMING_CONTACT_RANGE := 40.0
const INCOMING_TICK_INTERVAL := 1.0
const INCOMING_FALLBACK_DAMAGE := 6.0
const PET_SEPARATION_GAP := 2.0
const PET_SEPARATION_CHECK_RADIUS := 100.0
const PET_SEPARATION_FORCE := 130.0
const HURT_FLASH_TIME := 0.12
const ARROW_LAUNCH_HEIGHT := 15.5 ## (2026-11-16 ölçek 0,9 -> 1,0 ile 14 -> 15,5) okun çıktığı göğüs yüksekliği (ayaktan, dünya birimi)
const ARROW_AIM_HEIGHT := 11.0
const NET_BASE_INTERVAL := 0.2 ## konum yayını; birlik sayısı 10'u aşınca orantılı seyrelir (toplam ~50 RPC/sn tavanı)
const ARMY_RISE_SPEED := 1.4

## Ağ kodu: sprite_row = yön(0-4) + 5*aynalı + 10*anim + 100*birim.
const NET_ANIMS: Array[String] = ["idle", "walk", "attack", "attack2", "attack3", "block", "rise", "death", "cast"]
const NET_UNITS: Array[String] = ["common", "armored", "captain", "knight", "archer", "mage",
	"ghost_common", "ghost_armored", "ghost_captain", "ghost_knight", "ghost_archer"]
const ATTACK_ANIMS: Array[String] = ["attack", "attack2", "attack3"]
## Ayrışma gövde yarıçapı (dünya). 2026-11-16: WORLD_SCALE 0,9 -> 1,0 ile aynı oranda (x1,11) büyüdü.
const BODY_RADIUS := {"common": 15.5, "armored": 15.5, "captain": 18.0, "knight": 21.0, "archer": 15.5, "mage": 16.5}
## AYAK GÖLGESİ (2026-11-16, kullanıcı: "necromancerın spawnladığı yaratıkların gölgesi yok"): paket karelerinde gömülü gölge yok ->
## oyuncularla aynı piksel elips (ground_shadow.gd), Sprite'tan ÖNCE çizilir. Yarıçap birimin idle S gövde genişliğinden; hayalet birim (yarı saydam) daha soluk.
## Gölgenin kendi ölüm/yatma büyümesi kapalı (o kural oyuncu sayfalarının yatık pozuna göre; iskelet yere yığılıyor).
const GroundShadowScript := preload("res://scripts/ground_shadow.gd")
const SHADOW_RX_PER_BODY_W := 0.42 ## gölge yarı genişliği = gövde genişliği (dünya) x bu
const SHADOW_RY_RATIO := 0.36
const SHADOW_GHOST_ALPHA := 0.55
static var _body_w_cache: Dictionary = {} ## birim anahtarı -> idle S ilk karenin opak genişliği (sanat px)
const BALANCE_TAGS := {"warrior": &"s:necro_savasci", "archer": &"s:necro_okcu", "soldier": &"s:necro_ordu", "commander": &"s:necro_ordu"}

var unit_key: String = ""
var owner_player: Node2D = null
var is_dead: bool = false
var lifespan: float = 30.0
var temporary: bool = false ## R ordusu: süre bitince dağılır, büyücü diriltmez
var max_health: float = 50.0
var health: float = 50.0
var max_shield: float = 0.0
var shield: float = 0.0
var speed: float = 120.0
var attack_power: float = 5.0
var attack_interval: float = 0.75
var owner_ap: float = 10.0 ## Corvina'nın çağırma anındaki saldırı gücü (Super vuruş / ateş sütunu bunu çarpar)
var owner_as_percent: float = 0.0
var attack_range: float = NecroMath.ARCHER_RANGE
var pierce: int = 0
var dmg_mult: float = 1.0 ## evrim çarpanı (E4 ok hasarı ...); komutan aurası ayrıca vuruş anında sorulur
var _body_radius: float = 14.0

var _router = PetRouterScript.new()
var _dir: String = "s"
var _flip: bool = false
var _loco: String = ""
var _action: String = ""
var _dying: bool = false
var _attack_timer: float = 0.0
var _strike_left: float = -1.0
var _strike_anim: String = ""
var _strike_target: Node2D = null
var _strike_target_pos: Vector2 = Vector2.ZERO
var _focus_target: Node2D = null
var _scan_timer: float = 0.0
var _in_stance: bool = false
var _incoming_dmg_timer: float = 0.0
var _shield_idle: float = 0.0
var _combo: int = 0
var _reborn_cd: float = 3.0
var _flash: float = 0.0
var _rank_poll: float = 0.0
var _net_timer: float = 0.0
var _fx_timer: float = 0.0

## Kozmetik kopya
var network_instance_id: String = ""
var _is_network_visual: bool = false
var _network_target_position: Vector2 = Vector2.ZERO
var _network_state_received: bool = false
var _last_net_attacking: bool = false
var _last_net_anim: String = ""

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	add_to_group("player_allies")
	add_to_group("necro_units")
	sprite.scale = Vector2.ONE * NecroUnits.WORLD_SCALE
	_ensure_shadow()
	sprite.animation_finished.connect(_on_anim_finished)
	if unit_key.is_empty():
		set_unit(_default_unit())


func _default_unit() -> String:
	match kind:
		"archer":
			return "archer"
		"soldier":
			return "common"
		"commander":
			return "knight"
	return "common"


func is_ranged() -> bool:
	return kind == "archer"


func _is_knight() -> bool:
	return unit_key == "knight" or unit_key == "ghost_knight"


## Görünümü değiştirir (rütbe); oynayan anim yeni karelerde sürer.
func set_unit(key: String) -> void:
	if not NecroUnits.UNITS.has(key) or key == unit_key:
		return
	unit_key = key
	var u: Dictionary = NecroUnits.UNITS[key]
	if sprite == null:
		sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.sprite_frames = load(u["frames"])
	sprite.offset = u["offset"]
	_body_radius = float(BODY_RADIUS.get(key.trim_prefix("ghost_"), 15.5))
	_apply_depth_and_shadow(key, u)
	if _dying:
		_play_base("death", 1.3)
	elif not _action.is_empty():
		_play_base(_action, sprite.speed_scale)
	else:
		_play_loco("idle" if _loco.is_empty() else _loco, true)


func _ensure_shadow() -> Node2D:
	var sh: Node2D = get_node_or_null("Shadow") as Node2D
	if sh != null:
		return sh
	sh = GroundShadowScript.new()
	sh.name = "Shadow"
	add_child(sh)
	move_child(sh, 0) ## Sprite'tan önce = altında
	sh.set_process(false)
	return sh


## Y-SIRALAMA (2026-11-16, kullanıcı: "Y ekseni sorunları da var"): paket kareleri ayak = düğüm kökü olacak şekilde ofsetli (NecroUnits.UNITS offset),
## ayak ölçümünü main.gd'ye bırakmak yerine sabit verilir - doğuş anında oynayan "rise" karesi (yerden çıkan yığın) ölçülüp kalıcı önbelleğe yazılıyordu.
## Derinlik kutusu (creature_depth.gd _extent) tuvalin tamamından (boşluk dahil, ~2 kat boy) değil gövdeden.
func _apply_depth_and_shadow(key: String, u: Dictionary) -> void:
	var sc: float = NecroUnits.WORLD_SCALE
	var body_w: float = _body_width_px(key, u)
	set_meta("_foot_visual", sprite)
	set_meta("_foot_local", 0.0)
	set_meta("_depth_extent", Vector2(body_w * 0.5 * sc, float(u["body_h"]) * sc + 2.0))
	var sh: Node2D = _ensure_shadow()
	var rx: float = maxf(8.0, body_w * sc * SHADOW_RX_PER_BODY_W)
	sh.set("radius", Vector2(rx, maxf(3.0, rx * SHADOW_RY_RATIO)))
	if key.begins_with("ghost_"):
		sh.modulate.a = SHADOW_GHOST_ALPHA
	else:
		sh.modulate.a = 1.0
	sh.queue_redraw()


static func _body_width_px(key: String, u: Dictionary) -> float:
	if _body_w_cache.has(key):
		return _body_w_cache[key]
	var w: float = 24.0
	var sf: SpriteFrames = load(u["frames"]) as SpriteFrames
	var anim: String = NecroUnits.anim_name(sf, "idle", "s") if sf != null else "idle_s"
	if sf != null and sf.has_animation(anim) and sf.get_frame_count(anim) > 0:
		var tex: Texture2D = sf.get_frame_texture(anim, 0)
		var img: Image = tex.get_image() if tex != null else null
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var used: Rect2i = img.get_used_rect()
			if used.size.x > 0:
				w = float(used.size.x)
	_body_w_cache[key] = w
	return w


## Kaster: statları Corvina'dan hesapla (çağırma anı). Evrim çarpanları player.gd necro_apply_mods ile sonra gelir.
func setup_from_owner(player: Node, key: String, life: float, is_temporary: bool = false) -> void:
	owner_player = player as Node2D
	lifespan = life
	temporary = is_temporary
	owner_ap = float(player.get("damage_bonus")) if player.get("damage_bonus") != null else 10.0
	owner_as_percent = float(player.get_attack_speed_bonus_percent()) if player.has_method("get_attack_speed_bonus_percent") else 0.0
	var spd: Variant = player.get("speed")
	speed = maxf(30.0, float(spd if spd != null else 120.0) * float(NecroMath.STATS[kind]["speed"]))
	set_unit(key)
	apply_mods(1.0, 0.0, 1.0, 1.0, 0)
	health = max_health
	shield = max_shield


## Evrim çarpanları (can, ek saldırı hızı %, menzil, hasar, delme). Can/kalkan ORANI korunur (rütbe atlayınca can dolmaz/boşalmaz).
func apply_mods(hp_mult: float, extra_as_percent: float, range_mult: float, damage_mult: float, pierce_count: int) -> void:
	var hp_ratio: float = health / max_health if max_health > 0.0 else 1.0
	var sh_ratio: float = shield / max_shield if max_shield > 0.0 else 1.0
	max_health = NecroMath.max_hp(kind, owner_ap) * hp_mult
	max_shield = NecroMath.max_shield(kind, owner_ap)
	attack_power = NecroMath.hit_damage(kind, owner_ap)
	attack_interval = NecroMath.attack_interval(kind, owner_as_percent, extra_as_percent)
	attack_range = NecroMath.ARCHER_RANGE * range_mult
	dmg_mult = damage_mult
	pierce = pierce_count
	health = clampf(hp_ratio, 0.0, 1.0) * max_health
	shield = clampf(sh_ratio, 0.0, 1.0) * max_shield


## Doğuş animi (yerden kalkma); bitene kadar yapay zeka ve hasar yok.
func play_rise() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var n: String = NecroUnits.anim_name(sprite.sprite_frames, "rise", _dir)
	if n.begins_with("idle"):
		## Kemik Büyücüsü'nün yerden kalkma animi yok: büyü animiyle belirir (aksiyon döngüsüz biter, takılmaz).
		_play_action("cast")
		return
	_action = "rise"
	_play_base("rise", ARMY_RISE_SPEED if temporary else 1.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _is_network_visual:
		_process_network_visual(delta)
		return
	lifespan -= delta
	if lifespan <= 0.0:
		_expire()
		return
	_tick_flash(delta)
	_tick_shield(delta)
	_poll_rank(delta)
	if _action == "rise":
		_broadcast_network_state(delta)
		return
	_update_focus_target(delta)
	_process_movement(delta)
	_leash_to_owner_vision()
	_process_attack(delta)
	_process_reborn(delta)
	_process_incoming_damage(delta)
	_update_locomotion_anim()
	_broadcast_network_state(delta)


## ---------------------------------------------------------------- hedef / hareket (skeleton_pet.gd'den)

func _leash_to_owner_vision() -> void:
	if owner_player and is_instance_valid(owner_player) and is_inside_tree():
		global_position = ProjectileRangeScript.clamp_to_owner_vision(global_position, owner_player.global_position, get_tree())


func _in_owner_vision(p: Vector2) -> bool:
	if not owner_player or not is_instance_valid(owner_player):
		return true
	return ProjectileRangeScript.inside_owner_vision(p, owner_player.global_position, get_tree())


func _target_ok(t: Node2D) -> bool:
	return t != null and is_instance_valid(t) and t.get("is_dead") != true


func _seek_radius() -> float:
	return maxf(SEEK_RADIUS, attack_range + 40.0) if is_ranged() else SEEK_RADIUS


func _update_focus_target(delta: float) -> void:
	_scan_timer -= delta
	if _target_ok(_focus_target):
		if global_position.distance_to(_focus_target.global_position) <= _seek_radius() and _in_owner_vision(_focus_target.global_position):
			return
	_focus_target = null
	if _scan_timer > 0.0:
		return
	_scan_timer = TARGET_SCAN_INTERVAL
	var best: Node2D = null
	var best_d: float = _seek_radius()
	for e in EnemyQueryScript.candidates(get_tree(), global_position, best_d + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not _in_owner_vision(e.global_position):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	_focus_target = best


## Okçunun hedefle arasında orman var mı (ok ormanda durur - boşa atmasın, dolansın).
func _has_los(p: Vector2) -> bool:
	for t in [0.33, 0.66]:
		if GameManager.is_position_blocked_by_forest(global_position.lerp(p, t)):
			return false
	return true


func _block_movement_into_terrain() -> void:
	if velocity.length() < 0.1:
		return
	if GameManager.is_position_blocked_by_walls(global_position):
		return
	var probe_dist: float = 10.0
	if velocity.x != 0.0 and GameManager.is_position_blocked_by_walls(global_position + Vector2(signf(velocity.x) * probe_dist, 0.0)):
		velocity.x = 0.0
	if velocity.y != 0.0 and GameManager.is_position_blocked_by_walls(global_position + Vector2(0.0, signf(velocity.y) * probe_dist)):
		velocity.y = 0.0


func _move(v: Vector2) -> void:
	velocity = v
	_block_movement_into_terrain()
	move_and_slide()


func _process_movement(delta: float) -> void:
	var separation: Vector2 = _compute_pet_separation()
	if _action in ATTACK_ANIMS or _action == "cast":
		_move(separation)
		return
	if _target_ok(_focus_target):
		var to_target: Vector2 = _focus_target.global_position - global_position
		var dist: float = to_target.length()
		var stop_r: float = attack_range * NecroMath.ARCHER_APPROACH_RATIO if is_ranged() else MELEE_STOP_RANGE
		var resume_r: float = attack_range if is_ranged() else MELEE_RESUME_CHASE_RANGE
		if _in_stance:
			if dist > resume_r or (is_ranged() and not _has_los(_focus_target.global_position)):
				_in_stance = false
		elif dist <= stop_r and (not is_ranged() or _has_los(_focus_target.global_position)):
			_in_stance = true
		if not _in_stance:
			var chase_dir: Vector2 = _router.direction(global_position, _focus_target.global_position, delta)
			_move(chase_dir * speed + separation)
			_face(chase_dir if _router.following_route else to_target)
		else:
			_move(separation)
			_face(to_target)
		return
	_in_stance = false
	if not owner_player or not is_instance_valid(owner_player):
		_move(separation)
		return
	var to_owner: Vector2 = owner_player.global_position - global_position
	var dist_owner: float = to_owner.length()
	if dist_owner > CATCH_UP_DISTANCE:
		var catch_dir: Vector2 = _router.direction(global_position, owner_player.global_position, delta)
		if _router.following_route:
			_move(catch_dir * speed * CATCH_UP_ROUTE_SPEED_MULT + separation)
			_face(catch_dir)
		else:
			var catch_up_target: Vector2 = owner_player.global_position - to_owner.normalized() * FOLLOW_DISTANCE
			global_position = global_position.lerp(catch_up_target, minf(1.0, delta * 6.0))
			velocity = Vector2.ZERO
			_face(to_owner)
	elif dist_owner > FOLLOW_DISTANCE:
		var follow_dir: Vector2 = _router.direction(global_position, owner_player.global_position, delta)
		_move(follow_dir * speed + separation)
		_face(follow_dir)
	else:
		_move(separation)


func _compute_pet_separation() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for e in get_tree().get_nodes_in_group("player_allies"):
		if e == self or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var to_me: Vector2 = global_position - e.global_position
		var d: float = to_me.length()
		if d >= PET_SEPARATION_CHECK_RADIUS:
			continue
		if d < 0.001:
			to_me = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
			d = to_me.length()
			if d < 0.001:
				continue
		var r_variant: Variant = e.get("_body_radius")
		var other_radius: float = float(r_variant) if r_variant != null else 20.0
		var min_gap: float = _body_radius + other_radius + PET_SEPARATION_GAP
		if d < min_gap:
			push += (to_me / d) * ((min_gap - d) / min_gap)
	return push * PET_SEPARATION_FORCE


## ---------------------------------------------------------------- anim

func _face(v: Vector2) -> void:
	if v.length() < 0.1:
		return
	var r: Array = NecroUnits.dir_of(v, _flip)
	_dir = r[0]
	_flip = r[1]


func _play_base(base: String, speed_scale: float = 1.0) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var n: String = NecroUnits.anim_name(sprite.sprite_frames, base, _dir)
	sprite.flip_h = _flip
	sprite.speed_scale = speed_scale
	sprite.play(n)


func _play_loco(base: String, force: bool = false) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var n: String = NecroUnits.anim_name(sprite.sprite_frames, base, _dir)
	sprite.flip_h = _flip
	if force or sprite.animation != n or not sprite.is_playing():
		sprite.speed_scale = 1.0
		sprite.play(n)
	_loco = base


func _update_locomotion_anim() -> void:
	if not _action.is_empty() or _dying:
		return
	var moving: bool = velocity.length() > 8.0 and not _in_stance
	_play_loco("walk" if moving else "idle")


## Aksiyon animi (saldırı/engelleme/büyü). Saldırıda anim saldırı aralığına sığacak kadar hızlanır.
func _play_action(base: String, speed_scale: float = -1.0) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var n: String = NecroUnits.anim_name(sprite.sprite_frames, base, _dir)
	if not sprite.sprite_frames.has_animation(n) or n.begins_with("idle"):
		return
	var sc: float = speed_scale
	if sc <= 0.0:
		sc = 1.0
		if base in ATTACK_ANIMS:
			var dur: float = float(sprite.sprite_frames.get_frame_count(n)) / maxf(1.0, sprite.sprite_frames.get_animation_speed(n))
			sc = maxf(1.0, dur / maxf(0.05, attack_interval * 0.9))
	_action = base
	_play_base(base, sc)


func _on_anim_finished() -> void:
	if _dying:
		queue_free()
		return
	if not _action.is_empty():
		_action = ""
		_play_loco("idle", true)


func _tick_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	if _flash <= 0.0 and sprite:
		sprite.modulate = Color.WHITE


## Rütbe: sahibinin evrimlerine göre görünüm (evrim sırası rastgele, sayı belirler). Değişince statlar da yenilenir.
func _poll_rank(delta: float) -> void:
	_rank_poll -= delta
	if _rank_poll > 0.0:
		return
	_rank_poll = RANK_POLL_INTERVAL
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("necro_unit_key"):
		var want: String = owner_player.necro_unit_key(kind)
		if not want.is_empty() and want != unit_key:
			set_unit(want)
			if owner_player.has_method("necro_apply_mods"):
				owner_player.necro_apply_mods(self)


## ---------------------------------------------------------------- saldırı

func _process_attack(delta: float) -> void:
	_attack_timer -= delta
	if _strike_left >= 0.0:
		_strike_left -= delta
		if _strike_left < 0.0:
			_do_strike()
	if is_instance_valid(owner_player) and owner_player.get("is_dead") == true:
		return
	if not _action.is_empty() or _attack_timer > 0.0:
		return
	if not _target_ok(_focus_target):
		return
	var dist: float = global_position.distance_to(_focus_target.global_position)
	if is_ranged():
		if dist > attack_range or not _has_los(_focus_target.global_position):
			return
	elif dist > MELEE_STOP_RANGE + MELEE_HIT_SLACK:
		return
	_start_attack()


func _start_attack() -> void:
	_attack_timer = attack_interval
	var anim: String = "attack"
	if _is_knight():
		_combo = _combo % NecroMath.EVO_KNIGHT_COMBO + 1
		anim = ATTACK_ANIMS[_combo - 1]
	_face(_focus_target.global_position - global_position)
	_strike_anim = anim
	_strike_target = _focus_target
	_strike_target_pos = _focus_target.global_position
	_play_action(anim)
	var n: String = NecroUnits.anim_name(sprite.sprite_frames, anim, _dir)
	var count: int = sprite.sprite_frames.get_frame_count(n)
	var strike_frame: int = int(NecroUnits.UNITS[unit_key]["strike"].get(anim, count / 2))
	var fps: float = maxf(1.0, sprite.sprite_frames.get_animation_speed(n)) * maxf(0.01, sprite.speed_scale)
	_strike_left = float(strike_frame) / fps


func _do_strike() -> void:
	_strike_left = -1.0
	if is_ranged():
		if unit_key == "mage":
			_mage_fire()
		else:
			_shoot_arrow()
		return
	var aura: float = 1.0
	if kind == "soldier" and owner_player and is_instance_valid(owner_player) and owner_player.has_method("necro_commander_alive") \
			and owner_player.necro_commander_alive():
		aura = NecroMath.EVO_COMMANDER_DMG_MULT
	if _strike_anim == "attack3" and _is_knight():
		## Şövalye Super: 60 birim çevresine AP'nin %80'i + 1 sn sersemletme (bosslar sersemlemez - enemy.gd apply_stun).
		_hit_area(global_position, NecroMath.EVO_KNIGHT_SUPER_RADIUS, owner_ap * NecroMath.EVO_KNIGHT_SUPER_AP * dmg_mult * aura,
			NecroMath.EVO_KNIGHT_SUPER_STUN)
		return
	var dmg: float = attack_power * dmg_mult * aura
	if NecroMath.warrior_cleaves(unit_key):
		_hit_arc(dmg)
	elif _target_ok(_strike_target) and global_position.distance_to(_strike_target.global_position) <= MELEE_STOP_RANGE + MELEE_HIT_SLACK + 8.0:
		_hit(_strike_target, dmg, false)


func _facing_vector() -> Vector2:
	if _target_ok(_strike_target):
		var v: Vector2 = _strike_target.global_position - global_position
		if v.length() > 0.1:
			return v.normalized()
	var base: Vector2 = {"s": Vector2.DOWN, "se": Vector2(1, 1).normalized(), "e": Vector2.RIGHT,
		"ne": Vector2(1, -1).normalized(), "n": Vector2.UP}[_dir]
	if _flip:
		base.x = -base.x
	return base


## Yüzbaşı/Şövalye savurması: önündeki yaydaki herkes.
func _hit_arc(dmg: float) -> void:
	var fwd: Vector2 = _facing_vector()
	var half: float = deg_to_rad(NecroMath.WARRIOR_CLEAVE_ARC_DEG * 0.5)
	var reach: float = NecroMath.WARRIOR_CLEAVE_RANGE
	for e in EnemyQueryScript.candidates(get_tree(), global_position, reach + 24.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length() > reach + 12.0:
			continue
		if to_e.length() > 6.0 and absf(fwd.angle_to(to_e)) > half:
			continue
		_hit(e, dmg, true)


func _hit_area(center: Vector2, radius: float, dmg: float, stun: float) -> void:
	for e in EnemyQueryScript.candidates(get_tree(), center, radius + 16.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if center.distance_to(e.global_position) > radius + 8.0:
			continue
		_hit(e, dmg, true)
		if stun > 0.0 and e.has_method("apply_stun"):
			e.apply_stun(stun)


func _hit(e: Node, dmg: float, is_area: bool) -> void:
	if not e.has_method("take_damage"):
		return
	var crit: bool = false
	var amount: float = dmg
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("_roll_ability_crit"):
		crit = owner_player._roll_ability_crit()
		amount = owner_player._apply_ability_crit(amount, crit)
	BalanceLogScript.tag(BALANCE_TAGS.get(kind, &"s:necro_savasci"))
	e.take_damage(amount, crit, 0.0, is_area)


func _shoot_arrow() -> void:
	var to: Vector2 = _strike_target.global_position if _target_ok(_strike_target) else _strike_target_pos
	var from: Vector2 = global_position + Vector2(0.0, -ARROW_LAUNCH_HEIGHT)
	var aim: Vector2 = to + Vector2(0.0, -ARROW_AIM_HEIGHT)
	var ghost: bool = unit_key == "ghost_archer"
	NecroFx.spawn_arrow(get_tree(), from, aim, ghost, owner_player, attack_power * dmg_mult, pierce, attack_range * 1.3)
	_send_fx("arrow", from, aim, ghost)


func _mage_fire() -> void:
	var p: Vector2 = _strike_target.global_position if _target_ok(_strike_target) else _strike_target_pos
	NecroFx.spawn_fire(get_tree(), p)
	_hit_area(p, NecroMath.EVO_MAGE_FIRE_RADIUS, owner_ap * NecroMath.EVO_MAGE_FIRE_AP * dmg_mult, 0.0)
	_send_fx("fire", p, p, false)


## Kemik Büyücüsü: 15 sn'de bir yakında ölen bir iskeleti (sahibinin kaydından) aynı rütbede diriltir.
func _process_reborn(delta: float) -> void:
	if unit_key != "mage" or not _action.is_empty():
		return
	_reborn_cd -= delta
	if _reborn_cd > 0.0:
		return
	if not owner_player or not is_instance_valid(owner_player) or not owner_player.has_method("necro_take_fallen"):
		return
	var rec: Dictionary = owner_player.necro_take_fallen(global_position, NecroMath.EVO_MAGE_REBORN_RADIUS)
	if rec.is_empty():
		_reborn_cd = 1.0 ## kayıt yok: 1 sn sonra yine bak
		return
	_reborn_cd = NecroMath.EVO_MAGE_REBORN_COOLDOWN
	_face(Vector2(rec["pos"]) - global_position)
	_play_action("cast")
	owner_player.necro_reborn(rec)


func _send_fx(t: String, from: Vector2, to: Vector2, ghost: bool) -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	NetworkManager.send_player_vfx(multiplayer.get_unique_id(), "necro_fx", from, {"t": t, "to": to, "g": ghost})


## ---------------------------------------------------------------- hasar alma

## Yaratıklar bu müttefiğe kendileri vurmaz (enemy.gd yalnız "player"a temas eder): skeleton_pet.gd gibi yakındakileri kendisi tarar.
## Her yaratığın teması AYRI bir vuruştur (tek vuruş tavanı + engelleme vuruş başına).
func _process_incoming_damage(delta: float) -> void:
	_incoming_dmg_timer -= delta
	if _incoming_dmg_timer > 0.0:
		return
	var hits: Array[float] = []
	for e in EnemyQueryScript.candidates(get_tree(), global_position, INCOMING_CONTACT_RANGE + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true or e.get("is_frozen") == true:
			continue
		if global_position.distance_to(e.global_position) <= INCOMING_CONTACT_RANGE:
			hits.append(float(e.get("contact_damage")) if "contact_damage" in e else INCOMING_FALLBACK_DAMAGE)
	if hits.is_empty():
		return
	_incoming_dmg_timer = INCOMING_TICK_INTERVAL
	for h in hits:
		if is_dead:
			return
		take_damage(h)


func _melee_kind() -> bool:
	return kind != "archer"


func take_damage(amount: float, _source: Node2D = null) -> void:
	if is_dead or amount <= 0.0 or _action == "rise" or _is_network_visual:
		return
	if _melee_kind():
		var blk: float = NecroMath.warrior_block_chance(unit_key)
		if blk > 0.0 and randf() < blk:
			if _action.is_empty():
				_play_action("block", 2.0)
			return
	var dmg: float = NecroMath.capped_hit(kind, max_health, amount)
	_shield_idle = 0.0
	if shield > 0.0:
		var absorbed: float = minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
	if dmg <= 0.0:
		return
	health -= maxf(dmg, 1.0)
	_flash = HURT_FLASH_TIME
	if sprite:
		sprite.modulate = Color(1.0, 0.6, 0.6)
	if health <= 0.0:
		_die()


func _tick_shield(delta: float) -> void:
	if max_shield <= 0.0 or shield >= max_shield:
		return
	_shield_idle += delta
	if _shield_idle >= NecroMath.SHIELD_REGEN_DELAY:
		shield = minf(max_shield, shield + max_shield * NecroMath.SHIELD_REGEN_RATE * delta)


## Ömrü doldu (öldürülmedi): Kemik Büyücüsü bunu diriltmez (player.gd _necro_unit_fell).
var expired: bool = false


func _expire() -> void:
	expired = true
	_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	_start_death()


func _start_death() -> void:
	_dying = true
	_action = ""
	if sprite:
		sprite.modulate = Color.WHITE
	_play_base("death", 1.3)
	_broadcast_network_state(INF)


## Kozmetik kopya sahibinden despawn alınca (remote_player.gd _despawn_pet_visual).
func begin_out() -> void:
	if _dying:
		return
	is_dead = true
	_start_death()


## ---------------------------------------------------------------- ağ

func mark_as_network_visual() -> void:
	_is_network_visual = true
	visible = false ## ilk durum paketi gelene kadar (sahibinin ayağında belirip kaymasın)


func _net_code() -> int:
	var anim: String = "death" if _dying else (_action if not _action.is_empty() else (_loco if not _loco.is_empty() else "idle"))
	var a: int = maxi(0, NET_ANIMS.find(anim))
	var u: int = maxi(0, NET_UNITS.find(unit_key))
	return maxi(0, NecroUnits.DIRS.find(_dir)) + (5 if _flip else 0) + 10 * a + 100 * u


func _broadcast_network_state(delta: float) -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	_net_timer -= delta
	if _net_timer > 0.0:
		return
	var total: int = 1
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("necro_unit_total"):
		total = owner_player.necro_unit_total()
	_net_timer = NET_BASE_INTERVAL * maxf(1.0, float(total) / 10.0)
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position,
		_action in ATTACK_ANIMS, -1.0, -1.0, _net_code())


func update_network_pet_state(pos: Vector2, is_attacking: bool, sprite_row: int = -1, _teleport: bool = false) -> void:
	_network_target_position = pos
	if not _network_state_received:
		global_position = pos
		visible = true
	_network_state_received = true
	if sprite_row < 0 or _dying:
		return
	var u: int = sprite_row / 100
	var rem: int = sprite_row % 100
	var a: int = rem / 10
	var d: int = rem % 10
	if u < NET_UNITS.size():
		set_unit(NET_UNITS[u])
	_dir = NecroUnits.DIRS[d % 5]
	_flip = d >= 5
	var anim: String = NET_ANIMS[a] if a < NET_ANIMS.size() else "idle"
	## Aksiyon animi yalnız YENİ başladığında oynar (anim değişti ya da saldırı bayrağı yükseldi): paket geç gelirse kaster
	## hâlâ "attack" derken kopyanın animi bitmiş olabilir - aynı saldırıyı ikinci kez oynatmasın.
	var rising: bool = is_attacking and not _last_net_attacking
	if anim == "death":
		begin_out()
	elif anim in ["attack", "attack2", "attack3", "block", "cast", "rise"]:
		if anim != _last_net_anim or (rising and anim in ATTACK_ANIMS):
			_action = anim
			_play_base(anim, ARMY_RISE_SPEED if (anim == "rise" and kind == "soldier") else 1.0)
	elif _action.is_empty():
		_play_loco(anim)
	_last_net_anim = anim
	_last_net_attacking = is_attacking


func _process_network_visual(delta: float) -> void:
	if not _network_state_received:
		return
	var to_target: Vector2 = _network_target_position - global_position
	velocity = to_target if to_target.length() > 2.0 else Vector2.ZERO
	global_position = global_position.lerp(_network_target_position, minf(1.0, delta * 12.0))
