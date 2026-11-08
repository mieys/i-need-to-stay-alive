extends Node

## Zehir Asası "A - Zehir Damlası" (madde 410): mermi gövdesi zehir damlası (iz şeridi yok), kuyruktan kopan damlalar uçuşun altındaki
## zemine düşüp gölcük olur, isabette taç sıçraması + büyük gölcük (eski fx_poison_hit yok), asa ucundan sahibin ayak hizasına damla,
## geri tepme asa gibi (namlu kalkar, kritik "recoil").

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


func test_dart_flies_as_a_poison_drop_drips_and_splashes() -> void:
	_cleanup()
	var dart: Node2D = DartScene.instantiate()
	dart.set("impact_sounds", [] as Array[AudioStream])
	_scene().add_child(dart)
	_made.append(dart)
	dart.global_position = Vector2(200, 200)
	dart.set("direction", Vector2.RIGHT)
	var body: Sprite2D = dart.get("_art_body") as Sprite2D
	assert(body != null and body.texture.resource_path.ends_with("mermi/zehir_govde.png"), "gövde zehir damlası")
	assert(dart.get("_trail") == null and dart.get_node_or_null("ArtTrail") == null, "iz şeridi yok")
	for i in 12:
		dart.call("_physics_process", STEP)
	assert(body.visible and is_equal_approx(body.global_rotation, 0.0), "gövde uçuş yönünde görünür")
	var m: Node = _mgr()
	assert(m != null and int(m.call("drop_count")) >= 4, "0,2 sn uçuşta kuyruktan damla koptu: %d" % (int(m.call("drop_count")) if m else -1))
	var first: Dictionary = (m.get("_drops") as Array)[0]
	assert((first["g"] as Vector2).x < dart.global_position.x, "damla kuyrukta (merminin gerisinde)")
	var before: int = int(m.call("drop_count"))
	dart.global_position = Vector2(400, 300) ## kaster: isabette mermi yaratığın konumuna (ayak) ışınlanır
	dart.call("_spawn_impact")
	assert(int(m.call("drop_count")) == before + PoisonDripFx.SPLASH_N, "taç sıçraması")
	var big: int = 0
	for p: Dictionary in m.get("_puddles"):
		if int(p["k"]) == PoisonDripFx.K_PUDDLE_BIG:
			big += 1
			assert(absf((p["p"] as Vector2).y - 301.0) <= 0.5, "büyük gölcük ayak hizasında")
	assert(big == 1, "isabette büyük gölcük")
	var splash: Array = (m.get("_drops") as Array).slice(before)
	for d: Dictionary in splash:
		assert(float(d["vz"]) > 0.0, "sıçrama damlası yukarı fırlar")
		assert(float(d["z"]) >= PoisonDripFx.SPLASH_BODY - 3.0, "gövdeden (ayağın üstünden) çıkar")
	assert(get_tree().get_node_count_in_group("impact_fx_fx_poison_hit.tscn") == 0, "eski zehir patlaması yok")
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
