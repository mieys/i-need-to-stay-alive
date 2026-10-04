extends "res://scripts/enchant_behavior.gd"

## BIGerang (Bumerang) - bkz. EnchantDefs "bigerang". Bumerang düşmanları delip geçer, dönüşte de vurur ve her isabette
## büyür (boomerang_projectile.gd enchant_* anahtarları - mermi görünümünün "props"u ile kasterde VE uzak kopyada aynı büyür).
## 2026-10-04 denge turu (kullanıcı: "çok ağır ve efektsiz"): eski kural (delişte x1,03 çarpımsal, uç noktada sıfırlanır)
## 2,5 kata ancak tek gidişte 31 düşman delerek varıyordu - fiilen hiç büyümüyor, Final hiç açılmıyordu; delip geçtiği için
## her atış tam menzile gidip normal bumeranga göre ~2,5 kat seyrek atılıyordu. Yeni kural: büyüme toplamalı (+grow/isabet,
## gidiş VE dönüş), uç noktada sıfırlanmaz, büyüklük ATIŞTAN ATIŞA taşınır (enchant_grow_start); GROW_HOLD sn isabet yoksa
## yavaşça küçülür. Büyüklük hasarı da artırır (size_dmg: hasar x (1 + (boyut-1) x size_dmg)). Gidiş out_speed kat hızlı.
## Final (Titanyum Girdabı): en büyük boyuttaki bumerang çevresini çeker + vurur, büyüklük hiç küçülmez.

const VORTEX_RADIUS := 120.0
const VORTEX_EVERY := 0.3
const VORTEX_AP := 0.10
const RETURN_SPEED_MULT := 1.4
const GROW_HOLD := 2.0 ## son isabetten bu kadar sn sonra küçülmeye başlar
const SHRINK_PER_SEC := 0.25 ## boyut katsayısı / sn

var _projs: Array = []
var _vortex_t: float = 0.0


func _size() -> float:
	return float(keep_get("big_size", 1.0))


func look_extra(_proj: Node2D, d: Dictionary) -> Dictionary:
	## hit_on_return: kullanıcı bildirimi (2026-10-01) "BIGerang düşmanı deldikten sonra oyuncuya dönerken hasar vermiyor" -
	## düz bumerang dönüşte bilerek vurmaz (2026-09-26 kararı), BIGerang bunu açıyor. Düşman başına gidişte bir, dönüşte bir.
	d["props"] = {"enchant_pierce_all": true, "enchant_grow": f("grow", 0.08), "enchant_grow_max": f("grow_max", 2.0),
		"enchant_grow_start": minf(_size(), f("grow_max", 2.0)), "enchant_size_dmg": f("size_dmg", 0.3),
		"enchant_titan": flag("titan"), "hit_on_return": true, "enchant_return_speed_mult": RETURN_SPEED_MULT,
		"enchant_out_speed_mult": f("out_speed", 1.3)}
	return d


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	_projs.append(proj)


## Büyüklük kayıtta mermiyle aynı kuralla ilerler (mermi kendi boyutunu kendisi büyütür, burada sadece bir sonraki atışa
## taşınacak değer tutulur).
func hit_extra(t: Node, _dmg: float, _is_primary: bool, proj: Node2D) -> void:
	if proj == null or not is_enemy(t):
		return
	var cur: float = _size()
	if is_instance_valid(proj) and "_grow_factor" in proj:
		cur = maxf(cur, float(proj.get("_grow_factor")))
	keep_set("big_size", cur)
	keep_set("big_last_hit", Time.get_ticks_msec())


func process_extra(delta: float) -> void:
	var alive: Array = []
	for pr in _projs:
		## Tipsiz: bumerang yakalanınca serbest kalır (bkz. hafıza: freed == null).
		if is_instance_valid(pr):
			alive.append(pr)
	_projs = alive
	if _projs.is_empty() and not flag("titan") and _size() > 1.0:
		var idle: float = float(Time.get_ticks_msec() - int(keep_get("big_last_hit", 0))) / 1000.0
		if idle > GROW_HOLD:
			keep_set("big_size", maxf(1.0, _size() - SHRINK_PER_SEC * delta))
	if not flag("titan") or _projs.is_empty():
		return
	_vortex_t -= delta
	if _vortex_t > 0.0:
		return
	_vortex_t = VORTEX_EVERY
	for pr in _projs:
		if not pr.has_method("is_grown_max") or not pr.is_grown_max():
			continue
		var at: Vector2 = (pr as Node2D).global_position
		sprite("vortex", at, {"loop_time": VORTEX_EVERY + 0.1, "scale": VORTEX_RADIUS / (99.0 * 1.212), "z": 8})
		for e in enemies_near(at, VORTEX_RADIUS):
			hit(e, ap() * VORTEX_AP)
			if e.is_boss:
				continue
			var to_c: Vector2 = at - e.global_position
			if to_c.length() > 12.0:
				e.apply_element("knock", {"dir": to_c.normalized(), "dist": minf(30.0, to_c.length() - 10.0), "quiet": true})
