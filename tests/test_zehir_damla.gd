extends Node

## Zehir Asası "A - Zehir Damlası" (madde 410): mermi gövdesi zehir damlası (iz şeridi yok), kuyruktan kopan damlalar uçuşun altındaki
## zemine düşüp gölcük olur, isabette taç sıçraması + büyük gölcük (eski fx_poison_hit yok), asa ucundan sahibin ayak hizasına damla,
## geri tepme asa gibi (namlu kalkar, kritik "recoil").
## Madde 749: mermi / iz / isabet / sıçrama artık "B - Kabarcık" (asa ucu damlası ve trail_drop yolu duruyor).

const PoisonDripFx := preload("res://scripts/poison_drip_fx.gd")
const StaffTipFx := preload("res://scripts/staff_tip_fx.gd")
const ShellCasingFx := preload("res://scripts/shell_casing_fx.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const WeaponJuice := preload("res://scripts/weapon_juice.gd")
const WeaponCritAnim := preload("res://scripts/weapon_crit_anim.gd")
const DartScene: PackedScene = preload("res://scenes/dart_projectile.tscn")

const STEP := 1.0 / 60.0

var _made: Array[Node] = []


func _scene() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	return get_tree().current_scene


func _mgr() -> Node:
	return _scene().get_node_or_null(PoisonDripFx.NODE_NAME)


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	var m: Node = _mgr()
	if m != null:
		m.free()
	var g: Node = _scene().get_node_or_null("PoisonDripGround")
	if g != null:
		g.free()


func _run(m: Node, sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		m.call("_process", STEP)
		t += STEP


func test_trail_drop_falls_to_the_ground_under_the_flight_and_puddle_fades() -> void:
	_cleanup()
	assert(is_equal_approx(PoisonDripFx.trail_height(0.0), PoisonDripFx.H_START), "silahtan çıkışta yükseklik")
	assert(is_equal_approx(PoisonDripFx.trail_height(999.0), PoisonDripFx.H_END), "uzakta hedefin gövdesi")
	PoisonDripFx.trail_drop(get_tree(), Vector2(100, 100), Vector2.RIGHT, 0.0)
	var m: Node = _mgr()
	assert(m != null and int(m.call("drop_count")) == 1, "damla doğdu")
	var d: Dictionary = (m.get("_drops") as Array)[0]
	assert(is_equal_approx((d["g"] as Vector2).y, 100.0 + PoisonDripFx.H_START), "zemin uçuşun H_START altında")
	_run(m, 1.0)
	assert(int(m.call("drop_count")) == 0 and int(m.call("puddle_count")) == 1, "damla yere indi, gölcük oldu")
	var p: Dictionary = (m.get("_puddles") as Array)[0]
	assert(absf((p["p"] as Vector2).y - (100.0 + PoisonDripFx.H_START)) <= 0.5, "gölcük düştüğü zeminde")
	assert(int(p["k"]) == PoisonDripFx.K_PUDDLE, "küçük gölcük")
	_run(m, PoisonDripFx.PUDDLE_LIFE)
	assert(int(m.call("puddle_count")) == 0, "gölcük söndü")
	assert(not m.is_processing(), "boşken işlemez")
	_cleanup()


func test_drop_and_puddle_caps_drop_the_oldest() -> void:
	_cleanup()
	for i in PoisonDripFx.MAX_DROPS + 20:
		PoisonDripFx.trail_drop(get_tree(), Vector2(float(i), 0.0), Vector2.RIGHT, 0.0)
	assert(int(_mgr().call("drop_count")) == PoisonDripFx.MAX_DROPS, "damla tavanı")
	for i in PoisonDripFx.MAX_PUDDLES + 20:
		_mgr().call("_add_puddle", Vector2(float(i), 0.0), PoisonDripFx.K_PUDDLE, 1.0)
	assert(int(_mgr().call("puddle_count")) == PoisonDripFx.MAX_PUDDLES, "gölcük tavanı")
	_cleanup()


## Sahneye eklenmiş, sahne yolu verilen (tek seferlik efekt) düğümler.
func _fx_nodes(path: String) -> Array:
	var out: Array = []
	for c: Node in _scene().get_children():
		if c.scene_file_path == path and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _free_fx() -> void:
	for path in ["res://scenes/fx_hit_kabarcik.tscn", "res://scenes/fx_zehir_bulut.tscn", "res://scenes/fx_namlu_kabarcik.tscn"]:
		for n: Node in _fx_nodes(path):
			n.free()


## Madde 749 (kullanıcı "B - Kabarcık"ı seçti): gövde dönmeyen, esneyen zehir kabarcığı (1 dünya px pikseli), arkada kabaran puflar
## (yerde bir şey kalmaz), namlu pufu, isabette fx_hit_kabarcik gövde hizasında (taç sıçraması / gölcük artık yok).
func test_dart_flies_as_a_poison_bubble_puffs_and_pops() -> void:
	_cleanup()
	_free_fx()
	var dart: Node2D = DartScene.instantiate()
	dart.set("impact_sounds", [] as Array[AudioStream])
	dart.scale = Vector2(0.5, 0.5) ## oyuncunun attığı mermi kökü sahibin ölçeğinde (0,5)
	_scene().add_child(dart)
	_made.append(dart)
	dart.global_position = Vector2(200, 200)
	dart.set("direction", Vector2(0.6, 0.8))
	var body: AnimatedSprite2D = dart.get("_art_body") as AnimatedSprite2D
	assert(body != null and (body.sprite_frames.get_frame_texture(&"fly", 0) as AtlasTexture).atlas.resource_path.ends_with("mermi/kabarcik_govde.png"),
			"gövde zehir kabarcığı")
	assert(body.sprite_frames.get_frame_count(&"fly") == 6 and body.is_playing(), "kabarcık esner (6 karelik döngü)")
	var old_bullet: Sprite2D = dart.get_node_or_null("Bullet") as Sprite2D
	assert(old_bullet == null or not old_bullet.visible, "eski tek kareli gövde gizli")
	assert(dart.get("_trail") == null and dart.get_node_or_null("ArtTrail") == null, "iz şeridi yok")
	for i in 12:
		dart.call("_physics_process", STEP)
	assert(body.visible and is_equal_approx(body.global_rotation, 0.0), "kabarcık görünür ve dönmez")
	assert(is_equal_approx(body.global_scale.x, 1.0), "1 sanat pikseli = 1 dünya birimi")
	assert(_fx_nodes("res://scenes/fx_namlu_kabarcik.tscn").size() == 1, "namlu pufu bir kez")
	var m: Node = _mgr()
	assert(m != null and int(m.call("puff_count")) >= 3, "0,2 sn uçuşta puf izi: %d" % (int(m.call("puff_count")) if m else -1))
	assert(int(m.call("drop_count")) == 0 and int(m.call("puddle_count")) == 0, "damla / gölcük yok")
	var first: Dictionary = (m.get("_puffs") as Array)[0]
	assert((first["g"] as Vector2).y < dart.global_position.y, "puf kabarcığın gerisinde")
	_run(m, PoisonDripFx.PUFF_LIFE + 0.05)
	assert(int(m.call("puff_count")) == 0, "puflar söner (yerde kalmaz)")
	dart.global_position = Vector2(400, 300) ## kaster: isabette mermi yaratığın konumuna (ayak) ışınlanır
	dart.call("_spawn_impact")
	var hits: Array = _fx_nodes("res://scenes/fx_hit_kabarcik.tscn")
	assert(hits.size() == 1, "isabette kabarcık kırılır")
	assert(((hits[0] as Node2D).global_position - Vector2(400, 290)).length() < 0.01, "isabet gövde hizasında (ayağın 10 üstü)")
	assert(int(m.call("drop_count")) == 0 and int(m.call("puddle_count")) == 0, "taç sıçraması / gölcük yok")
	_free_fx()
	_cleanup()


## Sıçrayan Zehir damlası artık kabarcık: kalkışta cesetten zehir bulutu, yolda puf, varışta isabetin kırılması (gölcük yok).
func test_leap_is_a_bubble_with_cloud_and_pop() -> void:
	_cleanup()
	_free_fx()
	PoisonDripFx.leap(get_tree(), Vector2(100, 100), Vector2(180, 120), 0.28)
	var m: Node = _mgr()
	var clouds: Array = _fx_nodes("res://scenes/fx_zehir_bulut.tscn")
	assert(clouds.size() == 1 and ((clouds[0] as Node2D).global_position - Vector2(100, 90)).length() < 0.01, "cesetten bulut")
	_run(m, 0.15)
	assert(int(m.call("leap_count")) == 1 and int(m.call("puff_count")) >= 2, "kabarcık uçuyor, puf bırakıyor")
	_run(m, 0.2)
	assert(int(m.call("leap_count")) == 0, "vardı")
	var hits: Array = _fx_nodes("res://scenes/fx_hit_kabarcik.tscn")
	assert(hits.size() == 1 and ((hits[0] as Node2D).global_position - Vector2(180, 110)).length() < 0.01, "varışta kırılma")
	assert(int(m.call("drop_count")) == 0 and int(m.call("puddle_count")) == 0, "taç sıçraması / gölcük yok")
	_free_fx()
	_cleanup()


func test_staff_tip_drips_to_the_owner_feet() -> void:
	_cleanup()
	var owner_body := CharacterBody2D.new()
	owner_body.scale = Vector2(0.5, 0.5)
	_scene().add_child(owner_body)
	_made.append(owner_body)
	owner_body.global_position = Vector2(300, 300)
	var icon := Sprite2D.new()
	owner_body.add_child(icon)
	assert(WeaponTierArt.set_art(icon, "tuftuf"), "Zehir Asası çizimi")
	icon.global_position = Vector2(300, 240)
	var fx: Node2D = StaffTipFx.attach(icon, "tuftuf")
	assert(fx != null and str(fx.get("style")) == "poison", "Zehir Asası ucunda damla stili")
	_made.append(fx)
	await get_tree().process_frame
	for i in 150:
		fx.call("_process", STEP)
	var m: Node = _mgr()
	assert(m != null and int(m.call("drop_count")) + int(m.call("puddle_count")) >= 2, "2,5 sn'de seyrek damla")
	var feet: float = ShellCasingFx.ground_y(owner_body)
	var ok: bool = false
	for d: Dictionary in m.get("_drops"):
		ok = ok or absf((d["g"] as Vector2).y - feet) < 0.01
	for p: Dictionary in m.get("_puddles"):
		ok = ok or absf((p["p"] as Vector2).y - feet) <= 0.5
	assert(ok, "damla sahibin ayak hizasına (%.1f) düşer" % feet)
	_cleanup()


func test_recoil_is_staff_like() -> void:
	assert(float((WeaponJuice.RANGED_RECOIL["tuftuf"] as Dictionary)["rot"]) > 0.0, "normal atışta baş kalkar")
	assert(str((WeaponCritAnim.STYLES["tuftuf"] as Dictionary)["kind"]) == "recoil", "kritikte asa geri tepmesi (üfleme yok)")
