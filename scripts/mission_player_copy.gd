extends CharacterBody2D
class_name MissionPlayerCopy

## "Kopyanı Öldür" (Kill your copy) - kullanıcı isteği: aynı silah/statlar ama %90 daha az
## hasar alır/verir, %20 daha yavaş, yetenek kullanamaz, "negatif zıt tonlar" (kullanıcı cevabı:
## "renk tersine çevirme olsun" - basit bir RGB invert shader, aşağıdaki INVERT_SHADER_CODE).
## 5 dakika sürer, öldürülmezse yok olur (ödülsüz).
##
## GERÇEK SİLAH ATEŞLEMEZ (bilinen basitleştirme, bkz. world_event_manager.gd dosya başı notu):
## weapon.gd tamamen Player'a bağlı (attack_power/skills/vs. okuyor), bir NPC'ye güvenle
## takmak ciddi bir ek risk/efor - onun yerine temas hasarı (basit kovalama + değme) kullanıldı.
## "Aynı silaha sahip" sözü GÖRSEL olarak da karşılanmıyor (ikon eklenmedi) - zaman kısıtı.
##
## HASAR ALMA UYUMLULUĞU: enemy.gd'deki GERÇEK yaratıklarla AYNI çağrı imzası
## (take_damage(amount, is_crit, shield_pen_percent, is_area)) - weapon.gd zaten TÜM hedeflerini
## "enemies" grubundan seçtiği için (bkz. o dosyadaki get_nodes_in_group("enemies") aramaları)
## bu kopyayı da "enemies" grubuna ekleyip enemy.gd'nin AYNI collision_layer/HitArea düzenini
## kopyalamak, gerçek oyuncu silahlarının onu (ekstra kod YAZMADAN) otomatik olarak
## hedefleyip vurabilmesini sağlıyor.
##
## AĞ MİMARİSİ: SADECE host gerçek simüle eder (hareket/hasar/ölüm) - bkz. enemy.gd'nin AYNI
## deseni. Diğer istemcilerde bu Node salt kozmetik, konumunu/canlılığını
## NetworkManager.world_event_copy_state'ten alır (bkz. network_manager.gd notu).

const DAMAGE_TAKEN_MULT := 0.10
const DAMAGE_DEALT_MULT := 0.10
const SPEED_MULT := 0.80
const CONTACT_RANGE := 34.0
const CONTACT_INTERVAL := 0.8
const LIFETIME := 300.0
const SYNC_INTERVAL := 0.15
## DÜZELTME (kullanıcı bildirimi: "kopyanın ... silahları yok bize saldıramıyorlar bu yüzden") -
## dosya başı nottaki bilinen basitleştirme ("gerçek silah ateşlemez, sadece temas hasarı")
## kopyayı neredeyse zararsız yapıyordu (oyuncu menzilli silahla kolayca kaçıp öldürebiliyor,
## kopya asla yaklaşamıyor). weapon.gd'yi bir NPC'ye bağlamak hâlâ riskli (Player'a sıkı bağımlı,
## bkz. o not) - onun yerine mission_tree.gd _try_fire_at_nearest_enemy ile AYNI, zaten kanıtlanmış
## "basit mermi at" deseni kullanılıyor: kopya artık menzilden de gerçek bir tehdit.
const RANGED_RANGE := 320.0
const RANGED_INTERVAL := 1.4
const ProjectileScene := preload("res://scenes/projectile.tscn")

const INVERT_SHADER_CODE := "shader_type canvas_item;\nvoid fragment() {\n\tvec4 tex = texture(TEXTURE, UV);\n\tCOLOR = vec4(vec3(1.0) - tex.rgb, tex.a);\n}\n"

var mission_id: int = 0
var copy_index: int = 0
var is_dead: bool = false
var _is_host_simulated: bool = true
var health: float = 100.0
var max_health: float = 100.0
var contact_damage: float = 6.0 ## bkz. dosya başı not - setup() içinde ZATEN %10'a indirilmiş
var move_speed: float = 200.0
var _lifetime_left: float = LIFETIME
var _contact_timer: float = 0.0
var _ranged_timer: float = 0.0
var _sync_timer: float = 0.0
var _target: Node2D = null
## Kopyalanan oyuncu (host'ta; yerel Player ya da RemotePlayer kuklası). Hız her karede ondan okunur - bkz. _physics_process.
var source_player: Node2D = null
## Kullanıcı bildirimi (2026-09-24): "kopya ... normal bir şekilde hareket etmesi gerekiyor" - kopya her zaman idle_down
## oynatıp kayıyordu, istemcide de host'tan saniyede ~7 kez (SYNC_INTERVAL) gelen konuma her pakette SIÇRIYORDU.
## Artık yöne göre walk_/idle_ klibi oynar, istemcide konum son gelen hedefe yumuşakça yaklaşır (NET_SMOOTHING).
const NET_SMOOTHING := 12.0 ## 1/sn - üstel yaklaşma katsayısı (0.15 sn'lik paket aralığını dolduracak kadar hızlı)
const NET_SNAP_DISTANCE := 200.0 ## bundan uzak hedefe (ilk paket / gerçek ışınlanma) yumuşatmadan atla
var _facing: String = "down"
var _net_pos: Vector2 = Vector2.ZERO
var _has_net_pos: bool = false

var anim: AnimatedSprite2D = null
## Kullanıcı isteği: "kopyanın canı kalkanı görünmüyor" - enemy.gd/mission_tree.gd ile AYNI
## paylaşılan overhead_bar.gd (bkz. o dosyaların _create_overhead_bar/_ready deseni). Kopyada
## kalkan STAT'ı yok (health/max_health dışında hiç eklenmedi) - set_shield(0,0) ile çubuğun
## kalkan bölümü boş/gizli kalır, bu YENİ bir mekanik icat etmez, sadece can çubuğunu gösterir.
var _overhead_bar: Node2D = null


## DÜZELTME: bu Node .tscn'siz, tamamen kod içinde kuruluyor (bkz. dosya başı not) - @onready
## $Path yerine çocuklar burada, _ready()'de, add_child'dan HEMEN SONRA elle oluşturuluyor;
## setup() bu yüzden add_child'dan SONRA çağrılmalı (bkz. world_event_manager.gd çağrı sırası).
func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 0
	var body_shape := CollisionShape2D.new()
	var body_circle := CircleShape2D.new()
	body_circle.radius = 16.0
	body_shape.shape = body_circle
	add_child(body_shape)
	anim = AnimatedSprite2D.new()
	add_child(anim)
	_overhead_bar = Node2D.new()
	_overhead_bar.set_script(preload("res://scripts/overhead_bar.gd"))
	add_child(_overhead_bar)
	_overhead_bar.visible = true
	_overhead_bar.call("set_offset", -30.0)
	_overhead_bar.call("set_health", health, max_health)
	_overhead_bar.call("set_shield", 0.0, 0.0)
	set_physics_process(true)
	NetworkManager.world_event_copy_state.connect(_on_net_state)
	NetworkManager.world_event_copy_damage_requested.connect(_on_remote_damage)


func setup(mid: int, idx: int, char_id: int, p_max_health: float, p_speed: float, p_contact_damage: float, simulated: bool) -> void:
	mission_id = mid
	copy_index = idx
	_is_host_simulated = simulated
	max_health = maxf(20.0, p_max_health)
	health = max_health
	move_speed = p_speed * SPEED_MULT
	contact_damage = p_contact_damage * DAMAGE_DEALT_MULT
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
	var def: Dictionary = Characters.get_def(char_id)
	var path: String = def.get("frames", "")
	if path != "" and ResourceLoader.exists(path):
		anim.sprite_frames = load(path)
		if anim.sprite_frames.has_animation("idle_down"):
			anim.play("idle_down")
	var shader := Shader.new()
	shader.code = INVERT_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	anim.material = mat


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not _is_host_simulated:
		## bkz. dosya başı not - konum/canlılık ağdan geliyor; aradaki kareleri yumuşat (bkz. NET_SMOOTHING).
		if _has_net_pos:
			var before: Vector2 = global_position
			global_position = global_position.lerp(_net_pos, 1.0 - exp(-NET_SMOOTHING * delta))
			_update_move_anim((global_position - before) / maxf(delta, 0.0001))
		return
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_expire()
		return
	_contact_timer -= delta
	_ranged_timer -= delta
	if not _target or not is_instance_valid(_target) or _target.get("is_dead") == true:
		_target = _find_nearest_player()
	## Kullanıcı isteği (2026-09-24): "hareket hızı kopyaladığı kişinin hızından %20 daha az olmalı" - setup'taki TEK
	## seferlik değer yerine kopyalanan oyuncunun O ANKİ gerçek hızı (hız kartı/eşya/yetenek buff'ları dahil).
	if source_player and is_instance_valid(source_player) and source_player.has_method("get_effective_move_speed"):
		move_speed = float(source_player.call("get_effective_move_speed")) * SPEED_MULT
	if _target:
		var to_target: Vector2 = _target.global_position - global_position
		var dist: float = to_target.length()
		velocity = to_target.normalized() * move_speed if dist > 2.0 else Vector2.ZERO
		move_and_slide()
		_update_move_anim(velocity)
		if dist <= CONTACT_RANGE and _contact_timer <= 0.0 and _target.has_method("take_damage"):
			_contact_timer = CONTACT_INTERVAL
			_target.take_damage(contact_damage, self)
		elif dist <= RANGED_RANGE and _ranged_timer <= 0.0:
			_ranged_timer = RANGED_INTERVAL
			_fire_at(_target)
	else:
		velocity = Vector2.ZERO
		_update_move_anim(Vector2.ZERO)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_INTERVAL
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_world_event_copy_state.rpc(mission_id, copy_index, global_position, true, health / max_health)


const BoltScript := preload("res://scripts/mission_copy_bolt.gd")


## Hareket vektörüne göre yürüme/bekleme klibi (4 yön, karakterlerin walk_/idle_<yön> adlandırması - bkz. char_anim.gd
## DIRECTIONS). Klip yoksa (ör. eski bir SpriteFrames) sessizce mevcut klipte kalır.
func _update_move_anim(move: Vector2) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var moving: bool = move.length() > 5.0
	if moving:
		if absf(move.x) > absf(move.y):
			_facing = "right" if move.x > 0.0 else "left"
		else:
			_facing = "down" if move.y > 0.0 else "up"
	var clip: String = ("walk_" if moving else "idle_") + _facing
	if anim.sprite_frames.has_animation(clip) and anim.animation != clip:
		anim.play(clip)


func _fire_at(target: Node2D) -> void:
	spawn_bolt(global_position, target.global_position, contact_damage, self, false)
	## Mermi SADECE host'ta gerçek (hasar veren) - diğer istemciler aynı atışın hasarsız
	## kozmetik kopyasını görsün (bkz. CLAUDE.md "kaster görür, diğerleri görmez" sınıfı).
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_copy_bolt.rpc(global_position, target.global_position)


static func spawn_bolt(from_pos: Vector2, to_pos: Vector2, damage: float, source: Node2D, cosmetic: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var bolt := Node2D.new()
	bolt.set_script(BoltScript)
	tree.current_scene.add_child(bolt)
	bolt.call("setup", from_pos, to_pos, damage, source, cosmetic)


func _find_nearest_player() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(p) or p.get("is_dead") == true or p.get("is_downed") == true:
				continue
			var d: float = global_position.distance_to((p as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = p
	return best


## Enemy.gd ile AYNI imza (bkz. dosya başı not) - gerçek oyuncu silahları bunu çağırır.
func take_damage(amount: float, _is_crit: bool = false, _shield_pen_percent: float = 0.0, _is_area: bool = false) -> void:
	if is_dead:
		return
	## DÜZELTME (kullanıcı bildirimi 2026-09-24: görevler çok oyunculuda da çalışmalı) - host olmayan bir
	## istemcinin silahı SADECE bu kozmetik kopyaya vuruyordu ve hasar burada sessizce yok oluyordu (kopya
	## hiç ölmüyordu). Artık hasar host'taki GERÇEK kopyaya iletiliyor.
	if not _is_host_simulated:
		if NetworkManager.is_multiplayer_active:
			NetworkManager.request_world_event_copy_damage.rpc_id(NetworkManager._host_peer_id(), mission_id, copy_index, amount)
		return
	health = max(0.0, health - amount * DAMAGE_TAKEN_MULT)
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_copy_state.rpc(mission_id, copy_index, global_position, false, 0.0)
	queue_free()


func _expire() -> void:
	if is_dead:
		return
	is_dead = true
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_copy_state.rpc(mission_id, copy_index, global_position, false, 0.0)
	queue_free()


## Host'ta: bir istemcinin kozmetik kopyaya verdiği hasar (bkz. take_damage) gerçek kopyaya uygulanır.
func _on_remote_damage(mid: int, idx: int, amount: float) -> void:
	if not _is_host_simulated or mid != mission_id or idx != copy_index:
		return
	take_damage(amount)


## Kozmetik kopyalarda (bkz. dosya başı not) - host'un gerçek kopyasından gelen konum/canlılık/can.
func _on_net_state(mid: int, idx: int, pos: Vector2, alive: bool, health_ratio: float) -> void:
	if _is_host_simulated or mid != mission_id or idx != copy_index:
		return
	if not alive:
		is_dead = true
		queue_free()
		return
	if not _has_net_pos or global_position.distance_to(pos) > NET_SNAP_DISTANCE:
		global_position = pos
	_net_pos = pos
	_has_net_pos = true
	health = max_health * clampf(health_ratio, 0.0, 1.0)
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
