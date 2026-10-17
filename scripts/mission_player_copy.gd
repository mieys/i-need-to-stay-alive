extends CharacterBody2D
class_name MissionPlayerCopy

## "Kopyanı Öldür" (Kill your copy) - kullanıcı isteği: aynı silah/statlar, verdiği/aldığı hasar zamanla artan oranda azalır
## (bkz. RESIST_*), yetenek kullanamaz. Görünüm: GÜNCELLEME (kullanıcı isteği 2026-09-24:
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

## 2026-10-14 (kullanıcı: "kopya ilk levellerde çok dayanıklı çok az hasar veren bir şeyken late gamede tek yiyor"): TÜM eski çarpanlar
## (can/kalkan x30, hız %80, kalkan yedeği) SİLİNDİ - kopya kaynak oyuncunun can/kalkan/hız/saldırı statlarına AYNEN sahiptir.
## Tek ayar: verdiği VE aldığı hasar aynı oranda azalır (direnç). %50 ile başlar, oyunda geçen (GameManager.game_time) her 20 sn için
## %1 artar, en fazla %95 olur (15. dakikada dolar). Hasar verirken `damage x (1 - direnç)`, hasar alırken `amount x (1 - direnç)`.
const RESIST_START := 0.50
const RESIST_PER_STEP := 0.01
const RESIST_STEP_SECONDS := 20.0
const RESIST_MAX := 0.95
const BASE_CRIT_CHANCE := 0.05 ## weapon.gd crit_chance varsayılanı
const BASE_CRIT_DAMAGE := 1.5 ## weapon.gd crit_damage varsayılanı
## 2026-09-26 ("görev süreleri gereksiz uzun"): 300 -> 150 sn. world_event_manager.gd COPY_LIFETIME bunu okur (tek kaynak).
const LIFETIME := 150.0
const SYNC_INTERVAL := 0.15
## Kalkan = kaynak oyuncunun kalkan maksimumu (item_shield_max); oyuncunun kalkanı yoksa kopyanınki de yoktur. Hasar önce kalkandan
## düşer (mission_tree.gd ile aynı), SHIELD_REGEN_DELAY sn hasar almayınca saniyede max'ın SHIELD_REGEN_PER_SEC'i dolar.
## Kalkanın bir isabetten emdiği pay (oyuncu kalkanındaki "koruma payı" gibi): %80'i kalkana, %20'si kalkan dolu olsa bile doğrudan cana gider.
const SHIELD_ABSORB_RATIO := 0.8
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
## vurur. Hasar: kaynak oyuncunun taban "Hasar" statı (damage_bonus) x silah oranı x (1 - direnç) (bkz. RESIST_*;
## kopya oyuncuyla birlikte güçlenir).
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
const BalanceLogScript := preload("res://scripts/balance_log.gd")
const DamageNumbersScript := preload("res://scripts/damage_numbers.gd")
const WeaponTierArtScript := preload("res://scripts/weapon_tier_art.gd")
const WAND_SCALE_MULT := 0.3 ## remote_player.gd REMOTE_WAND_SCALE_MULT ile aynı
const MELEE_KEYS := ["dagger", "pence", "topuz", "uzunkilic"]
const AIM_EASE_RATE := 10.0
const RECOIL_DISTANCE := 10.0
const HOVER_BOB := 3.0

## Verdiği/aldığı hasarın azalma oranı (0..1) - oyunda geçen süreye göre (bkz. RESIST_*). Host ve istemci aynı game_time'ı okur.
static func resist_at(game_time: float) -> float:
	var steps: int = int(floor(maxf(game_time, 0.0) / RESIST_STEP_SECONDS))
	return minf(RESIST_MAX, RESIST_START + float(steps) * RESIST_PER_STEP)


static func resist_now() -> float:
	return resist_at(GameManager.game_time)


var mission_id: int = 0
var copy_index: int = 0
var is_dead: bool = false
var is_boss: bool = false ## silah özellikleri "boss değilse it/sersemlet" kuralına bakar
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
	## Silahlar kopya varken daima ona odaklanır (kullanıcı isteği 2026-09-25, bkz. weapon_target_priority.gd).
	add_to_group("mission_copies")
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
	NetworkManager.world_event_copy_knockback_requested.connect(_on_remote_knockback)
	NetworkManager.world_event_copy_swing.connect(_on_net_swing)


## p_max_health / p_max_shield: KAYNAK oyuncunun değerleri (çarpansız aynen kullanılır). İstemcideki kozmetik kopyada can/kalkan
## ORANLARI ağdan geldiği için bu değerler sadece çubuğun kalkan bölümünün görünmesi için önemli.
func setup(mid: int, idx: int, char_id: int, p_max_health: float, p_max_shield: float, p_speed: float,
		p_damage_bonus: float, simulated: bool) -> void:
	mission_id = mid
	copy_index = idx
	_is_host_simulated = simulated
	var base_hp: float = p_max_health if p_max_health >= 20.0 else 100.0 ## yerdeyken max_hp 1.0 senkronlanıyor
	max_health = base_hp
	health = max_health
	max_shield = maxf(p_max_shield, 0.0)
	shield = max_shield
	move_speed = p_speed
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
		interval /= GameManager.WEAPON_ATTACK_SPEED_MULT ## genel silah yavaşlatması (2026-10-17, -%30 saldırı hızı)
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
		icon.scale *= WeaponOrbitMath.ICON_SIZE_MULT ## 2026-09-25: silahlar %15 küçük (oyuncu/kukla ile aynı)
		## Zanaatkâr seti (madde 196): remote_player.gd ile AYNI sanat/ölçek/duruş (weapon_tier_art.gd). Kopya kademeyi bilmez -> 1. seviye.
		if WeaponTierArtScript.has_art(key) and WeaponTierArtScript.set_art(icon, key, 1):
			icon.scale = Vector2.ONE * WeaponTierArtScript.PUPPET_ICON_SCALE
			forward = deg_to_rad(float(WeaponTierArtScript.FORWARD[key]))
		icon.position = slots[i]
		icon.material = _tint_material
		_visual_root.add_child(icon)
		interval = maxf(0.25, interval)
		_weapons.append({"icon": icon, "key": key, "melee": is_melee, "forward": forward, "mirror": mirror,
			"slot": slots[i], "recoil": 0.0, "interval": interval, "ratio": ratio, "reach": reach,
			"info": attack_info(key), "timer": randf_range(0.3, 1.0) * interval})
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
		w["timer"] = float(w["interval"]) * _source_interval_mult() * randf_range(0.95, 1.1)
		var dmg: float = _weapon_hit_damage(float(w["ratio"]))
		if w["melee"]:
			var swing_dir: Vector2 = (target.global_position - global_position).normalized()
			_swing_melee_icon(w, swing_dir)
			_melee_hit(target, dmg)
			if NetworkManager.is_multiplayer_active:
				NetworkManager.broadcast_world_event_copy_swing.rpc(mission_id, copy_index, swing_dir)
		else:
			w["recoil"] = RECOIL_DISTANCE
			_fire_at(target, (w["icon"] as Node2D).global_position, dmg, w)


func _weapon_hit_damage(ratio: float) -> float:
	var dmg: float = damage_bonus * ratio * (1.0 - resist_now())
	if randf() < BASE_CRIT_CHANCE + _source_stat("crit_chance_bonus"):
		dmg *= BASE_CRIT_DAMAGE + _source_stat("crit_damage_bonus")
	return maxf(1.0, dmg)


## Kaynak oyuncunun saldırı hızı çarpanı (atış aralığı; < 1 = hızlı). Yerel Player'da player.gd, uzak oyuncuda remote_player.gd (main.gd
## extra "atk_iv" ile senkron) aynı adlı işlevi verir.
func _source_interval_mult() -> float:
	if source_player and is_instance_valid(source_player) and source_player.has_method("get_attack_interval_mult"):
		return clampf(float(source_player.call("get_attack_interval_mult")), 0.1, 3.0)
	return 1.0


func _source_stat(prop: String) -> float:
	if source_player and is_instance_valid(source_player):
		var v: Variant = source_player.get(prop)
		if v != null:
			return float(v)
	return 0.0


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
	_process_dots(delta)
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
		move_speed = float(source_player.call("get_base_move_speed"))
	if Time.get_ticks_msec() < _slow_until_msec:
		move_speed *= 1.0 - _slow_pct
	var desired := Vector2.ZERO
	if _target and not _is_disabled_now(): ## donmuş / sersemlemiş kopya yürümez ve saldırmaz (silah özellikleri)
		_track_target(delta)
		desired = _desired_direction(delta)
		_process_attacks(delta, _target, global_position.distance_to(_target.global_position))
	velocity = velocity.move_toward(desired * move_speed, ACCEL * delta)
	## İtiş hızı yürüme hızına eklenir, bu karede kullanılıp yaratıklarla AYNI oranda söner (bkz. apply_knockback_distance).
	var walk_velocity: Vector2 = velocity
	velocity += _knockback_velocity
	_block_walls()
	move_and_slide()
	velocity = walk_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, Enemy.KNOCKBACK_DECAY * delta)
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
		if GameManager.is_position_blocked_by_walls(_reposition_point):
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
	if velocity.length_squared() < 0.01 or GameManager.is_position_blocked_by_walls(global_position):
		return
	var probe: float = 12.0
	if velocity.x != 0.0 and GameManager.is_position_blocked_by_walls(global_position + Vector2(signf(velocity.x) * probe, 0.0)):
		velocity.x = 0.0
		_strafe_sign = -_strafe_sign
	if velocity.y != 0.0 and GameManager.is_position_blocked_by_walls(global_position + Vector2(0.0, signf(velocity.y) * probe)):
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
## KOPYA SİLAHLARIYLA ATEŞ EDER (kullanıcı bildirimi 2026-10-05: "kopya benim silahlarıma sahip ama onlarla ateş etmiyor, başka
## ateşler ediyor"): mermi görseli/hızı silahın KENDİ mermi sahnesinden gelir (attack_info), Şimşek Asası anlık ışın çizer.
## Hasar mantığı aynı (yolu boyunca değen ilk oyuncuya vurur, direnç oranında azaltılmış).
func _fire_at(target: Node2D, from_pos: Vector2, dmg: float, w: Dictionary = {}) -> void:
	var key: String = str(w.get("key", ""))
	var info: Dictionary = w.get("info", {})
	var tp: Vector2 = target.global_position
	if info.get("beam") != null:
		## Işın silahı (Şimşek Asası): anında vurur; ışın görseli kısa süre görünür (bkz. spawn_bolt/_spawn_beam_fx).
		_melee_hit(target, dmg)
		spawn_bolt(from_pos, tp, 0.0, self, true, key)
		if NetworkManager.is_multiplayer_active:
			NetworkManager.broadcast_world_event_copy_bolt.rpc(from_pos, tp, key)
		return
	var speed: float = float(info.get("speed", BOLT_SPEED))
	var t_flight: float = from_pos.distance_to(tp) / maxf(speed, 1.0)
	var aim: Vector2 = tp + _target_vel * t_flight * AIM_LEAD
	var dir: Vector2 = (aim - from_pos).normalized() if aim.distance_to(from_pos) > 1.0 else Vector2.RIGHT
	var end_pos: Vector2 = from_pos + dir * (from_pos.distance_to(aim) + 140.0)
	spawn_bolt(from_pos, end_pos, dmg, self, false, key)
	## Mermi SADECE host'ta gerçek (hasar veren) - diğer istemciler aynı atışın hasarsız kozmetik kopyasını görsün
	## (bkz. CLAUDE.md "kaster görür, diğerleri görmez" sınıfı). Silah anahtarı da gider ki istemci AYNI mermi görselini
	## çizsin (anahtardan attack_info ile türetilir - ikinci bir yol/yol dizgisi yazılmaz).
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_copy_bolt.rpc(from_pos, end_pos, key)


## Silah anahtarından saldırı görseli (host VE istemci aynı fonksiyonu kullanır): {"proj": mermi sahnesi | null, "speed": px/sn,
## "scale": ölçek çarpanı, "rot": dönüş ofseti, "beam": ışın sahnesi | null}. Silah sahnesi AĞACA EKLENMEDEN örneklenir
## (weapon.gd _ready çalışmaz). Anahtar başına bir kez hesaplanır. Bilinmeyen anahtar -> boş sözlük (eski mor mermi).
static var _attack_info_cache: Dictionary = {}


static func attack_info(key: String) -> Dictionary:
	if _attack_info_cache.has(key):
		return _attack_info_cache[key]
	var info: Dictionary = {}
	var scene: PackedScene = RemotePlayerScript.WEAPON_SCENES.get(key)
	if scene != null:
		var root: Node = scene.instantiate()
		info = {"proj": null, "speed": BOLT_SPEED, "scale": 1.0, "rot": 0.0, "beam": null}
		var ps: Variant = root.get("projectile_scene") if "projectile_scene" in root else null
		if ps is PackedScene:
			info["proj"] = ps
			var p: Node = (ps as PackedScene).instantiate()
			if "speed" in p and float(p.get("speed")) > 0.0:
				info["speed"] = float(p.get("speed"))
			## İsabet efekti + sesi (projectile.gd _spawn_impact / _play_impact_sound ile aynı veri): kopyanın mermisi de oyuncununki gibi patlasın.
			var imp: Variant = p.get("impact_scene") if "impact_scene" in p else null
			var imp_sounds: Variant = p.get("impact_sounds") if "impact_sounds" in p else null
			if imp is PackedScene or (imp_sounds is Array and not (imp_sounds as Array).is_empty()):
				info["impact"] = {"scene": imp if imp is PackedScene else null,
					"scale": float(p.get("impact_scale")) if "impact_scale" in p else 1.0,
					"offset": Vector2(p.get("impact_offset")) if "impact_offset" in p else Vector2.ZERO,
					"face": bool(p.get("impact_face_direction")) if "impact_face_direction" in p else false,
					"max_alive": int(p.get("impact_max_alive")) if "impact_max_alive" in p else 0,
					"sounds": (imp_sounds as Array) if imp_sounds is Array else [],
					"db": float(p.get("impact_sound_volume_db")) if "impact_sound_volume_db" in p else -8.79}
			p.free()
			if "ranged_projectile_scale_mult" in root:
				info["scale"] = float(root.get("ranged_projectile_scale_mult"))
			if "ranged_projectile_rotation_offset" in root:
				info["rot"] = float(root.get("ranged_projectile_rotation_offset"))
		var bs: Variant = root.get("beam_scene") if "beam_scene" in root else null
		if bs is PackedScene:
			info["beam"] = bs
		root.free()
	_attack_info_cache[key] = info
	return info


## key verilirse silahın kendi mermisi/ışını (bkz. attack_info), yoksa eski mor mermi. Işın silahında hasar burada değil
## çağıranda (anlık) uygulanır; bu yalnız görseli çizer.
static func spawn_bolt(from_pos: Vector2, to_pos: Vector2, damage: float, source: Node2D, cosmetic: bool, key: String = "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var info: Dictionary = attack_info(key) if key != "" else {}
	if info.get("beam") != null:
		_spawn_beam_fx(info["beam"] as PackedScene, from_pos, to_pos)
		return
	var visual: Dictionary = {}
	if info.get("proj") != null:
		visual = {"proj": info["proj"], "speed": info["speed"], "scale": info["scale"], "rot": info["rot"], "impact": info.get("impact", {})}
	var bolt := Node2D.new()
	bolt.set_script(BoltScript)
	## setup, add_child'dan ÖNCE: bolt _ready'de görselini `visual`dan kurar (add_child sonrası setup çok geç kalırdı).
	bolt.call("setup", from_pos, to_pos, damage, source, cosmetic, visual)
	tree.current_scene.add_child(bolt)
	bolt.global_position = from_pos


## Şimşek Asası ışını: namludan hedefe kısa süre görünür (fx_lightning_beam.gd, uzak oyuncuların kullandığı AYNI ağ kipi).
const BEAM_FX_SECONDS := 0.45


static func _spawn_beam_fx(scene: PackedScene, from_pos: Vector2, to_pos: Vector2) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var fx: Node2D = scene.instantiate() as Node2D
	if fx == null:
		return
	tree.current_scene.add_child(fx)
	if fx.has_method("setup_network"):
		fx.call("setup_network", to_pos, {"from_pos": from_pos})
	tree.create_timer(BEAM_FX_SECONDS).timeout.connect(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free())


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


## Enemy.gd ile AYNI imza (bkz. dosya başı not) - gerçek oyuncu silahları/yetenekleri bunu çağırır. Hasar önce kalkandan düşer.
## Vuran tarafın işleri (enemy.gd take_damage ile aynı sıra) BU makinenin yerel oyuncusu için burada yapılır: hasar sayısı, maç
## istatistiği, balans kaydı, can çalma. Hasar uygulamak ise host'ta (_apply_hit); istemcideki kozmetik kopya miktarı host'a iletir.
func take_damage(amount: float, is_crit: bool = false, _shield_pen_percent: float = 0.0, is_area: bool = false) -> void:
	var bl_src: String = BalanceLogScript.take_src() ## balans etiketi erken dönüşte de silinsin
	if is_dead:
		return
	_credit_local_dealer(amount * (1.0 - resist_now()), is_crit, is_area, bl_src)
	## DÜZELTME (kullanıcı bildirimi 2026-09-24: görevler çok oyunculuda da çalışmalı) - host olmayan bir
	## istemcinin silahı SADECE bu kozmetik kopyaya vuruyordu ve hasar burada sessizce yok oluyordu (kopya
	## hiç ölmüyordu). Artık hasar host'taki GERÇEK kopyaya iletiliyor.
	if not _is_host_simulated:
		if NetworkManager.is_multiplayer_active:
			NetworkManager.request_world_event_copy_damage.rpc_id(NetworkManager._host_peer_id(), mission_id, copy_index, amount)
		return
	_apply_hit(amount)


## Kopyaya gerçekten hasar işler (SADECE host'ta): direnç düşer, kalkan/can azalır, ölürse biter. Uzaktan gelen hasar da buradan geçer
## (vuran istemci sayısını/istatistiğini kendi makinesinde zaten yaptı, bkz. take_damage).
func _apply_hit(amount: float) -> void:
	if is_dead:
		return
	var dmg: float = amount * (1.0 - resist_now())
	_no_damage_timer = 0.0
	if shield > 0.0:
		var absorbed: float = minf(shield, dmg * SHIELD_ABSORB_RATIO)
		shield -= absorbed
		dmg -= absorbed
	health = max(0.0, health - dmg)
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)
	if health <= 0.0:
		_die()


## Yerel oyuncu bu kopyaya vurdu: enemy.gd take_damage'ın vuran tarafı (maç hasar istatistiği, balans kaydı, can çalma/Vampir) + hasar
## sayısı. Sayı yalnız vuranın ekranında çıkar (kullanıcı isteği 2026-09-25) - her makine kendi vuruşunu kendisi gösterir.
func _credit_local_dealer(shown: float, is_crit: bool, is_area: bool, bl_src: String) -> void:
	if shown <= 0.0:
		return
	var dealer: Node = get_tree().get_first_node_in_group("player")
	if dealer:
		if "match_damage_dealt" in dealer:
			dealer.match_damage_dealt += shown
			BalanceLogScript.on_hit(bl_src, shown, is_crit)
		if dealer.has_method("on_dealer_hit"):
			dealer.on_dealer_hit(shown, is_area)
	_spawn_damage_number(shown, is_crit)


const DMG_SPAWN_OFFSET := Vector2(0, -36)
const DMG_SCATTER := Vector2(22, 14)
const DMG_MAX_LIVE := 5
var _dmg_ids: Array[int] = []


## Yaratıklarla aynı toplu sayı sistemi (damage_numbers.gd, enemy.gd _spawn_floating_text ile aynı görünüm).
func _spawn_damage_number(amount: float, is_crit: bool) -> void:
	var dn = DamageNumbersScript.get_instance(get_tree())
	if dn == null:
		return
	var alive: Array[int] = []
	for id in _dmg_ids:
		if dn.is_alive(id):
			alive.append(id)
	while alive.size() >= DMG_MAX_LIVE:
		dn.remove(alive.pop_front())
	var jitter := Vector2(randf_range(-DMG_SCATTER.x, DMG_SCATTER.x), randf_range(-DMG_SCATTER.y, DMG_SCATTER.y))
	var color: Color = Color(1.0, 0.25, 0.2) if is_crit else Color(1.0, 1.0, 1.0)
	alive.append(dn.spawn_fixed(self, global_position + DMG_SPAWN_OFFSET + jitter, "%d" % maxi(1, int(round(amount))), color))
	_dmg_ids = alive


## ------------------------------------------------------------------ SİLAH ÖZELLİKLERİ (ELEMENT) GİRİŞİ
## 2026-10-11 (kullanıcı: "silah özellikleri bazı yaratıklara işlemiyor, mesela kopyanı öldür görevinde alev asasının püskürtmesi
## çalışmıyor"): silah özellikleri (scripts/weapon_traits/) yaratıklara enemy.gd apply_element ile element/durum uygular; kopyada bu
## yoktu ve özellik kodu kopyayı "düşman değil" sayıp hiç vurmuyordu. Kopyanın kendi sade element sistemi:
##  - yanma / zehir / kanama: saniyede bir hasar (yığınlı, süreli; kanama yaratıklardaki gibi ölene kadar), take_damage yolundan
##    (istemcide host'a iletilir)
##  - donma / sersemletme: süre boyunca yürüyemez ve saldıramaz; yavaşlatma: hız düşer; itme: apply_knockback_distance
##  - diğerleri (işaret, şok, öldürme izi...) kopyada etkisiz. Kontrol etkileri sadece host'ta (kopyayı host simüle eder).
const ELEMENT_DOT_TICK := 1.0
const BLEED_FOREVER := 9999.0
var _dots: Dictionary = {} ## "burn"/"poison"/"bleed" -> {"per": hasar/sn/yığın, "stacks": int, "until": msec}
var _dot_timer: float = ELEMENT_DOT_TICK
var _stun_until_msec: int = 0
var _frozen_until_msec: int = 0
var _slow_pct: float = 0.0
var _slow_until_msec: int = 0


func apply_element(kind: String, p: Dictionary) -> void:
	if is_dead:
		return
	var now: int = Time.get_ticks_msec()
	match kind:
		"burn":
			_add_dot("burn", float(p.get("tick", 1.0)), 1, maxi(1, int(p.get("max_stacks", 1))), float(p.get("dur", 3.0)), now)
		"poison":
			_add_dot("poison", float(p.get("dps", 1.0)), clampi(int(p.get("stacks", 1)), 1, 50), 50, float(p.get("dur", 10.0)), now)
		"bleed":
			_add_dot("bleed", float(p.get("tick", 1.0)), maxi(1, int(p.get("stacks", 1))), maxi(1, int(p.get("cap", 10))), BLEED_FOREVER, now)
		"freeze":
			_frozen_until_msec = maxi(_frozen_until_msec, now + int(float(p.get("dur", 1.5)) * 1000.0))
		"stun":
			_stun_until_msec = maxi(_stun_until_msec, now + int(float(p.get("dur", 0.5)) * 1000.0))
		"slow":
			_slow_pct = clampf(float(p.get("pct", 0.3)), 0.0, 0.9)
			_slow_until_msec = now + int(float(p.get("dur", 1.5)) * 1000.0)
		"knock":
			apply_knockback_distance(Vector2(p.get("dir", Vector2.RIGHT)), float(p.get("dist", 0.0)))


func _add_dot(kind: String, per: float, add: int, cap: int, dur: float, now: int) -> void:
	var d: Dictionary = _dots.get(kind, {"per": per, "stacks": 0, "until": 0})
	if int(d["until"]) < now:
		d["stacks"] = 0
	d["per"] = maxf(float(d["per"]), per)
	d["stacks"] = mini(cap, int(d["stacks"]) + add)
	d["until"] = maxi(int(d["until"]), now + int(dur * 1000.0))
	_dots[kind] = d


func _process_dots(delta: float) -> void:
	if _dots.is_empty():
		return
	_dot_timer -= delta
	if _dot_timer > 0.0:
		return
	_dot_timer = ELEMENT_DOT_TICK
	var now: int = Time.get_ticks_msec()
	var total: float = 0.0
	for kind in _dots.keys():
		var d: Dictionary = _dots[kind]
		if int(d["until"]) < now:
			_dots.erase(kind)
			continue
		total += float(d["per"]) * int(d["stacks"])
	if total > 0.0:
		take_damage(total, false, 0.0, true)


func _is_disabled_now() -> bool:
	var now: int = Time.get_ticks_msec()
	return now < _stun_until_msec or now < _frozen_until_msec


## Silah özelliklerinin durum sorguları (enchant_behavior.gd status) - yaratıklarla aynı adlar.
func is_burning() -> bool:
	return _dots.has("burn") and int(_dots["burn"]["until"]) >= Time.get_ticks_msec()


func is_poisoned() -> bool:
	return _dots.has("poison") and int(_dots["poison"]["until"]) >= Time.get_ticks_msec()


func is_frozen_now() -> bool:
	return Time.get_ticks_msec() < _frozen_until_msec


## ------------------------------------------------------------------ YARATIK API UYUMU
## 2026-10-12 (kullanıcı: "kopyalar yaratık gibi algılanmıyor, çok yeteneğimiz onlara işlemiyor"): yetenekler/evrimler/eşyalar hedefe
## `e.has_method("apply_burn")`, `apply_slow`, `apply_stun`, `apply_chill`... diye bakıp yoksa SESSİZCE atlıyordu; kopyada yalnızca
## take_damage/apply_element/itme vardı. Aşağıdaki işlevler enemy.gd ile AYNI imzayla, hepsi kopyanın kendi sade element sistemine
## (apply_element) yönlenir. Kopya boss gibi sayılır (is_boss): korku/çekme gibi yer değiştiren-yönlendiren etkiler bilerek etkisiz.
var mark_stacks: int = 0 ## enemy.gd ile aynı ad: element_reactions.gd doğrudan okur
var _mark_until_msec: int = 0


func apply_burn(tick_damage: float, duration: float) -> void:
	apply_element("burn", {"tick": tick_damage, "dur": duration})


func apply_poison(dps_per_stack: float, max_stacks: float, duration: float) -> void:
	apply_element("poison", {"dps": dps_per_stack, "dur": duration, "stacks": 1})


func apply_bee_poison(tick_damage_per_stack: float) -> void:
	apply_element("poison", {"dps": tick_damage_per_stack, "dur": 5.0, "stacks": 1})


func apply_bleed(tick_damage_per_stack: float, stacks_to_add: int, max_stacks: int) -> void:
	apply_element("bleed", {"tick": tick_damage_per_stack, "stacks": stacks_to_add, "cap": max_stacks})


func apply_slow(percent: float, duration: float, _allow_boss: bool = false) -> void:
	apply_element("slow", {"pct": minf(percent, 0.8), "dur": duration})


func apply_frost_slow(percent: float, duration: float) -> void:
	apply_element("slow", {"pct": minf(percent, 0.8), "dur": duration})


func apply_chill(_stacks_to_add: int) -> void:
	apply_element("slow", {"pct": 0.15, "dur": Enemy.CHILL_DURATION})


func apply_stun(duration: float) -> void:
	apply_element("stun", {"dur": duration})


func apply_freeze_full(duration: float, _allow_boss: bool = false) -> void:
	apply_element("freeze", {"dur": duration})


## Cadı'nın Delilik İksiri: kopyalar delirmez (elit sayılır) - API eşliği için boş (bkz. enemy.gd apply_madness).
func apply_madness(_duration: float) -> void:
	pass


func apply_root(duration: float) -> void:
	apply_element("slow", {"pct": 0.9, "dur": duration})


func apply_skill_push(dir: Vector2, distance: float) -> void:
	apply_knockback_distance(dir, distance)


func apply_element_host(kind: String, p: Dictionary, _attacker_peer: int) -> void:
	apply_element(kind, p)


## Boss gibi: korkutma / kışkırtma kopyanın hedef seçimini bozmaz (çağrı sorunsuz geçer, etkisiz).
func apply_fear(_source_pos: Vector2, _duration: float = 0.0) -> void:
	pass


func apply_fear_wander(_duration: float, _affect_boss: bool = false) -> void:
	pass


func apply_taunt(_duration: float, _taunter: Node2D = null) -> void:
	pass


func set_ability_invisible(_on: bool) -> void:
	pass


func is_shocked() -> bool:
	return false


## İşaret (Tabanca pasifi vb.): yükler 20 sn durur, her yük %1 ek hasar (enemy.gd ile aynı sabitler).
func apply_mark_stack(max_stacks: int) -> void:
	if is_dead:
		return
	if Time.get_ticks_msec() > _mark_until_msec:
		mark_stacks = 0
	mark_stacks = mini(mark_stacks + Enemy.MARK_STACKS_PER_HIT, max_stacks)
	_mark_until_msec = Time.get_ticks_msec() + int(Enemy.MARK_DURATION * 1000.0)


func get_mark_damage_mult() -> float:
	if Time.get_ticks_msec() > _mark_until_msec:
		mark_stacks = 0
	return 1.0 + mark_stacks * Enemy.MARK_PERCENT_PER_STACK


## Şaman totemi içindeki hedefe silah vuruşunda yanma (enemy.gd ile aynı kural).
func try_shaman_weapon_burn() -> bool:
	var dealer: Node = get_tree().get_first_node_in_group("player")
	if not (dealer and "damage_bonus" in dealer and dealer is Node2D):
		return false
	for totem in get_tree().get_nodes_in_group("shaman_totems"):
		if not is_instance_valid(totem) or not (totem is Node2D):
			continue
		var totem_r: float = float(totem.get("totem_radius")) if "totem_radius" in totem else 0.0
		if totem_r > 0.0 and (totem as Node2D).global_position.distance_to((dealer as Node2D).global_position) <= totem_r:
			apply_burn(float(dealer.damage_bonus) * 0.10, 3.0)
			return true
	return false


func take_damage_host(amount: float, _is_crit: bool, _shield_pen_percent: float, _attacker_id: int = 0) -> void:
	_apply_hit(amount) ## host'ta, başka bir oyuncunun vuruşu - vuran tarafın işleri (sayı/istatistik) onun makinesinde yapılır


func get_overhead_bar_offset() -> float:
	return -30.0


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


## BUG DÜZELTMESİ (kullanıcı bildirimi 2026-09-25: "İtme gücü kopyalara daha etkili çalışıyor bunu düzelt") - kök neden:
## kopyada apply_knockback_* YOKTU; weapon.gd/projectile.gd bu durumda son çare olarak hedefi itiş MESAFESİNİN TAMAMI
## kadar (400 px'e kadar) anında ışınlıyordu. Yaratıklarda ise aynı değer %20'ye ölçeklenip (KNOCKBACK_DISTANCE_MULT),
## 60 px tavanla, art arda vuruşlarda küçülerek (REPEAT) yumuşak, sönümlenen bir hıza çevriliyor. Artık kopya birebir aynı
## formülü ve sabitleri kullanıyor (TEK kaynak: enemy.gd). İstemcinin vuruşu host'taki gerçek kopyaya iletilir.
var _knockback_velocity: Vector2 = Vector2.ZERO
var _last_knockback_msec: int = -100000

func apply_knockback_distance(dir: Vector2, distance: float) -> void:
	if distance <= 0.0 or is_dead:
		return
	if not _is_host_simulated:
		if NetworkManager.is_multiplayer_active:
			NetworkManager.request_world_event_copy_knockback.rpc_id(NetworkManager._host_peer_id(), mission_id, copy_index, dir, distance)
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var now_msec: int = Time.get_ticks_msec()
	var repeat_mult: float = Enemy.KNOCKBACK_REPEAT_MULT if (now_msec - _last_knockback_msec) < int(Enemy.KNOCKBACK_REPEAT_WINDOW * 1000.0) else 1.0
	_last_knockback_msec = now_msec
	var v0: float = sqrt(2.0 * Enemy.KNOCKBACK_DECAY * minf(distance * Enemy.KNOCKBACK_DISTANCE_MULT * repeat_mult, Enemy.KNOCKBACK_DISTANCE_MAX))
	var along: float = _knockback_velocity.dot(d)
	if along < v0:
		_knockback_velocity += d * (v0 - maxf(along, 0.0))


## Hız cinsinden itiş (gövde itmesi vb.) - yaratıklardaki apply_knockback_force ile aynı tavan.
func apply_knockback_force(dir: Vector2, force: float) -> void:
	if force <= 0.0 or is_dead or not _is_host_simulated:
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_knockback_velocity += d * force
	if _knockback_velocity.length() > Enemy.KNOCKBACK_MAX_SPEED:
		_knockback_velocity = _knockback_velocity.normalized() * Enemy.KNOCKBACK_MAX_SPEED


func _on_remote_knockback(mid: int, idx: int, dir: Vector2, distance: float) -> void:
	if not _is_host_simulated or mid != mission_id or idx != copy_index:
		return
	apply_knockback_distance(dir, distance)


## Host'ta: bir istemcinin kozmetik kopyaya verdiği hasar (bkz. take_damage) gerçek kopyaya uygulanır.
func _on_remote_damage(mid: int, idx: int, amount: float) -> void:
	if not _is_host_simulated or mid != mission_id or idx != copy_index:
		return
	_apply_hit(amount)


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
