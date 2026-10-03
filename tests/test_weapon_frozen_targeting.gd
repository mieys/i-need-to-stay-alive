extends Node

## Kullanıcı bildirimi doğrulaması: "buz asası veya büyücü kız ile donmuş
## düşmanlar hedef alınamıyor" - bkz. weapon.gd _get_nearest_unfrozen_enemy
## üstündeki düzeltme notu. Bu testler: (1) en yakın düşman zaten donmamışsa
## davranış değişmediğini, (2) en yakın düşman donmuşsa VE yakında donmamış
## bir alternatif YOKSA artık donmuş düşmanın hedeflendiğini, (3) en yakın
## düşman donmuşsa AMA benzer mesafede donmamış bir alternatif VARSA hala o
## alternatifin (donmayı yaymak için) tercih edildiğini doğruluyor.

const WeaponScene: PackedScene = preload("res://scenes/weapon_buz_asasi.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")


## Yaratıklar test sonunda free() ile ANINDA silinir: queue_free'de bir sonraki test başladığında hâlâ "enemies" grubunda
## kalıp hedef adayı oluyorlardı (testler arası sızıntı). await physics_frame: konum C++ EnemyWorld'e (aday sorgusu) geçsin.
func _make_enemy(pos: Vector2, frozen: bool) -> Node:
	var e = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.is_frozen = frozen
	return e


func test_nearest_unfrozen_used_when_nearest_is_unfrozen() -> void:
	var weapon = WeaponScene.instantiate()
	add_child(weapon)
	weapon.global_position = Vector2.ZERO

	var close_unfrozen: Node = _make_enemy(Vector2(20, 0), false)
	## 120 px: Buz Asası'nın "80 px içindeki donmamışlardan RASTGELE seç" havuzunun (PREFER_UNFROZEN_MAX_EXTRA_DIST) dışında -
	## eskiden 100'de (yakındakine tam 80 px) havuza girip sonucu %50 şansa bırakıyordu (2026-10-03 test düzeltmesi).
	var far_unfrozen: Node = _make_enemy(Vector2(120, 0), false)
	await get_tree().physics_frame

	var target = weapon._get_nearest_unfrozen_enemy()
	assert(target == close_unfrozen, "En yakın donmamış düşman hedeflenmedi")

	weapon.queue_free()
	close_unfrozen.free()
	far_unfrozen.free()


func test_close_frozen_enemy_is_targeted_when_no_close_unfrozen_alternative() -> void:
	var weapon = WeaponScene.instantiate()
	add_child(weapon)
	weapon.global_position = Vector2.ZERO

	## Donmuş düşman ÇOK yakın, donmamış tek düşman ise çok daha uzakta
	## (PREFER_UNFROZEN_MAX_EXTRA_DIST'ten çok daha fazla fark) - artık
	## bitirilebilmesi için donmuş düşman hedeflenmeli.
	var close_frozen: Node = _make_enemy(Vector2(10, 0), true)
	var far_unfrozen: Node = _make_enemy(Vector2(150, 0), false)
	await get_tree().physics_frame

	var target = weapon._get_nearest_unfrozen_enemy()
	assert(target == close_frozen,
		"Yakın donmuş düşman, uzak donmamış bir alternatif yüzünden hedeflenemedi (bug geri geldi)")

	weapon.queue_free()
	close_frozen.free()
	far_unfrozen.free()


func test_frozen_enemy_still_avoided_when_similarly_close_unfrozen_exists() -> void:
	var weapon = WeaponScene.instantiate()
	add_child(weapon)
	weapon.global_position = Vector2.ZERO

	## Donmuş düşman biraz daha yakın ama donmamış bir alternatif de
	## NEREDEYSE aynı mesafede - donmayı yaymak için hala donmamış olan
	## tercih edilmeli.
	var close_frozen: Node = _make_enemy(Vector2(10, 0), true)
	var nearby_unfrozen: Node = _make_enemy(Vector2(30, 0), false)
	await get_tree().physics_frame

	var target = weapon._get_nearest_unfrozen_enemy()
	assert(target == nearby_unfrozen,
		"Yakında donmamış bir alternatif varken donmuş düşman yine de hedeflendi")

	weapon.queue_free()
	close_frozen.free()
	nearby_unfrozen.free()
