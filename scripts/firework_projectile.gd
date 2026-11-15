extends Node2D

## DİNAMİT (madde 651, 2026-11-13; eski adıyla Fişek - anahtar `fisek`, sahne/betik adları AYNI: kayıt/ağ/efsun uyumu).
## Kullanıcı: "oyundaki fişeği bununla değiştir ancak fişek artık dinamit olduğu için yukarı çıkıp uçmucak fırlatılıp
## patlıcak, ayrıca ucundaki ipte de efekt olmalı."
## - Görünüş: kullanıcının 32x32 dinamit çizimi (assets/weapons/yeni/dinamit.png = WeaponTierArt ART["fisek"]), kafadaki
##   ikonla AYNI piksel boyunda (ART_WORLD_PX).
## - Uçuş: eski "yukarı fırlayıp hedefin üstüne çakılan roket" (Bezier, burun teğete dönük) YOK. Dinamit hedefin ateş anındaki
##   SABİT noktasına alçak bir kavisle FIRLATILIR (yatayda sabit hız, yükseklik parabol), havada takla atar (gövde döner),
##   yere düşünce kısa bir sekip fitil son kez cızırdar, sonra patlar. Yerde altında, yükseldikçe küçülen bir gölge.
## - Fitil: ucunda Korsan bombasıyla AYNI tasarım kıvılcım (nefes alan hale + titreyen çekirdek + uçuşan korlar,
##   tools/gen_dinamit_fitil.py -> assets/fx/dinamit/fuse_*). Kıvılcım ayrı düğüm: fitil ucunu izler ama DÖNMEZ (korlar hep
##   aşağı düşer). Arkasında düşen kıvılcım izi (fx_particle_trail "fisek_kivilcim"); roketin duman izi kalktı.
## - Kural (değişmedi): yolda kimseye çarpmaz; inince ANINDA splash_radius içine alan hasarı. Uzak oyuncudaki kopya AYNI
##   sahne/betik (network_manager.gd broadcast_projectile, network_spawned): aynı başlangıç/hedeften aynı yörünge, hasarsız.

## Hava süresi (sn) - TABAN atış mesafesinde (REF_DIST); yakına daha kısa, uzağa biraz daha uzun (DIST_MIN..MAX çarpanı).
## Efsun hız çarpanı bunu böler (enchant_behavior.gd "flight_duration").
@export var flight_duration: float = 0.62
const REF_DIST := 180.0
const DIST_MULT_MIN := 0.7
const DIST_MULT_MAX := 1.3
## Kavis tepesi (dünya px): mesafeyle orantılı, sınırlı - "yukarı uçma" değil, el ile atış.
const ARC_PER_DIST := 0.24
const ARC_MIN := 16.0
const ARC_MAX := 52.0
## Takla hızı (rad/sn; yönü atış yönüne göre) ve yere düşünce sekme + son cızırtı.
const SPIN_SPEED := 13.0
const LAND_HOLD := 0.2
const BOUNCE_HEIGHT := 4.0
## Yerde yatış açısı: çizimin gövde ekseni -48,8 derece (sol-alt -> sağ-üst); +48,8 döndürünce yatay yatar.
const REST_ANGLE := 0.852

## 2026-10-10 (kullanıcı: "havai fişeğin patlama alanını %20 arttır"): 66 -> 79,2. Patlama efekti de aynı oranda büyür
## (_spawn_impact: FX_BASE_RADIUS'a göre ölçek). Ayrıntılı geçmiş: docs/notlar (fişek dengesi).
@export var splash_radius: float = 79.2
const FX_BASE_RADIUS := 66.0 ## fx_hit_big_burst.tscn bu yarıçapa göre boyutlu
@export var impact_scene: PackedScene
@export var impact_sounds: Array[AudioStream] = []
@export var impact_sound_volume_db: float = -8.79

var damage: float = 10.0
var is_crit: bool = false
## Efsun (bkz. weapon.gd enchant_on_projectile_hit / enchant_on_explode).
var source_weapon: Node = null
var shield_pen_percent: float = 0.0
## weapon.gd _fire_at() bunu ateş yönüne göre doldurur - target_position henüz (0,0) ise (güvenlik) iniş noktası tahmini.
var direction: Vector2 = Vector2.RIGHT
## weapon.gd _fire_at() bunu hedefin ateş anındaki SABİT konumuna ayarlar - dinamit hep bu noktaya düşer.
var target_position: Vector2 = Vector2.ZERO
## Kafanın üstündeki ikonu havadayken gizleyip patlayınca tekrar gösteren silaha geri bildirim (weapon.gd
## hide_icon_while_projectile_flying / _on_ranged_projectile_landed).
var return_callback_target: Node = null

const WeaponTierArtScript := preload("res://scripts/weapon_tier_art.gd")
## Dinamit pikseli (dünya px) = kafadaki ikonun pikseli (weapon_tier_art.gd WORLD_PX x SIZE_MULT["fisek"]).
const ART_WORLD_PX := WeaponTierArtScript.WORLD_PX * 1.3
## Fitil ucu, çizimin dokusunda (32x32, merkeze göre): kıvrılan ipin serbest ucu (27,3) pikselinin ortası.
const FUSE_TIP_TEX := Vector2(11.5, -12.5)
## Kıvılcım sayfasında (gen_dinamit_fitil.py) fitil ucu kare merkezinin 2 px altında.
const FUSE_SHEET_OFFSET := Vector2(0.0, -2.0)
const FUSE_FRAMES := preload("res://assets/fx/dinamit/fuse_frames.tres")
## Gölge (sanat pikseli): Korsan bombası gibi sert kenarlı iki tonlu elips, yükseldikçe küçülür.
const SHADOW_RX := 7.0
const SHADOW_RY := 2.2

const ParticleTrail := preload("res://scripts/fx_particle_trail.gd")
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

var _launch_position: Vector2
var _duration: float = 0.62
var _arc: float = 30.0
var _spin_dir: float = 1.0
var _elapsed: float = 0.0
var _land_elapsed: float = 0.0
var _landed: bool = false
var _height: float = 0.0
var _trajectory_ready: bool = false
var _done: bool = false

@onready var launch_sound: AudioStreamPlayer2D = get_node_or_null("LaunchSound")
@onready var icon: Sprite2D = get_node_or_null("Icon")
@onready var fuse: AnimatedSprite2D = get_node_or_null("Fuse")


func _ready() -> void:
	if fuse:
		fuse.sprite_frames = FUSE_FRAMES
		fuse.offset = FUSE_SHEET_OFFSET
		fuse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fuse.play(&"loop")
	ParticleTrail.attach(self, "fisek_kivilcim")


## Kök ölçeği (weapon.gd _fire_at: karakter ölçeği 0,5; uzak kopyada proj_scale) ateşten SONRA atanır -> sanat ölçeği her
## karede kök ölçeğine göre (dünya pikseli hep ART_WORLD_PX).
func _art_local_scale() -> float:
	return ART_WORLD_PX / maxf(0.01, absf(scale.x))


## weapon.gd _fire_at() önce add_child() çağırıp SONRA global_position/direction/target_position atıyor - yörünge ilk
## _process'te kurulur (o noktada atamalar tamam).
func _init_trajectory() -> void:
	_trajectory_ready = true
	_launch_position = global_position
	if target_position == Vector2.ZERO:
		target_position = global_position + direction * REF_DIST
	var dist: float = _launch_position.distance_to(target_position)
	_duration = maxf(0.05, flight_duration) * clampf(dist / REF_DIST, DIST_MULT_MIN, DIST_MULT_MAX)
	_arc = clampf(dist * ARC_PER_DIST, ARC_MIN, ARC_MAX)
	var dx: float = target_position.x - _launch_position.x
	_spin_dir = 1.0 if dx >= 0.0 else -1.0
	if launch_sound:
		launch_sound.play()


## Saf yörünge (test + iki istemcide aynı): t 0..1 -> [yerdeki nokta, yükseklik].
static func throw_ground_point(from: Vector2, to: Vector2, t: float) -> Vector2:
	return from.lerp(to, clampf(t, 0.0, 1.0))


static func throw_height(arc: float, t: float) -> float:
	var k: float = clampf(t, 0.0, 1.0)
	return 4.0 * arc * k * (1.0 - k)


func _process(delta: float) -> void:
	if not _trajectory_ready:
		_init_trajectory()
	if _done:
		return
	var art_scale: float = _art_local_scale()
	if icon:
		icon.scale = Vector2.ONE * art_scale
	if fuse:
		fuse.scale = Vector2.ONE * art_scale
	if not _landed:
		_elapsed += delta
		var t: float = clampf(_elapsed / _duration, 0.0, 1.0)
		_height = throw_height(_arc, t)
		global_position = throw_ground_point(_launch_position, target_position, t) + Vector2(0.0, -_height)
		if icon:
			icon.rotation += SPIN_SPEED * _spin_dir * delta
		if t >= 1.0:
			_landed = true
			if fuse:
				fuse.speed_scale = 2.0 ## son cızırtı
	else:
		_land_elapsed += delta
		var k: float = clampf(_land_elapsed / LAND_HOLD, 0.0, 1.0)
		_height = sin(minf(1.0, k * 2.0) * PI) * BOUNCE_HEIGHT
		global_position = target_position + Vector2(0.0, -_height)
		if icon:
			icon.rotation = lerp_angle(icon.rotation, _rest_angle(icon.rotation), minf(1.0, delta * 25.0))
			## patlamadan hemen önce titrer
			icon.position = Vector2((randf() - 0.5) * 1.2, 0.0) * k
		if k >= 1.0:
			global_position = target_position
			_explode()
			return
	if fuse and icon:
		fuse.position = icon.transform * FUSE_TIP_TEX
	queue_redraw()


## Yatışın iki yönünden (ip sağda / solda) dönüşe en yakını.
func _rest_angle(cur: float) -> float:
	var a: float = REST_ANGLE
	var b: float = REST_ANGLE + PI
	return a if absf(angle_difference(cur, a)) <= absf(angle_difference(cur, b)) else b


## Gölge: kök yerel uzayında, gövdenin _height kadar altında (yer), sanat pikseli ızgarasında.
func _draw() -> void:
	if _done or not _trajectory_ready:
		return
	var px: float = _art_local_scale()
	var ground_y: float = _height / maxf(0.01, absf(scale.y))
	var shrink: float = 1.0 - minf(0.45, _height / ART_WORLD_PX / 60.0)
	var rx: float = SHADOW_RX * shrink
	var ry: float = SHADOW_RY * shrink
	for dy in range(-3, 3):
		var yy: float = dy + 0.5
		if absf(yy) > ry:
			continue
		var half: float = rx * sqrt(maxf(0.0, 1.0 - (yy / ry) * (yy / ry)))
		var w: int = int(round(half))
		if w <= 0:
			continue
		var inner: bool = absf(yy) <= ry * 0.62
		draw_rect(Rect2(Vector2(-w, dy) * px + Vector2(0.0, ground_y), Vector2(w * 2, 1) * px), Color(0, 0, 0, 0.24))
		if inner:
			var wi: int = int(round(half * 0.62))
			if wi > 0:
				draw_rect(Rect2(Vector2(-wi, dy) * px + Vector2(0.0, ground_y), Vector2(wi * 2, 1) * px), Color(0, 0, 0, 0.14))


func _explode() -> void:
	_done = true
	queue_redraw()
	## Ağ üzerinden spawnlanan görsel kopyalar hasar vermez — sadece darbe efektini ve sesini oynatır.
	if get_meta("network_spawned", false):
		_spawn_impact()
		_play_impact_sound()
		queue_free()
		return
	## Şaman pasifi (Totem Auraları): bu patlama TEK bir "saldırı" sayılır - yakma EN FAZLA 1 düşmanda tetiklenebilir (bkz.
	## enemy.gd try_shaman_weapon_burn() üstündeki kök neden notu).
	var _shaman_burn_applied: bool = false
	## FPS (2026-10-18): tüm "enemies" grubu yerine patlama merkezinin çevresindeki adaylar (C++ ızgara sorgusu).
	for e in EnemyQueryScript.candidates(get_tree(), global_position, splash_radius):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not e.has_method("take_damage"):
			continue
		if global_position.distance_to(e.global_position) <= splash_radius:
			BalanceLogScript.tag(&"w:fisek")
			e.take_damage(damage, is_crit, shield_pen_percent, true) ## patlama alanı
			if is_instance_valid(source_weapon) and source_weapon.has_method("enchant_on_projectile_hit"):
				source_weapon.enchant_on_projectile_hit(self, e, damage, true)
			if not _shaman_burn_applied and e.has_method("try_shaman_weapon_burn"):
				_shaman_burn_applied = e.try_shaman_weapon_burn()
	if is_instance_valid(source_weapon) and source_weapon.has_method("enchant_on_explode"):
		source_weapon.enchant_on_explode(self, global_position)
	_spawn_impact()
	_play_impact_sound()
	if is_instance_valid(return_callback_target) and return_callback_target.has_method("_on_ranged_projectile_landed"):
		return_callback_target._on_ranged_projectile_landed()
	queue_free()


func _spawn_impact() -> void:
	if not impact_scene:
		return
	var fx = impact_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	if fx is Node2D and splash_radius > 0.0:
		(fx as Node2D).scale *= splash_radius / FX_BASE_RADIUS


func _play_impact_sound() -> void:
	if impact_sounds.is_empty():
		return
	var s := AudioStreamPlayer2D.new()
	s.stream = impact_sounds[randi() % impact_sounds.size()]
	s.volume_db = impact_sound_volume_db
	s.pitch_scale = randf_range(0.92, 1.08)
	s.max_distance = 1500.0
	s.global_position = global_position
	get_tree().current_scene.add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
