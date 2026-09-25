extends "res://scripts/enchant_behavior.gd"

## Kar Fırtınası (EnchantDefs "buz_firtina"): N sn'de bir etrafında süreli kar fırtınası (enchant_area.gd "blizzard" -
## tik hasarı + yavaşlatma, 2 sn kalan donar). VI: fırtına sahibini izler; final (Vitamin) Kutup Girdabı - kalıcı,
## izleyen fırtına + içindeki düşman başına can (silah grubu ile tek kopya).

const PERMANENT := 1000000.0

var _timer: float = 2.0


func _on_setup() -> void:
	if flag("blizzard_aura"):
		_ensure_aura()


func _params(dur: float, follow: bool) -> Dictionary:
	return {"radius": f("blizzard_radius", 120.0), "duration": dur, "damage": ap() * 0.3 * pw("area"),
		"freeze": flag("blizzard_freeze"), "follow": follow, "regen": 0.3 * power if flag("blizzard_aura") else 0.0}


func _ensure_aura() -> void:
	if own_count("aura") > 0:
		return
	var p: Node = owner_player()
	if p:
		tagged_area("aura", "blizzard", p.global_position, _params(PERMANENT, true))


func process_extra(delta: float) -> void:
	if flag("blizzard_aura"):
		if Engine.get_process_frames() % 60 == 0 and can_act():
			_ensure_aura()
		return
	if f("blizzard_cd") <= 0.0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var p: Node = owner_player()
	if not can_act() or nearest_enemy(p.global_position, f("blizzard_radius", 120.0) + 60.0) == null:
		_timer = 0.5
		return
	_timer = f("blizzard_cd")
	area("blizzard", p.global_position, _params(f("blizzard_dur", 2.0), flag("blizzard_follow")))
