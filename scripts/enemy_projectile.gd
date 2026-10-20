extends Node2D

const PaladinDome := preload("res://scripts/paladin_dome.gd") ## Şovalye kubbesi alanı (elips)
const PhysicsInterp := preload("res://scripts/physics_interp.gd")

## Mirror of scripts/projectile.gd (the player's shot) but for ranged enemies
## (Demon/Lich/Röntgen/İblis, see enemy.gd's is_ranged) - flies toward the
## player and calls their take_damage() instead of an enemy's.
##
## PERF DÜZELTMESİ (kullanıcı isteği: "ileri kademede uzağa ateş eden yaratıkların optimizasyonlarını kontrol eder
## misin" - iki pencereli gerçek multiplayer testinde ölçüldü): 200 menzilli Demon'da host 12 ms'den 31 ms'ye, istemci
## 6.5 ms'den 13 ms'ye çıkıyordu; mermiler her karede silinince fark tamamen kayboluyordu. Mermi script'i tek başına
## ucuzdu (~4.5 us/adım) - maliyet saniyede ~100 mermi doğup ölürken her birinin taşıdığı motor yükündeydi: fizik
## sunucusunda Area2D nesnesi yaratma/silme + her adımda broadphase'te taşıma, mermi başına SceneTreeTimer, her adımda
## get_nodes_in_group("remote_players") dizi kopyası, pürüzsüz (anti-aliased) daire çizimi ve isabet başına yumuşak
## halka FX'i. Artık:
##   - kök düğüm Area2D DEĞİL, düz Node2D: fizik sunucusunda hiçbir nesnesi yok. İsabet, eski Area2D'nin BİREBİR
##     aynı kuralıyla (collision_mask 2 = oyuncu katmanı, daire-daire örtüşmesi, devre dışı şekil sayılmaz) ama
##     fizik karesi başına BİR kez önbelleğe alınan hedef listesine karşı mesafeyle kontrol ediliyor. Adım başına
##     208 px/sn * 1/60 = 3.5 px ilerler, en küçük isabet mesafesi ~8 + 10 px - içinden geçip ıskalama olmaz.
##   - ömür SceneTreeTimer yerine kendi sayacı; Şovalye kalkanı listesi de karede bir kez hesaplanıyor.
##   - görsel ve çarpma efekti piksel tarzı (fx_projectile_orb.gd / fx_enemy_bolt_impact.gd).

const HIT_RADIUS := 8.0 ## eski CircleShape2D yarıçapı
const TARGET_LAYER_MASK := 2 ## eski Area2D collision_mask (main.tscn Player / remote_player.tscn katmanı)
const ProjectileRangeScript := preload("res://scripts/projectile_range.gd") ## menzil = görüş elipsi (bkz. projectile_range.gd)
const LIFETIME := 3.0
const ImpactScript: GDScript = preload("res://scripts/fx_enemy_bolt_impact.gd")
## Lich "Ruh Alevi" (madde 280): stil > 0 iken küre yerine pişmiş alev sprite'ı + kor katmanı + kendi isabeti.
const LichFlame := preload("res://scripts/lich_soul_flame.gd")
const LichImpactScript: GDScript = preload("res://scripts/fx_lich_flame_impact.gd")
const LichEmberLayerScript: GDScript = preload("res://scripts/lich_ember_layer.gd")
## Kor aralığı (dünya px, uçulan yol; her seferinde x0,6-1,4 düzensiz - düzenli aralık yolda noktalı çizgi bırakıyordu, madde 199).
const EMBER_EVERY := 13.0
const EMBER_EVERY_SMALL := 30.0
## Kullanıcı bildirimi (2026-09-24): yaratıklar duvar arkasından ateş edebiliyordu - ateş etme artık görüş hattına bağlı
## (bkz. enemy.gd _has_line_of_sight), ayrıca mermi uçarken orman/uçurum duvarına çarparsa orada söner (hedef duvarın
## arkasına kaçınca mermi duvardan geçmesin). İlk WALL_IGNORE_TIME saniye duvar sayılmaz: duvara yaslanmış yaratığın
## mermisi kendi dibindeki karoda anında sönmesin.
const WALL_IGNORE_TIME := 0.08
static var _forest_layer: TileMapLayer = null
static var _forest_inv: Transform2D = Transform2D.IDENTITY

@export var speed: float = 208.0 ## genel hız ayarı: 260'tan %20 düşürüldü
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var source: Node2D = null
var tint: Color = Color(1.0, 0.55, 0.15, 1.0)
## Menzilli yaratıkların İKİNCİ, zayıf ama GARANTİ İSABETLİ atışı (bkz.
## enemy.gd _fire_homing_attack) bunu true yapar - her karede direction
## oyuncunun GÜNCEL konumuna göre yeniden hesaplanır, yani asla ıskalamaz
## (sadece oyuncunun "sıyrılma" stat'ı take_damage() içinde onu durdurabilir,
## normal bir isabet gibi). false iken (büyü/spell) davranış eskisi gibi
## sabit yönlü düz bir mermi.
var homing: bool = false
## Görsel stili (LichFlame.STYLE_*): 0 = aile renginde küre, 1 / 2 = lich büyüsü / normal atışı. add_child'DAN ÖNCE atanmalı (_ready seçer).
var style: int = 0
var _life: float = 0.0
var _flame: Sprite2D = null
var _ember_acc: float = 0.0
var _ember_every: float = EMBER_EVERY
static var _ember_layer: Node2D = null

@onready var visual = $Visual

## ---- Fizik karesi başına paylaşılan hedef önbelleği (bkz. dosya başı PERF notu) ----
static var _cache_frame: int = -1
static var _targets: Array = [] ## [Node2D gövde, Vector2 şekil merkezi, float yarıçap]
static var _dome_owners: Array = [] ## aktif Şovalye kalkanı olan oyuncular (genelde boş)
## Talon "Kalkan Çemberi" evrimi (2026-09-28): salvo sürerken mermileri silah çemberinde söndüren oyuncular [gövde, yarıçap].
static var _ward_owners: Array = []
## İlk kullanımda yüklenir (preload DEĞİL: yeni sayfa henüz içe aktarılmadıysa bu script derlenmeye devam etsin).
const WARD_BLOCK_SCENE_PATH := "res://scenes/fx_evo_talon_block.tscn"
static var _ward_block_scene: PackedScene = null


func _ready() -> void:
	## Fizik interpolasyonu (bkz. physics_interp.gd): _physics_process'te hareket ediyor.
	PhysicsInterp.opt_in(self)
	## Görüş alanı sisi (bkz. vision_fog.gd HIDEABLE_GROUPS): sisin içinde
	## kalan düşman mermileri de düşmanlar gibi gizlenir, karanlıktan gelen
	## ateş top yalnızca görüş alanına girince belirir.
	add_to_group("enemy_projectiles")
	if style != LichFlame.STYLE_ORB:
		if visual:
			remove_child(visual)
			visual.free()
			visual = null
		_flame = LichFlame.new()
		add_child(_flame)
		_flame.setup(direction, style == LichFlame.STYLE_SMALL)
		_ember_every = (EMBER_EVERY_SMALL if style == LichFlame.STYLE_SMALL else EMBER_EVERY) * randf_range(0.6, 1.4)
	elif visual:
		visual.glow_color = tint
		visual.direction = direction
		visual.queue_redraw()


static func _refresh_cache(tree: SceneTree) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _cache_frame:
		return
	_cache_frame = frame
	_forest_layer = GameManager.get_forest_layer()
	if _forest_layer != null:
		_forest_inv = _forest_layer.global_transform.affine_inverse()
	_targets.clear()
	_dome_owners.clear()
	_ward_owners.clear()
	var bodies: Array = []
	var local_p: Node = tree.get_first_node_in_group("player")
	if local_p:
		bodies.append(local_p)
	bodies.append_array(tree.get_nodes_in_group("remote_players"))
	bodies.append_array(tree.get_nodes_in_group("player_allies"))
	## Dışarı atılan BABAANNE (madde 313): fizik gövdesi yok - ayak üstü gövde dairesiyle hedef listesine.
	var granny: Node2D = GameManager.babaanne_target
	if is_instance_valid(granny) and granny.is_inside_tree() and granny.get("is_dead") != true:
		_targets.append([granny, granny.global_position, 10.0])
	for b in bodies:
		if not is_instance_valid(b):
			continue
		## Şovalye (Paladin) ultisi: hangi oyuncuya hedeflenmiş olursa olsun HER aktif kalkan kontrol edilir.
		if "paladin_zone_active" in b and b.get("paladin_zone_active") == true:
			_dome_owners.append(b)
		## Talon "Kalkan Çemberi" (yerel oyuncu + uzak kukla aynı adlı fonksiyonu verir - host'ta uzak Talon'un çemberi de sayılır).
		if b.has_method("get_talon_ward_radius"):
			var ward_r: float = float(b.call("get_talon_ward_radius"))
			if ward_r > 0.0:
				_ward_owners.append([b, ward_r])
		if not (b is CollisionObject2D) or ((b as CollisionObject2D).collision_layer & TARGET_LAYER_MASK) == 0:
			continue
		for c in (b as Node).get_children():
			var cs := c as CollisionShape2D
			if cs == null or cs.disabled or cs.shape == null:
				continue
			var r: float
			if cs.shape is CircleShape2D:
				r = (cs.shape as CircleShape2D).radius
			else:
				r = cs.shape.get_rect().size.length() * 0.5
			r *= absf(cs.global_scale.x)
			_targets.append([b, cs.global_position, r])


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= LIFETIME:
		queue_free()
		return
	if not ProjectileRangeScript.within(self):
		queue_free()
		return
	if homing:
		var player := get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			direction = (player.global_position - global_position).normalized()
			if _flame != null:
				_flame.set_direction(direction)
	position += direction * speed * delta
	if _flame != null:
		_flame.advance(delta)
		_tick_embers(delta)
	_refresh_cache(get_tree())
	if _life >= WALL_IGNORE_TIME and _forest_layer != null and is_instance_valid(_forest_layer) 			and _forest_layer.get_cell_source_id(_forest_layer.local_to_map(_forest_inv * global_position)) != -1:
		_spawn_impact()
		queue_free()
		return

	## Şovalye (Paladin) ultisi aktifken koruma alanının içine hiçbir menzilli
	## saldırı giremiyor - bkz. player.gd paladin_zone_active/paladin_zone_
	## radius. Sınıra değince hasar vermeden sessizce kayboluyor. Kullanıcı
	## isteği: "ne olursa olsun hiçbir yaratığın kalkanın içine giremeyip
	## atışların da kalkanın içine girememesi lazım" - aktif kalkanı olan
	## HERHANGİ bir oyuncu (yerel + tüm RemotePlayer'lar) kontrol ediliyor,
	## mermi kime hedeflenmiş olursa olsun.
	for p in _dome_owners:
		if is_instance_valid(p) and PaladinDome.contains(p.global_position, float(p.get("paladin_zone_radius")), global_position):
			queue_free()
			return
	for w in _ward_owners:
		if is_instance_valid(w[0]) and global_position.distance_to((w[0] as Node2D).global_position) <= float(w[1]):
			_spawn_ward_block()
			queue_free()
			return

	## Seyyar satıcının güvenli bölgesi - yukarıdaki Şovalye kalkanıyla AYNI
	## "sınıra değince sessizce kaybol" davranışı, ama sabit bir dünya
	## konumuna göre (bkz. enemy.gd'deki AYNI desen notu).
	if GameManager.merchant_zone_active and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
		queue_free()
		return

	for t in _targets:
		var reach: float = HIT_RADIUS + float(t[2])
		if global_position.distance_squared_to(t[1]) <= reach * reach and is_instance_valid(t[0]):
			if _on_body_hit(t[0]):
				return


## Eski Area2D _on_body_entered'ın birebir karşılığı; mermi yok olduysa true.
func _on_body_hit(body: Node) -> bool:
	## Multiplayer görsel kopya — hasar verme, sadece yok ol
	if get_meta("network_spawned", false):
		_spawn_impact()
		queue_free()
		return true
	## "player_ally" (TEKİL - Matthew'in tilkisi, bkz. player_pet.gd) HEDEF ALINMIYOR - kullanıcı isteği:
	## "yaratıklar onu görmezden gelmeli". RemotePlayer (gerçek uzak katılımcının kuklası) "player" grubunda DEĞİL,
	## "remote_players" grubunda - onu da tanımazsak host'ta uzak oyuncular menzilli mermilere fiilen bağışık olurdu
	## (eski DÜZELTME: "bazen bir oyuncu hasar alınca diğer oyuncu da hasar alıyor"). Necromancer yaratıkları
	## ("player_allies" - ÇOĞUL) hasar alabilir ve mermileri engelleyebilir.
	var is_target: bool = body.is_in_group("player") or body.is_in_group("player_allies") or body.is_in_group("remote_players") \
			or body == GameManager.babaanne_target
	if is_target and body.has_method("take_damage"):
		## Mermiyi atan yaratık mermi uçarken ölüp silinmiş olabilir - silinmiş nesneyi take_damage'in TİPLİ (Node2D)
		## source parametresine geçirmek oyunu çökertiyordu (bkz. enemy_abilities.gd deal_special_damage ÇÖKME notu).
		body.take_damage(damage, source if is_instance_valid(source) else null)
		_spawn_impact()
		queue_free()
		return true
	return false


## Ruh Alevi'nin arkasından yükselen kor (madde 280): uçulan yol EMBER_EVERY'yi geçince tek piksel, paylaşılan katmana.
func _tick_embers(delta: float) -> void:
	_ember_acc += speed * delta
	if _ember_acc < _ember_every:
		return
	_ember_acc = 0.0
	var small: bool = style == LichFlame.STYLE_SMALL
	_ember_every = (EMBER_EVERY_SMALL if small else EMBER_EVERY) * randf_range(0.6, 1.4)
	if not is_visible_in_tree(): ## sisin içinde (vision_fog gizledi): kor gizli merminin yerini ele vermesin
		return
	var layer: Node2D = _get_ember_layer(get_tree())
	if layer == null:
		return
	var back: Vector2 = -direction * (4.0 if small else 7.0)
	layer.add(global_position + back + Vector2(randf_range(-2.0, 2.0), randf_range(-2.5, 2.5)),
			Vector2(randf_range(-3.0, 3.0), randf_range(-17.0, -9.0)), randf_range(0.35, 0.6))


static func _get_ember_layer(tree: SceneTree) -> Node2D:
	if _ember_layer != null and is_instance_valid(_ember_layer) and _ember_layer.is_inside_tree():
		return _ember_layer
	var scene: Node = tree.current_scene
	if scene == null:
		return null
	_ember_layer = LichEmberLayerScript.new()
	scene.add_child(_ember_layer)
	return _ember_layer


func _spawn_impact() -> void:
	if get_tree().current_scene == null:
		return
	var fx: Node2D
	if style != LichFlame.STYLE_ORB:
		fx = LichImpactScript.new()
		fx.set("small", style == LichFlame.STYLE_SMALL)
		fx.set("color", tint)
	else:
		fx = Node2D.new()
		fx.set_script(ImpactScript)
		fx.set("color", tint)
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position


## Talon "Kalkan Çemberi"nde sönen merminin küçük kıvılcımı - her makine kendi kopyası sönerken kendisi oynatır (yayın yok:
## mermi her makinede aynı kurala göre söner).
func _spawn_ward_block() -> void:
	if _ward_block_scene == null and ResourceLoader.exists(WARD_BLOCK_SCENE_PATH):
		_ward_block_scene = load(WARD_BLOCK_SCENE_PATH) as PackedScene
	if _ward_block_scene == null or get_tree().current_scene == null:
		return
	var fx: Node2D = _ward_block_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
