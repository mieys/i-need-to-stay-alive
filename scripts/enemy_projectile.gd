extends Node2D

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
const LIFETIME := 3.0
const ImpactScript: GDScript = preload("res://scripts/fx_enemy_bolt_impact.gd")
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
var _life: float = 0.0

@onready var visual = $Visual

## ---- Fizik karesi başına paylaşılan hedef önbelleği (bkz. dosya başı PERF notu) ----
static var _cache_frame: int = -1
static var _targets: Array = [] ## [Node2D gövde, Vector2 şekil merkezi, float yarıçap]
static var _dome_owners: Array = [] ## aktif Şovalye kalkanı olan oyuncular (genelde boş)


func _ready() -> void:
	## Fizik interpolasyonu (bkz. physics_interp.gd): _physics_process'te hareket ediyor.
	PhysicsInterp.opt_in(self)
	## Görüş alanı sisi (bkz. vision_fog.gd HIDEABLE_GROUPS): sisin içinde
	## kalan düşman mermileri de düşmanlar gibi gizlenir, karanlıktan gelen
	## ateş top yalnızca görüş alanına girince belirir.
	add_to_group("enemy_projectiles")
	if visual:
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
	var bodies: Array = []
	var local_p: Node = tree.get_first_node_in_group("player")
	if local_p:
		bodies.append(local_p)
	bodies.append_array(tree.get_nodes_in_group("remote_players"))
	bodies.append_array(tree.get_nodes_in_group("player_allies"))
	for b in bodies:
		if not is_instance_valid(b):
			continue
		## Şovalye (Paladin) ultisi: hangi oyuncuya hedeflenmiş olursa olsun HER aktif kalkan kontrol edilir.
		if "paladin_zone_active" in b and b.get("paladin_zone_active") == true:
			_dome_owners.append(b)
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
	if homing:
		var player := get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			direction = (player.global_position - global_position).normalized()
	position += direction * speed * delta
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
		if is_instance_valid(p) and global_position.distance_to(p.global_position) <= float(p.get("paladin_zone_radius")):
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
	var is_target: bool = body.is_in_group("player") or body.is_in_group("player_allies") or body.is_in_group("remote_players")
	if is_target and body.has_method("take_damage"):
		## Mermiyi atan yaratık mermi uçarken ölüp silinmiş olabilir - silinmiş nesneyi take_damage'in TİPLİ (Node2D)
		## source parametresine geçirmek oyunu çökertiyordu (bkz. enemy_abilities.gd deal_special_damage ÇÖKME notu).
		body.take_damage(damage, source if is_instance_valid(source) else null)
		_spawn_impact()
		queue_free()
		return true
	return false


func _spawn_impact() -> void:
	if get_tree().current_scene == null:
		return
	var fx := Node2D.new()
	fx.set_script(ImpactScript)
	fx.set("color", tint)
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
