extends Node

## Yaratık - oyuncu derinliği (kullanıcı isteği 2026-10-08, y-sıralama): oyuncunun ÖNÜNDE (ayağı daha aşağıda) ve onunla örtüşen yaratık oyuncunun üstüne
## çizilir (z 2), ARKASINDA kalan/uzak/ölü yaratık eski z'de kalır; ayrılınca z geri döner. Gerçek çizimin sonucu pencereli ekran görüntüsüyle bakıldı.

const CreatureDepthScript := preload("res://scripts/creature_depth.gd")

var _spawned: Array = []


class DeadCreature extends Node2D:
	var is_dead: bool = true


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _creature(pos: Vector2, dead: bool = false, width: int = 32) -> Node2D:
	var e: Node2D = DeadCreature.new() if dead else Node2D.new()
	e.add_to_group("enemies")
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = ImageTexture.create_from_image(Image.create(width, 48, false, Image.FORMAT_RGBA8))
	e.add_child(spr)
	_track(e)
	add_child(e)
	e.global_position = pos
	return e


func test_cover_rule_table() -> void:
	var H: float = CreatureDepthScript.HYSTERESIS
	## oyuncunun ayağı y=100, yaratık 48 px boyunda, aynı x
	assert(CreatureDepthScript.should_cover(130.0, 48.0, 0.0, 100.0, false), "ayağı aşağıda + örtüşüyor -> oyuncunun üstüne")
	assert(not CreatureDepthScript.should_cover(90.0, 48.0, 0.0, 100.0, false), "ayağı yukarıda: yaratık arkada, oyuncu üstte")
	assert(not CreatureDepthScript.should_cover(100.0, 48.0, 0.0, 100.0, false), "aynı hizada: yükselmez (titreme koruması)")
	assert(not CreatureDepthScript.should_cover(100.0 + H, 48.0, 0.0, 100.0, false), "tam eşikte yükselmez")
	assert(CreatureDepthScript.should_cover(100.0 + H + 0.5, 48.0, 0.0, 100.0, false), "eşiği geçince yükselir")
	assert(CreatureDepthScript.should_cover(100.0 - H + 0.5, 48.0, 0.0, 100.0, true), "yükselmişse biraz yukarı çıkana kadar yerinde kalır (histerezis)")
	assert(not CreatureDepthScript.should_cover(100.0 - H - 0.5, 48.0, 0.0, 100.0, true), "histerezis eşiğini geçince iner")
	assert(not CreatureDepthScript.should_cover(200.0, 48.0, 0.0, 100.0, false), "görselin tamamı oyuncunun ayağından aşağıda: örtüşme yok")
	assert(not CreatureDepthScript.should_cover(130.0, 48.0, 90.0, 100.0, false), "yatayda uzak: örtüşme yok")
	assert(CreatureDepthScript.should_cover(180.0, 140.0, 0.0, 100.0, false), "büyük (boss) yaratık uzaktan da örter")


func test_creature_in_front_is_raised_and_restored_when_it_moves_behind() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	_track(player)
	add_child(player)
	player.global_position = Vector2(100, 100) ## ayak = 115
	var overlapping: Node2D = _creature(Vector2(105, 135)) ## ayağı 135, görsel boyu 48 -> üst kenarı 135-48 = 87 < 115: örtüşür
	var behind: Node2D = _creature(Vector2(100, 70))
	var far: Node2D = _creature(Vector2(100, 400))
	var dead: Node2D = _creature(Vector2(100, 140), true)
	var cd: Node = CreatureDepthScript.new()
	_track(cd)
	add_child(cd)
	cd.update_now()
	assert(overlapping.z_index == CreatureDepthScript.FRONT_Z, "oyuncunun önünde ve örtüşen yaratık oyuncunun (z 1) üstüne çıkmalı: z=%d" % overlapping.z_index)
	assert(behind.z_index == 0, "arkada kalan yaratık dokunulmaz")
	assert(far.z_index == 0, "uzak yaratık dokunulmaz")
	assert(dead.z_index == 0, "ölüm animasyonundaki (yerde yatan) yaratık hep oyuncunun altında kalır")
	## yaratık oyuncunun arkasına geçince (ayağı yukarı) eski z'ye döner
	overlapping.global_position = Vector2(105, 60)
	cd.update_now()
	assert(overlapping.z_index == 0, "arkaya geçince z eski haline dönmeli: z=%d" % overlapping.z_index)
	## oyuncu yoksa (ölünce/gizlenince) yükselenler geri döner
	overlapping.global_position = Vector2(105, 135)
	cd.update_now()
	assert(overlapping.z_index == CreatureDepthScript.FRONT_Z)
	player.visible = false
	cd.update_now()
	assert(overlapping.z_index == 0, "karakter listede yoksa yaratık z'si geri alınmalı")
	cd.free()
	_spawned.erase(cd)
	_cleanup()


## KAPANIŞ (2026-10-09, "yeraltı canavarı yan yana dizilince birbirinin üzerinde görünüyor"): oyuncunun önünde yükseltilen yaratığın ÖNÜNDEKİ (ayağı daha aşağıdaki) ve onunla örtüşen komşusu
## yükseltilmezse (oyuncuyla örtüşmüyor), arkadaki yaratık öndekinin üstüne çiziliyordu (z 2 > z 0). Yükseltilen küme ayak sırasında aşağıya doğru kapalı kalmalı.
func test_raised_set_is_closed_downwards_so_creature_order_is_not_inverted() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	_track(player)
	add_child(player)
	player.global_position = Vector2(100, 100) ## ayak = 115
	var a: Node2D = _creature(Vector2(105, 135), false, 96) ## oyuncuyla örtüşüyor: doğrudan yükselir
	var b: Node2D = _creature(Vector2(170, 150), false, 96) ## oyuncudan yatayda uzak (doğrudan yükselmez) AMA a'nın önünde ve a ile örtüşüyor
	var c: Node2D = _creature(Vector2(500, 150), false, 96) ## a'dan yatayda çok uzak: örtüşmez, dokunulmaz
	var d: Node2D = _creature(Vector2(105, 400), false, 96) ## a'nın tamamen altında (görsel örtüşmesi yok)
	var cd: Node = CreatureDepthScript.new()
	_track(cd)
	add_child(cd)
	cd.update_now()
	assert(a.z_index == CreatureDepthScript.FRONT_Z, "oyuncuyla örtüşen yükselir")
	assert(b.z_index == CreatureDepthScript.FRONT_Z, "yükselen yaratığın önündeki örtüşen komşu da yükselir (yoksa arkadaki öndekinin üstüne çizilirdi): z=%d" % b.z_index)
	assert(c.z_index == 0 and d.z_index == 0, "örtüşmeyenlere dokunulmaz: %d %d" % [c.z_index, d.z_index])
	## komşu yukarı (arkaya) çıkınca (ayağı a'nınkinden küçük) kapanışa girmez
	b.global_position = Vector2(170, 120)
	cd.update_now()
	assert(b.z_index == 0, "a'nın ARKASINDAKİ yaratık yükselmez (a zaten öne çıktı, b altta kalmalı): z=%d" % b.z_index)
	cd.free()
	_spawned.erase(cd)
	_cleanup()


func test_close_over_pure_rule() -> void:
	var n1 := Node2D.new()
	var n2 := Node2D.new()
	var n3 := Node2D.new()
	var n4 := Node2D.new()
	for n in [n1, n2, n3, n4]:
		_track(n)
	## pool: düğüm -> [ayak y, x, yarım genişlik, boy]
	var pool: Dictionary = {n1: [100.0, 0.0, 30.0, 40.0], n2: [120.0, 50.0, 30.0, 40.0], n3: [140.0, 100.0, 30.0, 40.0], n4: [400.0, 0.0, 30.0, 40.0]}
	var want: Dictionary = {n1: true}
	var added: int = CreatureDepthScript.close_over(want, pool)
	assert(want.has(n2) and want.has(n3), "zincir: n1 -> n2 (örtüşür) -> n3 (n2 ile örtüşür)")
	assert(not want.has(n4), "yatay/dikey örtüşmeyen alttaki dokunulmaz")
	assert(added == 2)
	assert(CreatureDepthScript.close_over({}, pool) == 0, "yükseltilen yoksa bir şey yapmaz")
	## yukarıdaki (ayağı küçük) komşu kapanışa girmez
	var pool2: Dictionary = {n1: [100.0, 0.0, 30.0, 40.0], n2: [80.0, 20.0, 30.0, 40.0]}
	var want2: Dictionary = {n1: true}
	assert(CreatureDepthScript.close_over(want2, pool2) == 0 and not want2.has(n2), "arkadaki yaratık yükseltilmez")
	for n in [n1, n2, n3, n4]:
		n.free()
		_spawned.erase(n)
