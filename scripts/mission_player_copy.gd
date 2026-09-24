extends CharacterBody2D
class_name MissionPlayerCopy

## "Kopyanı Öldür" (Kill your copy) - kullanıcı isteği: aynı silah/statlar ama %90 daha az
## hasar alır/verir, %20 daha yavaş, yetenek kullanamaz. Görünüm: GÜNCELLEME (kullanıcı isteği 2026-09-24:
## "negatif yerine benden bir şekilde farklı görünmesini sağlayacak bir ton değişikliği yap üzerinde genel") - eski
## RGB invert shader yerine COPY_TINT_SHADER_CODE: mor "gölge klonu" tonu (bkz. orada).
## 5 dakika sürer, öldürülmezse yok olur (ödülsüz).
##
## weapon.gd'nin KENDİSİ TAKILMAZ (tamamen Player'a bağlı - attack_power/skills/vs. okuyor). Kopya kaynak oyuncunun
## silahlarını (remote_player.gd'deki kozmetik ikonlarla AYNI doku/ölçek/yerleşim kuralı) üstünde taşır ve her silah
## sahnesinin kendi atış aralığı/menzil/hasar oranıyla saldırır (bkz. aşağıdaki "saldıramıyor" notu). Silah listesi
## world_event_manager.gd _spawn_copies'te kaynaktan okunur, istemcilere meta ile gider.
##
## HASAR ALMA UYUMLULUĞU: enemy.gd'deki GERÇEK yaratıklarla AYNI çağrı imzası
## (take_damage(amount, is_crit, shield_pen_percent, is_area)) - weapon.gd zaten TÜM hedeflerini
## "enemies" grubundan seçtiği için (bkz. o dosyadaki get_nodes_in_group("enemies") aramaları)
## bu kopyayı da "enemies" grubuna ekleyip enemy.gd'nin AYNI collision_layer/HitArea düzenini
## kopyalamak, gerçek oyuncu silahlarının onu (ekstra kod YAZMADAN) otomatik olarak
## hedefleyip vurabilmesini sağlıyor.
##
## AĞ MİMARİSİ: SADECE host gerçek simüle eder (hareket/hasar/ölüm) - bkz. enemy.gd'nin AYNI
## deseni. Diğer istemcilerde bu Node salt kozmetik, konumunu/canlılığını/can-kalkan oranını
## NetworkManager.world_event_copy_state'ten alır (bkz. network_manager.gd notu).

const DAMAGE_TAKEN_MULT := 0.10
const DAMAGE_DEALT_MULT := 0.10
const SPEED_MULT := 0.80
const LIFETIME := 300.0
const SYNC_INTERVAL := 0.15
## Kullanıcı isteği (2026-09-24): "Kopyanın canı ve kalkanı normal oyuncunun 3 katı olmalı" + "kopyanın kalkanı yok".
## Kalkan = kaynak oyuncunun kalkan maksimumu (item_shield_max) x3; oyuncunun kalkanı yoksa (henüz kalkan eşyası
## seçilmemiş) canının SHIELD_FALLBACK_OF_HP oranı taban alınır ki kopya yine kalkansız doğmasın. Hasar önce kalkandan
## düşer (mission_tree.gd ile aynı), SHIELD_REGEN_DELAY sn hasar almayınca saniyede max'ın SHIELD_REGEN_PER_SEC'i dolar.
const HEALTH_MULT := 3.0
const SHIELD_MULT := 3.0
const SHIELD_FALLBACK_OF_HP := 0.3
const SHIELD_REGEN_DELAY := 7.0
const SHIELD_REGEN_PER_SEC := 0.05

## DÜZELTME (kullanıcı bildirimi 2026-09-24: "kopyanın silahları var ama saldıramıyor"). Kök nedenler: (1) mermi, hedefin
## ATEŞ ANINDAKİ noktasına uçup SADECE orada 28 px içinde kalan oyuncuya vuruyordu - 340 px/sn mermi 300 px'i ~0.9 sn'de
## alıyor, bu sürede yürüyen oyuncu ~75 px uzaklaşıyor: hareket eden oyuncuya neredeyse hiç isabet etmiyordu; (2) tüm
## silahlar TEK ortak 1.4 sn sayaçla sırayla ateşliyordu, sadece yakın dövüş silahı olan kopya HİÇ mermi atmıyordu;
## (3) yakın dövüş sadece 34 px temasla vuruyordu ama kopya oyuncudan %20 yavaş olduğu için hiç yetişemiyordu.
## Artık HER silah kendi sahnesindeki atış aralığı/menzil/hasar oranıyla (weapon.gd'deki fire_rate, attack_range x0.9,
## card_damage_bonus_ratio) bağımsız saldırır; menzilli mermi hedefin gideceği yere hafif önden nişan alır ve yolu
## boyunca değdiği İLK oyuncuya vurur (bkz. mission_copy_bolt.gd); yakın dövüş silahları kendi erişimi içinde doğrudan
## vurur. Hasar: kaynak oyuncunun taban "Hasar" statı (damage_bonus) x silah oranı x DAMAGE_DEALT_MULT (orijinal
## "%90 az hasar" kuralı aynen - kopya oyuncuyla birlikte güçlenir).
const MELEE_REACH := 62.0
const UZUNKILIC_REACH := 115.0 ## weapon.gd _ready: uzunkılıç attack_range = 115
const DEFAULT_RANGED_RANGE := 260.0 ## sahnede attack_range = 0 (sınırsız) olan menzilli silahlar için
const BOLT_SPEED := 340.0 ## mission_copy_bolt.gd SPEED ile aynı
const AIM_LEAD := 0.6 ## hedefin hızına göre önden nişan oranı (1 = kusursuz; <1 = kaçılabilir)

## DÜZELTME (kullanıcı bildirimi 2026-09-24: "kopya sapık gibi karakteri anlık takip ediyor daha farklı olmalı
## hareketleri"). Eskiden her karede hedefin O ANKİ konumuna dümdüz yürüyordu. Artık bir oyuncu gibi dövüşür:
## - Tepki gecikmesi: hedefin konumunu REACTION_MIN..MAX sn'de bir (küçük bir sapmayla) "görür", arada eski bilgiyle
##   hareket eder - ani yön değişimlerine gecikmeli tepki verir.
## - Mesafe tutma: menzilli silahı varsa en kısa menzilinin ~%70'inde durup çevresinde dolaşır (strafe), çok yakına
##   gelinirse geri çekilir; sadece yakın dövüş silahı varsa yaklaşıp etrafında döner.
## - Davranış kipleri (MODE_*): yana kayma (yön ara ara değişir), kısa duraklama (nişan alıyormuş gibi), rastgele
##   bir açıya yeniden konumlanma; uzaktaysa (FAR_CHASE_DIST) doğrudan yaklaşır.
## - İvme: hız anında değil ACCEL ile değişir (keskin zikzak yerine yumuşak dönüşler).
## - Duvarlar: orman duvarına girmez; araya duvar girerse yaratıklarla aynı A* yol bulmayı (enemy_pathing.gd) kullanır.
const REACTION_MIN := 0.25
const REACTION_MAX := 0.5
const PERCEPTION_JITTER := 20.0
const ACCEL := 650.0
const FAR_CHASE_DIST := 600.0
const MELEE_PREFERRED_DIST := 36.0
const MODE_APPROACH := 0
const MODE_STRAFE := 1
const MODE_HOLD := 2
const MODE_REPOSITION := 3
const ROUTE_REPLAN := 1.0
const ROUTE_WAYPOINT_REACHED := 12.0
const EnemyPathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")

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
var shield: float = 0.0
var max_shield: float = 0.0
var _no_damage_timer: float = 0.0
## Kaynak oyuncunun taban "Hasar" statı (setup'ta; host'ta her saldırıda source_player'dan tazelenir).
var damage_bonus: float = 10.0
var move_speed: float = 200.0
var _lifetime_left: float = LIFETIME
var _sync_timer: float = 0.0
var _target: Node2D = null
## Kopyalanan oyuncu (host'ta; yerel Player ya da RemotePlayer kuklası). Hız/hasar ondan okunur - bkz. _physics_process.
var source_player: Node2D = null
## Hareket yapay zekâsı (bkz. yukarıdaki "sapık gibi takip" notu).
var _perceived_pos: Vector2 = Vector2.ZERO
var _has_perception: bool = false
var _reaction_timer: float = 0.0
var _target_vel: Vector2 = Vector2.ZERO
var _target_last_pos: Vector2 = Vector2.ZERO
var _mode: int = MODE_APPROACH
var _mode_timer: float = 0.0
var _strafe_sign: float = 1.0
var _reposition_point: Vector2 = Vector2.ZERO
var _preferred_dist: float = MELEE_PREFERRED_DIST
var _route: PackedVector2Array = PackedVector2Array()
var _route_index: int = 0
var _route_timer: float = 0.0
var _fallback_attack_timer: float = 0.0
## Kullanıcı bildirimi (2026-09-24): "kopya ... normal bir şekilde hareket etmesi gerekiyor" - kopya her zaman idle_down
## oynatıp kayıyordu, istemcide de host'tan saniyede ~7 kez (SYNC_INTERVAL) gelen konuma her pakette SIÇRIYORDU.
## Artık yöne göre walk_/idle_ klibi oynar, istemcide konum son gelen hedefe yumuşakça yaklaşır (NET_SMOOTHING).
const NET_SMOOTHING := 12.0 ## 1/sn - üstel yaklaşma katsayısı (0.15 sn'lik paket aralığını dolduracak kadar hızlı)
const NET_SNAP_DISTANCE := 200.0 ## bundan uzak hedefe (ilk paket / gerçek ışınlanma) yumuşatmadan atla
var _facing: String = "down"
var _net_pos: Vector2 = Vector2.ZERO
var _has_net_pos: bool = false

var anim: AnimatedSprite2D = null
## enemy.gd/mission_tree.gd ile AYNI paylaşılan overhead_bar.gd (can + kalkan).
var _overhead_bar: Node2D = null
var _visual_root: Node2D = null
var _tint_material: ShaderMaterial = null
## Silah ikonları + saldırı verileri: her giriş {"icon": Node2D, "key": String, "melee": bool, "forward": float (rad),
## "mirror": bool, "slot": Vector2, "recoil": float, "interval": float (sn), "ratio": float, "reach": float, "timer": float}
var _weapons: Array = []
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
	_overhead_bar.call("set_shield", shield, max_shield)
	set_physics_process(true)
	NetworkManager.world_event_copy_state.connect(_on_net_state)
	NetworkManager.world_event_copy_damage_requested.connect(_on_remote_damage)
	NetworkManager.world_event_copy_swing.connect(_on_net_swing)


## p_max_health / p_max_shield: KAYNAK oyuncunun değerleri (x3 burada uygulanır). İstemcideki kozmetik kopyada can/kalkan
## ORANLARI ağdan geldiği için bu değerler sadece çubuğun kalkan bölümünün görünmesi için önemli.
func setup(mid: int, idx: int, char_id: int, p_max_health: float, p_max_shield: float, p_speed: float,
		p_damage_bonus: float, simulated: bool) -> void:
	mission_id = mid
	copy_index = idx
	_is_host_simulated = simulated
	var base_hp: float = p_max_health if p_max_health >= 20.0 else 100.0 ## yerdeyken max_hp 1.0 senkronlanıyor
	max_health = base_hp * HEALTH_MULT
	health = max_health
	var base_shield: float = p_max_shield if p_max_shield > 0.0 else base_hp * SHIELD_FALLBACK_OF_HP
	max_shield = base_shield * SHIELD_MULT
	shield = max_shield
	move_speed = p_speed * SPEED_MULT
	damage_bonus = p_damage_bonus
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)
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
## main.gd (meta "weapons") çağırır. Kozmetik ikon + saldırı verileri; weapon.gd'nin kendisi TAKILMAZ (Player'a bağlı).
func set_weapon_keys(keys: Array) -> void:
	for w in _weapons:
		if is_instance_valid(w["icon"]):
			w["icon"].queue_free()
	_weapons.clear()
	var slots: Array[Vector2] = RemotePlayerScript.WEAPON_ICON_SLOTS
	for i in range(mini(keys.size(), slots.size())):
		var key: String = str(keys[i])
		var scene: PackedScene = RemotePlayerScript.WEAPON_SCENES.get(key)
		if scene == null:
			continue
		## Sahne AĞACA EKLENMEDEN örneklenir (weapon.gd _ready/zamanlayıcıları hiç çalışmaz), sadece Icon + dışa
		## aktarılan saldırı değerleri okunur.
		var root: Node = scene.instantiate()
		var icon: Node2D = root.get_node_or_null("Icon") as Node2D
		if icon == null:
			root.free()
			continue
		root.remove_child(icon)
		var forward: float = deg_to_rad(float(root.get("sprite_forward_angle_deg"))) if "sprite_forward_angle_deg" in root else 0.0
		var mirror: bool = bool(root.get("mirror_icon_when_aiming_left")) if "mirror_icon_when_aiming_left" in root else false
		## Saldırı verileri - weapon.gd _ready'deki AYNI düzeltmelerle (yay aralığı /0.85, menzilli menzil x0.9).
		var interval: float = float(root.get("fire_rate")) if "fire_rate" in root else 1.0
		if key == "yay":
			interval /= 0.85
		var ratio: float = float(root.get("card_damage_bonus_ratio")) if "card_damage_bonus_ratio" in root else 1.0
		var is_melee: bool = key in MELEE_KEYS
		var reach: float = MELEE_REACH
		if key == "uzunkilic":
			reach = UZUNKILIC_REACH
		elif not is_melee:
			var ar: float = float(root.get("attack_range")) if "attack_range" in root else 0.0
			reach = ar * 0.9 if ar > 0.0 else DEFAULT_RANGED_RANGE
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
		interval = maxf(0.25, interval)
		_weapons.append({"icon": icon, "key": key, "melee": is_melee, "forward": forward, "mirror": mirror,
			"slot": slots[i], "recoil": 0.0, "interval": interval, "ratio": ratio, "reach": reach,
			"timer": randf_range(0.3, 1.0) * interval})
	_recompute_preferred_dist()


## Menzilli silahı varsa en KISA menzilinin ~%70'i (hepsi ateş edebilsin), yoksa yakın dövüş mesafesi.
func _recompute_preferred_dist() -> void:
	var min_ranged: float = INF
	for w in _weapons:
		if not w["melee"]:
			min_ranged = minf(min_ranged, float(w["reach"]))
	_preferred_dist = clampf(min_ranged * 0.7, 110.0, 230.0) if min_ranged < INF else MELEE_PREFERRED_DIST


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
			continue ## yakın dövüş silahı dinlenme açısında kalır, vuruşta savrulur (_swing_melee_icon)
		var flip: bool = bool(w["mirror"]) and dir.x < 0.0
		var target_rot: float = (dir.angle() - PI + float(w["forward"])) if flip else (dir.angle() - float(w["forward"]))
		if icon is Sprite2D:
			(icon as Sprite2D).flip_h = flip
		icon.rotation = lerp_angle(icon.rotation, target_rot, clampf(delta * AIM_EASE_RATE, 0.0, 1.0))


## Her silah kendi sayacıyla saldırır (bkz. dosya başı "saldıramıyor" notu). Silahı hiç yoksa gövdeyle yakın dövüş
## vuruşu yapar (eski kayıtlar/bozuk anahtar listesi için emniyet).
func _process_attacks(delta: float, target: Node2D, dist: float) -> void:
	if source_player and is_instance_valid(source_player):
		var db: Variant = source_player.get("damage_bonus")
		if db != null:
			damage_bonus = float(db)
	if _weapons.is_empty():
		_fallback_attack_timer -= delta
		if dist <= MELEE_REACH and _fallback_attack_timer <= 0.0:
			_fallback_attack_timer = 1.0
			_melee_hit(target, _weapon_hit_damage(1.0))
		return
	var shot_checked: bool = false
	var shot_clear: bool = false
	for w in _weapons:
		if not is_instance_valid(w["icon"]):
			continue
		w["timer"] = float(w["timer"]) - delta
		if float(w["timer"]) > 0.0 or dist > float(w["reach"]):
			continue
		if not w["melee"]:
			## Orman duvarı arkasındaki hedefe mermi harcamasın (yaratıkların görüş hattı kuralıyla aynı katman).
			if not shot_checked:
				shot_checked = true
				shot_clear = not EnemyPathingScript.line_blocked(global_position, target.global_position)
			if not shot_clear:
				continue
		w["timer"] = float(w["interval"]) * randf_range(0.95, 1.1)
		var dmg: float = _weapon_hit_damage(float(w["ratio"]))
		if w["melee"]:
			var swing_dir: Vector2 = (target.global_position - global_position).normalized()
			_swing_melee_icon(w, swing_dir)
			_melee_hit(target, dmg)
			if NetworkManager.is_multiplayer_active:
				NetworkManager.broadcast_world_event_copy_swing.rpc(mission_id, copy_index, swing_dir)
		else:
			w["recoil"] = RECOIL_DISTANCE
			_fire_at(target, (w["icon"] as Node2D).global_position, dmg)


func _weapon_hit_damage(ratio: float) -> float:
	return maxf(1.0, damage_bonus * ratio * DAMAGE_DEALT_MULT)


func _melee_hit(target: Node2D, dmg: float) -> void:
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(dmg, self)


## Yakın dövüş silahı hedefe doğru kısa bir savuruş yapar (kozmetik).
func _swing_melee_icon(w: Dictionary, dir: Vector2) -> void:
	var icon: Node2D = w["icon"]
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
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
			var near: Node2D = _find_nearest_player()
			var face: Vector2 = (near.global_position - global_position) * 0.001 if near else Vector2.ZERO
			_update_move_anim((global_position - before) / maxf(delta, 0.0001), face)
		_update_weapon_icons(delta)
		return
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_expire()
		return
	_process_shield_regen(delta)
	if not _target or not is_instance_valid(_target) or _target.get("is_dead") == true or _target.get("is_downed") == true:
		_target = _find_nearest_player()
		_has_perception = false
	## Kullanıcı isteği (2026-09-24): "hareket hızı kopyaladığı kişinin hızından %20 daha az olmalı" - kalıcı hız (taban +
	## kart + eşya; yetenek buff'ları HARİÇ - "yetenek kullanamamalı", bkz. player.gd/remote_player.gd
	## get_base_move_speed) her karede yeniden okunur.
	if source_player and is_instance_valid(source_player) and source_player.has_method("get_base_move_speed"):
		move_speed = float(source_player.call("get_base_move_speed")) * SPEED_MULT
	var desired := Vector2.ZERO
	if _target:
		_track_target(delta)
		desired = _desired_direction(delta)
		_process_attacks(delta, _target, global_position.distance_to(_target.global_position))
	velocity = velocity.move_toward(desired * move_speed, ACCEL * delta)
	_block_walls()
	move_and_slide()
	_clamp_to_map()
	var look: Vector2 = Vector2.ZERO
	if _target:
		look = (_target.global_position - global_position) * 0.001 ## dururken hedefe bak (eşik altı: idle klibi)
	_update_move_anim(velocity, look)
	_update_weapon_icons(delta)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_INTERVAL
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_world_event_copy_state.rpc(mission_id, copy_index, global_position, true,
				health / max_health, shield / maxf(max_shield, 0.001))


func _process_shield_regen(delta: float) -> void:
	_no_damage_timer += delta
	if _no_damage_timer < SHIELD_REGEN_DELAY or shield >= max_shield:
		return
	shield = minf(max_shield, shield + max_shield * SHIELD_REGEN_PER_SEC * delta)
	if _overhead_bar:
		_overhead_bar.call("set_shield", shield, max_shield)


## Hedefin hızını tahmin eder (nişan için) ve tepki gecikmesiyle "algılanan" konumunu günceller.
func _track_target(delta: float) -> void:
	var tp: Vector2 = _target.global_position
	if _has_perception:
		var inst_vel: Vector2 = (tp - _target_last_pos) / maxf(delta, 0.0001)
		if inst_vel.length() < 1000.0: ## ışınlanma/yeniden doğuş sıçramasını yok say
			_target_vel = _target_vel.lerp(inst_vel, clampf(delta * 6.0, 0.0, 1.0))
	_target_last_pos = tp
	_reaction_timer -= delta
	if not _has_perception or _reaction_timer <= 0.0:
		_reaction_timer = randf_range(REACTION_MIN, REACTION_MAX)
		_perceived_pos = tp + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * PERCEPTION_JITTER
		_has_perception = true


func _desired_direction(delta: float) -> Vector2:
	var to_t: Vector2 = _perceived_pos - global_position
	var dist: float = to_t.length()
	if dist < 0.5:
		return Vector2.ZERO
	var to_n: Vector2 = to_t / dist
	## Araya duvar girdiyse önce dolan (yaratıklarla aynı A*); kipler ancak açık alanda.
	if EnemyPathingScript.line_blocked(global_position, _perceived_pos):
		var routed: Vector2 = _route_dir(delta)
		return routed if routed != Vector2.ZERO else to_n
	_route = PackedVector2Array()
	_mode_timer -= delta
	if dist > FAR_CHASE_DIST:
		_mode = MODE_APPROACH
		_mode_timer = 0.0
	elif _mode_timer <= 0.0 or _mode == MODE_APPROACH:
		_pick_mode(to_n)
	match _mode:
		MODE_HOLD:
			if dist < _preferred_dist * 0.5:
				return -to_n ## çok yakına gelindiyse dururken bile geri adım at
			return Vector2.ZERO
		MODE_REPOSITION:
			var to_p: Vector2 = _reposition_point - global_position
			if to_p.length() < 14.0:
				_mode_timer = 0.0
				return Vector2.ZERO
			return to_p.normalized()
		MODE_STRAFE:
			## Radyal bileşen tercih edilen mesafeyi korur, teğet bileşen hedefin etrafında dolaştırır.
			var radial: float = clampf((dist - _preferred_dist) / 70.0, -1.0, 1.0)
			var tangent: Vector2 = to_n.orthogonal() * _strafe_sign
			return (to_n * radial + tangent * 0.85).normalized()
	return to_n


func _pick_mode(to_n: Vector2) -> void:
	var r: float = randf()
	var melee_only: bool = _preferred_dist <= MELEE_PREFERRED_DIST
	if r < (0.6 if melee_only else 0.5):
		_mode = MODE_STRAFE
		_mode_timer = randf_range(1.0, 2.6)
		if randf() < 0.55:
			_strafe_sign = -_strafe_sign
	elif r < (0.75 if melee_only else 0.72):
		_mode = MODE_HOLD
		_mode_timer = randf_range(0.35, 0.9)
	else:
		_mode = MODE_REPOSITION
		_mode_timer = randf_range(1.0, 2.0)
		## Hedefin çevresinde, mevcut açıdan 40-100 derece sapmış, tercih edilen mesafede bir nokta.
		var ang: float = (-to_n).angle() + randf_range(0.7, 1.75) * (1.0 if randf() < 0.5 else -1.0)
		var d: float = _preferred_dist * randf_range(0.85, 1.2)
		_reposition_point = _perceived_pos + Vector2.from_angle(ang) * d
		if GameManager.is_position_blocked_by_forest(_reposition_point):
			_mode = MODE_STRAFE


func _route_dir(delta: float) -> Vector2:
	_route_timer -= delta
	if (_route.is_empty() or _route_timer <= 0.0) and EnemyPathingScript.can_request():
		_route = EnemyPathingScript.find_path(global_position, _perceived_pos)
		_route_index = 0
		_route_timer = ROUTE_REPLAN
	while _route_index < _route.size() and global_position.distance_to(_route[_route_index]) < ROUTE_WAYPOINT_REACHED:
		_route_index += 1
	if _route_index >= _route.size():
		return Vector2.ZERO
	return (_route[_route_index] - global_position).normalized()


## Orman duvarına girmesin (collision_mask = 0 - fiziksel çarpışma yok; oyuncu/yaratıklarla aynı katman kuralı, bkz.
## enemy.gd _block_movement_into_terrain). Duvara dayanınca yana kayma yönünü de çevirir. Zaten duvarın içindeyse
## engelleme atlanır (sonsuza dek hapsolmasın - enemy.gd'deki aynı güvenlik ağı).
func _block_walls() -> void:
	if velocity.length_squared() < 0.01 or GameManager.is_position_blocked_by_forest(global_position):
		return
	var probe: float = 12.0
	if velocity.x != 0.0 and GameManager.is_position_blocked_by_forest(global_position + Vector2(signf(velocity.x) * probe, 0.0)):
		velocity.x = 0.0
		_strafe_sign = -_strafe_sign
	if velocity.y != 0.0 and GameManager.is_position_blocked_by_forest(global_position + Vector2(0.0, signf(velocity.y) * probe)):
		velocity.y = 0.0
		_strafe_sign = -_strafe_sign


func _clamp_to_map() -> void:
	var rect: Rect2 = GameManager.get_map_world_rect()
	if rect.size == Vector2.ZERO:
		return
	global_position = global_position.clamp(rect.position, rect.end)


const BoltScript := preload("res://scripts/mission_copy_bolt.gd")


## Yürüme/bekleme klibi (4 yön, karakterlerin walk_/idle_<yön> adlandırması - bkz. char_anim.gd DIRECTIONS). Hareket
## ederken hareket yönüne, dururken `face` yönüne (hedefe) bakar. Klip yoksa sessizce mevcut klipte kalır.
func _update_move_anim(move: Vector2, face: Vector2 = Vector2.ZERO) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var moving: bool = move.length() > 5.0
	var look: Vector2 = move if moving else face
	if look.length() > 0.0001:
		if absf(look.x) > absf(look.y):
			_facing = "right" if look.x > 0.0 else "left"
		else:
			_facing = "down" if look.y > 0.0 else "up"
	var clip: String = ("walk_" if moving else "idle_") + _facing
	if anim.sprite_frames.has_animation(clip) and anim.animation != clip:
		anim.play(clip)


## Hedefin gideceği yere (hızının AIM_LEAD oranında) önden nişan; mermi nişan noktasının biraz ötesine kadar uçar.
func _fire_at(target: Node2D, from_pos: Vector2, dmg: float) -> void:
	var tp: Vector2 = target.global_position
	var t_flight: float = from_pos.distance_to(tp) / BOLT_SPEED
	var aim: Vector2 = tp + _target_vel * t_flight * AIM_LEAD
	var dir: Vector2 = (aim - from_pos).normalized() if aim.distance_to(from_pos) > 1.0 else Vector2.RIGHT
	var end_pos: Vector2 = from_pos + dir * (from_pos.distance_to(aim) + 140.0)
	spawn_bolt(from_pos, end_pos, dmg, self, false)
	## Mermi SADECE host'ta gerçek (hasar veren) - diğer istemciler aynı atışın hasarsız
	## kozmetik kopyasını görsün (bkz. CLAUDE.md "kaster görür, diğerleri görmez" sınıfı).
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_copy_bolt.rpc(from_pos, end_pos)


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


## Enemy.gd ile AYNI imza (bkz. dosya başı not) - gerçek oyuncu silahları bunu çağırır. Hasar önce kalkandan düşer.
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
	var dmg: float = amount * DAMAGE_TAKEN_MULT
	_no_damage_timer = 0.0
	if shield > 0.0:
		var absorbed: float = minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
	health = max(0.0, health - dmg)
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)
	if health <= 0.0:
		_die()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_copy_state.rpc(mission_id, copy_index, global_position, false, 0.0, 0.0)
	queue_free()


func _expire() -> void:
	if is_dead:
		return
	is_dead = true
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_copy_state.rpc(mission_id, copy_index, global_position, false, 0.0, 0.0)
	queue_free()


## Kozmetik kopyada: host'taki gerçek kopya yakın dövüş vuruşu yaptı - yakın dövüş ikonlarını aynı yöne savur.
func _on_net_swing(mid: int, idx: int, dir: Vector2) -> void:
	if _is_host_simulated or is_dead or mid != mission_id or idx != copy_index:
		return
	for w in _weapons:
		if w["melee"] and is_instance_valid(w["icon"]):
			_swing_melee_icon(w, dir)


## Host'ta: bir istemcinin kozmetik kopyaya verdiği hasar (bkz. take_damage) gerçek kopyaya uygulanır.
func _on_remote_damage(mid: int, idx: int, amount: float) -> void:
	if not _is_host_simulated or mid != mission_id or idx != copy_index:
		return
	take_damage(amount)


## Kozmetik kopyalarda (bkz. dosya başı not) - host'un gerçek kopyasından gelen konum/canlılık/can/kalkan.
func _on_net_state(mid: int, idx: int, pos: Vector2, alive: bool, health_ratio: float, shield_ratio: float) -> void:
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
	shield = max_shield * clampf(shield_ratio, 0.0, 1.0)
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)
