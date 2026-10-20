extends "res://scripts/enchant_behavior.gd"

## Siper (Kalkan) - bkz. weapon_traits.gd "siper" (madde 338). Kalkan darbesi (weapon.gd _kalkan_contact) vurduğu düşman başına
## SAHİBİNE sabit mana kalkanı doldurur (yüzde DEĞİL - kullanıcı: "% lik kalkan yenilemesi çok op"); dostlara gitmez (heal_shield
## mirror = false: Kalkan Bağı yansıması da yok; boost = false: iyileştirme gücü çarpmaz, sayılar yazıldığı gibi). Taşan Siper: doldurulamayan
## kısım geçici havuza (en fazla siper_surplus) birikir, sahibe gelen hasarı kalkandan ÖNCE karşılar (on_owner_damaged), SURPLUS_MS darbesiz
## kalınca söner. Ağır Kenar: kalkan %50 üstündeyken darbe x(1 + siper_heavy). Sarsıcı Darbe: vurulanlar yavaşlar. Final (siper_wall = N):
## her N. darbe 360° (KalkanBashMath.WALL_R), x1,5 hasar (%100 -> %150), 1 sn sersem, kalkan + üst sınır x2. Sadece kasterde çalışır.

const SURPLUS_MS := 4000
const SLOW_DUR := 1.5
const WALL_STUN := 1.0
const WALL_DAMAGE_MULT := 1.5 ## %100 -> %150
const WALL_GAIN_MULT := 2.0
const HEAVY_AT := 0.5
const SRC := "w:kalkan" ## hasar istatistiği (BalanceLog on_gain / on_prevented)
const SURPLUS_TEXT := Color(1.0, 0.93, 0.66)

var _surplus: float = 0.0
var _surplus_until_msec: int = 0
var bashes: int = 0 ## gözlem/test
var gained: float = 0.0 ## doldurulan kalkan toplamı (gözlem/test)


## Bu darbe Final mi (attacks on_fire'da arttı: 5., 10., ... darbe).
func wants_wall() -> bool:
	return can_act() and n("siper_wall") > 0 and every(n("siper_wall"))


func _shield_ratio() -> float:
	var p: Node = owner_player()
	if p == null:
		return 0.0
	var mx: float = float(p.get("item_shield_max")) if p.get("item_shield_max") != null else 0.0
	if mx <= 0.0:
		return 0.0
	return float(p.get("item_shield_hp")) / mx


func bash_damage_mult(wall: bool) -> float:
	var m: float = WALL_DAMAGE_MULT if wall else 1.0
	if f("siper_heavy") > 0.0 and _shield_ratio() > HEAVY_AT:
		m *= 1.0 + f("siper_heavy")
	return m


## Darbenin dolduracağı kalkan: düşman başına siper_per (elit/boss 2 sayılır), darbe başına siper_cap; Final ikisini de x2.
func bash_gain(victims: Array, wall: bool) -> float:
	var per: float = f("siper_per", 1.0)
	var total: float = 0.0
	for v in victims:
		if not is_instance_valid(v):
			continue
		total += per * (2.0 if (status(v, "boss") or v.get("is_elite") == true) else 1.0)
	var cap: float = f("siper_cap", 3.0)
	if wall:
		total *= WALL_GAIN_MULT
		cap *= WALL_GAIN_MULT
	return minf(total, cap)


func on_bash(victims: Array, wall: bool) -> void:
	if not can_act():
		return
	bashes += 1
	if f("siper_surplus") > 0.0:
		_surplus_until_msec = Time.get_ticks_msec() + SURPLUS_MS ## her darbe havuzu canlı tutar
	if victims.is_empty():
		return
	for v in victims:
		if wall:
			el(v, "stun", {"dur": WALL_STUN})
		if f("siper_slow") > 0.0:
			el(v, "slow", {"pct": f("siper_slow"), "dur": SLOW_DUR})
	var p: Node = owner_player()
	if p == null or not p.has_method("heal_shield") or (p.has_method("is_safe_zone_frozen") and p.is_safe_zone_frozen()):
		return
	var amount: float = bash_gain(victims, wall)
	if amount <= 0.0 or float(p.get("item_shield_max")) <= 0.0:
		return
	var before: float = float(p.get("item_shield_hp"))
	p.heal_shield(amount, false, false, StringName(SRC))
	var added: float = maxf(0.0, float(p.get("item_shield_hp")) - before)
	gained += added
	var over: float = amount - added
	if f("siper_surplus") > 0.0 and over > 0.0:
		_surplus = minf(f("siper_surplus"), _surplus + over)


func surplus() -> float:
	return _surplus if Time.get_ticks_msec() <= _surplus_until_msec else 0.0


## Taşan Siper havuzu sahibe gelen hasarı kalkandan ÖNCE karşılar (player.gd _enchant_owner_damaged).
func on_owner_damaged(amount: float, _source: Node) -> float:
	var pool: float = surplus()
	if pool <= 0.0 or amount <= 0.0:
		return amount
	var take: float = minf(pool, amount)
	_surplus = pool - take
	BalanceLogScript.on_prevented(SRC, take)
	var p: Node = owner_player()
	if p and p.has_method("_spawn_floating_text"):
		p._spawn_floating_text("%d" % int(round(take)), SURPLUS_TEXT)
	return amount - take


func process_extra(_delta: float) -> void:
	if _surplus > 0.0 and Time.get_ticks_msec() > _surplus_until_msec:
		_surplus = 0.0
