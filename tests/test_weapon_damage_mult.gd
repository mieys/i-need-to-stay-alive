extends Node

## 2026-10-12 deneme: silah sınırı 3'e düştü, telafi olarak TÜM silah hasarı x1,5; Bıçak/Pençe/Topuz (kılıç hariç) ek x1,4 (weapon.gd damage_stat_mult).

const RemotePlayerScript: GDScript = preload("res://scripts/remote_player.gd")


func _scene_mult(key: String) -> float:
	var scene: PackedScene = RemotePlayerScript.WEAPON_SCENES.get(key)
	var w: Node = scene.instantiate()
	var m: float = float(w.call("damage_stat_mult"))
	w.free()
	return m


func test_every_weapon_gets_fifty_percent_and_only_three_melee_get_extra() -> void:
	assert(RemotePlayerScript.WEAPON_SCENES.size() == 15, "15 silah")
	for key in RemotePlayerScript.WEAPON_SCENES.keys():
		var want: float = 1.5 * 1.4 if key in ["dagger", "pence", "topuz"] else 1.5
		assert(absf(_scene_mult(key) - want) < 0.0001, "%s çarpanı %f olmalıydı: %f" % [key, want, _scene_mult(key)])


func test_weapon_slot_cap_is_three() -> void:
	const PlayerScript: GDScript = preload("res://scripts/player.gd")
	assert(PlayerScript.MAX_OWNED_WEAPONS == 3, "silah sınırı 3 (deneme)")
