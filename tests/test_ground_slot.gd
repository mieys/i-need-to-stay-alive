extends Node

## ZEMİN YUVASI (madde 573, scripts/ground_slot.gd): harita katmanları ve yaratıklar mutlak z 0 - zemin efekti z -1 olursa haritanın
## ALTINDA kalır (Topuz/Tırpan/Kalkan zeminleri ana haritada hiç görünmüyordu), sona eklenen z 0 ise yaratıkların ÜSTÜNE çizilir.
## Doğrusu: z 0 + sahne kökünde "Harita"nın hemen arkası. Burada test düğümü sahne kökü yapılır, "Harita" + önceden doğmuş bir
## "yaratık" konur, efektler gerçek spawn yollarından doğar. Gerçek çizicide ölçüm: tools/proto_20261111/zemin_fx/.

const GroundSlot := preload("res://scripts/ground_slot.gd")
const TopuzSlamMath := preload("res://scripts/topuz_slam_math.gd")
const TirpanReapMath := preload("res://scripts/tirpan_reap_math.gd")
const KalkanBashMath := preload("res://scripts/kalkan_bash_math.gd")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")


## Test düğümünü sahne kökü yapar; [önceki kök, Harita, yaratık] döner.
func _stage() -> Array:
	var prev: Node = get_tree().current_scene
	get_tree().current_scene = self
	var map_node := Node2D.new()
	map_node.name = "Harita"
	add_child(map_node)
	var mob := Node2D.new()
	mob.name = "Yaratik"
	add_child(mob)
	return [prev, map_node, mob]


func _unstage(st: Array) -> void:
	get_tree().current_scene = st[0]
	for c in get_children():
		c.free()


## Zemin yuvası: z 0 (göreli), Harita'nın hemen arkası, önceden doğmuş yaratığın ÖNÜNDE (ağaçta) = altında çizilir.
func _assert_ground(fx: CanvasItem, st: Array, what: String) -> void:
	assert(fx != null, "%s oluşmalı" % what)
	assert(fx.z_index == 0 and fx.z_as_relative, "%s z 0 olmalı: %d" % [what, fx.z_index])
	assert(fx.get_index() == (st[1] as Node).get_index() + 1, "%s Harita'nın hemen arkasında: %d" % [what, fx.get_index()])
	assert(fx.get_index() < (st[2] as Node).get_index(), "%s yaratığın altında (ağaçta önce)" % what)


func test_weapon_ground_fx_sit_on_the_map() -> void:
	var st: Array = _stage()
	var tp: Dictionary = TopuzSlamMath.make_plan(Vector2.RIGHT, Vector2(50.0, 20.0), 1.0, TopuzSlamMath.REF_OWNER_SCALE)
	_assert_ground(TopuzSlamMath.spawn_fx(TopuzSlamMath.GroundFxScene, self, tp, 1.0), st, "topuz zemini")
	var rp: Dictionary = TirpanReapMath.make_plan(Vector2.RIGHT, Vector2(50.0, 20.0), 1.0, TirpanReapMath.REF_OWNER_SCALE)
	_assert_ground(TirpanReapMath.spawn_fx(TirpanReapMath.GroundFxScene, self, rp, 1.0), st, "tırpan zemini")
	_assert_ground(KalkanBashMath.spawn_point_fx(KalkanBashMath.RingFxScene, self, Vector2(40.0, 0.0), 1.0), st, "kalkan halkası")
	_assert_ground(KalkanBashMath.spawn_point_fx(KalkanBashMath.WallFxScene, self, Vector2.ZERO, 1.0), st, "kalkan duvarı")
	## zemin dışı katmanlar sona eklenir (yaratıkların üstü) - yuvaya taşınmaz
	var top: AnimatedSprite2D = TopuzSlamMath.spawn_fx(TopuzSlamMath.TopFxScene, self, tp, 1.0)
	assert(top.get_index() == get_child_count() - 1 and top.z_index == 60, "üst katman en sonda, z 60")
	var trail: AnimatedSprite2D = TirpanReapMath.spawn_fx(TirpanReapMath.TrailFxScene, self, rp, 1.0)
	assert(trail.get_index() == get_child_count() - 1, "tırpan izi en sonda")
	_unstage(st)


func test_place_without_map_or_off_root() -> void:
	## Harita yoksa (test sahnesi) sıra değişmez, z yine 0
	var prev: Node = get_tree().current_scene
	get_tree().current_scene = self
	var a := Node2D.new()
	add_child(a)
	var b := Node2D.new()
	b.z_index = -1
	add_child(b)
	GroundSlot.place(b)
	assert(b.z_index == 0 and b.get_index() == 1, "haritasız: z 0, sıra aynı")
	## sahne kökünün çocuğu değilse yalnız z
	var c := Node2D.new()
	c.z_index = -1
	a.add_child(c)
	GroundSlot.place(c)
	assert(c.z_index == 0 and c.get_parent() == a, "kök dışı: taşınmaz")
	GroundSlot.place(null) ## çökmez
	get_tree().current_scene = prev
	for n in get_children():
		n.free()


func test_place_on_ground_keeps_z() -> void:
	## EnemyAbilities.place_on_ground (asit gölü, düşenler...) yalnız sırayı değiştirir, z'ye dokunmaz
	var st: Array = _stage()
	var n := Node2D.new()
	n.z_index = 3
	add_child(n)
	EnemyAbilities.place_on_ground(get_tree(), n)
	assert(n.z_index == 3, "z korunur")
	assert(n.get_index() == (st[1] as Node).get_index() + 1, "Harita'nın hemen arkası")
	_unstage(st)
