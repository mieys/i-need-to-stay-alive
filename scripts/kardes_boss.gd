extends RefCounted

## ÜÇ KARDEŞ (ana haritanın SON bossu, Kademe 10; kullanıcı isteği 2026-11-14): Kılıç / Ok / Büyü Kardeş TEK bir bossu temsil eder - üçü birlikte doğar,
## canları ve kalkanları üst bardaki ORTAK barın 3 parçasıdır (boss_bar_top.gd trio_entry). Kullanıcı: "oyundaki en zor boss olmalı".
## Bir kardeş ölünce (kullanıcı seçimi "Ölür, kalanlar öfkelenir") kalanlar ÖFKELENİR (on_sibling_died): hasar / hız / yetenek sıklığı artar, kalkanları
## bir miktar dolar ve ölen kardeşin imza yeteneğini devralırlar (Kılıç -> Atılma, Ok -> Ok Yağmuru, Büyü -> Meteor). Son kalan en tehlikelisidir.
## SADECE host / tek oyunculuda çalışır (enemy_abilities.gd "kardes_*" aileleri). Görseller istemcilere: özel animasyon boss_event "anim",
## mermi/alan efektleri broadcast_enemy_ability_fx ("kardes_shot" / "kardes_zone" / "charge_lane"), atılma sırasında ağ hızı tavanı boss_event "netcap",
## ışınlanma boss_event "warp" (enemy.gd on_ability_vfx).
##   KILIÇ KARDEŞ (yakın dövüş, çevik): ATILMA KESİĞİ (şerit uyarısı -> 2 zincir atılma, yolundakine kanama), KASIRGA (yakındaki herkese alan + savurma),
##     KILIÇ DALGASI (uzaktaki hedefe zemin boyunca ilerleyen 4 kesik). Normal saldırı = C++ temas.
##   OK KARDEŞ (vur-kaç, menzil tutar - sahnede is_ranged): SALVO (3-5 ok yelpaze), OK YELPAZESİ (11 ok), OK YAĞMURU (her oyuncunun çevresine düşen oklar),
##     GERİ SIÇRAMA (yakına gelen oyuncudan geri atlar + anında salvo).
##   BÜYÜ KARDEŞ (elemental): ATEŞ TOPLARI (3'lü, yanma), BUZ HALKASI (2 halka buz oku, yavaşlatma), YILDIRIM (her oyuncuya 3 ardışık çarpma, kısa sersemleme),
##     BUZ DİKENİ HATTI (hedefe doğru ilerleyen diken sırası), METEOR YAĞMURU (büyük + 4 küçük alan, yanma), IŞINLANMA (yakına gelen oyuncudan kaçar).
## Hasar sabitleri Kademe 10 için yazıldı (BOSS_HOME_TIER 10 -> çarpan 1,0); öfke çarpanı _rage_mult. Sayılar tek yerde (sabitler), kullanıcı oynayıp ayarlar.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const MinoMath := preload("res://scripts/minotaur_math.gd")

const ROLE_KILIC := "kardes_kilic"
const ROLE_OK := "kardes_ok"
const ROLE_BUYU := "kardes_buyu"
## Bar sırası (soldan sağa) = bu sıra. enemy_spawner NEW_BOSS_TIERS[10] ve boss_bar_top.gd aynı listeyi kullanır.
const TRIO_IDS := ["kardes_kilic1", "kardes_ok1", "kardes_buyu1"]
const GROUP := "kardes_boss"
## Ölen kardeşin kalanlara bıraktığı imza yeteneği.
const LEGACY := {ROLE_KILIC: "dash", ROLE_OK: "rain", ROLE_BUYU: "meteor"}

## --- öfke (kardeş başına bir kademe; iki kardeş ölünce 2) ---
const RAGE_DAMAGE_STEP := 0.25   ## hasar +%25 / kademe (temas + yetenekler)
const RAGE_SPEED_STEP := 0.15    ## yürüme +%15 / kademe
const RAGE_CD_STEP := 0.30       ## bekleme sayaçları %30 daha hızlı akar / kademe
const RAGE_SHIELD_REFILL := 0.35 ## kalanların kalkanı azami kalkanın %35'i kadar dolar

## --- KILIÇ ---
const DASH_DAMAGE := 190.0
const DASH_CD := Vector2(5.0, 6.5)
const DASH_RANGE := Vector2(90.0, 560.0)  ## hedef bu aralıktayken atılır
const DASH_WARN := 0.45
const DASH_WARN_CHAIN := 0.28   ## zincirdeki sonraki atılmaların uyarısı
const DASH_LEN := 400.0
const DASH_SPEED := 1150.0
const DASH_WIDTH := 64.0
const DASH_CHAIN := 2           ## bir dizideki atılma sayısı (+1 / öfke kademesi)
const DASH_PAUSE := 0.22
const SPIN_DAMAGE := 230.0
const SPIN_CD := Vector2(4.0, 5.5)
const SPIN_TRIGGER := 150.0
const SPIN_RADIUS := 130.0
const SPIN_WARN := 0.55
const SPIN_FLING := 150.0
const WAVE_DAMAGE := 150.0
const WAVE_CD := Vector2(7.0, 9.0)
const WAVE_MIN := 300.0
const WAVE_RANGE := 700.0
const WAVE_COUNT := 5
const WAVE_STEP := 70.0
const WAVE_RADIUS := 40.0

## --- OK ---
const ARROW_DAMAGE := 85.0
const ARROW_SPEED := 560.0
const VOLLEY_CD := Vector2(1.3, 1.7)
const VOLLEY_RANGE := 620.0
const VOLLEY_ARROWS := 3        ## +1 / öfke kademesi
const VOLLEY_SPREAD_DEG := 9.0  ## oklar arası açı
const FAN_CD := Vector2(7.0, 9.0)
const FAN_ARROWS := 11
const FAN_ARC_DEG := 80.0
const RAIN_DAMAGE := 140.0
const RAIN_CD := Vector2(10.0, 12.0)
const RAIN_RANGE := 800.0
const RAIN_PER_PLAYER := 5
const RAIN_RADIUS := 48.0
const RAIN_WARN := 1.0
const LEAP_CD := Vector2(4.5, 6.0)
const LEAP_TRIGGER := 160.0
const LEAP_LEN := 250.0
const LEAP_SPEED := 900.0

## --- BÜYÜ ---
const FIRE_DAMAGE := 120.0
const FIRE_SPLASH := 60.0       ## patlama alanı (vurduğu yerde çevresine)
const FIRE_SPEED := 340.0
const FIRE_CD := Vector2(2.4, 3.0)
const FIRE_RANGE := 650.0
const FIRE_COUNT := 3
const FIRE_GAP := 0.18
const ICE_DAMAGE := 85.0
const ICE_SPEED := 300.0
const ICE_CD := Vector2(8.0, 10.0)
const ICE_RANGE := 420.0
const ICE_PER_RING := 14
const BOLT_DAMAGE := 150.0
const BOLT_CD := Vector2(7.0, 9.0)
const BOLT_RANGE := 750.0
const BOLT_STRIKES := 3
const BOLT_RADIUS := 44.0
const BOLT_WARN := 0.7
const BOLT_GAP := 0.38
const SPIKE_DAMAGE := 130.0
const SPIKE_CD := Vector2(9.0, 11.0)
const SPIKE_RANGE := 520.0
const SPIKE_COUNT := 10
const SPIKE_STEP := 46.0
const SPIKE_RADIUS := 34.0
const SPIKE_WARN := 0.5
const METEOR_DAMAGE := 300.0
const METEOR_SMALL_DAMAGE := 160.0
const METEOR_CD := Vector2(13.0, 16.0)
const METEOR_RANGE := 800.0
const METEOR_RADIUS := 120.0
const METEOR_SMALL_RADIUS := 60.0
const METEOR_WARN := 1.6
const BLINK_CD := Vector2(6.0, 8.0)
const BLINK_TRIGGER := 130.0
const BLINK_DIST := 280.0

var e: Node2D = null
var role: String = ""
var _rage: int = 0
var _inherited: Array = []
var _cd: Dictionary = {}
var _busy: float = 0.0
var _queue: Array = []
var _last_pos: Dictionary = {}
var _vel: Dictionary = {}
## Elle sürülen hareket (atılma / geri sıçrama): {"dir", "left", "speed", "dmg", "ids", "then"}; boş = yok
var _move: Dictionary = {}
var _dash_chain: int = 0
var _base_contact: float = -1.0
var _base_speed: float = -1.0
## Testler duvar sorgusunu değiştirebilir (oyunda GameManager.is_position_blocked_by_walls).
var blocked_override: Callable = Callable()


func setup(owner_enemy: Node2D, fam: String) -> void:
	e = owner_enemy
	role = fam
	e.add_to_group(GROUP)
	match role:
		ROLE_KILIC:
			_cd = {"dash": 2.5, "spin": 1.5, "wave": 5.0}
		ROLE_OK:
			_cd = {"volley": 1.0, "fan": 4.0, "rain": 6.0, "leap": 0.0}
		_:
			_cd = {"fire": 1.5, "ice": 5.0, "bolt": 3.5, "spike": 6.5, "meteor": 9.0, "blink": 0.0}


## Atılma sırasında yakın dövüş (C++ temas) vuruşu yok - isabet atılmanın kendisi.
func blocks_melee() -> bool:
	return not _move.is_empty()


func rage_level() -> int:
	return _rage


func inherited() -> Array:
	return _inherited.duplicate()


func process(delta: float, _player: Node2D, _dist: float) -> void:
	if e == null or not is_instance_valid(e):
		return
	_track(delta)
	_run_queue(delta)
	if role != ROLE_KILIC:
		e.set("_ranged_timer", 5.0) ## menzil tutma C++'ta (is_ranged), atışlar bu kitte: C++'ın düz büyü mermisi hiç ateşlenmesin
	if not _move.is_empty():
		_move_step(delta)
		return
	if _busy > 0.0:
		_busy -= delta
		return
	var cd_rate: float = 1.0 + RAGE_CD_STEP * float(_rage)
	for k in _cd.keys():
		_cd[k] = float(_cd[k]) - delta * cd_rate
	match role:
		ROLE_KILIC:
			_think_kilic()
		ROLE_OK:
			_think_ok()
		_:
			_think_buyu()
	if _busy <= 0.0 and _move.is_empty():
		_think_inherited()


# ---------------------------------------------------------------------------------------------------- karar
func _ready_cd(key: String) -> bool:
	return float(_cd.get(key, 1.0)) <= 0.0


func _set_cd(key: String, range_: Vector2) -> void:
	_cd[key] = randf_range(range_.x, range_.y)


func _think_kilic() -> void:
	var near: Node2D = _nearest_target(INF)
	if near == null:
		return
	var d: float = near.global_position.distance_to(e.global_position)
	if _ready_cd("spin") and d <= SPIN_TRIGGER:
		_begin_spin()
	elif _ready_cd("dash") and d >= DASH_RANGE.x and d <= DASH_RANGE.y:
		_begin_dash_chain(near, DASH_CHAIN + _rage)
	elif _ready_cd("wave") and d >= WAVE_MIN and d <= WAVE_RANGE:
		_begin_wave(near)


func _think_ok() -> void:
	var near: Node2D = _nearest_target(INF)
	if near == null:
		return
	var d: float = near.global_position.distance_to(e.global_position)
	if _ready_cd("leap") and d <= LEAP_TRIGGER:
		_begin_leap(near)
	elif _ready_cd("rain") and d <= RAIN_RANGE:
		_begin_rain()
	elif _ready_cd("fan") and d <= VOLLEY_RANGE:
		_begin_fan(near)
	elif _ready_cd("volley") and d <= VOLLEY_RANGE:
		_begin_volley(near, VOLLEY_ARROWS + _rage)


func _think_buyu() -> void:
	var near: Node2D = _nearest_target(INF)
	if near == null:
		return
	var d: float = near.global_position.distance_to(e.global_position)
	if _ready_cd("blink") and d <= BLINK_TRIGGER:
		_begin_blink(near)
	elif _ready_cd("meteor") and d <= METEOR_RANGE:
		_begin_meteor(near)
	elif _ready_cd("bolt") and d <= BOLT_RANGE:
		_begin_bolts()
	elif _ready_cd("ice") and d <= ICE_RANGE:
		_begin_ice_rings()
	elif _ready_cd("spike") and d <= SPIKE_RANGE:
		_begin_spikes(near)
	elif _ready_cd("fire") and d <= FIRE_RANGE:
		_begin_fireballs(near)


## Ölen kardeşten devralınan imza yetenekleri (kendi sayaçlarıyla, rolün kendi yeteneklerinden sonra denenir).
func _think_inherited() -> void:
	for skill: String in _inherited:
		if not _ready_cd("legacy_" + skill):
			continue
		var near: Node2D = _nearest_target(INF)
		if near == null:
			return
		var d: float = near.global_position.distance_to(e.global_position)
		match skill:
			"dash":
				if d >= DASH_RANGE.x and d <= DASH_RANGE.y:
					_cd["legacy_dash"] = randf_range(DASH_CD.x, DASH_CD.y) * 1.4
					_begin_dash_chain(near, 1, false)
					return
			"rain":
				if d <= RAIN_RANGE:
					_cd["legacy_rain"] = randf_range(RAIN_CD.x, RAIN_CD.y) * 1.3
					_begin_rain(false)
					return
			"meteor":
				if d <= METEOR_RANGE:
					_cd["legacy_meteor"] = randf_range(METEOR_CD.x, METEOR_CD.y) * 1.3
					_begin_meteor(near, false)
					return


# ---------------------------------------------------------------------------------------------------- öfke
## Bir kardeş öldü (ölen kardeşin kiti on_owner_died'da çağırır; yalnız host): öfke kademesi, imza yeteneği, kalkan dolumu.
func on_sibling_died(dead_role: String) -> void:
	if e == null or not is_instance_valid(e) or e.get("is_dead") == true:
		return
	if e.has_method("_ew_wake"):
		e.call("_ew_wake")
	if _base_contact < 0.0:
		_base_contact = float(e.get("contact_damage"))
		_base_speed = float(e.get("speed"))
	_rage += 1
	e.set("contact_damage", _base_contact * _rage_mult())
	e.set("speed", _base_speed * (1.0 + RAGE_SPEED_STEP * float(_rage)))
	var legacy: String = str(LEGACY.get(dead_role, ""))
	if legacy != "" and legacy != _own_signature() and not _inherited.has(legacy):
		_inherited.append(legacy)
		_cd["legacy_" + legacy] = 2.0
	var sh_max: float = float(e.get("item_shield_max"))
	if sh_max > 0.0:
		e.set("item_shield_hp", minf(sh_max, float(e.get("item_shield_hp")) + sh_max * RAGE_SHIELD_REFILL))
		if e.has_signal("item_shield_changed"):
			e.emit_signal("item_shield_changed", e.get("item_shield_hp"), sh_max)
	## Öfke işareti (herkeste): alevli patlama + büyü pozu
	_spawn("kardes_zone", e.global_position, {"style": "rage", "warn": 0.0, "radius": 0.0}, 0.0)
	_anim("cast", 0.6)
	_busy = maxf(_busy, 0.5)


func _rage_mult() -> float:
	return 1.0 + RAGE_DAMAGE_STEP * float(_rage)


func _own_signature() -> String:
	return str(LEGACY.get(role, ""))


## Sahip öldü: kalan kardeşleri öfkelendir.
func on_owner_died() -> void:
	if e == null or not is_instance_valid(e) or not e.is_inside_tree():
		return
	for n: Node in e.get_tree().get_nodes_in_group(GROUP):
		if n == e or not is_instance_valid(n) or n.get("is_dead") == true:
			continue
		var ab = n.get("_abilities")
		if ab == null:
			continue
		var kit = ab.get("_boss_kit")
		if kit != null and kit.has_method("on_sibling_died"):
			kit.on_sibling_died(role)


# ---------------------------------------------------------------------------------------------------- KILIÇ
func _begin_dash_chain(target: Node2D, count: int, own: bool = true) -> void:
	if own:
		_set_cd("dash", DASH_CD)
	_dash_chain = count
	_dash_windup(target, DASH_WARN)


func _dash_windup(target: Node2D, warn: float) -> void:
	var to: Vector2 = target.global_position + _lead(target, 0.25) if target != null and is_instance_valid(target) else e.global_position + Vector2.RIGHT
	var dir: Vector2 = (to - e.global_position)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	var length: float = MinoMath.clip_travel(e.global_position, dir, DASH_LEN, _blocked_cb())
	_busy = warn + 0.05
	_lock(warn + 0.1)
	e.call("_update_facing", dir)
	_anim("cast", warn)
	AbilitiesScript.spawn_synced_world_fx(e.get_tree(), "charge_lane", e.global_position,
			{"warn": warn, "dir": dir, "length": maxf(length, 40.0), "width": DASH_WIDTH}, e)
	_after(warn, _start_move.bind(dir, length, DASH_SPEED, DASH_DAMAGE, "kardes_cut", "dash"))


func _start_move(dir: Vector2, length: float, speed: float, dmg: float, kind: String, anim_name: String) -> void:
	if length < 30.0:
		_end_move()
		return
	_move = {"dir": dir, "left": length, "speed": speed, "dmg": dmg, "kind": kind, "ids": {}}
	_anim(anim_name, length / speed + 0.1)
	_event({"k": "netcap", "cap": speed * 1.1})


func _move_step(delta: float) -> void:
	var dir: Vector2 = _move["dir"]
	var step: float = minf(float(_move["speed"]) * delta, float(_move["left"]))
	var from: Vector2 = e.global_position
	var to: Vector2 = from + dir * step
	if MinoMath.step_blocked(from, to, _blocked_cb()):
		_end_move()
		return
	e.global_position = to
	if str(_move["kind"]) != "":
		e.call("_update_facing", dir)
	_lock(0.2)
	if float(_move["dmg"]) > 0.0:
		_move_hits(from, to)
	_move["left"] = float(_move["left"]) - step
	if float(_move["left"]) <= 0.5:
		_end_move()


func _move_hits(from: Vector2, to: Vector2) -> void:
	var ids: Dictionary = _move["ids"]
	for p: Node2D in _targets_in(INF):
		var id: int = p.get_instance_id()
		if ids.has(id):
			continue
		if MinoMath.segment_distance(p.global_position + Vector2(0.0, MinoMath.FEET_OFFSET), from, to) > DASH_WIDTH * 0.5 + MinoMath.HIT_MARGIN:
			continue
		ids[id] = true
		_deal(p, float(_move["dmg"]), str(_move["kind"]))


func _end_move() -> void:
	var was_dash: bool = not _move.is_empty() and float(_move.get("dmg", 0.0)) > 0.0
	_move = {}
	_event({"k": "netcap", "cap": 0.0})
	if was_dash:
		_dash_chain -= 1
		if _dash_chain > 0:
			_busy = DASH_PAUSE
			_after(DASH_PAUSE * 0.5, func() -> void:
				var t: Node2D = _nearest_target(DASH_RANGE.y + 200.0)
				if t != null:
					_dash_windup(t, DASH_WARN_CHAIN)
				else:
					_dash_chain = 0)
		else:
			_busy = 0.45 ## atılma sonu toparlanma: kaçma penceresi
			_lock(0.45)


func _begin_spin() -> void:
	_set_cd("spin", SPIN_CD)
	_busy = SPIN_WARN + 0.35
	_lock(SPIN_WARN + 0.35)
	_anim("spin", SPIN_WARN + 0.3)
	_spawn("kardes_zone", e.global_position, {"style": "spin", "warn": SPIN_WARN, "radius": SPIN_RADIUS, "kind": "kardes_spin",
			"fling": SPIN_FLING}, SPIN_DAMAGE)


func _begin_wave(target: Node2D) -> void:
	_set_cd("wave", WAVE_CD)
	var dir: Vector2 = (target.global_position + _lead(target, 0.5) - e.global_position).normalized()
	_busy = 0.6
	_lock(0.6)
	e.call("_update_facing", dir)
	_anim("spin", 0.55)
	for i in range(WAVE_COUNT):
		var pos: Vector2 = e.global_position + dir * (90.0 + WAVE_STEP * float(i))
		if GameManager.is_position_blocked_by_walls(pos):
			break
		_spawn("kardes_zone", pos, {"style": "slash", "warn": 0.35 + 0.09 * float(i), "radius": WAVE_RADIUS, "kind": "kardes_cut"}, WAVE_DAMAGE)


# ---------------------------------------------------------------------------------------------------- OK
func _begin_volley(target: Node2D, count: int) -> void:
	_set_cd("volley", VOLLEY_CD)
	_busy = 0.35
	var aim: Vector2 = target.global_position + _lead(target, e.global_position.distance_to(target.global_position) / ARROW_SPEED)
	var base: Vector2 = (aim - _origin()).normalized()
	e.call("_update_facing", base)
	_anim("attack", 0.4)
	for i in range(count):
		var off: float = (float(i) - float(count - 1) * 0.5) * deg_to_rad(VOLLEY_SPREAD_DEG)
		_shot("arrow", base.rotated(off), ARROW_SPEED, ARROW_DAMAGE, "kardes_arrow")


func _begin_fan(target: Node2D) -> void:
	_set_cd("fan", FAN_CD)
	_busy = 0.7
	_lock(0.6)
	var base: Vector2 = (target.global_position - _origin()).normalized()
	e.call("_update_facing", base)
	_anim("cast", 0.55)
	var n: int = FAN_ARROWS + 2 * _rage
	_after(0.4, func() -> void:
		for i in range(n):
			var a: float = -deg_to_rad(FAN_ARC_DEG) * 0.5 + deg_to_rad(FAN_ARC_DEG) * float(i) / float(maxi(n - 1, 1))
			_shot("arrow", base.rotated(a), ARROW_SPEED * 0.9, ARROW_DAMAGE, "kardes_arrow"))


func _begin_rain(own: bool = true) -> void:
	if own:
		_set_cd("rain", RAIN_CD)
	_busy = 0.7
	_lock(0.7)
	_anim("cast", 0.6)
	for p: Node2D in _targets_in(RAIN_RANGE + 200.0):
		var center: Vector2 = p.global_position + _lead(p, RAIN_WARN * 0.6)
		for i in range(RAIN_PER_PLAYER + _rage):
			var pos: Vector2 = center if i == 0 else center + Vector2.from_angle(randf() * TAU) * randf_range(55.0, 135.0)
			if GameManager.is_position_blocked_by_walls(pos):
				continue
			_spawn("kardes_zone", pos, {"style": "arrows", "warn": RAIN_WARN + 0.12 * float(i), "radius": RAIN_RADIUS, "kind": "kardes_arrow"}, RAIN_DAMAGE)


func _begin_leap(target: Node2D) -> void:
	_set_cd("leap", LEAP_CD)
	var away: Vector2 = (e.global_position - target.global_position)
	away = away.normalized() if away.length() > 1.0 else Vector2.from_angle(randf() * TAU)
	## Duvara doğru atlamasın: geri yön kapalıysa yana dene
	var best_dir: Vector2 = away
	var best_len: float = MinoMath.clip_travel(e.global_position, away, LEAP_LEN, _blocked_cb())
	for ang: float in [0.7, -0.7, 1.4, -1.4]:
		var d2: Vector2 = away.rotated(ang)
		var l2: float = MinoMath.clip_travel(e.global_position, d2, LEAP_LEN, _blocked_cb())
		if l2 > best_len + 40.0:
			best_dir = d2
			best_len = l2
	_spawn("kardes_zone", e.global_position, {"style": "dust", "warn": 0.0, "radius": 0.0}, 0.0)
	_start_move(best_dir, best_len, LEAP_SPEED, 0.0, "", "cast")
	## İner inmez karşılık salvosu (bir ok fazla)
	_after(best_len / LEAP_SPEED + 0.05, func() -> void:
		var t: Node2D = _nearest_target(VOLLEY_RANGE)
		if t != null:
			_begin_volley(t, VOLLEY_ARROWS + 1 + _rage))


# ---------------------------------------------------------------------------------------------------- BÜYÜ
func _begin_fireballs(target: Node2D) -> void:
	_set_cd("fire", FIRE_CD)
	var n: int = FIRE_COUNT + _rage
	_busy = FIRE_GAP * float(n) + 0.25
	_lock(_busy)
	_anim("attack", _busy)
	for i in range(n):
		_after(0.15 + FIRE_GAP * float(i), func() -> void:
			var t: Node2D = target if is_instance_valid(target) and target.get("is_dead") != true else _nearest_target(FIRE_RANGE + 150.0)
			if t == null:
				return
			var aim: Vector2 = t.global_position + _lead(t, e.global_position.distance_to(t.global_position) / FIRE_SPEED)
			var dir: Vector2 = (aim - _origin()).normalized()
			e.call("_update_facing", dir)
			_shot("fireball", dir, FIRE_SPEED, FIRE_DAMAGE, "fireball", {"splash": FIRE_SPLASH * _rage_mult() * _dmg_mult_meta()}))


func _begin_ice_rings() -> void:
	_set_cd("ice", ICE_CD)
	_busy = 0.9
	_lock(0.9)
	_anim("cast", 0.8)
	var base: float = randf() * TAU
	for ring in range(2):
		_after(0.3 + 0.35 * float(ring), func() -> void:
			for i in range(ICE_PER_RING):
				var a: float = base + (float(i) + 0.5 * float(ring)) * TAU / float(ICE_PER_RING)
				_shot("ice", Vector2.from_angle(a), ICE_SPEED, ICE_DAMAGE, "kardes_frost"))


func _begin_bolts() -> void:
	_set_cd("bolt", BOLT_CD)
	_busy = 0.6
	_lock(0.6)
	_anim("cast", 0.6)
	for p: Node2D in _targets_in(BOLT_RANGE + 200.0):
		for i in range(BOLT_STRIKES + _rage):
			_after(BOLT_GAP * float(i), func() -> void:
				if not is_instance_valid(p) or p.get("is_dead") == true:
					return
				var pos: Vector2 = p.global_position + _lead(p, BOLT_WARN * 0.7)
				if GameManager.is_position_blocked_by_walls(pos):
					pos = p.global_position
				_spawn("kardes_zone", pos, {"style": "bolt", "warn": BOLT_WARN, "radius": BOLT_RADIUS, "kind": "kardes_shock"}, BOLT_DAMAGE))


func _begin_spikes(target: Node2D) -> void:
	_set_cd("spike", SPIKE_CD)
	_busy = 0.6
	_lock(0.6)
	_anim("cast", 0.55)
	var dir: Vector2 = (target.global_position + _lead(target, 0.6) - e.global_position).normalized()
	for side in ([0.0] if _rage == 0 else [-0.32, 0.0, 0.32]):
		var d2: Vector2 = dir.rotated(float(side))
		for i in range(SPIKE_COUNT):
			var pos: Vector2 = e.global_position + d2 * (60.0 + SPIKE_STEP * float(i))
			if GameManager.is_position_blocked_by_walls(pos):
				break
			_spawn("kardes_zone", pos, {"style": "spikes", "warn": SPIKE_WARN + 0.06 * float(i), "radius": SPIKE_RADIUS, "kind": "kardes_frost"}, SPIKE_DAMAGE)


func _begin_meteor(target: Node2D, own: bool = true) -> void:
	if own:
		_set_cd("meteor", METEOR_CD)
	_busy = 1.0
	_lock(1.0)
	_anim("cast", 0.9)
	var center: Vector2 = target.global_position + _lead(target, 0.5)
	if GameManager.is_position_blocked_by_walls(center):
		center = target.global_position
	_spawn("kardes_zone", center, {"style": "meteor", "warn": METEOR_WARN, "radius": METEOR_RADIUS, "kind": "fireball"}, METEOR_DAMAGE)
	for i in range(4 + _rage):
		var pos: Vector2 = center + Vector2.from_angle(float(i) * TAU / float(4 + _rage) + randf() * 0.5) * randf_range(150.0, 220.0)
		if GameManager.is_position_blocked_by_walls(pos):
			continue
		_spawn("kardes_zone", pos, {"style": "meteor", "warn": METEOR_WARN + 0.3 + 0.15 * float(i), "radius": METEOR_SMALL_RADIUS, "kind": "fireball"}, METEOR_SMALL_DAMAGE)


func _begin_blink(target: Node2D) -> void:
	_set_cd("blink", BLINK_CD)
	var away: Vector2 = (e.global_position - target.global_position)
	away = away.normalized() if away.length() > 1.0 else Vector2.RIGHT
	var to: Vector2 = Vector2.INF
	for ang: float in [0.0, 0.6, -0.6, 1.2, -1.2, PI * 0.5, -PI * 0.5]:
		var cand: Vector2 = e.global_position + away.rotated(ang) * BLINK_DIST
		if not GameManager.is_position_blocked_by_walls(cand):
			to = cand
			break
	if to == Vector2.INF:
		_cd["blink"] = 1.0
		return
	var from: Vector2 = e.global_position
	_spawn("kardes_zone", from, {"style": "spark", "warn": 0.0, "radius": 0.0}, 0.0)
	e.global_position = to
	_event({"k": "warp", "to": to})
	_spawn("kardes_zone", to, {"style": "spark", "warn": 0.0, "radius": 0.0}, 0.0)
	_busy = 0.35
	## Işınlandığı yerde ilk iş: yakındaki oyuncuya buz halkası (kaçış + karşılık)
	_cd["ice"] = minf(float(_cd.get("ice", 0.0)), 0.3)


# ---------------------------------------------------------------------------------------------------- yardımcılar
func _track(delta: float) -> void:
	if delta <= 0.0:
		return
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		var pn := p as Node2D
		var id: int = pn.get_instance_id()
		if _last_pos.has(id):
			var v: Vector2 = (pn.global_position - Vector2(_last_pos[id])) / delta
			_vel[id] = Vector2(_vel.get(id, Vector2.ZERO)).lerp(v, clampf(delta * 6.0, 0.0, 1.0))
		_last_pos[id] = pn.global_position


## Hedefin `seconds` sn sonraki tahmini yer değişimi (sınırlı - ışınlanan/savrulan oyuncu nişanı fırlatmasın).
func _lead(p: Node2D, seconds: float) -> Vector2:
	var v: Vector2 = Vector2(_vel.get(p.get_instance_id(), Vector2.ZERO))
	return (v * clampf(seconds, 0.0, 1.2)).limit_length(240.0)


func _targets_in(radius: float) -> Array:
	var out: Array = []
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		var pn := p as Node2D
		if pn.get("is_indoors") == true or pn.get("is_downed") == true or pn.get("is_in_merchant_zone") == true:
			continue
		if pn.global_position.distance_to(e.global_position) <= radius:
			out.append(pn)
	return out


func _nearest_target(radius: float) -> Node2D:
	var best: Node2D = null
	var bd: float = radius
	for pn: Node2D in _targets_in(radius):
		var d: float = pn.global_position.distance_to(e.global_position)
		if best == null or d < bd:
			best = pn
			bd = d
	return best


func _origin() -> Vector2:
	return e.global_position + Vector2(0.0, -18.0)


func _run_queue(delta: float) -> void:
	var i: int = 0
	while i < _queue.size():
		_queue[i]["t"] = float(_queue[i]["t"]) - delta
		if float(_queue[i]["t"]) <= 0.0:
			var fn: Callable = _queue[i]["fn"]
			_queue.remove_at(i)
			if e != null and is_instance_valid(e) and e.get("is_dead") != true:
				fn.call()
		else:
			i += 1


func _after(seconds: float, fn: Callable) -> void:
	_queue.append({"t": seconds, "fn": fn})


func _anim(anim_name: String, duration: float) -> void:
	_event({"k": "anim", "n": anim_name, "d": duration})


func _event(data: Dictionary) -> void:
	e.call("emit_ability_vfx", "boss_event", data)


func _lock(seconds: float) -> void:
	e.set("ability_move_lock", maxf(float(e.get("ability_move_lock")), seconds))


func _blocked_cb() -> Callable:
	if blocked_override.is_valid():
		return blocked_override
	return func(p: Vector2) -> bool: return GameManager.is_position_blocked_by_walls(p)


func _dmg_mult_meta() -> float:
	return float(e.get_meta("boss_damage_mult", 1.0))


## Yetenek hasarı: sabit x kademe yuvası çarpanı x öfke.
func _scaled(dmg: float) -> float:
	return dmg * _dmg_mult_meta() * _rage_mult()


func _deal(p: Node2D, dmg: float, kind: String) -> void:
	AbilitiesScript.deal_special_damage(p, _scaled(dmg), e, kind)


func _spawn(kind: String, pos: Vector2, data: Dictionary, dmg: float) -> Node2D:
	var node: Node2D = AbilitiesScript.spawn_world_fx(e.get_tree(), kind, pos, data, true, e, _scaled(dmg))
	AbilitiesScript._broadcast_world_fx(kind, pos, data)
	return node


func _shot(style: String, dir: Vector2, speed: float, dmg: float, kind: String, extra: Dictionary = {}) -> void:
	var data: Dictionary = {"style": style, "dir": dir, "speed": speed, "kind": kind}
	data.merge(extra)
	_spawn("kardes_shot", _origin() + dir * 14.0, data, dmg)
