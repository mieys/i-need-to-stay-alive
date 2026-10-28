extends Node

## Yerdeki XP/altın birleştirme + üst sınır + uyku görselleri (scripts/drop_merge.gd, drop_attraction.gd; kullanıcı isteği 2026-10-12).

const DropMerge := preload("res://scripts/drop_merge.gd")
const DropAttraction := preload("res://scripts/drop_attraction.gd")
const XpOrbScene: PackedScene = preload("res://scenes/xp_orb.tscn")
const GoldScene: PackedScene = preload("res://scenes/gold_drop.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func _begin() -> void:
	DropMerge.reset()
	DropMerge.xp_cap = 300
	DropMerge.gold_cap = 200


func _orb(pos: Vector2, tier: int = 1, value: float = 5.0) -> Node2D:
	var o: Node2D = XpOrbScene.instantiate() as Node2D
	o.set("xp_tier", tier)
	o.set("xp_value", value)
	o.global_position = pos
	add_child(o)
	return o


func _gold(pos: Vector2, amount: int = 3, boss: bool = false) -> Node2D:
	var g: Node2D = GoldScene.instantiate() as Node2D
	g.set("amount", amount)
	g.set("is_boss_gold", boss)
	g.global_position = pos
	add_child(g)
	return g


func test_xp_merges_into_nearby_same_tier_orb_and_keeps_total() -> void:
	_begin()
	var a: Node2D = _orb(Vector2(0, 0), 1, 5.0)
	assert(DropMerge.absorb_xp(Vector2(20, 10), 1, 3.0), "yakındaki aynı kademe küreye emilmeli")
	assert(is_equal_approx(float(a.get("xp_value")), 8.0), "toplam XP korunmalı: %s" % a.get("xp_value"))
	assert(int(a.get("merged_count")) == 2)
	assert(DropMerge.count(DropMerge.KIND_XP) == 1, "yeni düğüm açılmamalı (kayıtlı küre 1)")
	a.queue_free()
	DropMerge.reset()


func test_xp_does_not_merge_across_tier_distance_or_when_magnetized() -> void:
	_begin()
	var a: Node2D = _orb(Vector2(0, 0), 2, 5.0)
	assert(not DropMerge.absorb_xp(Vector2(10, 0), 1, 3.0), "farklı kademe birleşmemeli")
	assert(not DropMerge.absorb_xp(Vector2(200, 0), 2, 3.0), "yarıçap dışı birleşmemeli")
	a.set("is_magnetized", true)
	assert(not DropMerge.absorb_xp(Vector2(10, 0), 2, 3.0), "çekilen küreye eklenmemeli")
	a.queue_free()
	DropMerge.reset()


func test_xp_merge_max_then_new_orb_needed() -> void:
	_begin()
	var a: Node2D = _orb(Vector2(0, 0), 1, 1.0)
	for i in DropMerge.XP_MERGE_MAX - 1:
		assert(DropMerge.absorb_xp(Vector2(5, 5), 1, 1.0), "%d. birleşme" % (i + 1))
	assert(not DropMerge.absorb_xp(Vector2(5, 5), 1, 1.0), "üst sınırda yeni küre gerekir")
	assert(is_equal_approx(float(a.get("xp_value")), float(DropMerge.XP_MERGE_MAX)))
	a.queue_free()
	DropMerge.reset()


func test_over_cap_widens_radius_and_credits_directly() -> void:
	_begin()
	DropMerge.xp_cap = 1
	var a: Node2D = _orb(Vector2(0, 0), 1, 5.0)
	assert(DropMerge.xp_over_cap())
	assert(DropMerge.absorb_xp(Vector2(200, 0), 1, 2.0), "sınır aşılınca geniş yarıçapta birleşmeli")
	assert(not DropMerge.absorb_xp(Vector2(900, 0), 1, 2.0), "çok uzakta yine birleşmez")
	## Doğrudan yazım: tek oyunculu, oyuncu yerine "player" grubunda düz Node2D (canlı sayılır).
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	var before: float = GameManager.team_xp
	assert(DropMerge.credit_xp(get_tree(), Vector2(900, 0), 0.5), "oyuncuya doğrudan yazılmalı")
	assert(GameManager.team_xp >= before and (GameManager.team_xp > before or GameManager.team_level > 1), "XP havuzuna eklenmeli")
	var gold_before: int = GameManager.gold
	assert(DropMerge.credit_gold(get_tree(), Vector2(900, 0), 4))
	assert(GameManager.gold == gold_before + 4, "altın yazılmalı")
	p.remove_from_group("player")
	p.queue_free()
	a.queue_free()
	DropMerge.reset()


func test_gold_merges_but_boss_gold_never_does() -> void:
	_begin()
	var g: Node2D = _gold(Vector2(0, 0), 3)
	var b: Node2D = _gold(Vector2(300, 0), 5, true)
	assert(DropMerge.absorb_gold(Vector2(10, 0), 2))
	assert(int(g.get("amount")) == 5, "altın toplamı korunmalı: %s" % g.get("amount"))
	assert(not DropMerge.absorb_gold(Vector2(300, 0), 2), "boss altınına birleşme yok")
	assert(int(b.get("amount")) == 5)
	g.queue_free()
	b.queue_free()
	DropMerge.reset()


func test_freed_drops_unregister() -> void:
	_begin()
	var a: Node2D = _orb(Vector2(0, 0))
	assert(DropMerge.count(DropMerge.KIND_XP) == 1)
	remove_child(a)
	assert(DropMerge.count(DropMerge.KIND_XP) == 0, "ağaçtan çıkan küre kayıttan düşmeli")
	a.free()
	DropMerge.reset()


func test_sleeping_drop_pauses_visuals_and_wakes() -> void:
	_begin()
	var o: Node2D = _orb(Vector2(0, 0))
	var spr: AnimatedSprite2D = o.get_node("AnimatedSprite2D")
	## 2026-10-21 sade kristal: XP küresinin _process'i yok (nefes ölçeği kalktı) - uyanıklık = animasyon + bayrak.
	assert(not o.is_processing(), "sade kristal _process çalıştırmamalı")
	assert(spr.is_playing())
	DropAttraction.set_visual_awake(o, false)
	assert(not o.is_processing(), "uyuyan küre _process çalıştırmamalı")
	assert(not spr.is_playing(), "uyuyan küre animasyonu durmalı")
	DropAttraction.wake(o)
	assert(spr.is_playing() and not bool(o.get("visual_asleep")), "uyanınca görseller geri gelmeli")
	o.queue_free()
	DropMerge.reset()


func test_extra_pickups_apply_item_heals_without_sound() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.max_health = 100.0
	player.health = 10.0
	player.item_xp_heal_chance = 1.0
	player.on_xp_collected_extra(3)
	assert(is_equal_approx(player.health, 13.0), "birleşen 3 küre fazlası 3 can vermeli: %s" % player.health)
	player.queue_free()


## Çift ödül (2026-10-12): bir istemcinin isteği küreyi zaten sahiplendiyse host'un fiziksel teması ikinci kez XP vermemeli.
func test_claimed_orb_gives_no_second_xp() -> void:
	_begin()
	var o: Node2D = _orb(Vector2(0, 0), 1, 3.0)
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	o.set_meta("claimed", true)
	var before: float = GameManager.team_xp
	var lvl: int = GameManager.team_level
	o._on_body_entered(p)
	assert(is_equal_approx(GameManager.team_xp, before) and GameManager.team_level == lvl, "sahiplenilmiş küre XP vermemeli")
	p.remove_from_group("player")
	p.queue_free()
	o.queue_free()
	DropMerge.reset()
