extends RefCounted

## Aşama 1 - EnemyWorld davranış testleri (harita YÜKLEMEDEN, yapay ızgarayla; ~1 sn). Her test enemy.gd'deki bir kuralı
## C++ çekirdeğinde doğrular (kovalama, duvar dolanma, menzilli dur/atış/görüş, korku, donma/kök, tahrik, Şovalye
## baloncuğu odağı + kalkana saldırı, müttefik önyargısı, ağaç önceliği, hedefsiz dolaşma, itme formülleri, satıcı
## bölgesi, temas aralığı, hayalet, saldırı kilidi).
##
## Test gövdeleri (2026-10-03'ten beri iki çalıştırıcı: tools/enemy_rewrite/test_world_behaviors.gd (SceneTree, ayrıntılı
## çıktı) ve projenin test paketi tests/test_enemy_world.gd). run_all() başarısız sayısını döner.

const DT := 1.0 / 60.0
const CELL := 16.0
const GW := 64
const GH := 64
const BODY := 11.4

var _pass: int = 0
var _fail: int = 0
var _events: Dictionary = {}

# EnemyWorld olay ve bayrak sabitleri (C++ enum'larıyla aynı)
const E_MELEE := 0
const E_BARRIER := 1
const E_GHOST := 2
const E_RANGED := 3
const E_HOMING := 4
const E_TAUNT_LOST := 5
const F_FROZEN := 1 << 1
const F_ROOTED := 1 << 2
const F_ATTACK_LOCK := 1 << 3
const F_RANGED := 1 << 5
const F_BOSS := 1 << 6
const F_GHOST := 1 << 7
const F_FEAR_FLEE := 1 << 10
const F_FEAR_WANDER := 1 << 11
const T_PLAYER := 0
const T_ALLY := 2
const T_TREE := 3


## Tüm testleri koşar; başarısız sayısını döner (her test "PASS ad" / "FAIL ad: neden" yazar).
func run_all() -> int:
	_test_chase_open()
	_test_wall_route()
	_test_ranged_stop_and_fire()
	_test_ranged_no_los()
	_test_fear_flee()
	_test_fear_wander()
	_test_frozen_and_rooted()
	_test_taunt()
	_test_zone_focus_and_barrier()
	_test_ally_bias_and_tree()
	_test_wander()
	_test_knockback_formulas()
	_test_merchant_zone()
	_test_contact_interval()
	_test_ghost()
	_test_attack_lock()
	_test_queries()
	_test_hit_probe()
	_test_query_before_first_step()
	return _fail


# ------------------------------------------------------------------ yardımcılar

func _world(walls: Array = []) -> Object:
	var w: Object = ClassDB.instantiate("EnemyWorld")
	var b := PackedByteArray(); b.resize(GW * GH)
	for c: Vector2i in walls:
		b[c.y * GW + c.x] = 1
	w.call("set_grid", b, Vector2i.ZERO, Vector2i(GW, GH), CELL, Vector2.ZERO)
	w.call("set_seed", 7)
	return w


## targets: [{pos, kind?, targetable?, ghost?, zone?, id?}]
func _targets(w: Object, list: Array) -> void:
	var pos := PackedVector2Array(); var kind := PackedInt32Array(); var tg := PackedByteArray()
	var gh := PackedByteArray(); var body := PackedFloat32Array(); var zone := PackedFloat32Array()
	var ids := PackedInt64Array()
	for i in list.size():
		var d: Dictionary = list[i]
		pos.append(d["pos"]); kind.append(int(d.get("kind", T_PLAYER))); tg.append(1 if d.get("targetable", true) else 0)
		gh.append(1 if d.get("ghost", false) else 0); body.append(BODY); zone.append(float(d.get("zone", 0.0)))
		ids.append(int(d.get("id", i + 1)))
	w.call("set_targets", pos, kind, tg, gh, body, zone, ids)


func _add(w: Object, p: Vector2, params: Dictionary = {}) -> int:
	var prm := {"radius": 14.0, "speed": 60.0, "contact_interval": 1.0}
	prm.merge(params, true)
	return int(w.call("add_enemy", null, null, p, prm))


## frames kare çalıştırır; olayları _events[tür] sayacına ekler. per_frame(Callable) her kareden sonra çağrılır.
func _steps(w: Object, frames: int, per_frame: Callable = Callable()) -> void:
	for f in frames:
		w.call("step", DT)
		var ev: PackedInt32Array = w.call("pop_events")
		var j: int = 0
		while j < ev.size():
			_events[ev[j]] = int(_events.get(ev[j], 0)) + 1
			j += 3
		if per_frame.is_valid():
			per_frame.call()


func _ev(t: int) -> int:
	return int(_events.get(t, 0))


func _check(name: String, ok: bool, why: String) -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		print("FAIL ", name, ": ", why)


func _pos(w: Object, s: int) -> Vector2:
	return w.call("get_position", s)


# ------------------------------------------------------------------ testler

func _test_chase_open() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(800, 500)}])
	var s := _add(w, Vector2(200, 500))
	_steps(w, 180)
	var p := _pos(w, s)
	# 3 sn x 60 px/sn = 180 px düz çizgide, yan sapma yok (zikzak yok)
	_check("kovalama_acik_alan", absf(p.x - 380.0) < 4.0 and absf(p.y - 500.0) < 0.5, "konum %s (beklenen ~(380,500))" % p)
	_check("kovalama_yon_satiri", int(w.call("get_facing_row", s)) == 3, "satır %d (beklenen 3=sağ)" % int(w.call("get_facing_row", s)))


func _test_wall_route() -> void:
	_events = {}
	var walls: Array = []
	for y in range(8, 56):
		walls.append(Vector2i(30, y)); walls.append(Vector2i(31, y))
	var w := _world(walls)
	_targets(w, [{"pos": Vector2(800, 480)}])
	var s := _add(w, Vector2(200, 480))
	var in_wall := [0]
	_steps(w, 60 * 25, func() -> void:
		if w.call("is_solid_at", _pos(w, s)):
			in_wall[0] += 1)
	var d: float = _pos(w, s).distance_to(Vector2(800, 480))
	_check("duvar_dolanma", d < 60.0 and in_wall[0] == 0, "son mesafe %.0f, duvar içi kare %d" % [d, in_wall[0]])


func _test_ranged_stop_and_fire() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(900, 500)}])
	var s := _add(w, Vector2(300, 500), {"flags": F_RANGED, "ranged_range": 200.0, "ranged_interval": 1.0, "homing_interval": 2.0})
	_steps(w, 60 * 12)
	var d: float = _pos(w, s).distance_to(Vector2(900, 500))
	# 600'den yürür, 200'de durur (menzil + görüş var). 500..320 arası garanti isabet, 320 içinde büyü.
	_check("menzilli_durur", d > 196.0 and d <= 201.0, "mesafe %.1f (beklenen ~200)" % d)
	# zaman çizelgesi (tek paylaşılan zamanlayıcı): 1,67 sn garanti (500 px), 3,67 sn garanti (380 px > 320), 5,67 sn'den
	# itibaren her saniye büyü -> 12 sn'de 7 büyü + 2 garanti
	_check("menzilli_atis", _ev(E_RANGED) == 7 and _ev(E_HOMING) == 2 and _ev(E_MELEE) == 0,
			"büyü %d, garanti %d, yakın %d" % [_ev(E_RANGED), _ev(E_HOMING), _ev(E_MELEE)])


func _test_ranged_no_los() -> void:
	_events = {}
	var walls: Array = []
	for y in range(0, 40):
		walls.append(Vector2i(25, y))
	var w := _world(walls)
	_targets(w, [{"pos": Vector2(480, 300)}])
	var s := _add(w, Vector2(330, 300), {"flags": F_RANGED, "ranged_range": 200.0, "ranged_interval": 1.0, "homing_interval": 2.0})
	_steps(w, 60)
	var moved: float = _pos(w, s).distance_to(Vector2(330, 300))
	# hedef 150 px'te (menzil içi) ama duvar arkasında: ateş etmez, durmaz (dolanmaya başlar)
	_check("menzilli_gorus_yok", _ev(E_RANGED) == 0 and _ev(E_HOMING) == 0 and moved > 20.0,
			"büyü %d garanti %d, 1 sn'de yer değiştirme %.1f" % [_ev(E_RANGED), _ev(E_HOMING), moved])


func _test_fear_flee() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(500, 500)}])
	var s := _add(w, Vector2(540, 500), {"flags": F_FEAR_FLEE})
	w.call("set_fear_source", s, Vector2(500, 500))
	_steps(w, 60)
	var d: float = _pos(w, s).distance_to(Vector2(500, 500))
	_check("korku_kacis", d > 95.0 and _ev(E_MELEE) == 0, "mesafe %.1f (beklenen ~100), yakın %d" % [d, _ev(E_MELEE)])


func _test_fear_wander() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(500, 500)}])
	var s := _add(w, Vector2(520, 500), {"flags": F_FEAR_WANDER})
	var prev := [_pos(w, s)]
	var max_v := [0.0]
	_steps(w, 120, func() -> void:
		var p := _pos(w, s)
		max_v[0] = maxf(max_v[0], p.distance_to(prev[0]) / DT)
		prev[0] = p)
	# korku-dolaşma hızı = speed x 0,7 (42), saldırı yok. (Sert yapıştırma yok: hedef yok.)
	_check("korku_dolasma", max_v[0] > 30.0 and max_v[0] <= 42.5 and _ev(E_MELEE) == 0,
			"en yüksek hız %.1f (beklenen <=42), yakın %d" % [max_v[0], _ev(E_MELEE)])


func _test_frozen_and_rooted() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(500, 500)}])
	var a := _add(w, Vector2(530, 500), {"flags": F_FROZEN})
	_steps(w, 120)
	_check("donma", _pos(w, a) == Vector2(530, 500) and _ev(E_MELEE) == 0, "konum %s, yakın %d" % [_pos(w, a), _ev(E_MELEE)])
	_events = {}
	var w2 := _world()
	_targets(w2, [{"pos": Vector2(500, 500)}])
	var b := _add(w2, Vector2(600, 500), {"flags": F_ROOTED})
	var c := _add(w2, Vector2(500, 535), {"flags": F_ROOTED})
	_steps(w2, 120)
	# kök: yürümez ama menzildeyse saldırır (c: 35 px, menzil 14+11,4+26 = 51,4)
	_check("kok", _pos(w2, b) == Vector2(600, 500) and _pos(w2, c) == Vector2(500, 535) and _ev(E_MELEE) >= 2,
			"b %s c %s yakın %d" % [_pos(w2, b), _pos(w2, c), _ev(E_MELEE)])


func _test_taunt() -> void:
	_events = {}
	var w := _world()
	var list := [{"pos": Vector2(400, 500), "id": 11}, {"pos": Vector2(900, 500), "id": 22}]
	_targets(w, list)
	var s := _add(w, Vector2(300, 500))
	w.call("set_taunt", s, 22, 5.0)
	_steps(w, 6)
	var t1: int = w.call("get_target", s)
	list[1]["targetable"] = false
	_targets(w, list)
	_steps(w, 6)
	var t2: int = w.call("get_target", s)
	_check("tahrik", t1 == 1 and t2 == 0 and _ev(E_TAUNT_LOST) == 1,
			"tahrikte hedef %d (beklenen 1), kışkırtan gidince %d (beklenen 0), kayıp olayı %d" % [t1, t2, _ev(E_TAUNT_LOST)])


func _test_zone_focus_and_barrier() -> void:
	_events = {}
	var w := _world()
	# A Şovalye (baloncuk 120), B baloncuğun içinde; yaratık B'ye daha yakın -> hedef A, baloncuğa saldırır
	_targets(w, [{"pos": Vector2(500, 500), "zone": 120.0, "id": 1}, {"pos": Vector2(560, 500), "id": 2}])
	var s := _add(w, Vector2(800, 500))
	_steps(w, 60 * 8)
	var t: int = w.call("get_target", s)
	var d: float = _pos(w, s).distance_to(Vector2(500, 500))
	_check("baloncuk_odagi", t == 0 and d >= 119.5 and _ev(E_BARRIER) >= 2 and _ev(E_MELEE) == 0,
			"hedef %d, A'ya mesafe %.1f (>=120), kalkan %d, yakın %d" % [t, d, _ev(E_BARRIER), _ev(E_MELEE)])


func _test_ally_bias_and_tree() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(600, 500)}, {"pos": Vector2(500, 650), "kind": T_ALLY}])
	var s := _add(w, Vector2(500, 500))
	_steps(w, 4)
	# oyuncu 100 px, müttefik 150 px (<=160 -> x0,35 = 52,5): müttefik
	_check("muttefik_onyargisi", int(w.call("get_target", s)) == 1, "hedef %d (beklenen 1)" % int(w.call("get_target", s)))
	_targets(w, [{"pos": Vector2(600, 500)}, {"pos": Vector2(900, 900), "kind": T_TREE}])
	_steps(w, 4)
	_check("agac_onceligi", int(w.call("get_target", s)) == 1, "hedef %d (beklenen 1 = ağaç)" % int(w.call("get_target", s)))


func _test_wander() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(100, 100), "targetable": false}])
	var s := _add(w, Vector2(500, 500))
	var prev := [_pos(w, s)]
	var max_v := [0.0]
	var moving_frames := [0]
	_steps(w, 60 * 15, func() -> void:
		var p := _pos(w, s)
		var v: float = p.distance_to(prev[0]) / DT
		max_v[0] = maxf(max_v[0], v)
		if v > 1.0:
			moving_frames[0] += 1
		prev[0] = p)
	# dolaşma hızı speed x 0,45 = 27; bazen durur, bazen yürür
	_check("dolasma", bool(w.call("is_wandering", s)) and max_v[0] <= 27.5 and moving_frames[0] > 60 and moving_frames[0] < 60 * 15,
			"dolaşıyor %s, en yüksek hız %.1f, yürüyen kare %d" % [str(w.call("is_wandering", s)), max_v[0], moving_frames[0]])


func _test_knockback_formulas() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(100, 500)}])
	var a := _add(w, Vector2(500, 200), {"speed": 0.0})
	var b := _add(w, Vector2(500, 400), {"speed": 0.0})
	var c := _add(w, Vector2(500, 600), {"speed": 0.0, "flags": F_BOSS})
	var d := _add(w, Vector2(500, 800), {"speed": 0.0})
	_steps(w, 2)
	var a0 := _pos(w, a); var b0 := _pos(w, b); var c0 := _pos(w, c); var d0 := _pos(w, d)
	w.call("apply_knockback_distance", a, Vector2.RIGHT, 100.0) # 100 x 0,2 = 20 px
	w.call("apply_skill_push", b, Vector2.RIGHT, 100.0) # 100 px
	w.call("apply_skill_push", c, Vector2.RIGHT, 100.0) # boss x0,4 = 40 px
	w.call("apply_knockback_force", d, Vector2.RIGHT, 300.0) # 300² / 2800 = 32 px
	_steps(w, 60)
	var da: float = _pos(w, a).x - a0.x; var db: float = _pos(w, b).x - b0.x
	var dc: float = _pos(w, c).x - c0.x; var dd: float = _pos(w, d).x - d0.x
	# ayrık tümleme (enemy.gd ile aynı) yarım adım fazlası verir: v0*dt/2 kadar
	_check("itme_formulleri", absf(da - 20.0) < 3.0 and absf(db - 100.0) < 5.0 and absf(dc - 40.0) < 3.5 and absf(dd - 32.1) < 3.0,
			"mesafe %.1f (20) itme %.1f (100) boss %.1f (40) kuvvet %.1f (32)" % [da, db, dc, dd])
	# tekrar penceresi: 0,7 sn içinde ikinci itiş x0,25
	w.call("apply_knockback_distance", a, Vector2.RIGHT, 100.0)
	var a1 := _pos(w, a)
	w.call("apply_knockback_distance", a, Vector2.RIGHT, 100.0)
	_steps(w, 60)
	_check("itme_tekrar_penceresi", _pos(w, a).x - a1.x < 21.0, "iki hızlı itiş toplam %.1f (tek itişten ~20 fazla olmamalı)" % (_pos(w, a).x - a1.x))


func _test_merchant_zone() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(500, 500), "targetable": false}])
	w.call("set_merchant_zone", true, Vector2(500, 500), 100.0)
	var s := _add(w, Vector2(520, 500))
	_steps(w, 2)
	var d: float = _pos(w, s).distance_to(Vector2(500, 500))
	_check("satici_bolgesi", d >= 99.9, "mesafe %.1f (>=100)" % d)


func _test_contact_interval() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(500, 500)}])
	var _s := _add(w, Vector2(540, 500), {"contact_interval": 1.0})
	_steps(w, 60 * 5)
	_check("temas_araligi", _ev(E_MELEE) >= 5 and _ev(E_MELEE) <= 6, "yakın %d (beklenen 5-6)" % _ev(E_MELEE))


func _test_ghost() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(500, 500)}])
	var _s := _add(w, Vector2(540, 500), {"flags": F_GHOST})
	_steps(w, 30)
	_check("hayalet", _ev(E_GHOST) >= 1 and _ev(E_MELEE) == 0, "ortaya çıkma %d, yakın %d" % [_ev(E_GHOST), _ev(E_MELEE)])


func _test_attack_lock() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(900, 500)}])
	var s := _add(w, Vector2(300, 500), {"flags": F_ATTACK_LOCK})
	_steps(w, 60)
	_check("saldiri_kilidi", _pos(w, s).distance_to(Vector2(300, 500)) < 0.5, "yer değiştirme %.2f" % _pos(w, s).distance_to(Vector2(300, 500)))


func _test_queries() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(100, 100), "targetable": false}])
	var na := Node2D.new(); var nb := Node2D.new(); var nc := Node2D.new(); var nd := Node2D.new()
	## düğüm konumu C++'ınkiyle aynı olmalı (adım başı "dışarıdan taşındı mı" kontrolü düğümü okur)
	na.position = Vector2(300, 500); nb.position = Vector2(600, 505); nc.position = Vector2(800, 530); nd.position = Vector2(450, 500)
	var a := int(w.call("add_enemy", na, null, Vector2(300, 500), {"radius": 14.0, "speed": 0.0}))
	var b := int(w.call("add_enemy", nb, null, Vector2(600, 505), {"radius": 14.0, "speed": 0.0}))
	var _c := int(w.call("add_enemy", nc, null, Vector2(800, 530), {"radius": 14.0, "speed": 0.0}))
	var d := int(w.call("add_enemy", nd, null, Vector2(450, 500), {"radius": 14.0, "speed": 0.0}))
	_steps(w, 1)
	w.call("set_flags", d, 1) # F_DEAD: sorgulara girmez
	var seg: Array = w.call("query_segment", Vector2(0, 500), Vector2(1000, 500), 3.0)
	# a (300) ve b (600, 5 px yukarı - 3+14 içinde) sırayla; c 30 px uzakta (ıska); d ölü
	_check("sorgu_segment", seg.size() == 2 and seg[0] == na and seg[1] == nb, "sonuç %s" % str(seg))
	var rev: Array = w.call("query_segment", Vector2(1000, 500), Vector2(0, 500), 3.0)
	_check("sorgu_segment_ters_sira", rev.size() == 2 and rev[0] == nb and rev[1] == na, "sonuç %s" % str(rev))
	var circ: Array = w.call("query_circle", Vector2(600, 500), 10.0)
	_check("sorgu_cember", circ.size() == 1 and circ[0] == nb, "sonuç %s" % str(circ))
	# kova adım başında kuruldu; yaratık sonradan 12 px kaysa da bulunur (sorgu payı)
	w.call("set_position", a, Vector2(312, 500))
	na.position = Vector2(312, 500)
	var moved: Array = w.call("query_circle", Vector2(312, 500), 1.0)
	_check("sorgu_kayan_yaratik", moved.size() == 1 and moved[0] == na, "sonuç %s" % str(moved))
	for n in [na, nb, nc, nd]:
		n.free()


func _test_hit_probe() -> void:
	_events = {}
	var w := _world()
	_targets(w, [{"pos": Vector2(500, 500)}])
	# temas aralığı 10 sn. Oyuncu doğumda zaten içeride: Area2D ilk fizik adımında body_entered verir -> ilk saldırıdan
	# hemen sonra zamanlayıcı sıfırlanır, 2. saldırı (eski yolda da aynı). Sonra çıkıp yeniden girince bir saldırı daha.
	var _s := _add(w, Vector2(540, 500), {"contact_interval": 10.0, "hit_radius": 50.0, "speed": 0.0})
	w.call("set_hit_probe", Vector2(500, 500), 8.0)
	_steps(w, 30)
	var first: int = _ev(E_MELEE)
	w.call("set_hit_probe", Vector2(500, 500), -1.0) # çıktı (ör. çarpışması kapandı)
	_steps(w, 2)
	w.call("set_hit_probe", Vector2(500, 500), 8.0) # yeniden girdi
	_steps(w, 3)
	_check("temas_alani_sifirlama", first == 2 and _ev(E_MELEE) == 3, "ilk %d, yeniden girişten sonra toplam %d (beklenen 2 / 3)" % [first, _ev(E_MELEE)])


## Adımdan SONRA kaydolan (ve doğumda add_child sonrası taşınan) yaratık, ilk adımı beklemeden sorgularda bulunmalı
## (2026-10-03: kova ızgarası yalnızca adım başında kuruluyordu - yeni doğan yaratık 1 kare hedeflenemiyordu).
func _test_query_before_first_step() -> void:
	var w := _world()
	_targets(w, [{"pos": Vector2(2000, 2000)}])
	var n := Node2D.new()
	var s := int(w.call("add_enemy", n, null, Vector2.ZERO, {"radius": 14.0, "speed": 60.0}))
	var near: Array = w.call("query_points", Vector2.ZERO, 30.0)
	var ok1: bool = near.size() == 1 and near[0] == n
	## düğüm ağaçta değilse konum tazelenmez - kayıt konumu geçerli; ağaçtaki taşıma test_weapon_frozen_targeting'de sınanıyor
	var far: Array = w.call("query_points", Vector2(500, 0), 30.0)
	w.call("remove_enemy", s)
	var gone: Array = w.call("query_points", Vector2.ZERO, 30.0)
	_check("sorgu_ilk_adimdan_once", ok1 and far.is_empty() and gone.is_empty(),
			"yeni=%d uzak=%d silinen=%d" % [near.size(), far.size(), gone.size()])
	n.free()
