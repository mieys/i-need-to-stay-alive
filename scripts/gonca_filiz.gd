extends RefCounted

## FİLİZ (madde 682) - Zehirli Gonca'nın tohumundan çıkan küçük çiçek canavarı ("filiz" ailesi; SADECE host / tek oyunculuda process()).
##   - Doğunca topraktan çıkar ("grow" klibi), yerinden KIPIRDAMAZ (SUMMON_STATS hız 0).
##   - Yaklaşan oyuncuyu ısırır: C++ temas saldırısı, isabet handle_melee_hit -> "gonca_bite" (hasar + zehir, player.gd).
##   - Kendisi de belli aralıklarla etrafına bir tohum saçar (gonca_boss.gd throw_seed, tavan bossun filiz_cap'i) -> sürü giderek çoğalır.
##   - Öldürülünce (die, host) bossun canından ve kalkanından pay keser (gonca_boss.gd drain_boss) + bossa akan öz görseli (gonca_drain).
##     Boss onu Kök Göçü'nde içine çekerse (meta "gonca_absorbed", ödülsüz dağılma) kesinti YOK. Boss ölünce/yok olunca ödülsüz dağılır.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const BossKit := preload("res://scripts/gonca_boss.gd")

const OWNER_CHECK := 0.5
const SEED_FIRST_MIN := 6.0
const SEED_FIRST_MAX := 9.0
const SEED_CD_MIN := 9.0
const SEED_CD_MAX := 13.0
const SEED_RANGE_MIN := 70.0
const SEED_RANGE_MAX := 200.0
const SEED_WINDUP := 0.45
const SEED_BUSY := 0.9
const GROW_TIME := 0.45
const MOUTH := Vector2(0.0, -22.0)

var e: Node2D = null
var _owner_t: float = 0.0
var _seed_cd: float = 0.0
var _busy: float = 0.0
var _throw_at: float = -1.0
var _grown: bool = false


func setup(owner_enemy: Node2D) -> void:
	e = owner_enemy
	_seed_cd = randf_range(SEED_FIRST_MIN, SEED_FIRST_MAX)


func _boss() -> Node2D:
	var b: Variant = e.get_meta("summoner", null)
	if b == null or not is_instance_valid(b) or (b as Node).get("is_dead") == true:
		return null
	return b as Node2D


func process(delta: float, _player: Node2D, _dist: float) -> void:
	if not _grown:
		_grown = true
		_busy = GROW_TIME
		e.set("ability_move_lock", GROW_TIME)
		e.set("_ranged_timer", maxf(float(e.get("_ranged_timer")), GROW_TIME))
		e.call("emit_ability_vfx", "boss_event", {"k": "anim", "n": "grow", "d": GROW_TIME})
	_owner_t += delta
	if _owner_t >= OWNER_CHECK:
		_owner_t = 0.0
		if _boss() == null:
			e.call("emit_ability_vfx", "boss_event", {"k": "dismiss"})
			return
	if _throw_at >= 0.0:
		_throw_at -= delta
		if _throw_at < 0.0:
			_throw()
	if _busy > 0.0:
		_busy -= delta
		return
	_seed_cd -= delta
	if _seed_cd > 0.0:
		return
	var boss: Node2D = _boss()
	if boss == null:
		return
	var kit: Variant = _boss_kit(boss)
	_seed_cd = randf_range(SEED_CD_MIN, SEED_CD_MAX) * (float(kit.haste()) if kit != null else 1.0)
	if kit != null and BossKit.filiz_count(boss) >= int(kit.filiz_cap()):
		return ## tavan dolu: bu tur saçmaz
	_busy = SEED_BUSY
	e.set("ability_move_lock", SEED_BUSY)
	e.set("_ranged_timer", maxf(float(e.get("_ranged_timer")), SEED_BUSY))
	e.call("emit_ability_vfx", "boss_event", {"k": "anim", "n": "spit", "d": 0.9})
	_throw_at = SEED_WINDUP


func _throw() -> void:
	var boss: Node2D = _boss()
	if boss == null or e.get("is_dead") == true:
		return
	var to: Vector2 = e.global_position + Vector2.from_angle(randf() * TAU) * randf_range(SEED_RANGE_MIN, SEED_RANGE_MAX)
	BossKit.throw_seed(boss, e.global_position + MOUTH, BossKit.free_landing(e.global_position, to))


static func _boss_kit(boss: Node) -> Variant:
	var ab: Variant = boss.get("_abilities")
	if ab == null:
		return null
	var kit: Variant = (ab as Object).get("_boss_kit")
	return kit if kit != null and (kit as Object).has_method("filiz_cap") else null


## Isırık: hasar + zehir (player.gd take_special_damage "gonca_bite"). true = vuruş burada işlendi.
func handle_melee_hit(target: Node) -> bool:
	AbilitiesScript.deal_special_damage(target, float(e.get("contact_damage")), e, "gonca_bite")
	return true


## Öldü (enemy.gd die(); istemcide de çalışır -> karar yalnız host / tek oyunculuda): bossun canı ve kalkanı azalır.
func on_owner_died() -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	if e.has_meta("gonca_absorbed"):
		return
	var boss: Node2D = _boss()
	if boss == null:
		return
	var data: Dictionary = {"to": boss.global_position + Vector2(0.0, -30.0)}
	AbilitiesScript.spawn_world_fx(e.get_tree(), "gonca_drain", e.global_position + Vector2(0.0, -12.0), data, true, boss, 0.0)
	AbilitiesScript._broadcast_world_fx("gonca_drain", e.global_position + Vector2(0.0, -12.0), data)
	BossKit.drain_boss(boss, BossKit.DRAIN_FRACTION)
