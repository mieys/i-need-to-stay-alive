extends "res://scripts/enchant_behavior.gd"

## Anka Kuşu (EnchantDefs "ates_anka"): her N öldürmede (player.gd _notify_enchants_kill -> on_event "kill") etrafında
## dönen ateş kuşları (enchant_area.gd "bird", sahibini izler). Final (Vitamin): kuşlar kalıcı + ölümcül darbede bir kez
## %50 canla kalkış ve patlama (player.gd die -> _enchant_cheat_death), 180 sn bekleme. Sayaç ve bekleme silahın
## meta'sında (keep_*) - Aşkın kartı davranışı yeniden kurunca sıfırlanmasın.

const REBIRTH_COOLDOWN_MSEC := 180000
const REBIRTH_RADIUS := 180.0
const PERMANENT := 1000000.0
const FIRE := Color(1.0, 0.55, 0.2)


func _on_setup() -> void:
	if flag("phoenix_rebirth"):
		_ensure_permanent_birds()


func on_event(event: String, _data: Dictionary) -> void:
	if event != "kill" or flag("phoenix_rebirth"):
		return
	var kills: int = int(keep_get("anka_kills", 0)) + 1
	if kills >= n("bird_kills", 20):
		kills = 0
		_spawn_birds(f("bird_dur", 6.0))
	keep_set("anka_kills", kills)


func _spawn_birds(dur: float) -> void:
	var p: Node = owner_player()
	if p == null:
		return
	var count: int = n("bird_count", 1)
	for k in range(count):
		tagged_area("bird", "bird", p.global_position, {"follow": true, "duration": dur, "orbit_radius": 70.0,
			"orbit_speed": 3.2, "angle": TAU * float(k) / float(count), "touch": 28.0,
			"damage": ap() * f("bird_dmg") * pw("area"), "burn_tick": ap() * 0.10 * pw("area"), "ap": ap(),
			"blast": flag("bird_blast"), "blast_dmg": ap() * 1.5 * pw("area"), "color": FIRE})


func _ensure_permanent_birds() -> void:
	if own_count("bird") >= n("bird_count", 1):
		return
	for nd in get_tree().get_nodes_in_group(own_group("bird")):
		nd.queue_free()
	_spawn_birds(PERMANENT)


func process_extra(_delta: float) -> void:
	## Kalıcı kuşlar: bir sahne geçişi / ölüm-dirilme sonrası kaybolduysa yeniden çağır.
	if flag("phoenix_rebirth") and Engine.get_process_frames() % 60 == 0 and can_act():
		_ensure_permanent_birds()


func cheat_death() -> bool:
	if not flag("phoenix_rebirth"):
		return false
	var now: int = Time.get_ticks_msec()
	var last: int = int(keep_get("anka_rebirth", -REBIRTH_COOLDOWN_MSEC))
	if now - last < REBIRTH_COOLDOWN_MSEC:
		return false
	keep_set("anka_rebirth", now)
	var p: Node = owner_player()
	if p == null:
		return false
	p.set("health", float(p.get("max_health")) * 0.5)
	if p.has_signal("health_changed"):
		p.emit_signal("health_changed", p.get("health"), p.get("max_health"))
	blast(p.global_position, REBIRTH_RADIUS, ap() * 3.0 * power, FIRE)
	fx("burst", p.global_position, {"palette": "fire", "count": 40, "speed": 260.0, "life": 0.8})
	fx("text", p.global_position, {"text": "Küllerinden Doğuş", "color": Color(1.0, 0.7, 0.3)})
	return true
