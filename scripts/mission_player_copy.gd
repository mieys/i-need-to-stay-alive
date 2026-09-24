extends CharacterBody2D
class_name MissionPlayerCopy

## "Kopyanı Öldür" (Kill your copy) - kullanıcı isteği: aynı silah/statlar ama %90 daha az
## hasar alır/verir, %20 daha yavaş, yetenek kullanamaz. Görünüm: GÜNCELLEME (kullanıcı isteği 2026-09-24:
## "negatif yerine benden bir şekilde farklı görünmesini sağlayacak bir ton değişikliği yap üzerinde genel") - eski
## RGB invert shader yerine COPY_TINT_SHADER_CODE: mor "gölge klonu" tonu (bkz. orada).
## 5 dakika sürer, öldürülmezse yok olur (ödülsüz).
##
## GERÇEK SİLAH ATEŞLEMEZ (bilinen basitleştirme, bkz. world_event_manager.gd dosya başı notu):
## weapon.gd tamamen Player'a bağlı (attack_power/skills/vs. okuyor), bir NPC'ye güvenle
## takmak ciddi bir ek risk/efor - onun yerine temas hasarı (basit kovalama + değme) kullanıldı.
## GÜNCELLEME (kullanıcı bildirimi 2026-09-24: "kopyanın silahları görünmüyor ... tıpkı benim gibi silahları olmalı
## fakat yetenek kullanamamalı"): kopya artık kaynak oyuncunun silahlarını (remote_player.gd'deki kozmetik ikonlarla
## AYNI doku/ölçek/yerleşim kuralı) üstünde taşır, hedefe nişan alır; menzilli saldırıları sırayla bu silahların
## namlusundan çıkar (geri tepmeyle), yakın dövüş silahları temasta savrulur. Hasar dengesi eskisiyle aynı (bkz.
## _fire_next_weapon). Silah listesi world_event_manager.gd _spawn_copies'te kaynaktan okunur, istemcilere meta ile gider.
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

## Mor gölge klonu tonu: rengin %72'si parlaklığa göre mor bir rampaya kayar (koyular derin mor, açıklar soluk
## lavanta) - karakter ve silahları tanınır kalır ama oyuncudan net ayrışır (eskiden koyu karakterlerde sadece
## "biraz daha koyu" görünüyordu).
const COPY_TINT_SHADER_CODE := """shader_type canvas_item;
void fragment() {
	// Godot 4: COLOR burada ZATEN doku x modulate - dokuyu ikinci kez çarpmak rengi mora değil siyaha çekiyordu.
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shadow_ramp = mix(vec3(0.30, 0.12, 0.52), vec3(0.92, 0.80, 1.0), lum);
	COLOR = vec4(mix(c.rgb, shadow_ramp, 0.72), c.a);
}
"""
## Oyuncu kökü 0.5 ölçekli (main.tscn) - kopyanın görseli (gövde + silahlar) aynı ölçekte bir düğümde, böylece
## player.gd'nin karakter ölçeği/ofseti ve remote_player.gd'nin silah yuvası konumları birebir geçerli.
const VISUAL_ROOT_SCALE := 0.5
const RemotePlayerScript := preload("res://scripts/remote_player.gd")
const WAND_SCALE_MULT := 0.3 ## remote_player.gd REMOTE_WAND_SCALE_MULT ile aynı
const MELEE_KEYS := ["dagger", "pence", "topuz", "uzunkilic"]
const AIM_EASE_RATE := 10.0
const RECOIL_DISTANCE := 10.0
const HOVER_BOB := 3.0

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
var _visual_root: Node2D = null
var _tint_material: ShaderMaterial = null
## Silah ikonları: her giriş {"icon": Node2D, "key": String, "melee": bool, "forward": float (rad), "mirror": bool,
## "slot": Vector2, "recoil": float}
var _weapons: Array = []
var _next_weapon: int = 0
var _hover_t: float = 0.0


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
	_visual_root = Node2D.new()
	_visual_root.scale = Vector2.ONE * VISUAL_ROOT_SCALE
	add_child(_visual_root)
	_tint_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = COPY_TINT_SHADER_CODE
	_tint_material.shader = shader
	anim = AnimatedSprite2D.new()
	anim.material = _tint_material
	_visual_root.add_child(anim)
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
	## Oyuncuyla AYNI boy (bkz. player.gd _load_character_frames: DEFS "scale"/"offset" + EntityScale; varsayılanlar player.gd DEFAULT_ANIM_SCALE/OFFSET).
	anim.scale = def.get("scale", Vector2(1.27575, 1.27575)) * EntityScale.SIZE
	anim.offset = def.get("offset", Vector2(0, -5))
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Kaynak oyuncunun silahları (shop anahtarları, ör. ["dagger", "yay"]) - host'ta world_event_manager.gd, istemcide
## main.gd (meta "weapons") çağırır. Kozmetik ikon + atış çıkış noktası; weapon.gd'nin kendisi TAKILMAZ (Player'a bağlı).
func set_weapon_keys(keys: Array) -> void:
	for w in _weapons:
		if is_instance_valid(w["icon"]):
			w["icon"].queue_free()
	_weapons.clear()
	_next_weapon = 0
	var slots: Array[Vector2] = RemotePlayerScript.WEAPON_ICON_SLOTS
	for i in range(mini(keys.size(), slots.size())):
		var key: String = str(keys[i])
		var scene: PackedScene = RemotePlayerScript.WEAPON_SCENES.get(key)
		if scene == null:
			continue
		## Sahne AĞACA EKLENMEDEN örneklenir (weapon.gd _ready/zamanlayıcıları hiç çalışmaz), sadece Icon alınır.
		var root: Node = scene.instantiate()
		var icon: Node2D = root.get_node_or_null("Icon") as Node2D
		if icon == null:
			root.free()
			continue
		root.remove_child(icon)
		var forward: float = deg_to_rad(float(root.get("sprite_forward_angle_deg"))) if "sprite_forward_angle_deg" in root else 0.0
		var mirror: bool = bool(root.get("mirror_icon_when_aiming_left")) if "mirror_icon_when_aiming_left" in root else false
		root.free()
		## remote_player.gd update_weapon_visuals ile AYNI doku/ölçek kuralı (asalar v3 ikon + x0.3, diğerleri x0.9).
		var wand_tex: String = ""
		if key.containsn("arcane"):
			wand_tex = "res://assets/weapons/arcane/icon_v3.png"
		elif key.containsn("fire"):
			wand_tex = "res://assets/weapons/fire/firestaff_icon_v3.png"
		elif key.containsn("lightning"):
			wand_tex = "res://assets/weapons/lightning/icon_v3.png"
		elif key.containsn("buz"):
			wand_tex = "res://assets/weapons/buz_asasi/icon_v3.png"
		if wand_tex != "":
			if icon is Sprite2D:
				(icon as Sprite2D).texture = load(wand_tex)
			icon.scale = Vector2(0.99, 0.99) * WAND_SCALE_MULT
		else:
			icon.scale *= 0.9
		icon.position = slots[i]
		icon.material = _tint_material
		_visual_root.add_child(icon)
		_weapons.append({"icon": icon, "key": key, "melee": key in MELEE_KEYS, "forward": forward, "mirror": mirror,
			"slot": slots[i], "recoil": 0.0})


## Her karede (host ve istemci): silahlar hedefe nişan alır, hafifçe süzülür, geri tepme söner.
func _update_weapon_icons(delta: float) -> void:
	if _weapons.is_empty():
		return
	_hover_t += delta
	var target: Node2D = _target if (_target and is_instance_valid(_target)) else _find_nearest_player()
	for i in range(_weapons.size()):
		var w: Dictionary = _weapons[i]
		var icon: Node2D = w["icon"]
		if not is_instance_valid(icon):
			continue
		w["recoil"] = move_toward(float(w["recoil"]), 0.0, delta * 60.0)
		var dir: Vector2 = Vector2.DOWN
		if target:
			var to_t: Vector2 = target.global_position - (global_position + (w["slot"] as Vector2) * VISUAL_ROOT_SCALE)
			if to_t.length() > 1.0:
				dir = to_t.normalized()
		var bob: float = sin(_hover_t * 2.4 + float(i) * 1.3) * HOVER_BOB
		icon.position = (w["slot"] as Vector2) + Vector2(0.0, bob) - dir * float(w["recoil"])
		if w["melee"]:
			continue ## yakın dövüş silahı dinlenme açısında kalır, temasta savrulur (_swing_melee)
		var flip: bool = bool(w["mirror"]) and dir.x < 0.0
		var target_rot: float = (dir.angle() - PI + float(w["forward"])) if flip else (dir.angle() - float(w["forward"]))
		if icon is Sprite2D:
			(icon as Sprite2D).flip_h = flip
		icon.rotation = lerp_angle(icon.rotation, target_rot, clampf(delta * AIM_EASE_RATE, 0.0, 1.0))


## Menzilli saldırı: sıradaki MENZİLLİ silahın konumundan bolt (hasar/aralık eskisiyle aynı - toplam DPS değişmedi).
## Silahı yoksa (ör. yaratıkla doğmuş eski kayıt) eskisi gibi gövdeden atar; sadece yakın dövüş silahı varsa atmaz.
func _fire_next_weapon(target: Node2D) -> void:
	var ranged: Array = _weapons.filter(func(w: Dictionary) -> bool: return not w["melee"] and is_instance_valid(w["icon"]))
	if _weapons.is_empty():
		_fire_at(target, global_position)
		return
	if ranged.is_empty():
		return
	var w: Dictionary = ranged[_next_weapon % ranged.size()]
	_next_weapon += 1
	w["recoil"] = RECOIL_DISTANCE
	_fire_at(target, (w["icon"] as Node2D).global_position)


## Temas vuruşunda yakın dövüş silahları hedefe doğru kısa bir savuruş yapar (kozmetik).
func _swing_melee(target: Node2D) -> void:
	for w in _weapons:
		if not w["melee"] or not is_instance_valid(w["icon"]):
			continue
		var icon: Node2D = w["icon"]
		var dir: Vector2 = (target.global_position - global_position).normalized() if target else Vector2.RIGHT
		var tw := create_tween()
		tw.tween_property(icon, "rotation", dir.angle() + 1.2, 0.08)
		tw.tween_property(icon, "rotation", dir.angle() - 0.9, 0.1)
		tw.tween_property(icon, "rotation", 0.0, 0.18)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not _is_host_simulated:
		## bkz. dosya başı not - konum/canlılık ağdan geliyor; aradaki kareleri yumuşat (bkz. NET_SMOOTHING).
		if _has_net_pos:
			var before: Vector2 = global_position
			global_position = global_position.lerp(_net_pos, 1.0 - exp(-NET_SMOOTHING * delta))
			_update_move_anim((global_position - before) / maxf(delta, 0.0001))
		_update_weapon_icons(delta)
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
	## DÜZELTME (kullanıcı bildirimi 2026-09-24: "ben yetenek kullanınca onda da aktif oluyor ... yetenek kullanamamalı"):
	## eskiden get_effective_move_speed() okunuyordu - o, oyuncunun yetenek/ruhani/geçici hız buff'larını da içerdiği
	## için (Elara Q, Matthew E, Taktiksel...) oyuncu yetenek kullanınca kopya da aynı anda hızlanıyordu. Artık SADECE
	## kalıcı hız (taban + kart + eşya) kopyalanır (bkz. player.gd/remote_player.gd get_base_move_speed).
	if source_player and is_instance_valid(source_player) and source_player.has_method("get_base_move_speed"):
		move_speed = float(source_player.call("get_base_move_speed")) * SPEED_MULT
	if _target:
		var to_target: Vector2 = _target.global_position - global_position
		var dist: float = to_target.length()
		velocity = to_target.normalized() * move_speed if dist > 2.0 else Vector2.ZERO
		move_and_slide()
		_update_move_anim(velocity)
		if dist <= CONTACT_RANGE and _contact_timer <= 0.0 and _target.has_method("take_damage"):
			_contact_timer = CONTACT_INTERVAL
			_target.take_damage(contact_damage, self)
			_swing_melee(_target)
		elif dist <= RANGED_RANGE and _ranged_timer <= 0.0:
			_ranged_timer = RANGED_INTERVAL
			_fire_next_weapon(_target)
	else:
		velocity = Vector2.ZERO
		_update_move_anim(Vector2.ZERO)
	_update_weapon_icons(delta)
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


func _fire_at(target: Node2D, from_pos: Vector2) -> void:
	spawn_bolt(from_pos, target.global_position, contact_damage, self, false)
	## Mermi SADECE host'ta gerçek (hasar veren) - diğer istemciler aynı atışın hasarsız
	## kozmetik kopyasını görsün (bkz. CLAUDE.md "kaster görür, diğerleri görmez" sınıfı).
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_copy_bolt.rpc(from_pos, target.global_position)


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
