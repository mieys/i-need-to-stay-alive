extends Node

## EFSUN DAVRANIŞI TEMEL SINIFI. Her efsunun mantığı scripts/enchants/<efsun id>.gd içinde bunu genişletir; silah
## (weapon.gd set_enchant) onu kendi çocuğu olarak kurar ve atış/isabet anlarında kancaları çağırır.
## Davranış SADECE yerel oyuncunun gerçek silahında çalışır (uzak kuklalarda weapon.gd yok) - hasar take_damage,
## elementler enemy.apply_element üzerinden gider (istemcide ikisi de host'a yönlendirilir). Dünyadaki görseller
## EnchantFx.play / EnchantArea.spawn ile yayınlanır, uzak oyuncular aynı efekti görür.
##
## ORTAK MEKANİKLER BURADA (stats anahtarlarıyla, EnchantDefs'teki adım "set"/"add" alanlarından): zehir/yanma/kanama/
## şok/donma/yavaşlatma/işaret/sersemletme/can çalma, durum bonusları, kritik, kalkan delme, delme/sekme/güdüm/itme/
## boyut/hız, yelpaze ve seri ek atışlar, saldırı hızı/menzil/alan, yakın dövüş parça sayısı, ışın zinciri. Efsun
## scriptleri sadece kendine özgü kısmı *_extra kancalarıyla ekler.
##
## power = efsun gücü (1 + kart/Aşkın gücü); stats["power_on"] neyi çarptığını söyler: "hit" (silah vuruşu), "poison",
## "burn", "bleed", "shock", "area" (efsunun alan/ek hasarları), "heal", "shield".

const EnchantFx := preload("res://scripts/enchant_fx.gd")
const EnchantArea := preload("res://scripts/enchant_area.gd")
const VisionFogScript := preload("res://scripts/vision_fog.gd")
const BOUNCE_RANGE := 220.0
const HOMING_TURN := 9.0

var weapon: Node2D = null
var stats: Dictionary = {}
var power: float = 1.0
## Gerçek (ek atış olmayan) saldırı sayacı - "her N. saldırıda" tetikleyicileri için.
var attacks: int = 0
var _hits_on: Dictionary = {} ## düşman id -> bu silahın isabet sayısı ("N isabette donar")
var _bled: Dictionary = {} ## düşman id -> son kanatma anı (istemcide kanama görünmediği için yerel kayıt)
var _combo_id: int = 0
var _combo: int = 0
var _elem_hits: int = 0
var _homing: Array = [] ## [mermi, hedef]
var _haste: float = 0.0
var _haste_until_msec: int = 0
var _still_time: float = 0.0
var _heal_budget: float = 0.0
## Yakın dövüş darbe sayısı arttığında (Fırtına Bıçakları, Dörtlü Pençe) weapon.gd toplam hasarı parçalara BÖLÜYOR
## (_deal_melee_damage) - "darbe 3 -> 4" gerçekten daha çok vursun diye hasar yeni/eski oranıyla çarpılır.
var _segment_mult: float = 1.0


func setup(w: Node2D, s: Dictionary) -> void:
	weapon = w
	stats = s
	power = float(s.get("power_mult", 1.0))
	if stats.has("segments"):
		var orig: int = maxi(1, int(weapon.get("melee_hit_segments")))
		_segment_mult = float(n("segments")) / float(orig)
		weapon.set_enchant_prop("melee_hit_segments", n("segments"))
	if stats.has("aoe_pct"):
		weapon.set_enchant_prop("melee_aoe_damage_percent", f("aoe_pct"))
	_on_setup()


func _on_setup() -> void:
	pass


## ------------------------------------------------------------------ yardımcılar
func f(key: String, d: float = 0.0) -> float:
	return float(stats.get(key, d))


func n(key: String, d: int = 0) -> int:
	return int(stats.get(key, d))


func flag(key: String) -> bool:
	return bool(stats.get(key, false))


## Efsun gücü bu etkiyi çarpıyor mu?
func pw(kind: String) -> float:
	return power if str(stats.get("power_on", "hit")) == kind else 1.0


func owner_player() -> Node:
	return weapon.get_parent() if is_instance_valid(weapon) else null


func my_peer() -> int:
	return multiplayer.get_unique_id() if (NetworkManager.is_multiplayer_active and multiplayer.has_multiplayer_peer()) else 0


## Zamanlayıcıyla kendi başına tetiklenen etkiler için: sahip ölü/yerde/satıcı bölgesinde değilken.
func can_act() -> bool:
	var p: Node = owner_player()
	if p == null:
		return false
	return p.get("is_dead") != true and p.get("is_downed") != true and p.get("is_in_merchant_zone") != true


## SG = oyuncunun saldırı gücü (damage_bonus).
func ap() -> float:
	var p: Node = owner_player()
	return float(p.get("damage_bonus")) if p and "damage_bonus" in p else 10.0


func elem(extra: Dictionary) -> Dictionary:
	var d: Dictionary = extra.duplicate()
	d["ap"] = ap()
	d["rp"] = GameManager.enchant_reaction_power + f("reaction_power")
	d["power"] = power
	return d


func count_attack(is_extra: bool) -> bool:
	return not is_extra


func luck() -> float:
	var p: Node = owner_player()
	return float(p.get("luck")) if p and "luck" in p else 0.0


## Kaos Kitabı'nın çift atış şansı (bazı finaller onu kendi etkilerine de uygular).
func double_fire_chance() -> float:
	var p: Node = owner_player()
	return float(p.get("item_double_fire_chance")) if p and "item_double_fire_chance" in p else 0.0


func max_hp() -> float:
	var p: Node = owner_player()
	return float(p.get("max_health")) if p and "max_health" in p else 100.0


## Efsun kartı (Aşkın dahil) her alındığında davranış yeniden kurulur - sıfırlanmaması gereken sayaçlar/bekleme
## süreleri (Kelle Avcısı, Ruh Hasadı, Küllerinden Doğuş) silah düğümünün meta'sında tutulur.
func keep_get(key: String, d: Variant = 0) -> Variant:
	return weapon.get_meta("ench_" + key, d) if is_instance_valid(weapon) else d


func keep_set(key: String, v: Variant) -> void:
	if is_instance_valid(weapon):
		weapon.set_meta("ench_" + key, v)


## Bu silahın dünyada duran kalıcı alanları (kuş, kalıcı fırtına, kristal) - yeniden kurulumda çoğalmasın diye grupla sayılır.
func own_group(tag: String) -> String:
	return "ench_%s_%d" % [tag, weapon.get_instance_id()]


func own_count(tag: String) -> int:
	var c: int = 0
	for nd in get_tree().get_nodes_in_group(own_group(tag)):
		if is_instance_valid(nd) and not nd.is_queued_for_deletion():
			c += 1
	return c


func tagged_area(tag: String, kind: String, pos: Vector2, params: Dictionary) -> Node2D:
	var a: Node2D = area(kind, pos, params)
	if a:
		a.add_to_group(own_group(tag))
	return a


## Yerel yük tahmini (istemcide düşmanın zehir/kanama/işaret yükleri görünmez): bu silahın bıraktığı yükleri sayar,
## "window" sn yeni yük gelmezse sıfırlar. Döndürdüğü = güncel tahmin.
var _stack_book: Dictionary = {}

func track_stacks(t: Node, add: int, cap: int, window: float) -> int:
	if not is_instance_valid(t):
		return 0
	var id: int = t.get_instance_id()
	var now: int = Time.get_ticks_msec()
	var rec: Array = _stack_book.get(id, [0, now])
	if now - int(rec[1]) > int(window * 1000.0):
		rec = [0, now]
	rec[0] = mini(cap, int(rec[0]) + add)
	rec[1] = now
	_stack_book[id] = rec
	if _stack_book.size() > 300:
		_stack_book.clear()
	return int(rec[0])


func stacks_on(t: Node, window: float) -> int:
	if not is_instance_valid(t):
		return 0
	var rec: Array = _stack_book.get(t.get_instance_id(), [0, 0])
	return int(rec[0]) if Time.get_ticks_msec() - int(rec[1]) <= int(window * 1000.0) else 0


func random_enemies(pos: Vector2, radius: float, count: int, exclude: Node = null) -> Array:
	var c: Array = enemies_near(pos, radius, exclude)
	c.shuffle()
	return c.slice(0, mini(count, c.size()))


func dir_to(from_pos: Vector2, t: Node) -> Vector2:
	if not is_instance_valid(t):
		return Vector2.RIGHT
	var d: Vector2 = (t as Node2D).global_position - from_pos
	return d.normalized() if d.length() > 0.5 else Vector2.RIGHT


## Alan hasarı + halka görseli (patlama, dalga, deprem). Vurulanları döndürür.
func blast(pos: Vector2, radius: float, amount: float, color: Color, fx_kind: String = "explosion") -> Array:
	fx(fx_kind, pos, {"radius": radius, "color": color})
	var victims: Array = enemies_near(pos, radius)
	for e in victims:
		hit(e, amount)
	return victims


func every(count: int) -> bool:
	return count > 0 and attacks > 0 and attacks % count == 0


func is_enemy(t: Node) -> bool:
	return is_instance_valid(t) and t.has_method("apply_element") and t.get("is_dead") != true


func is_moving() -> bool:
	var p: Node = owner_player()
	return p is CharacterBody2D and (p as CharacterBody2D).velocity.length() > 8.0


func enemies_near(pos: Vector2, radius: float, exclude: Node = null) -> Array:
	var out: Array = []
	for e in Enemy.get_enemies_near(get_tree(), pos, radius):
		if is_instance_valid(e) and e != exclude and not e.is_dead:
			out.append(e)
	return out


func nearest_enemy(pos: Vector2, radius: float, exclude: Array = []) -> Node:
	var best: Node = null
	var best_d: float = INF
	for e in Enemy.get_enemies_near(get_tree(), pos, radius):
		if not is_instance_valid(e) or e.is_dead or exclude.has(e):
			continue
		var d: float = e.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func status(t: Node, what: String) -> bool:
	if not is_instance_valid(t):
		return false
	match what:
		"burning":
			return t.has_method("is_burning") and t.is_burning()
		"poisoned":
			return t.has_method("is_poisoned") and t.is_poisoned()
		"shocked":
			return t.has_method("is_shocked") and t.is_shocked()
		"frozen":
			return t.has_method("is_frozen_now") and t.is_frozen_now()
		"bleeding":
			return Time.get_ticks_msec() - int(_bled.get(t.get_instance_id(), -100000)) < 4000
		"boss":
			return t.get("is_boss") == true
	return false


func area(kind: String, pos: Vector2, params: Dictionary) -> Node2D:
	var d: Dictionary = params.duplicate()
	d["peer"] = my_peer()
	return EnchantArea.spawn(get_tree(), kind, pos, d, true)


func fx(kind: String, pos: Vector2, data: Dictionary = {}) -> void:
	EnchantFx.play(get_tree(), kind, pos, data)


## Alan/ek hasar (patlama, dalga, dal) - is_area = true (can emme %33 kuralı).
func hit(t: Node, amount: float) -> void:
	if amount > 0.0 and is_enemy(t):
		t.take_damage(amount, false, 0.0, true)


func heal_owner(amount: float) -> void:
	var p: Node = owner_player()
	if p and p.has_method("heal") and amount > 0.0:
		p.heal(amount)


## Kısa süreli ek saldırı hızı (bu silah için).
func haste(pct: float, dur: float) -> void:
	_haste = maxf(_haste if Time.get_ticks_msec() < _haste_until_msec else 0.0, pct)
	_haste_until_msec = Time.get_ticks_msec() + int(dur * 1000.0)


## ------------------------------------------------------------------ element yardımcıları
func apply_poison_to(t: Node, extra: Dictionary = {}) -> void:
	if not is_enemy(t):
		return
	var p: Dictionary = elem({"dps": ap() * f("poison_dps", 0.02) * pw("poison"), "cap": f("poison_cap", 20.0),
		"dur": f("poison_dur", 10.0), "stacks": n("poison_stacks", 1), "true_dmg": flag("poison_true"), "death_cloud": flag("death_cloud"),
		"death_burst": n("poison_death_burst"), "kobra": flag("kobra")})
	p.merge(poison_extra(), true)
	p.merge(extra, true)
	t.apply_element("poison", p)


## Efsuna özgü zehir parametreleri (Salgın: bulaşma) - her zehir uygulamasına eklenir.
func poison_extra() -> Dictionary:
	return {}


func apply_burn_to(t: Node, extra: Dictionary = {}) -> void:
	if not is_enemy(t):
		return
	var tick: float = ap() * f("burn_ap", 0.10) * pw("burn")
	if flag("burn_death_blast"):
		## Cehennem Tohumu: Sigara'nın hasar bonusu yanmaya iki kat işler.
		var pl: Node = owner_player()
		tick *= 1.0 + 2.0 * (float(pl.get("item_damage_mult_bonus")) if pl and "item_damage_mult_bonus" in pl else 0.0)
	var bp: Dictionary = elem({"tick": tick, "dur": f("burn_dur", 3.0), "max_stacks": n("burn_stacks", 1),
		"burn_spread": flag("burn_spread"), "burn_death_blast": flag("burn_death_blast")})
	bp.merge(extra, true)
	t.apply_element("burn", bp)


## Sahnesiz alanlara (lav, alev izi) verilecek yanma parametreleri.
func burn_area_params() -> Dictionary:
	return {"burn_tick": ap() * f("burn_ap", 0.10) * pw("burn"), "burn_dur": f("burn_dur", 3.0), "max_stacks": n("burn_stacks", 1),
		"ap": ap(), "rp": GameManager.enchant_reaction_power + f("reaction_power")}


func apply_bleed_to(t: Node, stacks: int = -1) -> void:
	if not is_enemy(t):
		return
	_bled[t.get_instance_id()] = Time.get_ticks_msec()
	t.apply_element("bleed", elem({"tick": ap() * f("bleed_ap", 0.03) * pw("bleed"), "stacks": stacks if stacks > 0 else n("bleed_stacks", 1),
		"cap": n("bleed_cap", 10), "fast": flag("bleed_fast"), "bleed_transfer": flag("bleed_transfer"), "burst": flag("bleed_burst"),
		"burst_pct": 0.5 * power, "bleed_death_blast": flag("bleed_death_blast"), "bleed_kill": flag("bleed_kill")}))


func shock_params() -> Dictionary:
	return elem({"dur": f("shock_dur", 4.0), "jump": f("shock_jump", 0.25) * pw("shock"), "jumps": n("shock_jumps", 1),
		"spark": f("shock_spark", 0.0) * power, "death_bolt": flag("shock_death_bolt")})


func apply_shock_to(t: Node) -> void:
	if is_enemy(t):
		t.apply_element("shock", shock_params())


func apply_mark_to(t: Node, stacks: int = -1) -> void:
	if is_enemy(t):
		t.apply_element("mark", elem({"stacks": stacks if stacks > 0 else n("mark_stacks", 1), "cap": n("mark_cap", 20),
			"dur": f("mark_dur", 20.0), "pct": f("mark_pct", 0.01), "decree": flag("decree"), "mark_transfer": flag("mark_transfer"),
			"mark_soul": flag("mark_soul"), "mark_death_blast": flag("mark_death_blast")}))


func freeze(t: Node, dur: float) -> void:
	if is_enemy(t):
		t.apply_element("freeze", elem({"dur": dur, "boss_hits": n("boss_freeze_hits"), "linger_slow": f("linger_slow"),
			"contagious": flag("contagious"), "frozen_shards": flag("frozen_shards"), "shards_freeze": flag("shards_freeze")}))


## ------------------------------------------------------------------ kancalar (weapon.gd çağırır)
func on_fire(target: Node2D, is_extra: bool) -> void:
	if not is_extra:
		attacks += 1
	fire_start(target, is_extra)


func fire_start(_target: Node2D, _is_extra: bool) -> void:
	pass


func crit_bonus(t: Node2D) -> float:
	var c: float = f("crit_chance")
	if f("crit_vs_poisoned") > 0.0 and status(t, "poisoned"):
		c += f("crit_vs_poisoned")
	if f("crit_vs_shocked") > 0.0 and status(t, "shocked"):
		c += f("crit_vs_shocked")
	return c + crit_extra(t)


func crit_extra(_t: Node2D) -> float:
	return 0.0


func crit_damage_bonus(t: Node2D) -> float:
	var c: float = f("crit_damage")
	if f("crit_damage_vs_burning") > 0.0 and status(t, "burning"):
		c += f("crit_damage_vs_burning")
	return c


func modify_damage(dmg: float, t: Node2D) -> float:
	var m: float = pw("hit") * _segment_mult
	if f("burning_bonus") > 0.0 and status(t, "burning"):
		m *= 1.0 + f("burning_bonus")
	if f("poisoned_bonus") > 0.0 and status(t, "poisoned"):
		m *= 1.0 + f("poisoned_bonus")
	if f("shocked_bonus") > 0.0 and status(t, "shocked"):
		m *= 1.0 + f("shocked_bonus")
	if f("frozen_bonus") > 0.0 and status(t, "frozen"):
		m *= 1.0 + f("frozen_bonus")
	if f("bleeding_bonus") > 0.0 and status(t, "bleeding"):
		m *= 1.0 + f("bleeding_bonus")
	if f("boss_bonus") > 0.0 and status(t, "boss"):
		m *= 1.0 + f("boss_bonus")
	if f("far_bonus") > 0.0 and is_instance_valid(t) and is_instance_valid(weapon):
		var rng: float = float(weapon.get("attack_range"))
		if rng > 0.0 and weapon.global_position.distance_to(t.global_position) >= rng * 0.7:
			m *= 1.0 + f("far_bonus")
	if f("combo_ramp") > 0.0 and is_instance_valid(t):
		var id: int = t.get_instance_id()
		_combo = _combo + 1 if id == _combo_id else 0
		_combo_id = id
		m *= 1.0 + minf(f("combo_cap", 0.4), f("combo_ramp") * float(_combo))
	if f("full_shield_bonus") > 0.0:
		var pl: Node = owner_player()
		if pl and float(pl.get("item_shield_max")) > 0.0 and float(pl.get("item_shield_hp")) >= float(pl.get("item_shield_max")) - 0.5:
			m *= 1.0 + f("full_shield_bonus")
	return damage_extra(dmg * m, t)


func damage_extra(dmg: float, _t: Node2D) -> float:
	return dmg


func extra_shield_pen() -> float:
	return f("shield_pen") + pen_extra()


func pen_extra() -> float:
	return 0.0


func configure_projectile(proj: Node2D, target: Node2D, is_extra: bool) -> void:
	if n("pierce") > 0:
		proj.set("pierce_count", int(proj.get("pierce_count")) + n("pierce"))
		proj.set("pierce_damage_percent", f("pierce_pct", 0.8))
	if f("proj_speed", 1.0) != 1.0:
		if "flight_duration" in proj:
			proj.set("flight_duration", float(proj.get("flight_duration")) / f("proj_speed"))
		elif "speed" in proj:
			proj.set("speed", float(proj.get("speed")) * f("proj_speed"))
	if f("proj_scale", 1.0) != 1.0:
		proj.scale *= f("proj_scale")
	if f("knockback") > 0.0 and "knockback_force" in proj:
		proj.set("knockback_force", float(proj.get("knockback_force")) + f("knockback"))
	if f("aoe_mult", 1.0) != 1.0 and "splash_radius" in proj and float(proj.get("splash_radius")) > 0.0:
		proj.set("splash_radius", float(proj.get("splash_radius")) * f("aoe_mult"))
	if "throw_distance" in proj and f("range_mult", 1.0) != 1.0:
		proj.set("throw_distance", float(proj.get("throw_distance")) * f("range_mult"))
	if f("apex_pause") > 0.0 and "apex_pause" in proj:
		proj.set("apex_pause", f("apex_pause"))
	if n("bounce") > 0:
		proj.set("pierce_count", int(proj.get("pierce_count")) + n("bounce"))
		proj.set("pierce_damage_percent", f("bounce_pct", 0.7))
		proj.set_meta("enchant_bounce", n("bounce"))
	if flag("homing") and is_instance_valid(target):
		_homing.append([proj, target])
	projectile_extra(proj, target, is_extra)


func projectile_extra(_proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	pass


## Kasterde apply_projectile_look ile uygulanır VE broadcast_projectile ile uzak kopyaya gönderilir.
func projectile_look(proj: Node2D) -> Dictionary:
	var d: Dictionary = {}
	var el: String = str(stats.get("element", "fiziksel"))
	if el != "fiziksel":
		d["tint"] = EnchantDefs.element_color(el).lerp(Color.WHITE, 0.55)
	var pierce_total: int = n("pierce") + n("bounce")
	if pierce_total > 0:
		d["pierce"] = pierce_total
	if f("apex_pause") > 0.0:
		d["apex_pause"] = f("apex_pause")
	return look_extra(proj, d)


func look_extra(_proj: Node2D, d: Dictionary) -> Dictionary:
	return d


## Hem yakın dövüş isabetleri (proj = null), mermi/bumerang/fişek isabetleri hem ışın tikleri.
func on_hit(t: Node, dmg: float, is_primary: bool, proj: Node2D) -> void:
	if is_enemy(t) and (is_primary or not flag("primary_only")):
		_generic_hit(t, dmg, is_primary, proj)
	if proj != null and is_instance_valid(proj):
		_projectile_follow_up(t, proj)
	hit_extra(t, dmg, is_primary, proj)


func _generic_hit(t: Node, dmg: float, is_primary: bool, proj: Node2D) -> void:
	if n("poison_stacks") > 0:
		apply_poison_to(t)
	if f("burn_ap") > 0.0:
		apply_burn_to(t)
	if n("bleed_stacks") > 0:
		apply_bleed_to(t)
	if f("shock_dur") > 0.0:
		_elem_hits += 1
		if _elem_hits % maxi(1, n("shock_every", 1)) == 0:
			apply_shock_to(t)
	if f("slow_pct") > 0.0:
		t.apply_element("slow", {"pct": f("slow_pct"), "dur": f("slow_dur", 2.0)})
	if n("freeze_after") > 0:
		var id: int = t.get_instance_id()
		var c: int = int(_hits_on.get(id, 0)) + 1
		if c >= n("freeze_after"):
			c = 0
			freeze(t, f("freeze_dur", 2.0))
		_hits_on[id] = c
	elif f("freeze_dur") > 0.0:
		freeze(t, f("freeze_dur"))
	if n("mark_stacks") > 0:
		apply_mark_to(t)
	if f("stun_on_hit") > 0.0:
		t.apply_element("stun", {"dur": f("stun_on_hit")})
	if f("lifesteal") > 0.0 and dmg > 0.0:
		var ls: float = f("lifesteal") * pw("heal")
		var pl: Node = owner_player()
		if flag("low_hp_double") and pl and float(pl.get("health")) < float(pl.get("max_health")) * 0.3:
			ls *= 2.0
		_lifesteal(dmg * ls * (1.0 if is_primary else 0.33))


## Can çalma - Kan Lordu (fazla iyileşmenin %10'u kalıcı maks can) gibi kancalar için ayrı fonksiyon.
func _lifesteal(amount: float) -> void:
	heal_owner(amount)


func _projectile_follow_up(t: Node, proj: Node2D) -> void:
	if f("pierce_ramp") > 0.0:
		proj.set("damage", float(proj.get("damage")) * (1.0 + f("pierce_ramp")))
	if not proj.has_meta("enchant_bounce") or not is_instance_valid(t):
		return
	var left: int = int(proj.get_meta("enchant_bounce"))
	if left <= 0:
		if flag("bounce_end_blast"):
			proj.remove_meta("enchant_bounce")
			fx("explosion", t.global_position, {"radius": 80.0, "color": EnchantDefs.element_color(str(stats.get("element", "fiziksel")))})
			for e in enemies_near(t.global_position, 80.0):
				hit(e, ap() * 0.6 * power)
		return
	proj.set_meta("enchant_bounce", left - 1)
	if f("bounce_ramp") > 0.0:
		proj.set("damage", float(proj.get("damage")) * (1.0 + f("bounce_ramp")))
	if f("bounce_heal") > 0.0:
		_heal_budget = minf(5.0, _heal_budget)
		if _heal_budget < 5.0:
			_heal_budget += f("bounce_heal")
			heal_owner(f("bounce_heal"))
	if f("bounce_crit") > 0.0 and not bool(proj.get("is_crit")):
		var hits: int = (proj.get("_hit_bodies") as Array).size()
		if randf() < f("bounce_crit") * float(hits):
			proj.set("is_crit", true)
			proj.set("damage", float(proj.get("damage")) * float(weapon.get("crit_damage")))
	var hit_list: Array = proj.get("_hit_bodies")
	var nxt: Node = null
	var rng: float = BOUNCE_RANGE * f("bounce_range", 1.0)
	if flag("bounce_prefer_hp"):
		var best_hp: float = -1.0
		for e in enemies_near(t.global_position, rng):
			if hit_list.has(e):
				continue
			if float(e.health) > best_hp:
				best_hp = float(e.health)
				nxt = e
	else:
		nxt = nearest_enemy(t.global_position, rng, hit_list)
	if nxt == null:
		return
	var dir: Vector2 = (nxt.global_position - proj.global_position).normalized()
	proj.set("direction", dir)
	if bool(proj.get("face_direction")):
		proj.rotation = dir.angle() + float(weapon.get("ranged_projectile_rotation_offset"))
	if f("bounce_split") > 0.0 and randf() < f("bounce_split") * (1.0 + 0.05 * float((owner_player().get("luck") if owner_player() else 0.0))):
		weapon.spawn_enchant_projectile(proj.global_position, dir.rotated(0.5), float(proj.get("damage")), hit_list.duplicate(),
			projectile_look(proj), {"enchant_bounce": left - 1})


func hit_extra(_t: Node, _dmg: float, _is_primary: bool, _proj: Node2D) -> void:
	pass


func after_fire(target: Node2D, is_extra: bool) -> void:
	if not is_extra and is_instance_valid(target):
		var c: int = n("multi_count", 1)
		for k in range(1, c):
			var side: float = 1.0 if k % 2 == 1 else -1.0
			var step: float = float((k + 1) / 2)
			weapon.fire_enchant_shot(target, 0.0, f("multi_dmg", 1.0), deg_to_rad(f("fan_deg", 11.0) * step * side))
		if n("volley_every") > 0 and every(n("volley_every")):
			var vc: int = n("volley_count", 1)
			for k in range(vc):
				var ang: float = 0.0
				if flag("volley_fan"):
					ang = deg_to_rad(9.0 * float((k + 2) / 2) * (1.0 if k % 2 == 0 else -1.0))
				weapon.fire_enchant_shot(target, f("volley_delay", 0.09) * float(k + 1), f("volley_dmg", 1.0), ang)
	fire_extra(target, is_extra)


func fire_extra(_target: Node2D, _is_extra: bool) -> void:
	pass


func attack_speed_bonus() -> float:
	var b: float = f("attack_speed")
	if Time.get_ticks_msec() < _haste_until_msec:
		b += _haste
	if f("move_attack_speed") > 0.0 and is_moving():
		b += f("move_attack_speed")
	if f("still_speed") > 0.0 and _still_time >= 1.0:
		b += f("still_speed")
	return b + attack_speed_extra()


func attack_speed_extra() -> float:
	return 0.0


func range_mult() -> float:
	return f("range_mult", 1.0)


func aoe_mult() -> float:
	return f("aoe_mult", 1.0) * aoe_extra()


func aoe_extra() -> float:
	return 1.0


func orbit_cd_mult() -> float:
	return f("orbit_cd_mult", 1.0)


## Yıldırım ışını zinciri (weapon.gd _deal_beam_tick/_apply_chain_jumps).
func chain_bonus() -> int:
	return n("chain_add")


func chain_pct(base: float) -> float:
	return f("chain_pct", base)


func chain_range_mult() -> float:
	return f("chain_range", 1.0)


func on_chain(_primary: Node, _targets: Array, _dmg: float) -> void:
	pass


func on_beam_tick(target: Node, dmg: float) -> void:
	on_hit(target, dmg, true, null)


## Uzunkılıç: kılıç her çeyrek turda (~1 sn, weapon.gd ENCHANT_SWING_ARC) (weapon.gd _process_uzunkilic_orbit) - "savuruş" sayacı.
func on_revolution(pos: Vector2) -> void:
	attacks += 1
	revolution_extra(pos)


func revolution_extra(_pos: Vector2) -> void:
	pass


func on_boomerang_apex(_proj: Node2D) -> void:
	pass


func on_boomerang_caught(_proj: Node2D) -> void:
	pass


## Fişek patlaması (firework_projectile.gd _explode) - vurduğu düşmanlar ayrıca on_hit ile gelir.
func on_explode(_proj: Node2D, _pos: Vector2) -> void:
	pass


## Hedef seçimini efsun belirlesin mi (ör. Düello: en yüksek canlı). null = silahın normal seçimi.
func pick_target() -> Node2D:
	return null


func overrides_multishot() -> bool:
	return false


func on_skill_used() -> void:
	pass


func on_event(_event: String, _data: Dictionary) -> void:
	pass


## Sahip hasar aldı (player.gd take_damage, kalkandan önce). Dönen değer yeni hasar (engelleme/azaltma).
func on_owner_damaged(amount: float, _source: Node) -> float:
	return amount


func block_chance() -> float:
	return 0.0


## Sahibin engellediği saldırı (player.gd _enchant_owner_damaged) - Karşı Saldırı.
func on_blocked(_amount: float, _source: Node) -> void:
	pass


func on_dodge() -> void:
	pass


## Ölümcül darbe (player.gd die öncesi) - true dönerse ölüm iptal (Küllerinden Doğuş).
func cheat_death() -> bool:
	return false


func _process(delta: float) -> void:
	if is_moving():
		_still_time = 0.0
	else:
		_still_time += delta
	_heal_budget = maxf(0.0, _heal_budget - delta * 5.0)
	if not _homing.is_empty():
		var alive: Array = []
		for pair in _homing:
			## Tipsiz: serbest bırakılmış bir mermiyi tipli değişkene atamak hata verir (bkz. hafıza: freed == null).
			var proj = pair[0]
			var tgt = pair[1]
			if not is_instance_valid(proj) or not is_instance_valid(tgt) or tgt.get("is_dead") == true:
				continue
			var cur: Vector2 = Vector2(proj.get("direction"))
			var want: Vector2 = (tgt.global_position - proj.global_position).normalized()
			var nd: Vector2 = cur.slerp(want, clampf(HOMING_TURN * delta, 0.0, 1.0)).normalized()
			proj.set("direction", nd)
			if bool(proj.get("face_direction")):
				proj.rotation = nd.angle() + float(weapon.get("ranged_projectile_rotation_offset"))
			alive.append(pair)
		_homing = alive
	process_extra(delta)


func process_extra(_delta: float) -> void:
	pass
