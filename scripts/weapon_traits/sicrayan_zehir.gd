extends "res://scripts/enchant_behavior.gd"

## Sıçrayan Zehir (Zehir Asası, kalıcı özellik; madde 592, 2026-11-11) - bkz. weapon_traits.gd "sicrayan_zehir". Eski "Bulaşıcı Salgı"nın
## yerine (görünmeyen ölüm bulaşması Oakley'nin Salgın Zehir'iyle aynı koddu; yaratıklar zehir işlemeden ölüyordu).
## Zehrin kendisi ortak poison_* anahtarlarıyla (_generic_hit -> apply_poison_to). Burada: bu asanın zehirlediği düşmanlar kaydedilir
## ({düğüm, zehrin bittiği an, kalan sıçrama}); ZEHİRLİYKEN ölünce (kim öldürürse öldürsün: GameManager.enemy_died her makinede gelir,
## Kırık Buz deseni) cesetten leap_count damla leap_range içindeki en yakın düşmana (önce bu asanın zehirlemediği) sıçrar, LEAP_TIME sonra
## varır: önce zehir (kalan sıçrama 1 azalır = zincir), sonra saldırı gücü x leap_ap hasar (damla öldürürse zincir sürsün diye bu sıra).
## Yalnız sahibin makinesinde çalışır (hasar hit() / zehir el() -> host), görsel EnchantFx "poison_leap" ile herkese (poison_drip_fx.gd leap).
## Yere kalıcı bir şey bırakmaz; aynı anda en çok MAX_IN_FLIGHT damla uçar (kalabalık ölümde ekran dolmasın).

const LimboScript := preload("res://scripts/limbo.gd")
const LEAP_TIME := 0.28
const MAX_IN_FLIGHT := 6
const MATCH_DIST := 8.0
const GRACE_MS := 150 ## zehrin bittiği andan sonra ölüm hâlâ "zehirliyken" sayılır (son tik ile ölüm aynı karede)
const MAX_TRACKED := 200

var _poisoned: Dictionary = {} ## düşman kimliği -> {"node", "until", "hops"}
var _reserved: Dictionary = {} ## uçan damlanın hedefi (kimlik -> true): iki damla aynı düşmana gitmesin
var _in_flight: int = 0
var _next_hops: int = -1 ## >= 0: sıradaki apply_poison_to bir damladan (kalan sıçrama bu)
var leaps: int = 0 ## gönderilen damla sayısı (test / ölçüm)


func _on_setup() -> void:
	if not GameManager.enemy_died.is_connected(_on_enemy_died):
		GameManager.enemy_died.connect(_on_enemy_died)


func _exit_tree() -> void:
	if GameManager.enemy_died.is_connected(_on_enemy_died):
		GameManager.enemy_died.disconnect(_on_enemy_died)


func apply_poison_to(t: Node, extra: Dictionary = {}) -> void:
	super.apply_poison_to(t, extra)
	_track(t, _next_hops if _next_hops >= 0 else n("leap_hops", 3))


func _track(t: Node, hops: int) -> void:
	if not is_enemy(t) or t.get("is_dead") == true:
		return
	var id: int = t.get_instance_id()
	var prev: Dictionary = _poisoned.get(id, {})
	if not prev.is_empty():
		hops = maxi(hops, int(prev["hops"])) ## asanın kendi atışı damlanın kısalmış zincirini tazeler, tersi olmaz
	_poisoned[id] = {"node": t, "until": Time.get_ticks_msec() + int(f("poison_dur", 6.0) * 1000.0), "hops": hops}
	if _poisoned.size() > MAX_TRACKED:
		_prune()


func _prune() -> void:
	var now: int = Time.get_ticks_msec()
	for id in _poisoned.keys():
		var rec: Dictionary = _poisoned[id]
		if now > int(rec["until"]) + GRACE_MS or not is_instance_valid(rec["node"]):
			_poisoned.erase(id)


func _is_ours(id: int, now: int) -> bool:
	return _poisoned.has(id) and now <= int(_poisoned[id]["until"]) + GRACE_MS


func _on_enemy_died(pos: Vector2) -> void:
	if _poisoned.is_empty() or not is_instance_valid(weapon) or not can_act() or LimboScript.is_peer(LimboScript.local_peer()):
		return
	var now: int = Time.get_ticks_msec()
	for id in _poisoned.keys():
		var rec: Dictionary = _poisoned[id]
		var nd = rec["node"]
		if not is_instance_valid(nd):
			_poisoned.erase(id)
			continue
		if nd.get("is_dead") != true:
			continue
		if now > int(rec["until"]) + GRACE_MS:
			_poisoned.erase(id) ## zehri bitmişken öldü
			continue
		if (nd as Node2D).global_position.distance_to(pos) > MATCH_DIST:
			continue
		_poisoned.erase(id)
		_leap_from(pos, nd, int(rec["hops"]))
		return


func _leap_from(pos: Vector2, dead: Node, hops: int) -> void:
	if hops <= 0:
		return
	for i in range(maxi(1, n("leap_count", 1))):
		if _in_flight >= MAX_IN_FLIGHT:
			return
		var t: Node2D = leap_target(pos, dead)
		if t == null:
			return
		_send(pos, t, hops - 1)


## Cesetten leap_range içinde: önce bu asanın zehirlemediği en yakın düşman, yoksa en yakın; uçan bir damlanın hedefi hiç seçilmez.
func leap_target(pos: Vector2, dead: Node) -> Node2D:
	var now: int = Time.get_ticks_msec()
	var best: Node2D = null
	var best_d: float = INF
	var best_fresh: bool = false
	for e in enemies_near(pos, f("leap_range", 110.0), dead):
		if not is_enemy(e) or e.get("is_ability_invisible") == true:
			continue
		var id: int = e.get_instance_id()
		if _reserved.has(id):
			continue
		var fresh: bool = not _is_ours(id, now)
		var d: float = pos.distance_squared_to((e as Node2D).global_position)
		if (fresh and not best_fresh) or (fresh == best_fresh and d < best_d):
			best = e as Node2D
			best_d = d
			best_fresh = fresh
	return best


func _send(from: Vector2, t: Node2D, hops_left: int) -> void:
	var id: int = t.get_instance_id()
	_reserved[id] = true
	_in_flight += 1
	leaps += 1
	fx("poison_leap", from, {"to": t.global_position, "time": LEAP_TIME})
	## Düğüm değil kimlik bağlanır (uçuşta ölüp silinen hedef "previously freed" hatası vermesin); ağaç duraklayınca bekler.
	get_tree().create_timer(LEAP_TIME, false).timeout.connect(_arrive.bind(id, hops_left))


func _arrive(id: int, hops_left: int) -> void:
	_in_flight = maxi(0, _in_flight - 1)
	_reserved.erase(id)
	var t: Object = instance_from_id(id)
	if t == null or not is_instance_valid(t) or t.get("is_dead") == true or not is_instance_valid(weapon):
		return
	_next_hops = maxi(0, hops_left)
	apply_poison_to(t as Node)
	_next_hops = -1
	hit(t as Node, ap() * f("leap_ap", 0.5))
