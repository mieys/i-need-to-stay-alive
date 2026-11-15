extends Node

## 2026-11-12 (kullanıcı: "Talon'un E'si çoğu silahta doğru çalışmıyor: yakın dövüşte zincire bağlı saldırı animasyonu + spam gerekiyor;
## Gökkuşağı/Yıldırım asası dümdüz saldırı spamlamalı ama menzile yaratık girince aktifleşiyor"):
##  - SalvoStrikeMath: zincir ucundaki yuvaya göre silaha özel vuruş animasyonu (yuvadan kopmaz, 0'da başlar/biter, görünür genlik);
##  - yakın dövüş salvoda yaratık olmasa da vurur (animasyon başlar), kukla aynı örnekleyiciyle oynatır;
##  - ışın asaları salvoda yaratığa kilitlenmez: ikonun baktığı yönde DÜZ açılır, dönerken peşinden gelir, yolundaki ilk yaratığa vurur.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemoteScene: PackedScene = preload("res://scenes/remote_player.tscn")
const S: GDScript = preload("res://scripts/spiritual_skills.gd")
const Strike := preload("res://scripts/salvo_strike_math.gd")
const Smooth := preload("res://scripts/beam_net_smooth.gd")
const Catalog := preload("res://scripts/weapon_catalog.gd")

const MELEE := ["dagger", "pence", "topuz", "uzunkilic", "mizrak", "kalkan"]

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1
var _prev_spirit: String = ""


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var _body_radius: float = 20.0
	var hits: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	_prev_spirit = GameManager.selected_spiritual
	GameManager.selected_char_id = 1
	GameManager.selected_character = Characters.get_def(1)["skill"]
	GameManager.selected_spiritual = S.PARA
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.item_shield_hp = 0.0
	player.item_shield_max = 0.0
	player._last_damage_taken_at_msec = -999999
	return player


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	GameManager.selected_spiritual = _prev_spirit
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _weapon(player: Node, key: String) -> Node:
	player.buy_weapon_copy(key, 1)
	for w in player.owned_weapon_nodes:
		if w.get_meta("shop_key", "") == key:
			return w
	return null


## Talon E dizilimi: silah dışa (açı) bakar - ikon dönüşü = açı - forward (player.gd _talon_set_weapons_circular ile aynı).
func _salvo_face(w: Node, angle: float) -> void:
	w.fire_in_facing_direction = true
	w.icon_faces_target = false
	w.icon_sprite.rotation = angle - deg_to_rad(float(w.sprite_forward_angle_deg))


func _enemy_at(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	_spawned.append(e)
	e.global_position = pos
	return e


# ------------------------------------------------------------------ örnekleyici (tek kaynak)

func test_every_melee_weapon_has_a_strike_kind() -> void:
	for key in Catalog.MELEE_KEYS:
		assert(Strike.kind_of_key(str(key)) != "", "yakın dövüş silahının salvo vuruşu yok: %s" % key)
	assert(Strike.kind_of_key("tabanca") == "" and Strike.kind_of_key("lightning_staff") == "", "menzilli silahın vuruş türü olmamalı")


func test_strike_is_attached_to_the_slot_and_clearly_visible() -> void:
	for kind in ["sword", "dagger", "hammer", "scythe", "spear", "shield"]:
		for outward in [0.0, 1.0, PI, -2.2]:
			var a: Dictionary = Strike.sample(kind, 0.0, 1.0, outward)
			var b: Dictionary = Strike.sample(kind, 1.0, 1.0, outward)
			assert((a["pos"] as Vector2).length() < 0.001 and absf(float(a["rot"])) < 0.001, "%s: vuruş yuvadan başlamalı" % kind)
			assert((b["pos"] as Vector2).length() < 0.001 and absf(float(b["rot"])) < 0.001, "%s: vuruş yuvada bitmeli (sıçrama yok)" % kind)
		var max_pos: float = 0.0
		var max_rot: float = 0.0
		for i in range(101):
			var p: Dictionary = Strike.sample(kind, float(i) / 100.0, -1.0, 0.7)
			max_pos = maxf(max_pos, (p["pos"] as Vector2).length())
			max_rot = maxf(max_rot, absf(float(p["rot"])))
		assert(max_pos >= 24.0 or max_rot >= 0.9, "%s: vuruş görünür olmalı (6 px'lik dürtme yetmez): %f / %f" % [kind, max_pos, max_rot])
		assert(max_pos <= 70.0, "%s: zincir ucundan kopmamalı (70 birim = 35 dünya px, silahın kendi boyu): %f" % [kind, max_pos])


func test_strikes_differ_per_weapon_type() -> void:
	## Kılıç/tırpan yay çizer (dönüş büyük), bıçak/mızrak/kalkan dönmeden dışa atılır, balyoz hem döner hem öne iner.
	var rot_max := func(kind: String) -> float:
		var m: float = 0.0
		for i in range(101):
			m = maxf(m, absf(float(Strike.sample(kind, float(i) / 100.0, 1.0, 0.0)["rot"])))
		return m
	assert(rot_max.call("sword") > 1.2 and rot_max.call("scythe") > rot_max.call("sword"), "kılıç/tırpan yay çizmeli (tırpan daha geniş)")
	assert(rot_max.call("dagger") == 0.0 and rot_max.call("spear") == 0.0 and rot_max.call("shield") == 0.0, "bıçak/mızrak/kalkan dönmeden atılır")
	assert(rot_max.call("hammer") > 0.8, "balyoz kaldırıp indirir")
	## Dışa (x) en çok atılan an: mızrak/kalkan/bıçak öne doğru, geri çekilme de var (mızrak önce arkaya).
	var spear_back: float = 0.0
	var spear_front: float = 0.0
	for i in range(101):
		var x: float = (Strike.sample("spear", float(i) / 100.0, 1.0, 0.0)["pos"] as Vector2).x
		spear_back = minf(spear_back, x)
		spear_front = maxf(spear_front, x)
	assert(spear_back <= -12.0 and spear_front >= 36.0, "mızrak önce geri çekilir sonra saplar: %f / %f" % [spear_back, spear_front])


func test_strike_duration_fits_the_fire_interval() -> void:
	for kind in ["sword", "dagger", "hammer", "scythe", "spear", "shield"]:
		var fast: float = Strike.duration(kind, 0.1)
		assert(fast <= 0.1 * Strike.DUR_FILL + 0.0001 or fast <= Strike.DUR_MIN + 0.0001, "%s: hızlı atışta vuruş aralığa sığmalı: %f" % [kind, fast])
		assert(Strike.duration(kind, 5.0) <= float(Strike.DUR_MAX[kind]) + 0.0001, "%s: yavaş atışta üst sınırı aşmamalı" % kind)


# ------------------------------------------------------------------ yetkili silah: yaratık olmasa da vurur

func test_salvo_melee_animates_every_strike_even_with_no_enemy() -> void:
	for key in MELEE:
		var player: Node = _make_player() ## oyuncu başına silah sınırı: her silah kendi oyuncusunda
		var w: Node = _weapon(player, key)
		assert(w != null, "silah alınmalı: %s" % key)
		_salvo_face(w, 0.0)
		var ghost: Node2D = w._make_facing_direction_target()
		assert(not ghost.has_method("take_damage"), "%s: yaratık yok, hayalet hedef" % key)
		w._fire_at(ghost)
		assert(w._strike_t == 0.0 and w._strike_dur > 0.0, "%s: yaratık olmasa da vuruş animasyonu başlamalı" % key)
		var max_move: float = 0.0
		var max_turn: float = 0.0
		for i in range(20):
			var pose: Dictionary = w.salvo_strike_pose(0.0)
			max_move = maxf(max_move, (pose["pos"] as Vector2).length())
			max_turn = maxf(max_turn, absf(float(pose["rot"])))
			w._process(w._strike_dur / 20.0)
		assert(max_move >= 24.0 or max_turn >= 0.9, "%s: vuruş görünür hareket etmeli: %f / %f" % [key, max_move, max_turn])
		assert(w._strike_t < 0.0, "%s: vuruş süresi dolunca temizlenmeli" % key)
		assert(w.icon_sprite.position.length() < 0.5, "%s: ikon yerel konumu yuvada kalmalı (savrulmaz)" % key)
		_cleanup()


func test_salvo_strike_keeps_the_facing_direction_clean() -> void:
	## Vuruşun dönüşü (kılıç ±75 derece) hayalet hedefi / hasar hattını sallamamalı: yön hep yuvanın dışa bakışı.
	var player: Node = _make_player()
	var sword: Node = _weapon(player, "uzunkilic")
	_salvo_face(sword, 0.0)
	sword._fire_at(sword._make_facing_direction_target())
	sword._process(sword._strike_dur * 0.2) ## kurulma bitti, yay başında: dönüş en büyük (orta noktada sıfırı geçer)
	var pose: Dictionary = sword.salvo_strike_pose(0.0)
	sword.icon_sprite.rotation = -deg_to_rad(float(sword.sprite_forward_angle_deg)) + float(pose["rot"]) ## formasyon duruşu + vuruş
	assert(absf(float(pose["rot"])) > 0.3, "ölçüm anında vuruş dönmüş olmalı")
	var dir: Vector2 = sword._icon_facing_dir()
	assert(dir.distance_to(Vector2.RIGHT) < 0.01, "yön vuruş dönüşünden bağımsız olmalı: %s" % dir)
	_cleanup()


func test_salvo_end_clears_the_strike() -> void:
	var player: Node = _make_player()
	var hammer: Node = _weapon(player, "topuz")
	player._skill_talon_weapon_salvo()
	hammer._fire_at(hammer._make_facing_direction_target())
	assert(hammer._strike_t >= 0.0, "salvoda vuruş başlamalı")
	player._end_talon_weapon_salvo()
	assert(hammer._strike_t < 0.0 and not hammer.fire_in_facing_direction, "salvo bitince vuruş + dizilim kapanmalı")
	_cleanup()


# ------------------------------------------------------------------ kukla (diğer oyuncunun ekranı)

func test_puppet_plays_the_same_strike_attached_to_the_slot() -> void:
	var puppet: Node2D = RemoteScene.instantiate()
	puppet.set("_weapon_keys", ["uzunkilic", "dagger", "tabanca"])
	puppet.call("_start_formation_strike", 0, 0.2, Vector2.RIGHT)
	puppet.call("_start_formation_strike", 1, 0.0, Vector2.RIGHT) ## süre gelmezse (eski sürüm) türün varsayılanı
	puppet.call("_start_formation_strike", 2, 0.2, Vector2.RIGHT) ## menzilli: vuruş türü yok -> eski küçük dürtme, çökmez
	var moved: bool = false
	for i in range(10):
		var p: Dictionary = puppet.call("_formation_strike_pose", 0, 0.0, 0.02)
		if (p["pos"] as Vector2).length() > 1.0 or absf(float(p["rot"])) > 0.1:
			moved = true
	assert(moved, "kukla kılıç vuruşunu oynatmalı")
	var done: Dictionary = puppet.call("_formation_strike_pose", 0, 0.0, 1.0)
	assert((done["pos"] as Vector2).length() < 0.001 and float(done["rot"]) == 0.0, "süre dolunca yuvaya dönmeli")
	assert((puppet.call("_formation_strike_pose", 2, 0.0, 0.02)["pos"] as Vector2).length() == 0.0, "menzilli silahta salvo vuruşu yok")
	puppet.free()


func test_puppet_formation_applies_the_strike_to_the_icon_in_the_real_update() -> void:
	## Uçtan uca: "weapon_fire" olayı -> _update_talon_formation her karede ikonu formasyon yuvası + vuruş ofsetinde tutar.
	var puppet: Node2D = RemoteScene.instantiate() as Node2D
	add_child(puppet)
	_spawned.append(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.call("snap_to_network_position", Vector2(22000.0, 22000.0))
	puppet.call("update_weapon_visuals", ["uzunkilic", "dagger", "fire_staff"])
	puppet.set("_talon_formation", "salvo")
	var icons: Array = puppet.get("_weapon_icons")
	assert(icons.size() == 3, "üç ikon")
	puppet.call("_update_talon_formation", 0.016) ## dinlenme duruşu (vuruş yok)
	var slot_pos: Vector2 = (icons[0] as Node2D).position
	var slot_rot: float = (icons[0] as Node2D).rotation
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": 1.0, "direction_y": 0.0, "ss_dur": 0.2})
	var moved: float = 0.0
	var turned: float = 0.0
	var last_ang: float = 0.0
	for i in range(8):
		puppet.call("_update_talon_formation", 0.02)
		var icon: Node2D = icons[0]
		## slot her karede döner: yerini dönüş açısından bul (yarıçap sabit, vuruş ofseti yarıçapı bozar)
		moved = maxf(moved, absf(icon.position.length() - TalonFormationMath.SALVO_RADIUS))
		turned = maxf(turned, absf(angle_difference(icon.rotation, slot_rot)))
		last_ang = icon.rotation
	assert(moved > 1.0 or turned > 0.3, "kukla ikonu vuruşta yuvasından görünür şekilde oynamalı: %f / %f" % [moved, turned])
	for i in range(12):
		puppet.call("_update_talon_formation", 0.02)
	var icon0: Node2D = icons[0]
	assert(absf(icon0.position.length() - TalonFormationMath.SALVO_RADIUS) < 0.01, "vuruş bitince ikon yuva yarıçapına döner: %f" % icon0.position.length())
	assert(slot_pos.length() > 0.0)


# ------------------------------------------------------------------ ışın asaları: dümdüz spam

func _beam_weapon(player: Node, key: String) -> Node:
	var w: Node = _weapon(player, key)
	assert(w != null and w.continuous_beam, "%s sürekli ışın silahı olmalı" % key)
	return w


func test_beam_staffs_fire_straight_in_salvo_without_any_enemy() -> void:
	for key in ["lightning_staff", "gokkusagi"]:
		var player: Node = _make_player()
		var w: Node = _beam_weapon(player, key)
		_salvo_face(w, 0.0)
		w._process_continuous_beam(0.016)
		assert(w._beam_fx != null and is_instance_valid(w._beam_fx), "%s: yaratık yokken de ışın açılmalı (menzile yaratık girmesini beklemez)" % key)
		assert(w._beam_hit == null, "%s: boşa giden ışın hiçbir şeye kilitli değil" % key)
		var origin: Vector2 = (w.muzzle if w.muzzle else w.icon_sprite).global_position
		assert(origin.distance_to(w._beam_end) > w.attack_range * 0.5, "%s: ışın menzil boyunca uzanmalı: %f" % [key, origin.distance_to(w._beam_end)])
		assert(((w._beam_end - origin).normalized()).distance_to(Vector2.RIGHT) < 0.02, "%s: ışın ikonun baktığı yöne düz" % key)
		## Silah dönerken ışın peşinden gelir (3 sn'de 2 tur).
		_salvo_face(w, PI * 0.5)
		w._process_continuous_beam(0.016)
		var origin2: Vector2 = (w.muzzle if w.muzzle else w.icon_sprite).global_position
		assert(((w._beam_end - origin2).normalized()).distance_to(Vector2.DOWN) < 0.02, "%s: ışın dönen ikonu izlemeli" % key)
		w._end_beam()
		_cleanup()


func test_beam_hits_only_what_is_on_its_ray_in_salvo() -> void:
	for key in ["lightning_staff", "gokkusagi"]:
		var player: Node = _make_player()
		var w: Node = _beam_weapon(player, key)
		_salvo_face(w, 0.0)
		var origin: Vector2 = (w.muzzle if w.muzzle else w.icon_sprite).global_position
		## Menzilde ama ışının YANINDA duran yaratığa kilitlenmemeli (eski kural: en yakın yaratığa dönüp kilitlenirdi).
		var off_ray: FakeEnemy = _enemy_at(origin + Vector2(30.0, 120.0))
		w._process_continuous_beam(0.016)
		assert(w._beam_hit == null and off_ray.hits.is_empty(), "%s: ışının yanındaki yaratığa kilitlenmemeli" % key)
		## Işının yolundaki yaratık tik anında vurulur.
		var on_ray: FakeEnemy = _enemy_at(origin + Vector2(150.0, 4.0))
		w._process_continuous_beam(0.016)
		assert(w._beam_hit == on_ray, "%s: ışının yolundaki yaratığa değmeli" % key)
		assert(origin.distance_to(w._beam_end) < 200.0, "%s: ışın ilk değdiği yaratıkta biter (temel ışın): %f" % [key, origin.distance_to(w._beam_end)])
		w._beam_tick_timer = 0.0
		w._process_continuous_beam(0.016)
		assert(on_ray.hits.size() >= 1 and off_ray.hits.is_empty(), "%s: tik yalnız ışının değdiği yaratığa" % key)
		w._end_beam()
		_cleanup()


func test_fire_staff_sprays_straight_in_salvo_instead_of_waiting_for_a_target() -> void:
	## Ateş Asası'nın alev püskürtmesi (ates_nefesi: normal atış kapalı, koni en yakın yaratığa) da salvoda ikonun baktığı yöne düz sürer.
	var player: Node = _make_player()
	var w: Node = _weapon(player, "fire_staff")
	var entry: Dictionary = {"key": "fire_staff"}
	EnchantDefs.ensure_trait(entry) ## doğuştan özellik (player.gd _apply_enchant_to_weapon ile aynı)
	w.set_enchant(entry.get("enchant", {}))
	assert(w != null and is_instance_valid(w.enchant_behavior), "Ateş Asası özelliği (ates_nefesi) yüklü olmalı")
	var ench: Node = w.enchant_behavior
	_salvo_face(w, 0.0)
	var origin: Vector2 = w.global_position
	## Konide ve menzilde: ışının yönünde. Menzilde ama konide DEĞİL: yanda (eski kural en yakın yaratığa dönerdi).
	var in_cone: FakeEnemy = _enemy_at(origin + Vector2(70.0, 6.0))
	var beside: FakeEnemy = _enemy_at(origin + Vector2(10.0, 90.0))
	var hit_log: Array = []
	var hits_before: int = in_cone.hits.size()
	## Madde 639: alan alevle birlikte uzar ("start" animasyonu) - püskürtme sürüyormuş gibi (alev tam boyda) başlat.
	ench.set("_last_tick_ms", Time.get_ticks_msec())
	ench.set("_spray_start_ms", Time.get_ticks_msec() - 2000)
	ench.set("_tick_t", 0.0)
	ench.process_extra(0.016)
	assert(ench.aim_target() == null, "salvoda püskürtme yaratığa kilitlenmez (ikon formasyonda kalır)")
	assert(in_cone.hits.size() > hits_before, "ikonun baktığı yöndeki alevde yaratık hasar almalı")
	assert(beside.hits.is_empty(), "konide olmayan (yandaki) yaratığa dönülmemeli")
	hit_log.append(1)
	## Normal modda (salvo dışı) davranış aynı: en yakın yaratığa döner.
	w.fire_in_facing_direction = false
	ench.set("_tick_t", 0.0)
	ench.process_extra(0.016)
	assert(ench.aim_target() != null, "salvo dışında püskürtme en yakın yaratığı hedefler")
	_cleanup()


func test_beam_icon_is_left_to_the_formation_in_salvo() -> void:
	## Eski hata: ışın dalı _update_aim çağırıp ikonu en yakın yaratığa çeviriyordu (formasyon duruşunu bozup ışını yaratığa kilitliyordu).
	var player: Node = _make_player()
	var w: Node = _beam_weapon(player, "lightning_staff")
	_salvo_face(w, 0.0)
	var origin: Vector2 = w.icon_sprite.global_position
	_enemy_at(origin + Vector2(0.0, 150.0)) ## menzilde, ışının tam yanında
	var rot_before: float = w.icon_sprite.rotation
	w._process(0.016)
	assert(absf(w.icon_sprite.rotation - rot_before) < 0.0001, "salvoda ışın silahının ikonu yaratığa çevrilmemeli: %f -> %f" % [rot_before, w.icon_sprite.rotation])
	w._end_beam()
	_cleanup()


func test_beam_without_salvo_still_locks_on_the_enemy() -> void:
	## Normal (salvo dışı) davranış değişmedi: menzildeki yaratığa kilitlenir, yaratık yoksa ışın kapanır.
	var player: Node = _make_player()
	var w: Node = _beam_weapon(player, "lightning_staff")
	w._process_continuous_beam(0.016)
	assert(w._beam_fx == null, "hedef yokken ışın açılmaz")
	var e: FakeEnemy = _enemy_at(w.icon_sprite.global_position + Vector2(80.0, 0.0))
	w._process_continuous_beam(0.016)
	assert(w._beam_fx != null and w._beam_target == e, "menzildeki yaratığa kilitlenir")
	w._end_beam()
	_cleanup()


# ------------------------------------------------------------------ uzak ışın yumuşatma

func test_remote_beam_smoothing_follows_a_spinning_beam() -> void:
	var s = Smooth.new()
	var origin := Vector2(100.0, 100.0)
	var r: float = 300.0
	var spin: float = 4.2 ## rad/sn (Talon E: 3 sn'de 2 tur)
	var worst: float = 0.0
	var prev: Vector2 = Vector2.ZERO
	var t_net: float = 0.0
	s.push(origin, origin + Vector2.from_angle(0.0) * r)
	## 20 Hz ağ güncellemesi, 60 Hz çizim
	for frame in range(1, 90):
		var now: float = float(frame) / 60.0
		if now - t_net >= 0.05 - 0.0001:
			t_net = now
			s.push(origin, origin + Vector2.from_angle(spin * now) * r)
		s.step(1.0 / 60.0)
		var to: Vector2 = s.to_pos()
		if frame > 12:
			worst = maxf(worst, to.distance_to(prev))
		prev = to
	## Ham 20 Hz örnekte çizilen uç 50 ms'de 4,2 x 0,05 x 300 = 63 px sıçrar; yumuşatılmışta kare başına ~21 px (60 Hz'de akıcı).
	assert(worst < 30.0, "uzak ışın ucu kare başına akıcı ilerlemeli: en büyük adım %f px" % worst)
