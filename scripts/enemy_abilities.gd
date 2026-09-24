extends RefCounted

## ==============================================================================
## YARATIK YETENEKLERİ (kullanıcı isteği 2026-09-24: "yaratıklara rasgele aralıklarla kullanacakları birer skill ver")
## ==============================================================================
## enemy.gd her yaratık için ailesine (creature_id'nin rakamsız kısmı: "hayalet", "vampire", "rontgen", "iblis",
## "agac") göre BİR kez bu nesneyi oluşturur (bkz. enemy.gd _init_abilities) ve host'ta (tek oyunculuda yerel) her
## fizik karesinde process()'i çağırır. Yeteneği olmayan aileler (golem/zombi/ork statlarla ya da ölüm/öfke kancasıyla
## çözüldü, bkz. enemy_spawner.gd FAMILY_TRAITS, enemy.gd die()/_rage_*) bu nesneyi hiç oluşturmaz - 200 yaratıkta
## ek maliyet sadece yetenekli ailelerin birkaç zamanlayıcısı.
##
## ÇOK OYUNCULU MİMARİ (mevcut yaratık saldırılarıyla AYNI, bkz. enemy_projectile.gd): karar ve hasar SADECE host'ta.
##  - Dünyada duran etkiler (lazer, diken, asit, ateş topu) host'ta "yetkili" (hasar veren) örnek olarak doğar ve
##    NetworkManager.broadcast_enemy_ability_fx ile istemcilerde SADECE görsel kopya olarak doğar (spawn_world_fx).
##  - Yaratığın kendi durumu (hayaletin görünmezliği, vampirin ışınlanması) broadcast_enemy_vfx'in "ghost_vanish"/
##    "ghost_reveal"/"vampire_blink" dallarıyla taşınır (bkz. enemy.gd on_ability_vfx).
##  - Uzak oyuncuya isabet: RemotePlayer.take_special_damage -> forward_special_damage_to_peer RPC'si -> o oyuncunun
##    KENDİ makinesinde player.gd take_special_damage (yanma/kalkan x2 gibi özel kurallar orada uygulanır).
## ==============================================================================

const FxScript := preload("res://scripts/fx_enemy_ability.gd")
const VisionFogScript := preload("res://scripts/vision_fog.gd")
const GHOST_FRAMES := preload("res://assets/fx/enemy_abilities/ghost_frames.tres")
const VAMPIRE_FRAMES := preload("res://assets/fx/enemy_abilities/vampire_frames.tres")

## --- Hayalet (kullanıcı: "rasgele aralıklarla görünmez ve hedef alınamaz olsun, fakat görünmezken saldıramazlar ve
## hasar veremezler. görünmezlikleri 3-4 saniye sürmeli sonrasında 6-7 saniye bekleme süresinde olmalı ve rasgele-orta
## sıklıklarla görünmez olmalılar" + ilk madde: "görünmezken yakınına gelip saldırır, saldırdığı anda görünmezliği
## gider, sadece 10 saniyede 1 kez görünmez olabilirler"). İkisi birlikte: görünmezken oyuncuya yaklaşır ama vuramaz;
## saldırı mesafesine girince ÖNCE görünür olur (GHOST_REVEAL_ATTACK_DELAY sonra normal saldırısı gelir). Bir döngü
## (3-4 sn görünmez + 6-7 sn bekleme) ~10 sn.
const GHOST_INVIS_MIN := 3.0
const GHOST_INVIS_MAX := 4.0
const GHOST_COOLDOWN_MIN := 6.0
const GHOST_COOLDOWN_MAX := 7.0
const GHOST_TRIGGER_CHANCE_PER_SEC := 0.45 ## bekleme bitince her saniye bu olasılıkla (orta sıklık) görünmez olur
const GHOST_ACTIVE_RANGE := 700.0 ## sadece bir oyuncuya bu kadar yakınken yetenek kullanılır
const GHOST_REVEAL_ATTACK_DELAY := 0.35

## --- Vampir ("dostların görüş alanlarına girdikten 1 ila 6 saniye arasında rasgele bir süre içinde aniden
## karakterlerin yakınına ışınlanarak saldırır. Bu işlemi her vampir 15 saniyede bir yapabilir").
const VAMPIRE_COOLDOWN := 15.0
const VAMPIRE_DELAY_MIN := 1.0
const VAMPIRE_DELAY_MAX := 6.0
const VAMPIRE_BLINK_DISTANCE := 46.0 ## hedefin bu kadar yanına belirir (temas mesafesi civarı)
const VAMPIRE_VISION_CHECK_INTERVAL := 0.25

## --- Röntgen ("baktıkları yöne doğru düz bir çizgi halinde lazer ışını gönderir. Bu ışınlar isabet halinde
## kalkanlara normal hasarlarının 2 katı kadar hasar verir. ışın atılmadan önce uyarı çizgisi gelmeli").
const LASER_COOLDOWN_MIN := 6.0
const LASER_COOLDOWN_MAX := 9.0
const LASER_TRIGGER_RANGE := 380.0
const LASER_LENGTH := 440.0
const LASER_WARN_TIME := 0.9
const LASER_FIRE_TIME := 0.3
const LASER_DAMAGE_MULT := 1.0 ## sağlığa normal hasar; kalkana x2 (bkz. player.gd take_special_damage "laser")

## --- İblis ("ateş topu fırlatır, ateş topu isabet ettiğinde karakteri 3 saniye boyunca yakarak hasar verir").
const FIREBALL_COOLDOWN_MIN := 5.0
const FIREBALL_COOLDOWN_MAX := 8.0
const FIREBALL_RANGE := 420.0
const FIREBALL_SPEED := 230.0
const FIREBALL_DAMAGE_MULT := 1.0 ## isabet anı; yanma player.gd ENEMY_BURN_* (isabet hasarının %25'i/sn, 3 sn)

## --- Ağaç canavarı ("rasgele aralıklarla bulunduğun konuma yerden diken çıkarsın ... 10 saniye bekleme süresi ...
## normal saldırısı kadar hasar ... diken çıkarmadan önce çıkaracağı yerde uyarı çıksın").
const THORNS_COOLDOWN := 10.0
const THORNS_COOLDOWN_RANDOM_EXTRA := 3.0 ## "rasgele aralıklarla": 10 sn bekleme + 0-3 sn rastgele
const THORNS_RANGE := 420.0
const THORNS_WARN_TIME := 1.0
const THORNS_RADIUS := 42.0

## --- Zombi ("ölünce patlayarak yere 4 saniyeliğine zehirli asit bırakıp oraya basanlara normal hasarı kadar hasar
## versin") - ölüm kancası bu sınıfın statik spawn_world_fx'ini kullanır (bkz. enemy.gd die()).
const ACID_DURATION := 4.0
## Kullanıcı isteği (2026-09-24): "zombinin zehrinin hasarını %50 azalt" - tik başına hasar = temas hasarı x bu çarpan.
const ACID_DAMAGE_MULT := 0.5

## Oyuncu gövde yarıçapı (enemy.gd PLAYER_BODY_RADIUS ile aynı mertebe) - alan/çizgi isabet toleransı.
const TARGET_BODY_RADIUS := 12.0

var e: Node2D = null ## sahip yaratık (Enemy)
var family: String = ""
var _cd: float = 0.0
var _timer: float = 0.0
var _pending: float = -1.0
var _vision_check: float = 0.0


func setup(owner_enemy: Node2D, fam: String) -> void:
	e = owner_enemy
	family = fam
	match family:
		"hayalet":
			_cd = randf_range(1.5, 5.0)
		"vampire":
			_cd = 0.0
		"rontgen":
			_cd = randf_range(2.0, 5.0)
		"iblis":
			_cd = randf_range(2.0, 5.0)
		"agac":
			_cd = randf_range(3.0, 8.0)


static func family_has_ability(fam: String) -> bool:
	return fam in ["hayalet", "vampire", "rontgen", "iblis", "agac"]


## Host'ta her fizik karesi (yaratık donmuş/korkmuş/sersemlemişken çağrılmaz - bkz. enemy.gd). player/dist: yaratığın
## o anki hedefi ve uzaklığı (gezinirken null/INF).
func process(delta: float, player: Node2D, dist: float) -> void:
	match family:
		"hayalet":
			_process_ghost(delta, player, dist)
		"vampire":
			_process_vampire(delta)
		"rontgen":
			_process_laser(delta, player, dist)
		"iblis":
			_process_fireball(delta, player, dist)
		"agac":
			_process_thorns(delta, player, dist)


func _valid_target(player: Node2D) -> bool:
	return player != null and is_instance_valid(player) and player.get("is_dead") != true


# ---------------------------------------------------------------------------------------------------- hayalet
func _process_ghost(delta: float, player: Node2D, dist: float) -> void:
	if e.get("is_ability_invisible") == true:
		_timer -= delta
		if _timer <= 0.0:
			ghost_reveal(false)
		return
	_cd -= delta
	if _cd > 0.0 or not _valid_target(player) or dist > GHOST_ACTIVE_RANGE:
		return
	if randf() < GHOST_TRIGGER_CHANCE_PER_SEC * delta:
		_ghost_vanish()


func _ghost_vanish() -> void:
	_timer = randf_range(GHOST_INVIS_MIN, GHOST_INVIS_MAX)
	e.call("set_ability_invisible", true)
	FxScript.spawn(e.get_tree().current_scene, e.global_position, GHOST_FRAMES, &"vanish", 2)
	_broadcast_enemy_vfx("ghost_vanish", {})


## for_attack: saldırı mesafesine girdiği için görünür oluyor (enemy.gd temas saldırısı dalı) - asıl saldırı kısa bir
## gecikmeyle gelir, görünmezken hasar verilmez.
func ghost_reveal(for_attack: bool) -> void:
	if e.get("is_ability_invisible") != true:
		return
	e.call("set_ability_invisible", false)
	_cd = randf_range(GHOST_COOLDOWN_MIN, GHOST_COOLDOWN_MAX)
	if for_attack:
		e.set("_contact_timer", GHOST_REVEAL_ATTACK_DELAY)
	if e.is_inside_tree():
		FxScript.spawn(e.get_tree().current_scene, e.global_position, GHOST_FRAMES, &"appear", 2)
	_broadcast_enemy_vfx("ghost_reveal", {})


# ---------------------------------------------------------------------------------------------------- vampir
func _process_vampire(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta
		return
	if _pending < 0.0:
		_vision_check -= delta
		if _vision_check > 0.0:
			return
		_vision_check = VAMPIRE_VISION_CHECK_INTERVAL
		## "dostların görüş alanına girdikten sonra": host'un sisi takım görüşünü de hesaplıyor (VIS_META), yani bu
		## kontrol herhangi bir oyuncunun gördüğü anı yakalar.
		if VisionFogScript.can_target(e):
			_pending = randf_range(VAMPIRE_DELAY_MIN, VAMPIRE_DELAY_MAX)
		return
	_pending -= delta
	if _pending > 0.0:
		return
	_pending = -1.0
	if _vampire_blink():
		_cd = VAMPIRE_COOLDOWN


func _vampire_blink() -> bool:
	var target: Node2D = e.call("_find_closest_target_player") as Node2D
	if not _valid_target(target):
		return false
	var from: Vector2 = e.global_position
	var to: Vector2 = Vector2.ZERO
	var found: bool = false
	var base_angle: float = randf() * TAU
	for i in range(8):
		var cand: Vector2 = target.global_position + Vector2.from_angle(base_angle + i * TAU / 8.0) * VAMPIRE_BLINK_DISTANCE
		if GameManager.is_position_blocked_by_terrain(cand):
			continue
		if GameManager.merchant_zone_active and cand.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
			continue
		to = cand
		found = true
		break
	if not found:
		return false
	e.global_position = to
	e.set("_contact_timer", 0.0) ## belirir belirmez saldırsın
	e.set("_ai_has_decision", false) ## bir sonraki karede hedefini yeniden düşünsün
	var scene_root: Node = e.get_tree().current_scene
	FxScript.spawn(scene_root, from, VAMPIRE_FRAMES, &"blink", 2)
	FxScript.spawn(scene_root, to, VAMPIRE_FRAMES, &"blink", 2)
	_broadcast_enemy_vfx("vampire_blink", {"from": from, "to": to})
	return true


# ---------------------------------------------------------------------------------------------------- röntgen
func _process_laser(delta: float, player: Node2D, dist: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	if not _valid_target(player) or dist > LASER_TRIGGER_RANGE:
		return
	if not bool(e.call("_has_line_of_sight", player)):
		_cd = 0.5
		return
	var to_p: Vector2 = player.global_position - e.global_position
	var dir: Vector2 = to_p.normalized() if to_p.length() > 0.1 else Vector2.RIGHT
	var length: float = clip_ray_to_walls(e.global_position, dir, LASER_LENGTH)
	var dmg: float = float(e.get("contact_damage")) * LASER_DAMAGE_MULT
	e.set("ability_move_lock", LASER_WARN_TIME + LASER_FIRE_TIME)
	e.set("_ranged_timer", maxf(float(e.get("_ranged_timer")), LASER_WARN_TIME + LASER_FIRE_TIME + 0.2))
	e.call("_update_facing", dir)
	e.call("_play_ability_attack_anim")
	var data: Dictionary = {"dir": dir, "length": length, "warn": LASER_WARN_TIME, "fire": LASER_FIRE_TIME}
	spawn_world_fx(e.get_tree(), "laser", e.global_position, data, true, e, dmg)
	_broadcast_world_fx("laser", e.global_position, data)
	_cd = randf_range(LASER_COOLDOWN_MIN, LASER_COOLDOWN_MAX)


# ---------------------------------------------------------------------------------------------------- iblis
func _process_fireball(delta: float, player: Node2D, dist: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	if not _valid_target(player) or dist > FIREBALL_RANGE:
		return
	if not bool(e.call("_has_line_of_sight", player)):
		_cd = 0.5
		return
	var to_p: Vector2 = player.global_position - e.global_position
	var dir: Vector2 = to_p.normalized() if to_p.length() > 0.1 else Vector2.RIGHT
	var dmg: float = float(e.get("contact_damage")) * FIREBALL_DAMAGE_MULT
	e.call("_play_ability_attack_anim")
	var pos: Vector2 = e.global_position + dir * 14.0
	var data: Dictionary = {"dir": dir, "speed": FIREBALL_SPEED}
	spawn_world_fx(e.get_tree(), "fireball", pos, data, true, e, dmg)
	_broadcast_world_fx("fireball", pos, data)
	_cd = randf_range(FIREBALL_COOLDOWN_MIN, FIREBALL_COOLDOWN_MAX)


# ---------------------------------------------------------------------------------------------------- ağaç
func _process_thorns(delta: float, player: Node2D, dist: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	if not _valid_target(player) or dist > THORNS_RANGE:
		return
	if not bool(e.call("_has_line_of_sight", player)):
		_cd = 0.5
		return
	var pos: Vector2 = player.global_position
	var dmg: float = float(e.get("contact_damage"))
	e.call("_play_ability_attack_anim")
	var data: Dictionary = {"warn": THORNS_WARN_TIME, "radius": THORNS_RADIUS}
	spawn_world_fx(e.get_tree(), "thorns", pos, data, true, e, dmg)
	_broadcast_world_fx("thorns", pos, data)
	_cd = THORNS_COOLDOWN + randf() * THORNS_COOLDOWN_RANDOM_EXTRA


# ---------------------------------------------------------------------------------------------------- ortak
func _broadcast_enemy_vfx(kind: String, data: Dictionary) -> void:
	if not (NetworkManager.is_multiplayer_active and NetworkManager.is_host):
		return
	var net_id: int = int(e.get_meta("network_enemy_id", 0))
	if net_id > 0:
		NetworkManager.broadcast_enemy_vfx.rpc(net_id, kind, data)


static func _broadcast_world_fx(kind: String, pos: Vector2, data: Dictionary) -> void:
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		NetworkManager.broadcast_enemy_ability_fx.rpc(kind, pos, data)


## Zombi ölüm kancası (enemy.gd die(), SADECE host): asit gölünü yetkili olarak doğurur ve istemcilere yayınlar.
static func spawn_zombie_acid(tree: SceneTree, pos: Vector2, damage: float, source: Node2D) -> void:
	var data: Dictionary = {"duration": ACID_DURATION}
	spawn_world_fx(tree, "acid", pos, data, true, source, damage * ACID_DAMAGE_MULT)
	_broadcast_world_fx("acid", pos, data)


## Dünya etkisini doğurur. authoritative=true: host/tek oyunculu örnek (hasar verir); false: istemcideki görsel kopya.
static func spawn_world_fx(tree: SceneTree, kind: String, pos: Vector2, data: Dictionary, authoritative: bool,
		source: Node2D = null, damage: float = 0.0) -> Node2D:
	if tree == null or tree.current_scene == null:
		return null
	var script_path: String = ""
	match kind:
		"laser":
			script_path = "res://scripts/enemy_laser.gd"
		"thorns":
			script_path = "res://scripts/enemy_thorns.gd"
		"acid":
			script_path = "res://scripts/enemy_acid_pool.gd"
		"fireball":
			script_path = "res://scripts/enemy_fireball.gd"
		_:
			return null
	var node := Node2D.new()
	node.set_script(load(script_path))
	node.set("data", data)
	node.set("authoritative", authoritative)
	node.set("source", source)
	node.set("damage", damage)
	## Konum add_child'dan ÖNCE: _ready() (ör. asit gölünün patlama efekti) doğru yerde çalışsın. current_scene kökü
	## dünya orijininde olduğu için yerel konum = dünya konumu.
	node.position = pos
	tree.current_scene.add_child(node)
	node.global_position = pos
	if kind == "acid":
		place_on_ground(tree, node)
	return node


## DÜZELTME (kullanıcı bildirimi: "zehirler yaratıkların üstünde görünüyor zeminde görünmüyor"): sahnede y-sort yok,
## aynı z'deki kardeşler AĞAÇ SIRASIYLA çizilir. Yaratıklar current_scene'e çalışma anında eklendiği için sona
## eklenen bir zemin efekti o ana kadar doğmuş HER yaratığın üstünde kalıyordu. Zemin efektini haritanın ("Harita")
## hemen arkasına taşı: zeminin üstünde, sonradan eklenen tüm yaratık/oyuncuların altında çizilir.
static func place_on_ground(tree: SceneTree, node: Node) -> void:
	var root: Node = tree.current_scene
	if root == null or node.get_parent() != root:
		return
	var harita: Node = root.get_node_or_null("Harita")
	if harita == null:
		return
	root.move_child(node, harita.get_index() + 1)


## Hasar alabilecek oyuncular: yerel oyuncu + (host'ta) uzak oyuncu kuklaları. Kukladaki take_special_damage hasarı
## RPC ile o oyuncunun kendi makinesine iletir (bkz. remote_player.gd).
static func damageable_players(tree: SceneTree) -> Array:
	var out: Array = []
	var local_p: Node = tree.get_first_node_in_group("player")
	if local_p != null and is_instance_valid(local_p) and local_p.get("is_dead") != true:
		out.append(local_p)
	for rp in tree.get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and rp.get("is_dead") != true:
			out.append(rp)
	return out


static func deal_special_damage(target: Node, amount: float, source: Node2D, kind: String) -> void:
	if target == null or not is_instance_valid(target) or amount <= 0.0:
		return
	var src: Node2D = source if (source != null and is_instance_valid(source)) else null
	if target.has_method("take_special_damage"):
		target.call("take_special_damage", amount, src, kind)
	elif target.has_method("take_damage"):
		target.call("take_damage", amount, src)


## Işını orman duvarına kadar kısaltır (duvarın arkasına geçmesin) - 8 birimlik adımlarla örnekler.
static func clip_ray_to_walls(origin: Vector2, dir: Vector2, max_len: float) -> float:
	var step: float = 8.0
	var d: float = step
	while d < max_len:
		if GameManager.is_position_blocked_by_forest(origin + dir * d):
			return maxf(d - step * 0.5, step)
		d += step
	return max_len
